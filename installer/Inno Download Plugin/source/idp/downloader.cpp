#include <process.h>
#include <direct.h>
#include "downloader.h"
#include "file.h"
#include "trace.h"

Downloader::Downloader()
{
    stopOnError         = true;
    ownMsgLoop          = false;
    preserveFtpDirs     = true;
    filesSize           = 0;
    downloadedFilesSize = 0;
    ui                  = NULL;
    errorCode           = 0;
    internet            = NULL;
    downloadThread      = NULL;
    downloadCancelled   = false;
    downloadPaused      = false;
    finishedCallback    = NULL;
}

Downloader::~Downloader()
{
    clearFiles();
    clearMirrors();
    clearFtpDirs();
}

void Downloader::setUi(Ui *newUi)
{
    ui = newUi;
}

void Downloader::setInternetOptions(InternetOptions opt)
{
    internetOptions = opt;

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        NetFile *file = i->second;
        file->url.internetOptions = opt;
    }
}

void Downloader::setComponents(tstring comp)
{
    tstringtoset(components, comp, _T(','));
}

void Downloader::setFinishedCallback(FinishedCallback callback)
{
    finishedCallback = callback;
}

void Downloader::addFile(tstring url, tstring filename, DWORDLONG size, tstring comp)
{
    if(!files.count(url))
    {
        files[url] = new NetFile(url, filename, size, comp);
        files[url]->url.internetOptions = internetOptions;
    }
}

void Downloader::addMirror(tstring url, tstring mirror)
{
    mirrors.insert(pair<tstring, tstring>(url, mirror));
}

void Downloader::setMirrorList(Downloader *d)
{
    mirrors = d->mirrors;
}

void Downloader::clearFiles()
{
    if(files.empty())
        return;

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        NetFile *file = i->second;
        delete file;
    }

    files.clear();
    filesSize           = 0;
    downloadedFilesSize = 0;
}

void Downloader::clearMirrors()
{
    if(!mirrors.empty())
        mirrors.clear();
}

void Downloader::clearFtpDirs()
{
    if(ftpDirs.empty())
        return;

    for(list<FtpDir *>::iterator i = ftpDirs.begin(); i != ftpDirs.end(); i++)
    {
        FtpDir *f = *i;
        delete f;
    }

    ftpDirs.clear();
}

int Downloader::filesCount()
{
    return (int)files.size();
}

int Downloader::ftpDirsCount()
{
    return (int)ftpDirs.size();
}

bool Downloader::filesDownloaded()
{
    if(!ftpDirsProcessed())
        return false;

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        NetFile *file = i->second;
        
        if(!file->selected(components))
            continue;

        if(!file->downloaded)
            return false;
    }

    return true;
}

bool Downloader::ftpDirsProcessed()
{
    for(list<FtpDir *>::iterator i = ftpDirs.begin(); i != ftpDirs.end(); i++)
    {
        FtpDir *dir = *i;

        if(!dir->selected(components))
            continue;

        if(!dir->processed)
            return false;
    }

    return true;
}

bool Downloader::fileDownloaded(tstring url)
{
    return files[url]->downloaded;
}

bool Downloader::openInternet()
{
    if(internet)
        return true; //already opened

#ifdef _DEBUG
    _TCHAR *atype;

    switch(internetOptions.accessType)
    {
    case INTERNET_OPEN_TYPE_DIRECT                     : atype = _T("INTERNET_OPEN_TYPE_DIRECT"); break;
    case INTERNET_OPEN_TYPE_PRECONFIG                  : atype = _T("INTERNET_OPEN_TYPE_PRECONFIG"); break;
    case INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY: atype = _T("INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY"); break;
    case INTERNET_OPEN_TYPE_PROXY                      : atype = _T("INTERNET_OPEN_TYPE_PROXY"); break;
    default: atype = _T("Unknown (error)!");
    }

    TRACE(_T("Opening internet..."));
    TRACE(_T("    access type: %s"), atype);
    TRACE(_T("    proxy name : %s"), internetOptions.proxyName.empty() ? _T("(none)") : internetOptions.proxyName.c_str());
#endif

    if(!internet)
        if(!(internet = InternetOpen(internetOptions.userAgent.c_str(), internetOptions.accessType, 
                                     internetOptions.proxyName.empty() ? NULL : internetOptions.proxyName.c_str(), 
                                     NULL, 0)))
            return false;

    TRACE(_T("Setting timeouts..."));

    if(internetOptions.connectTimeout != TIMEOUT_DEFAULT)
        InternetSetOption(internet, INTERNET_OPTION_CONNECT_TIMEOUT, &internetOptions.connectTimeout, sizeof(DWORD));

    if(internetOptions.sendTimeout    != TIMEOUT_DEFAULT)
        InternetSetOption(internet, INTERNET_OPTION_SEND_TIMEOUT,    &internetOptions.sendTimeout,    sizeof(DWORD));

    if(internetOptions.receiveTimeout != TIMEOUT_DEFAULT)
        InternetSetOption(internet, INTERNET_OPTION_RECEIVE_TIMEOUT, &internetOptions.receiveTimeout, sizeof(DWORD));

#ifdef _DEBUG
    DWORD connectTimeout, sendTimeout, receiveTimeout, bufSize = sizeof(DWORD);

    InternetQueryOption(internet, INTERNET_OPTION_CONNECT_TIMEOUT, &connectTimeout, &bufSize);
    InternetQueryOption(internet, INTERNET_OPTION_SEND_TIMEOUT,    &sendTimeout,    &bufSize);
    InternetQueryOption(internet, INTERNET_OPTION_RECEIVE_TIMEOUT, &receiveTimeout, &bufSize);

    TRACE(_T("Internet options:"));
    TRACE(_T("    Connect timeout: %d"), connectTimeout);
    TRACE(_T("    Send timeout   : %d"), sendTimeout);
    TRACE(_T("    Receive timeout: %d"), receiveTimeout);
#endif

    return true;
}

bool Downloader::closeInternet()
{
    if(internet)
    {
        bool res = InternetCloseHandle(internet) != NULL;
        internet = NULL;
        return res;
    }
    else
        return true;
}

void downloadThreadProc(void *param)
{
    Downloader *d = (Downloader *)param;
    bool res = d->downloadFiles();

    if((!d->downloadCancelled) && d->finishedCallback)
        d->finishedCallback(d, res);
}

void Downloader::startDownload()
{
    downloadThread = (HANDLE)_beginthread(&downloadThreadProc, 0, (void *)this);
}

void Downloader::stopDownload()
{
    if(ownMsgLoop)
    {
        downloadCancelled = true;
        return;
    }

    Ui *uitmp = ui;
    ui = NULL;
    downloadCancelled = true;
    WaitForSingleObject(downloadThread, DOWNLOAD_CANCEL_TIMEOUT);
    downloadCancelled = false;
    ui = uitmp;
}

void Downloader::pauseDownload()
{
    downloadPaused = true;
}

void Downloader::resumeDownload()
{
    downloadPaused = false;
}

DWORDLONG Downloader::getFileSizes(bool useComponents)
{
    if(ownMsgLoop)
        downloadCancelled = false;

    if(files.empty())
        return 0;

    updateStatus(msg("Initializing..."));
    processMessages();

    if(!openInternet())
    {
        storeError();
        return FILE_SIZE_UNKNOWN;
    }

    filesSize = 0;
    bool sizeUnknown = false;

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        updateStatus(msg("Getting file information..."));
        processMessages();

        NetFile *file = i->second;

        if(downloadCancelled)
            break;

        if(useComponents)
            if(!file->selected(components))
                continue;

        if(file->size == FILE_SIZE_UNKNOWN)
        {
            try
            {
                try
                {
                    updateFileName(file);
                    processMessages();
                    file->size = file->url.getSize(internet);
                }
                catch(HTTPError &e)
                {
                    updateStatus(msg(e.what()));
                    //TODO: if allowContinue==0 & error code == file not found - stop.
                }
                
                if(file->size == FILE_SIZE_UNKNOWN)
                    checkMirrors(i->first, false);
            }
            catch(FatalNetworkError &e)
            {
                updateStatus(msg(e.what()));
                storeError(msg(e.what()));
                closeInternet();
                return OPERATION_STOPPED;
            }
        }

        if(!(file->size == FILE_SIZE_UNKNOWN))
            filesSize += file->size;
        else
            sizeUnknown = true;
    }

    closeInternet();

    if(sizeUnknown && !filesSize)
        filesSize = FILE_SIZE_UNKNOWN; //TODO: if only part of files has unknown size - ???

#ifdef _DEBUG
    TRACE(_T("getFileSizes result:"));

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        NetFile *file = i->second;
        TRACE(_T("    %s: %s"), file->getShortName().c_str(), (file->size == FILE_SIZE_UNKNOWN) ? _T("Unknown") : itotstr((DWORD)file->size).c_str()); 
    }
#endif

    return filesSize;
}

bool Downloader::downloadFiles(bool useComponents)
{
    if(ownMsgLoop)
        downloadCancelled = false;

    if(files.empty() && ftpDirs.empty())
        return true;

    setMarquee(true);

    processFtpDirs();

    if(getFileSizes() == OPERATION_STOPPED)
    {
        TRACE(_T("OPERATION_STOPPED"));
        setMarquee(false);
        return false;
    }

    TRACE(_T("filesSize: %d"), (DWORD)filesSize);

    if(!openInternet())
    {
        storeError();
        setMarquee(false);
        return false;
    }

    sizeTimeTimer.start(500);
    updateStatus(msg("Starting download..."));
    TRACE(_T("Starting file download cycle..."));

    if(!(filesSize == FILE_SIZE_UNKNOWN))
        setMarquee(false);

    processMessages();

    for(map<tstring, NetFile *>::iterator i = files.begin(); i != files.end(); i++)
    {
        NetFile *file = i->second;

        if(downloadCancelled)
            break;

        if(useComponents)
            if(!file->selected(components))
                continue;

        if(!file->downloaded)
        {
            // If mirror was used in getFileSizes() function, check mirror first:
            if(file->mirrorUsed.length())
            {
                NetFile newFile(file->mirrorUsed, file->name, file->size);

                if(downloadFile(&newFile))
                {
                    downloadedFilesSize += file->bytesDownloaded;
                    continue;
                }
            }

            if(!downloadFile(file))
            {
                TRACE(_T("File was not downloaded."));

                if(checkMirrors(i->first, true))
                    downloadedFilesSize += file->bytesDownloaded;
                else
                {
                    if(stopOnError)
                    {
                        closeInternet();
                        return false;
                    }
                    else
                    {
                        TRACE(_T("Ignoring file %s"), file->name.c_str());
                    }
                }
            }
            else
                downloadedFilesSize += file->bytesDownloaded;
        }

        processMessages();
    }

    closeInternet();
    return filesDownloaded();
}

bool Downloader::checkMirrors(tstring url, bool download/* or get size */)
{
    TRACE(_T("Checking mirrors for %s (%s)..."), url.c_str(), download ? _T("download") : _T("get size"));
    pair<multimap<tstring, tstring>::iterator, multimap<tstring, tstring>::iterator> fileMirrors = mirrors.equal_range(url);
    
    for(multimap<tstring, tstring>::iterator i = fileMirrors.first; i != fileMirrors.second; ++i)
    {
        tstring mirror = i->second;
        TRACE(_T("Checking mirror %s:"), mirror.c_str());
        NetFile f(mirror, files[url]->name, files[url]->size);

        if(download)
        {
            if(downloadFile(&f))
            {
                files[url]->downloaded = true;
                return true;
            }
        }
        else // get size
        {
            try
            {
                DWORDLONG size = f.url.getSize(internet);

                if(size != FILE_SIZE_UNKNOWN)
                {
                    files[url]->size = size;
                    files[url]->mirrorUsed = mirror;
                    return true;
                }
            }
            catch(HTTPError &e)
            {
                updateStatus(msg(e.what()));
            }
        }

        processMessages();
    }

    return false;
}

bool Downloader::downloadFile(NetFile *netFile)
{
    BYTE  buffer[READ_BUFFER_SIZE];
    DWORD bytesRead;
    File  file;

    updateFileName(netFile);
    updateStatus(msg("Connecting..."));
    setMarquee(true, false);

    try
    {
        netFile->open(internet);
    }
    catch(exception &e)
    {
        setMarquee(false, stopOnError ? (netFile->size == FILE_SIZE_UNKNOWN) : false);
        updateStatus(msg(e.what()));
        storeError(msg(e.what()));
        return false;
    }

    if(!netFile->handle)
    {
        setMarquee(false, stopOnError ? (netFile->size == FILE_SIZE_UNKNOWN) : false);
        updateStatus(msg("Cannot connect"));
        storeError();
        return false;
    }

    if(!file.open(netFile->name))
    {
        setMarquee(false, stopOnError ? (netFile->size == FILE_SIZE_UNKNOWN) : false);
        tstring errstr = msg("Cannot create file") + _T(" ") + netFile->name;
        updateStatus(errstr);
        storeError(errstr);
        return false;
    }

    Timer progressTimer(100);
    Timer speedTimer(1000);

    updateStatus(msg("Downloading..."));

    if(!(netFile->size == FILE_SIZE_UNKNOWN))
        setMarquee(false, false);

    processMessages();

    while(true)
    {
        if(downloadCancelled)
        {
            file.close();
            netFile->close();
            return true;
        }

        if(!netFile->read(buffer, READ_BUFFER_SIZE, &bytesRead))
        {
            setMarquee(false, netFile->size == FILE_SIZE_UNKNOWN);
            updateStatus(msg("Download failed"));
            storeError();
            file.close();
            netFile->close();
            return false;
        }

        if(bytesRead == 0)
            break;

        file.write(buffer, bytesRead);

        if(progressTimer.elapsed())
            updateProgress(netFile);

        if(speedTimer.elapsed())
            updateSpeed(netFile, &speedTimer);

        if(sizeTimeTimer.elapsed())
            updateSizeTime(netFile, &sizeTimeTimer);

        processMessages();
    }

    updateProgress(netFile);
    updateSpeed(netFile, &speedTimer);
    updateSizeTime(netFile, &sizeTimeTimer);
    updateStatus(msg("Download complete"));
    processMessages();

    file.close();
    netFile->close();
    netFile->downloaded = true;

    return true;
}

void Downloader::updateProgress(NetFile *file)
{
    if(ui)
        ui->setProgressInfo(filesSize, downloadedFilesSize + file->bytesDownloaded, file->size, file->bytesDownloaded);
}

void Downloader::updateFileName(NetFile *file)
{
    if(ui)
        ui->setFileName(file->getShortName());
}

void Downloader::updateFileName(tstring filename)
{
    if(ui)
        ui->setFileName(filename);
}

void Downloader::updateSpeed(NetFile *file, Timer *timer)
{
    if(ui)
    {
        double speed = (double)file->bytesDownloaded / ((double)timer->totalElapsed() / 1000.0);
        double rtime = (double)(filesSize - (downloadedFilesSize + file->bytesDownloaded)) / speed * 1000.0;
        
        if((filesSize == FILE_SIZE_UNKNOWN) || ((downloadedFilesSize + file->bytesDownloaded) > filesSize))
            ui->setSpeedInfo(f2i(speed));
        else
            ui->setSpeedInfo(f2i(speed), f2i(rtime));
    }
}

void Downloader::updateSizeTime(NetFile *file, Timer *timer)
{
    if(ui)
        ui->setSizeTimeInfo(filesSize, downloadedFilesSize + file->bytesDownloaded, file->size, file->bytesDownloaded, timer->totalElapsed());
}

void Downloader::updateStatus(tstring status)
{
    if(ui)
        ui->setStatus(status);
}

void Downloader::setMarquee(bool marquee, bool total)
{
    if(ui)
        ui->setMarquee(marquee, total);
}

void Downloader::processMessages()
{
    if(!ownMsgLoop)
        return;

    while(PeekMessage(&windowsMsg, 0, 0, 0, PM_REMOVE))
    {
        TranslateMessage(&windowsMsg);
        DispatchMessage(&windowsMsg);
    }
}

tstring Downloader::msg(string key)
{
    tstring res;

    if(ui)
        res = ui->msg(key);
    else
        return tocurenc(key);

    int errcode = _ttoi(res.c_str());

    if(errcode > 0)
        return tstrprintf(msg("HTTP error %d"), errcode);

    return res;
}

void Downloader::storeError()
{
    errorCode = GetLastError();
    errorStr  = formatwinerror(errorCode);
}

void Downloader::storeError(tstring msg, DWORD errcode)
{
    errorCode = errcode;
    errorStr  = msg;
}

DWORD Downloader::getLastError()
{
    return errorCode;
}

tstring Downloader::getLastErrorStr()
{
    return errorStr;
}

void Downloader::addFtpDir(tstring url, tstring mask, tstring destdir, bool recursive, tstring comp)
{
    ftpDirs.push_back(new FtpDir(url, mask, destdir, recursive, comp));
}

bool Downloader::scanFtpDir(FtpDir *ftpDir, tstring destsubdir)
{
    Url url(ftpDir->url);
    url.internetOptions = internetOptions;
    
    updateFileName(url.components.lpszUrlPath);
    
    if(!url.connect(internet))
    {
        storeError();
        return false;
    }
    
    if(!FtpSetCurrentDirectory(url.connection, url.components.lpszUrlPath))
    {
        storeError();
        return false;
    }
    
    list<tstring> dirs;
    WIN32_FIND_DATA fd;

    TRACE(_T("Scanning FTP dir %s:"), ftpDir->url.c_str());
    HINTERNET handle = FtpFindFirstFile(url.connection, ftpDir->mask.c_str(), &fd, NULL, NULL);

    if(handle)
    {
        TRACE(_T("    (%s) %s"), (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? _T("D") : _T("F"), fd.cFileName);
        updateFileName(tstring(fd.cFileName));

        if(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            tstring dirname(fd.cFileName);

            if(!(dirname.compare(_T(".")) == 0) && !(dirname.compare(_T("..")) == 0))
                dirs.push_back(dirname);
        }
        else
        {
            tstring fileUrl  = addslash(ftpDir->url);
            tstring fileName = addbackslash(ftpDir->destdir);
            fileUrl  += tstring(fd.cFileName);
            fileName += addbackslash(destsubdir);
            fileName += tstring(fd.cFileName);
            
            addFile(fileUrl, fileName, ((DWORDLONG)fd.nFileSizeHigh << 32) | fd.nFileSizeLow, ftpDir->compstr);
        }

        while(InternetFindNextFile(handle, &fd))
        {
            TRACE(_T("    (%s) %s"), (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? _T("D") : _T("F"), fd.cFileName);
            updateFileName(tstring(fd.cFileName));

            if(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
            {
                tstring dirname(fd.cFileName);

                if(!(dirname.compare(_T(".")) == 0) && !(dirname.compare(_T("..")) == 0))
                    dirs.push_back(dirname);
            }
            else
            {
                tstring fileUrl  = addslash(ftpDir->url);
                tstring fileName = addbackslash(ftpDir->destdir);
                fileUrl  += tstring(fd.cFileName);
                fileName += addbackslash(destsubdir);
                fileName += tstring(fd.cFileName);
                
                addFile(fileUrl, fileName, ((DWORDLONG)fd.nFileSizeHigh << 32) | fd.nFileSizeLow, ftpDir->compstr);
            }
        }
    }

    url.disconnect();

    if(ftpDir->recursive && !dirs.empty())
    {
        for(list<tstring>::iterator i = dirs.begin(); i != dirs.end(); i++)
        {
            tstring dir = *i;

            tstring urlstr = addslash(ftpDir->url);
            urlstr += dir;
            FtpDir fdir(urlstr, ftpDir->mask, ftpDir->destdir, ftpDir->recursive, ftpDir->compstr);
            
            if(preserveFtpDirs)
            {
                tstring destdir(addbackslash(ftpDir->destdir));
                destdir += addbackslash(destsubdir);
                destdir += dir;
                TRACE(_T("Creating directory %s"), destdir.c_str());
                _tmkdir(destdir.c_str());

                tstring subdir = addbackslash(destsubdir);
                subdir += dir;
                scanFtpDir(&fdir, subdir);
            }
            else
                scanFtpDir(&fdir);
        }
    }

    return true;
}

void Downloader::processFtpDirs()
{
    if(ftpDirsProcessed())
        return;

    openInternet();

    if(!ftpDirs.empty())
    {
        updateStatus(msg("Getting file information..."));
        processMessages();

        for(list<FtpDir *>::iterator i = ftpDirs.begin(); i != ftpDirs.end(); i++)
        {
            FtpDir *f = *i;

            if(f->processed)
                continue;

            if(f->selected(components))
            {
                if(scanFtpDir(f))
                    f->processed = true;
            }
        }
    }
    
    if(ftpDirsProcessed())
        clearFtpDirs();
}

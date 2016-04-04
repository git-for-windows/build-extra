#include "idp.h"
#include "trace.h"

HINSTANCE idpDllHandle = NULL;

Downloader      downloader;
Ui              ui;
InternetOptions internetOptions;

void idpAddFile(_TCHAR *url, _TCHAR *filename)
{
    downloader.addFile(STR(url), STR(filename));
}

void idpAddFileSize(_TCHAR *url, _TCHAR *filename, DWORDLONG filesize)
{
    downloader.addFile(STR(url), STR(filename), filesize);
}

void idpAddFileComp(_TCHAR *url, _TCHAR *filename, _TCHAR *components)
{
    downloader.addFile(STR(url), STR(filename), FILE_SIZE_UNKNOWN, STR(components));
}

void idpAddFileSizeComp(_TCHAR *url, _TCHAR *filename, DWORDLONG filesize, _TCHAR *components)
{
    downloader.addFile(STR(url), STR(filename), filesize, STR(components));
}

void idpAddMirror(_TCHAR *url, _TCHAR *mirror)
{
    downloader.addMirror(STR(url), STR(mirror));
}

void idpAddFtpDir(_TCHAR *url, _TCHAR *mask, _TCHAR *destdir, bool recursive)
{
    downloader.addFtpDir(STR(url), STR(mask), STR(destdir), recursive);
}

void idpAddFtpDirComp(_TCHAR *url, _TCHAR *mask, _TCHAR *destdir, bool recursive, _TCHAR *components)
{
    downloader.addFtpDir(STR(url), STR(mask), STR(destdir), recursive, components);
}

void idpClearFiles()
{
    downloader.clearFiles();
}

int idpFilesCount()
{
    return downloader.filesCount();
}

int idpFtpDirsCount()
{
    return downloader.ftpDirsCount();
}

bool idpFilesDownloaded()
{
    return downloader.filesDownloaded();
}

bool idpFileDownloaded(_TCHAR *url)
{
    return downloader.fileDownloaded(STR(url));
}

bool idpGetFileSize(_TCHAR *url, DWORDLONG *size)
{
    Downloader d;
    d.setInternetOptions(internetOptions);
    d.setMirrorList(&downloader);
    d.addFile(STR(url), _T(""));
    *size = d.getFileSizes();

    return *size != FILE_SIZE_UNKNOWN;
}

bool idpGetFilesSize(DWORDLONG *size)
{
    downloader.setUi(NULL);
    downloader.setInternetOptions(internetOptions);
    *size = downloader.getFileSizes(false);
    return *size != FILE_SIZE_UNKNOWN;
}

bool idpDownloadFile(_TCHAR *url, _TCHAR *filename)
{
    Downloader d;
    d.setInternetOptions(internetOptions);
    d.setMirrorList(&downloader);
    d.addFile(STR(url), STR(filename));
    return d.downloadFiles();
}

bool idpDownloadFiles()
{
    downloader.ownMsgLoop = false;
    downloader.setUi(NULL);
    downloader.setInternetOptions(internetOptions);
    return downloader.downloadFiles(false);
}

bool idpDownloadFilesComp()
{
    downloader.ownMsgLoop = false;
    downloader.setUi(NULL);
    downloader.setInternetOptions(internetOptions);
    return downloader.downloadFiles(true);
}

bool idpDownloadFilesCompUi()
{
    ui.lockButtons();
    downloader.ownMsgLoop = true;
    downloader.processMessages();
    downloader.setUi(&ui);
    downloader.setInternetOptions(internetOptions);
    
    bool res;

    while(true)
    {
        res = downloader.downloadFiles(true);

        TRACE(_T("idpDownloadFilesCompUi: ui.errorDlgMode == %d"), ui.errorDlgMode);

        if(res || (ui.errorDlgMode == DLG_NONE) || downloader.downloadCancelled)
            break; // go to next page
        else if(ui.errorDlgMode == DLG_SIMPLE)
        {
            int dlgRes = ui.messageBox(ui.msg("Download failed") + _T(": ") + downloader.getLastErrorStr() + _T("\r\n") + (ui.allowContinue ?
                                       ui.msg("Check your connection and click 'Retry' to try downloading the files again, or click 'Next' to continue installing anyway.") :
                                       ui.msg("Check your connection and click 'Retry' to try downloading the files again, or click 'Cancel' to terminate setup.")),
                                       ui.msg("Download failed"), MB_ICONWARNING | (ui.hasRetryButton ? MB_OK : MB_RETRYCANCEL));

            if     (dlgRes == IDRETRY)  continue;
            else if(dlgRes == IDCANCEL) break;
        }
        else
        {
            ui.dllHandle = idpDllHandle;

            int dlgRes = ui.errorDialog(&downloader);
            
            if     (dlgRes == IDRETRY)  continue;
            else if(dlgRes == IDABORT)  break;
            else if(dlgRes == IDIGNORE) break;
        }
    }

    ui.unlockButtons();
    return res;
}

void idpConnectControl(_TCHAR *name, HWND handle)
{
    if(name)
        ui.connectControl(name, handle);
}

void idpAddMessage(_TCHAR *name, _TCHAR *message)
{
    if(name)
        ui.addMessage(STR(name), STR(message));
}

void idpSetComponents(_TCHAR *components)
{
    downloader.setComponents(STR(components));
}

void idpStartDownload()
{
    ui.lockButtons();
    downloader.ownMsgLoop = false;
    downloader.setUi(&ui);
    downloader.setInternetOptions(internetOptions);
    downloader.setFinishedCallback(&downloadFinished);
    downloader.startDownload();
}

void idpStopDownload()
{
    downloader.stopDownload();
    ui.unlockButtons();
    ui.setStatus(ui.msg("Download cancelled"));
}

void downloadFinished(Downloader *d, bool res)
{
    ui.reportError(); //salto-mortale to main thread, which calls idpReportError
}

void idpReportError()
{
    ui.unlockButtons(); // allow user to click Retry or Next

    if(downloader.filesDownloaded() || (ui.errorDlgMode == DLG_NONE))
        ui.clickNextButton(); // go to next page
    else if(ui.errorDlgMode == DLG_SIMPLE)
    {
        if(ui.messageBox(ui.msg("Download failed") + _T(": ") + downloader.getLastErrorStr() + _T("\r\n") + (ui.allowContinue ?
                         ui.msg("Check your connection and click 'Retry' to try downloading the files again, or click 'Next' to continue installing anyway.") :
                         ui.msg("Check your connection and click 'Retry' to try downloading the files again, or click 'Cancel' to terminate setup.")),
                         ui.msg("Download failed"), MB_ICONWARNING | (ui.hasRetryButton ? MB_OK : MB_RETRYCANCEL)) == IDRETRY)
            idpStartDownload();
    }
    else
    {
        ui.dllHandle = idpDllHandle;

        switch(ui.errorDialog(&downloader))
        {
        case IDRETRY : idpStartDownload();   break;
        case IDIGNORE: ui.clickNextButton(); break;
        }
    }
}

// ANSI Inno Setup don't support 64-bit integers.

void idpAddFileSize32(_TCHAR *url, _TCHAR *filename, DWORD filesize)
{
    idpAddFileSize(STR(url), STR(filename), filesize);
}

void idpAddFileSizeComp32(_TCHAR *url, _TCHAR *filename, DWORD filesize, _TCHAR *components)
{
    idpAddFileSizeComp(STR(url), STR(filename), filesize, STR(components));
}

bool idpGetFileSize32(_TCHAR *url, DWORD *size)
{
    DWORDLONG size64;
    bool r = idpGetFileSize(STR(url), &size64);
    *size = (DWORD)size64;
    return r;
}

bool idpGetFilesSize32(DWORD *size)
{
    DWORDLONG size64;
    bool r = idpGetFilesSize(&size64);
    *size = (DWORD)size64;
    return r;
}

DWORD timeoutVal(_TCHAR *value)
{
    string val = toansi(tstrlower(STR(value)));

    if(val.compare("infinite") == 0) return TIMEOUT_INFINITE;
    if(val.compare("infinity") == 0) return TIMEOUT_INFINITE;
    if(val.compare("inf")      == 0) return TIMEOUT_INFINITE;

    return _ttoi(value);
}

bool boolVal(_TCHAR *value)
{
    string val = toansi(tstrlower(STR(value)));

    if(val.compare("true")  == 0) return true;
    if(val.compare("t")     == 0) return true;
    if(val.compare("yes")   == 0) return true;
    if(val.compare("y")     == 0) return true;
    if(val.compare("false") == 0) return false;
    if(val.compare("f")     == 0) return false;
    if(val.compare("no")    == 0) return false;
    if(val.compare("n")     == 0) return false;

    return _ttoi(value) > 0;
}

int dlgVal(_TCHAR *value)
{
    string val = toansi(tstrlower(STR(value)));

    if(val.compare("none")     == 0) return DLG_NONE;
    if(val.compare("simple")   == 0) return DLG_SIMPLE;
    if(val.compare("filelist") == 0) return DLG_FILELIST;
    if(val.compare("urllist")  == 0) return DLG_URLLIST;

    return boolVal(value) ? DLG_NONE : DLG_SIMPLE;
}

int invCertVal(_TCHAR *value)
{
    string val = toansi(tstrlower(STR(value)));

    if(val.compare("showdialog") == 0) return INVC_SHOWDLG;
    if(val.compare("showdlg")    == 0) return INVC_SHOWDLG;
    if(val.compare("stop")       == 0) return INVC_STOP;
    if(val.compare("ignore")     == 0) return INVC_IGNORE;

    return INVC_SHOWDLG;
}

DWORD proxyVal(_TCHAR *value)
{
    string val = toansi(tstrlower(STR(value)));

    if(val.compare("auto")      == 0) return INTERNET_OPEN_TYPE_PRECONFIG;
    if(val.compare("preconfig") == 0) return INTERNET_OPEN_TYPE_PRECONFIG;
    if(val.compare("preconf")   == 0) return INTERNET_OPEN_TYPE_PRECONFIG;
    if(val.compare("direct")    == 0) return INTERNET_OPEN_TYPE_DIRECT;
    if(val.compare("none")      == 0) return INTERNET_OPEN_TYPE_DIRECT;
    if(val.compare("proxy")     == 0) return INTERNET_OPEN_TYPE_PROXY;

    return INTERNET_OPEN_TYPE_PRECONFIG;
}

void idpSetInternalOption(_TCHAR *name, _TCHAR *value)
{
    if(!name)
        return;

    TRACE(_T("idpSetInternalOption(%s, %s)"), name, value);

    string key = toansi(tstrlower(name));

    if(key.compare("allowcontinue") == 0)
    {
        ui.allowContinue       = boolVal(value);
        downloader.stopOnError = !ui.allowContinue;
    }
    else if(key.compare("stoponerror")      == 0) downloader.stopOnError         = boolVal(value);
    else if(key.compare("preserveftpdirs")  == 0) downloader.preserveFtpDirs     = boolVal(value);
    else if(key.compare("retrybutton")      == 0) ui.hasRetryButton              = boolVal(value);
    else if(key.compare("redrawbackground") == 0) ui.redrawBackground            = boolVal(value);
    else if(key.compare("errordialog")      == 0) ui.errorDlgMode                = dlgVal(value);
    else if(key.compare("errordlg")         == 0) ui.errorDlgMode                = dlgVal(value);
    else if(key.compare("useragent")        == 0) internetOptions.userAgent      = STR(value);
    else if(key.compare("referer")          == 0) internetOptions.referer        = STR(value);
    else if(key.compare("invalidcert")      == 0) internetOptions.invalidCert    = invCertVal(value);
    else if(key.compare("oninvalidcert")    == 0) internetOptions.invalidCert    = invCertVal(value);
    else if(key.compare("connecttimeout")   == 0) internetOptions.connectTimeout = timeoutVal(value);
    else if(key.compare("sendtimeout")      == 0) internetOptions.sendTimeout    = timeoutVal(value);
    else if(key.compare("receivetimeout")   == 0) internetOptions.receiveTimeout = timeoutVal(value);
    else if(key.compare("username")         == 0) internetOptions.login          = STR(value);
    else if(key.compare("password")         == 0) internetOptions.password       = STR(value);
    else if(key.compare("proxymode")        == 0) internetOptions.accessType     = proxyVal(value);
    else if(key.compare("proxyusername")    == 0) internetOptions.proxyLogin     = STR(value);
    else if(key.compare("proxypassword")    == 0) internetOptions.proxyPassword  = STR(value);
    else if(key.compare("proxyname")        == 0)
    {
        internetOptions.proxyName = STR(value);

        if(!internetOptions.proxyName.empty())
            internetOptions.accessType = INTERNET_OPEN_TYPE_PROXY;
    }
}

void idpSetProxyMode(_TCHAR *mode)
{
    if(!mode)
        return;

    internetOptions.accessType = proxyVal(mode);
}

void idpSetProxyName(_TCHAR *name)
{
    internetOptions.proxyName = STR(name);

    if(!internetOptions.proxyName.empty())
        internetOptions.accessType = INTERNET_OPEN_TYPE_PROXY;
}

void idpSetProxyLogin(_TCHAR *login, _TCHAR *password)
{
    internetOptions.proxyLogin    = STR(login);
    internetOptions.proxyPassword = STR(password);
}

void idpSetLogin(_TCHAR *login, _TCHAR *password)
{
    internetOptions.login    = STR(login);
    internetOptions.password = STR(password);
}

void idpSetDetailedMode(bool mode)
{
    ui.setDetailedMode(mode);
}

void idpTrace(_TCHAR *text)
{
    TRACE(_T("%s"), text);
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD dwReason, LPVOID lpvReserved)
{
    if(dwReason == DLL_PROCESS_ATTACH)
        idpDllHandle = hinstDLL;
        
    return TRUE;
}

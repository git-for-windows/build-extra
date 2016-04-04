#include <stdio.h>
#include <conio.h>
#include "../../idp/downloader.h"

void idpReportError() {} // stub to aviod compile error

int _tmain(int argc, _TCHAR* argv[])
{
    Downloader downloader;
    DWORDLONG  fs;

    downloader.addFile(_T("http://127.0.0.1/test1.zip"), _T("test1.rar"), FILE_SIZE_UNKNOWN, _T("comp1"));
    downloader.addFile(_T("http://127.0.0.1/test2.zip"), _T("test2.rar"), FILE_SIZE_UNKNOWN, _T("comp2"));
    downloader.addFile(_T("http://127.0.0.1/test3.zip"), _T("test3.rar"), FILE_SIZE_UNKNOWN, _T("comp3"));
    
    downloader.setComponents(_T("comp1,comp2,comp3"));

    _tprintf(_T("Getting file sizes...\n"));
    fs = downloader.getFileSizes();
    
    if(fs == FILE_SIZE_UNKNOWN)
        _tprintf(_T("Size unknown\n"));
    else if(fs == OPERATION_STOPPED)
        _tprintf(_T("Error getting file sizes\n"));
    else
        _tprintf(_T("Total size: %d\n"), (DWORD)fs);
        

    bool result = downloader.downloadFiles();
    _tprintf(_T("Download %s\n"), result ? _T("OK") : _T("FAILED"));
    if(!result)
        _tprintf(_T("Error code: %u, error description: %s\n"), downloader.getLastError(), downloader.getLastErrorStr().c_str());
    _gettch();
    
    return 0;
}
#include <stdio.h>
#include <conio.h>
#include "../../idp/downloader.h"

void idpReportError() {} // stub to aviod compile error

int _tmain(int argc, _TCHAR* argv[])
{
    Downloader downloader;

    downloader.addFtpDir(_T("ftp://127.0.0.1/"), _T(""), _T(""), true);
    bool result = downloader.downloadFiles();

    _tprintf(_T("Download %s\n"), result ? _T("OK") : _T("FAILED"));
    if(!result)
        _tprintf(_T("Error code: %u, error description: %s\n"), downloader.getLastError(), downloader.getLastErrorStr().c_str());
    _gettch();
    
    return 0;
}
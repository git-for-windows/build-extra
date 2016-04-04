#include <stdio.h>
#include <conio.h>
#include "../../idp/idp.h"

#ifdef __MINGW32__
    #define _gettch getch
#endif

int _tmain(int argc, _TCHAR* argv[])
{
    idpAddFileComp(_T("http://127.0.0.1/test1.rar"), _T("test1.rar"), _T("comp1"));
    idpAddFileComp(_T("http://127.0.0.1/test2.rar"), _T("test2.rar"), _T("comp2"));
    idpAddFileComp(_T("http://127.0.0.1/test3.rar"), _T("test3.rar"), _T("comp3"));

    DWORDLONG size;
    idpGetFilesSize(&size);
    _tprintf(_T("Size of files: %d bytes\n"), (int)size);

    idpSetInternalOption(_T("ErrorDialog"), _T("UrlList"));
    idpSetComponents(_T("comp1,comp2"));
    idpStartDownload();

    _tprintf(_T("Download started\n"));
    _gettch();

    return 0;
}

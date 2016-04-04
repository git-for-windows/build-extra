#include <tchar.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <windows.h>
#include "tstring.h"

void debugprintf(const _TCHAR *format, ...)
{
    _TCHAR str[1024];

    _tcscpy(str, _T("IDP: "));

    va_list argptr;
    va_start(argptr, format);
    _vstprintf(&str[5], format, argptr);
    va_end(argptr);

    _tcscat(str, _T("\n"));

    OutputDebugString(str);
}

tstring formatwinerror(DWORD error)
{
    _TCHAR buf[1024];
    memset(buf, 0, sizeof(buf));

    if((error >= 12000) && (error <= 12174))
        FormatMessage(FORMAT_MESSAGE_FROM_HMODULE | FORMAT_MESSAGE_IGNORE_INSERTS, GetModuleHandle(_T("wininet.dll")), error, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), buf, 1024, NULL);
    else
        FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, error, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), buf, 1024, NULL);
    
    tstring res = buf;
    return res;

}
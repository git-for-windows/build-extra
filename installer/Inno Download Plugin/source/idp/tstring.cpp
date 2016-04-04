#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include "tstring.h"
#include "trace.h"

string toansi(tstring s)
{
#ifdef UNICODE
    int bufsize = (int)s.length()+1;
    char *buffer = new char[bufsize];
    WideCharToMultiByte(CP_ACP, 0, s.c_str(), -1, buffer, bufsize, NULL, NULL);
    string res = buffer;
    delete[] buffer;
    return res;
#else
    return s;
#endif
}

tstring tocurenc(string s)
{
#ifdef UNICODE
    int bufsize = (int)s.length()+1;
    wchar_t *buffer = new wchar_t[bufsize];
    MultiByteToWideChar(CP_ACP, 0, s.c_str(), -1, buffer, bufsize);
    tstring res = buffer;
    delete[] buffer;
    return res;
#else
    return s;
#endif
}

tstring tstrlower(const _TCHAR *s)
{
    int bufsize = (int)_tcslen(s)+1;
    _TCHAR *buffer = new _TCHAR[bufsize];
    _tcscpy(buffer, s);
    _tcslwr(buffer);
    return buffer;
}

tstring itotstr(int d)
{
    _TCHAR buf[34];
    _itot(d, buf, 10);
    return buf;
}

string dwtostr(unsigned long d)
{
    char buf[34];
    _ultoa(d, buf, 10);
    return buf;
}

tstring tstrprintf(tstring format, ...)
{
    _TCHAR str[256];

    va_list argptr;
    va_start(argptr, format);
    _vstprintf(str, format.c_str(), argptr);
    va_end(argptr);

    return str;
}

tstring formatsize(unsigned long long size, tstring kb, tstring mb, tstring gb)
{
    if(size < 1048576)
        return tstrprintf(_T("%d ")   + kb, size / 1024);
    else if(size < 1073741824)
        return tstrprintf(_T("%.2f ") + mb, (double)size / 1048576.0);
    else
        return tstrprintf(_T("%.2f ") + gb, (double)size / 1073741824.0);
}

tstring formatsize(tstring ofmsg, unsigned long long size1, unsigned long long size2, tstring kb, tstring mb, tstring gb)
{
    /*if(size2 < 1048576)
        return tstrprintf(ofmsg + _T(" ") + kb, (double)size1 / 1024.0,       (double)size2 / 1024.0);
    else*/ if(size2 < 1073741824)
        return tstrprintf(ofmsg + _T(" ") + mb, (double)size1 / 1048576.0,    (double)size2 / 1048576.0);
    else
        return tstrprintf(ofmsg + _T(" ") + gb, (double)size1 / 1073741824.0, (double)size2 / 1073741824.0);
}

tstring formatspeed(unsigned long speed, tstring kbs, tstring mbs)
{
    if(speed < 1048576)
        return itotstr((int)((double)speed / 1024.0))    + _T(" ") + kbs;
    else if(speed < 10485760)
        return tstrprintf(_T("%.1f "), (double)speed / 1048576.0) + mbs;
    else
        return itotstr((int)((double)speed / 1048576.0)) + _T(" ") + mbs;
}

void tstringtoset(set<tstring> &stringset, tstring str, _TCHAR sep)
{
    tstringstream s(str);
    tstring token;

    while(getline(s, token, sep))
        stringset.insert(token);
}

tstring addslash(tstring s)
{
    if(s.empty())
        return s;

    tstring r = s;

    if(!(r.at(r.length()-1) == '/'))
        r.append(_T("/"));
    
    return r;
}

tstring addbackslash(tstring s)
{
    if(s.empty())
        return s;

    tstring r = s;

    if(!(r.at(r.length()-1) == '\\'))
        r.append(_T("\\"));
    
    return r;
}

#pragma once

#include <string>
#include <sstream>
#include <set>
#include <tchar.h>

using namespace std;

typedef basic_string<_TCHAR> tstring;
typedef basic_stringstream<_TCHAR> tstringstream;

string  toansi(tstring s);
tstring tocurenc(string s);
tstring tstrlower(const _TCHAR *s);
tstring tstrprintf(tstring format, ...);
tstring itotstr(int d);
string  dwtostr(unsigned long d);
tstring formatsize(unsigned long long size, tstring kb, tstring mb, tstring gb);
tstring formatsize(tstring ofmsg, unsigned long long size1, unsigned long long size2, tstring kb, tstring mb, tstring gb);
tstring formatspeed(unsigned long speed, tstring kbs, tstring mbs);
void    tstringtoset(set<tstring> &stringset, tstring str, _TCHAR sep);
tstring addslash(tstring s);
tstring addbackslash(tstring s);

#define STR(x) x ? x : const_cast<_TCHAR *>(_T(""))

#pragma once
#include <set>
#include "tstring.h"

class FtpDir
{
public:
    FtpDir(tstring u, tstring m, tstring d, bool r, tstring comp = _T(""));
    bool selected(set<tstring> comp);

    tstring      url;
    tstring      mask;
    tstring      destdir;
    bool         recursive;
    set<tstring> components;
    tstring      compstr;
    bool         processed;
};
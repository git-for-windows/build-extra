#include "ftpdir.h"

FtpDir::FtpDir(tstring u, tstring m, tstring d, bool r, tstring comp)
{
    url       = u;
    mask      = m;
    destdir   = d;
    recursive = r;
    compstr   = comp;
    processed = false;

    tstringtoset(components, comp, _T(' '));
}

bool FtpDir::selected(set<tstring> comp)
{
    if(components.empty())
        return true;

    for(set<tstring>::iterator i = components.begin(); i != components.end(); i++)
    {
        tstring comp1 = *i;
        for(set<tstring>::iterator j = comp.begin(); j != comp.end(); j++)
        {
            tstring comp2 = *j;

            if(comp1 == comp2)
                return true;
        }
    }

    return false;
}

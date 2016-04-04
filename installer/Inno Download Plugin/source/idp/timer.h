#pragma once

#include <windows.h>
#include "tstring.h"

class Timer
{
public:
    Timer();
    Timer(DWORD msec);
    
    void    start(DWORD msec);
    bool    elapsed();
    DWORD   totalElapsed();
    tstring totalElapsedStr(tstring fmt);

    static tstring msecToStr(DWORD msec, tstring fmt);

protected:
    DWORD interval;
    DWORD startTime;
    DWORD period;
};

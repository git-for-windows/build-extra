#include <stdio.h>
#include "timer.h"

Timer::Timer()
{
}

Timer::Timer(DWORD msec)
{
    start(msec);
}

void Timer::start(DWORD msec)
{
    interval  = msec;
    startTime = GetTickCount();
    period    = startTime;
}

bool Timer::elapsed()
{
    DWORD elapsedTime = GetTickCount();

    if((elapsedTime - period) > interval)
    {
        period = elapsedTime;
        return true;
    }
    else
        return false;
}

DWORD Timer::totalElapsed()
{
    return GetTickCount() - startTime;
}

tstring Timer::totalElapsedStr(tstring fmt)
{
    return msecToStr(totalElapsed(), fmt);
}

tstring Timer::msecToStr(DWORD msec, tstring fmt)
{
    DWORD hoursMod = msec % 3600000;
    DWORD hours = (msec - hoursMod) / 3600000;
    DWORD minsMod = hoursMod % 60000;
    DWORD mins = (hoursMod - minsMod) / 60000;
    DWORD secs = (int)(minsMod / 1000);

    _TCHAR *buf = new _TCHAR[fmt.length() + 30];
    _stprintf(buf, fmt.c_str(), hours, mins, secs);
    tstring res = buf;
    delete[] buf;

    return res;
}
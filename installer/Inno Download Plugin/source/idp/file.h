#pragma once

#include <windows.h>
#include <stdio.h>
#include "tstring.h"

class File
{
public:
    File();
    ~File();

    bool  open(tstring filename);
    bool  close();
    DWORD write(BYTE *buffer, DWORD size);

protected:
    FILE *handle;
};

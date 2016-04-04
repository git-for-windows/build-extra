#include "file.h"

File::File()
{
    handle = NULL;
}

File::~File()
{
    if(handle)
        fclose(handle);
}

bool File::open(tstring filename)
{
    return (handle = _tfopen(filename.c_str(), _T("wb"))) != NULL;
}

bool File::close()
{
    return handle ? (fclose(handle) == 0) : true;
}

DWORD File::write(BYTE *buffer, DWORD size)
{
    return (DWORD)fwrite(buffer, 1, size, handle);
}
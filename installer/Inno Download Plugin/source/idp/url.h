#pragma once

#include <windows.h>
#include <wininet.h>
#include <tchar.h>
#include "tstring.h"
#include "internetoptions.h"

#define FILE_SIZE_UNKNOWN 0xffffffffffffffffULL
#define OPERATION_STOPPED 0xfffffffffffffffeULL

class FatalNetworkError: public exception
{
private:
    string msg;

public:
    FatalNetworkError(const string &message): msg(message) {};
    virtual ~FatalNetworkError() throw() {};
    virtual const char *what() const throw() { return msg.c_str(); };
};

class HTTPError: public exception
{
private:
    string msg;

public:
    HTTPError(const string &message): msg(message) {};
    virtual ~HTTPError() throw() {};
    virtual const char *what() const throw() { return msg.c_str(); };
};

class Url
{
public:
    Url(tstring address);
    ~Url();

    HINTERNET connect(HINTERNET internet);
    HINTERNET open(HINTERNET internet, const _TCHAR *httpVerb = NULL);
    void      disconnect();
    void      close();
    DWORDLONG getSize(HINTERNET internet);

    tstring         urlString;
    InternetOptions internetOptions;
    URL_COMPONENTS  components;
    HINTERNET      connection;
    HINTERNET      filehandle;

protected:
    _TCHAR        *scheme;
    _TCHAR        *hostName;
    _TCHAR        *userName;
    _TCHAR        *password;
    _TCHAR        *urlPath;
    _TCHAR        *extraInfo;
    DWORD          service;
};

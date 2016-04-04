#pragma once

#include <windows.h>
#include <wininet.h>

//Workaround for old MinGW version header files
#ifndef INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY
    #define INTERNET_OPEN_TYPE_PRECONFIG_WITH_NO_AUTOPROXY 4
#endif

#include "tstring.h"

#define INVC_SHOWDLG 0
#define INVC_STOP    1
#define INVC_IGNORE  2

#define TIMEOUT_INFINITE 0xFFFFFFFF
#define TIMEOUT_DEFAULT  0xFFFFFFFE

#define IDP_USER_AGENT _T("InnoDownloadPlugin/1.5")

class InternetOptions
{
public:
    InternetOptions(tstring lgn = _T(""), tstring pass = _T(""), int invCert = INVC_SHOWDLG);
    ~InternetOptions();

    bool hasLoginInfo();
    bool hasProxyLoginInfo();
    bool hasReferer();

    tstring login;
    tstring password;
    int     invalidCert;
    tstring referer;
    tstring userAgent;
    tstring proxyName;
    tstring proxyLogin;
    tstring proxyPassword;

    DWORD   accessType;

    DWORD   connectTimeout;
    DWORD   sendTimeout;
    DWORD   receiveTimeout;
};

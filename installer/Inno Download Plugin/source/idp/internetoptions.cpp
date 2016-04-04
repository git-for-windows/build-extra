#include "internetoptions.h"

InternetOptions::InternetOptions(tstring lgn, tstring pass, int invCert)
{
    login         = lgn;
    password      = pass;
    invalidCert   = invCert;
    referer       = _T("");
    userAgent     = IDP_USER_AGENT;
    proxyName     = _T("");
    proxyLogin    = _T("");
    proxyPassword = _T("");

    accessType  = INTERNET_OPEN_TYPE_PRECONFIG;
    
    connectTimeout = TIMEOUT_DEFAULT;
    sendTimeout    = TIMEOUT_DEFAULT;
    receiveTimeout = TIMEOUT_DEFAULT;
}

InternetOptions::~InternetOptions()
{
}

bool InternetOptions::hasLoginInfo()
{
    return (!login.empty()) || (!password.empty());
}

bool InternetOptions::hasProxyLoginInfo()
{
    return (!proxyLogin.empty()) || (!proxyPassword.empty());
}

bool InternetOptions::hasReferer()
{
    return !referer.empty();
}

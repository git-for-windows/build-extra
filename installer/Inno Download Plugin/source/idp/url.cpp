#include <string.h>
#include "tstring.h"
#include "trace.h"
#include "url.h"
#include "ui.h"

Url::Url(tstring address)
{
    urlString = address;
    int len = (int)urlString.length();

    scheme    = new _TCHAR[len];
    hostName  = new _TCHAR[len];
    userName  = new _TCHAR[len];
    password  = new _TCHAR[len];
    urlPath   = new _TCHAR[len];
    extraInfo = new _TCHAR[len];

    components.dwStructSize      = sizeof(URL_COMPONENTS);
    components.lpszScheme        = scheme;
    components.dwSchemeLength    = len;
    components.lpszHostName      = hostName;
    components.dwHostNameLength  = len;
    components.lpszUserName      = userName;
    components.dwUserNameLength  = len;
    components.lpszPassword      = password;
    components.dwPasswordLength  = len;
    components.lpszUrlPath       = urlPath;
    components.dwUrlPathLength   = len;
    components.lpszExtraInfo     = extraInfo;
    components.dwExtraInfoLength = len;

    InternetCrackUrl(urlString.c_str(), 0, 0, &components);

    switch(components.nScheme)
    {
    case INTERNET_SCHEME_FTP  : service = INTERNET_SERVICE_FTP;  break;
    case INTERNET_SCHEME_HTTP : service = INTERNET_SERVICE_HTTP; break;
    case INTERNET_SCHEME_HTTPS: service = INTERNET_SERVICE_HTTP; break;
    }

    connection = NULL;
    filehandle = NULL;
}

Url::~Url()
{
    close();

    delete[] scheme;
    delete[] hostName;
    delete[] userName;
    delete[] password;
    delete[] urlPath;
    delete[] extraInfo;
}

HINTERNET Url::connect(HINTERNET internet)
{
    DWORD flags = (service == INTERNET_SERVICE_FTP) ? INTERNET_FLAG_PASSIVE : 0;

    TRACE(_T("Connecting to %s://%s:%d..."), components.lpszScheme, hostName, components.nPort);
    //TRACE(_T("    Username=\"%s\", Password=\"%s\" (Global)"), internetOptions.login.c_str(), internetOptions.password.c_str());
    //TRACE(_T("    Username=\"%s\", Password=\"%s\" (URL)"), userName, password);
    
    _TCHAR user[1024], pass[1024];

    if((_tcslen(userName) > 0) || (_tcslen(password) > 0))
    {
        _tcscpy(user, userName);
        _tcscpy(pass, password);
    }
    else
    {
        _tcscpy(user, internetOptions.login.c_str());
        _tcscpy(pass, internetOptions.password.c_str());
    }
    TRACE(_T("    Username=\"%s\", Password=\"%s\""), user, pass);

    connection = InternetConnect(internet, hostName, components.nPort, user, pass, service, flags, NULL);
    
    TRACE(_T("%s"), connection ? _T("Connected OK") : _T("Connection FAILED"));
    return connection;
}

HINTERNET Url::open(HINTERNET internet, const _TCHAR *httpVerb)
{
    LPCTSTR acceptTypes[] = { _T("*/*"), NULL };
    bool proxyAuthSet = false;

    if(!connect(internet))
        return NULL;

    if(service == INTERNET_SERVICE_FTP)
        filehandle = FtpOpenFile(connection, urlPath, GENERIC_READ, FTP_TRANSFER_TYPE_BINARY | INTERNET_FLAG_RELOAD, NULL);
    else
    {
        DWORD flags = INTERNET_FLAG_NO_CACHE_WRITE | INTERNET_FLAG_RELOAD | INTERNET_FLAG_KEEP_CONNECTION;

        if(components.nScheme == INTERNET_SCHEME_HTTPS)
        {
            flags |= INTERNET_FLAG_SECURE;

            if(internetOptions.invalidCert == INVC_IGNORE)
                flags |= INTERNET_FLAG_IGNORE_CERT_CN_INVALID | INTERNET_FLAG_IGNORE_CERT_DATE_INVALID;
        }

        tstring fullUrl = urlPath;
        fullUrl += extraInfo;
        TRACE(_T("Opening %s..."), fullUrl.c_str());
        filehandle = HttpOpenRequest(connection, httpVerb, fullUrl.c_str(), NULL, internetOptions.hasReferer() ? internetOptions.referer.c_str() : NULL, acceptTypes, flags, NULL);

retry:
        TRACE(_T("Sending request..."));
        if(!HttpSendRequest(filehandle, NULL, 0, NULL, 0))
        {
            DWORD error = GetLastError();

            if((error == ERROR_INTERNET_INVALID_CA           ) ||
               (error == ERROR_INTERNET_SEC_CERT_CN_INVALID  ) ||
               (error == ERROR_INTERNET_SEC_CERT_DATE_INVALID))
            {
                TRACE(_T("Invalid certificate (0x%08x: %s)"), error, formatwinerror(error).c_str());

                if(internetOptions.invalidCert == INVC_SHOWDLG)
                {
                    TRACE(_T("Showing InternetErrorDlg"));
                    
                    DWORD r = InternetErrorDlg(uiMainWindow(), filehandle, error,
                                               FLAGS_ERROR_UI_FILTER_FOR_ERRORS | FLAGS_ERROR_UI_FLAGS_GENERATE_DATA | FLAGS_ERROR_UI_FLAGS_CHANGE_OPTIONS,
                                               NULL);

#ifdef _DEBUG
                    _TCHAR *rstr;
                    switch(r)
                    {
                    case ERROR_SUCCESS             : rstr = _T("ERROR_SUCCESS");              break;
                    case ERROR_INTERNET_FORCE_RETRY: rstr = _T("ERROR_INTERNET_FORCE_RETRY"); break;
                    case ERROR_CANCELLED           : rstr = _T("ERROR_CANCELLED");            break;
                    case ERROR_INVALID_HANDLE      : rstr = _T("ERROR_INVALID_HANDLE");       break;
                    default                        : rstr = _T("Unknown error code");         break;
                    }
                    TRACE(_T("InternetErrorDlg returned 0x%08x: %s"), r, rstr);
#endif

                    if((r == ERROR_SUCCESS) || (r == ERROR_INTERNET_FORCE_RETRY)) 
                        goto retry;
                    else if(r == ERROR_CANCELLED)
                    {
                        close();
                        throw FatalNetworkError("Download cancelled");
                    }
                }
                else if(internetOptions.invalidCert == INVC_IGNORE)
                {
                    TRACE(_T("Ignoring invalid certificate"));
                    
                    DWORD flags;
                    DWORD flagsSize = sizeof(flags);

                    InternetQueryOption(filehandle, INTERNET_OPTION_SECURITY_FLAGS, (LPVOID)&flags, &flagsSize);
                    flags |= SECURITY_FLAG_IGNORE_UNKNOWN_CA;
                    InternetSetOption(filehandle, INTERNET_OPTION_SECURITY_FLAGS, &flags, sizeof(flags));

                    goto retry;
                }
            }

            TRACE(_T("HttpSendRequest FAILED: 0x%08x - %s"), error, formatwinerror(error).c_str());
            return NULL;
        }

        DWORD dwStatusCode = 0, dwIndex = 0, dwBufSize;
        dwBufSize = sizeof(DWORD);

        if(!HttpQueryInfo(filehandle, HTTP_QUERY_STATUS_CODE | HTTP_QUERY_FLAG_NUMBER, &dwStatusCode, &dwBufSize, &dwIndex))
        {
            TRACE(_T("HttpQueryInfo FAILED"));
            return NULL;
        }

        TRACE(_T("HTTP Status code: %d"), dwStatusCode);

        if(dwStatusCode == HTTP_STATUS_PROXY_AUTH_REQ)
        {
            TRACE(_T("Proxy authentification requested"));

            if(internetOptions.hasProxyLoginInfo())
            {
                if(!proxyAuthSet)
                {
                    TRACE(_T("Setting proxy username & password: %s, %s"), internetOptions.proxyLogin.c_str(), internetOptions.proxyPassword.c_str());

                    InternetSetOption(connection, INTERNET_OPTION_PROXY_USERNAME, (LPVOID)internetOptions.proxyLogin.c_str(),    (DWORD)internetOptions.proxyLogin.length());
                    InternetSetOption(connection, INTERNET_OPTION_PROXY_PASSWORD, (LPVOID)internetOptions.proxyPassword.c_str(), (DWORD)internetOptions.proxyPassword.length());

                    proxyAuthSet = true;
                    goto retry;
                }
                else
                {
                    TRACE(_T("Proxy username & password not accepted"));
                    close();
                    throw FatalNetworkError("407");
                }
            }
            else
            {
                TRACE(_T("Proxy auth: Showing InternetErrorDlg"));
                    
                DWORD r = InternetErrorDlg(uiMainWindow(), filehandle, ERROR_INTERNET_INCORRECT_PASSWORD,
                                           FLAGS_ERROR_UI_FILTER_FOR_ERRORS | FLAGS_ERROR_UI_FLAGS_GENERATE_DATA | FLAGS_ERROR_UI_FLAGS_CHANGE_OPTIONS,
                                           NULL);

#ifdef _DEBUG
                _TCHAR *rstr;
                switch(r)
                {
                case ERROR_SUCCESS             : rstr = _T("ERROR_SUCCESS");              break;
                case ERROR_INTERNET_FORCE_RETRY: rstr = _T("ERROR_INTERNET_FORCE_RETRY"); break;
                case ERROR_CANCELLED           : rstr = _T("ERROR_CANCELLED");            break;
                case ERROR_INVALID_HANDLE      : rstr = _T("ERROR_INVALID_HANDLE");       break;
                default                        : rstr = _T("Unknown error code");         break;
                }
                TRACE(_T("InternetErrorDlg returned 0x%08x: %s"), r, rstr);
#endif

                if(r == ERROR_INTERNET_FORCE_RETRY)
                    goto retry;
                else
                {
                    close();
                    throw FatalNetworkError("407");
                }
            }
        }
        
        if((dwStatusCode != HTTP_STATUS_OK) && (dwStatusCode != HTTP_STATUS_CREATED/*Not sure, if this code can be returned*/))
        {
            close();
            throw HTTPError(dwtostr(dwStatusCode));
        }

        TRACE(_T("Request opened OK"));
    }

    return filehandle;
}

void Url::disconnect()
{
    if(connection)
        InternetCloseHandle(connection);

    connection = NULL;
}

void Url::close()
{
    if(filehandle)
        InternetCloseHandle(filehandle);

    filehandle = NULL;
    disconnect();
}

DWORDLONG Url::getSize(HINTERNET internet)
{
    DWORDLONG res;

    TRACE(_T("Getting size of %s..."), urlString.c_str());

    if(!open(internet, _T("HEAD")))
        return FILE_SIZE_UNKNOWN;

    if(service == INTERNET_SERVICE_FTP)
    {
        DWORD loword, hiword;
        loword = FtpGetFileSize(filehandle, &hiword);
        res = ((DWORDLONG)hiword << 32) | loword;
    }
    else
    {
        DWORD dwFileSize = 0, dwIndex = 0, dwBufSize;
        dwBufSize = sizeof(DWORD);

        if(!HttpQueryInfo(filehandle, HTTP_QUERY_CONTENT_LENGTH | HTTP_QUERY_FLAG_NUMBER, &dwFileSize, &dwBufSize, &dwIndex))
            return FILE_SIZE_UNKNOWN;

        res = dwFileSize;
    }

    TRACE(_T("Size of %s: %d bytes"), urlString.c_str(), (DWORD)res);
    close();

    return res;
}

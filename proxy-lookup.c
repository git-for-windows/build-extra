// based on the sample provided here: https://github.com/git-for-windows/git/issues/387
// probably inspired by https://msdn.microsoft.com/en-us/library/aa384122(v=vs.85).aspx

#include <stdio.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <shellapi.h>

LPCWSTR get_proxy_for_url(LPCWSTR url)
{
    WINHTTP_CURRENT_USER_IE_PROXY_CONFIG config;
    WINHTTP_AUTOPROXY_OPTIONS options;
    WINHTTP_PROXY_INFO info;

    memset(&config, 0, sizeof(config));

    if (!WinHttpGetIEProxyConfigForCurrentUser(&config))
        config.fAutoDetect = FALSE;
    else if (config.lpszAutoConfigUrl)
        config.fAutoDetect = TRUE;

    if (config.fAutoDetect) {
        HINTERNET handle = WinHttpOpen(L"Proxy Lookup/1.0",
                WINHTTP_ACCESS_TYPE_NO_PROXY,
                WINHTTP_NO_PROXY_NAME,
                WINHTTP_NO_PROXY_BYPASS, 0);

        memset(&options, 0, sizeof(options));

        // use pac file URL from IE proxy configuration
        options.lpszAutoConfigUrl = config.lpszAutoConfigUrl;

        options.fAutoLogonIfChallenged = TRUE;
        options.dwFlags = options.lpszAutoConfigUrl ?
            WINHTTP_AUTOPROXY_CONFIG_URL :
            WINHTTP_AUTOPROXY_AUTO_DETECT;
        if (!options.lpszAutoConfigUrl)
            options.dwAutoDetectFlags =
                WINHTTP_AUTO_DETECT_TYPE_DHCP |
                WINHTTP_AUTO_DETECT_TYPE_DNS_A;

        config.fAutoDetect = WinHttpGetProxyForUrl(handle, url,
                &options, &info );

        WinHttpCloseHandle(handle);
    }

    if (config.fAutoDetect)
        return info.lpszProxy;
    return config.lpszProxy;
}

int main(int argc, char **argv)
{
    LPWSTR *wargv;
    int i, wargc;

    wargv = CommandLineToArgvW(GetCommandLineW(), &wargc);
    wprintf(L"Proxy lookup\n");

    for (i = 1; i < wargc; i++)
        wprintf(L"URL: %s, proxy: %s\n",
                wargv[i], get_proxy_for_url(wargv[i]));

    return 0;
}

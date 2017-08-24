/*
 * Given a URL, this tool looks up the proxy URL configured to access said URL.
 * If no proxy URL was configured for the URL, it prints an empty line.
 *
 * Using information at https://msdn.microsoft.com/en-us/library/aa384080.aspx,
 * initially intended for https://github.com/git-for-windows/git/issues/387,
 * the code was later modified to be a generic tool for use in scripts,
 * included in Git for Windows' git-extra package.
 *
 * The source code in this file is placed in the public domain.
 */

#include <stdio.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <shellapi.h>

LPCWSTR get_proxy_for_url(LPCWSTR url)
{
	static WINHTTP_CURRENT_USER_IE_PROXY_CONFIG config;

	memset(&config, 0, sizeof(config));

	if (!WinHttpGetIEProxyConfigForCurrentUser(&config))
		config.fAutoDetect = FALSE;
	else if (config.lpszAutoConfigUrl)
		config.fAutoDetect = TRUE;

	if (config.fAutoDetect) {
		static WINHTTP_PROXY_INFO info;
		static WINHTTP_AUTOPROXY_OPTIONS options;
		HINTERNET handle = WinHttpOpen(L"Proxy Lookup/1.0",
			WINHTTP_ACCESS_TYPE_NO_PROXY, WINHTTP_NO_PROXY_NAME,
			WINHTTP_NO_PROXY_BYPASS, 0);
		BOOL result;

		memset(&options, 0, sizeof(options));

		/* Use the .pac file URL from IE proxy configuration */
		options.lpszAutoConfigUrl = config.lpszAutoConfigUrl;

		options.fAutoLogonIfChallenged = TRUE;
		options.dwFlags = options.lpszAutoConfigUrl ?
			WINHTTP_AUTOPROXY_CONFIG_URL :
			WINHTTP_AUTOPROXY_AUTO_DETECT;
		if (!options.lpszAutoConfigUrl)
			options.dwAutoDetectFlags =
				WINHTTP_AUTO_DETECT_TYPE_DHCP |
				WINHTTP_AUTO_DETECT_TYPE_DNS_A;

		result = WinHttpGetProxyForUrl(handle, url, &options, &info);

		WinHttpCloseHandle(handle);

		if (result)
			return info.lpszProxy;
	}

	return config.lpszProxy;
}

int main(int argc, char **argv)
{
	LPWSTR *wargv;
	int i, wargc, verbose = 0;

	wargv = CommandLineToArgvW(GetCommandLineW(), &wargc);

	for (i = 1; i < wargc; i++) {
		LPCWSTR arg = wargv[i], proxy;

		if (!wcscmp(L"--verbose", arg) || !wcscmp(L"-v", arg)) {
			verbose = 1;
			continue;
		}

		proxy = get_proxy_for_url(arg);
		if (!proxy)
			proxy = L"";

		if (verbose)
			wprintf(L"URL: %s, proxy: %s\n", arg, proxy);
		else
			wprintf(L"%s\n", proxy);
	}

	return 0;
}

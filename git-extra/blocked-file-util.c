#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

static int find_pids_blocking_files(WCHAR *top_level_directory, int len)
{
	int ret = 0;
	HANDLE process_snapshot;
	PROCESSENTRY32W process_entry;
	WCHAR *path;
	BOOL res;

	process_snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (process_snapshot == INVALID_HANDLE_VALUE)
		return -1;

	process_entry.dwSize = sizeof(PROCESSENTRY32W);
	res = Process32FirstW(process_snapshot, &process_entry);

	while (res) {
		DWORD pid = process_entry.th32ProcessID;
		HANDLE module_snapshot;
		MODULEENTRY32W module_entry;

		if (pid <= 0)
			goto next_process;
		module_snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE |
							   TH32CS_SNAPMODULE32,
							   pid);
		if (module_snapshot == INVALID_HANDLE_VALUE)
			goto next_process;
		module_entry.dwSize = sizeof(MODULEENTRY32W);
		res = Module32FirstW(module_snapshot, &module_entry);
		while (res) {
			path = module_entry.szExePath;
			if (!_wcsnicmp(top_level_directory, path, len) &&
			    path[len] == L'\\') {
				ret++;
				fprintf(stderr, "Pid %ld uses %S\n", pid, path);
				break;
			}
			res = Module32NextW(module_snapshot, &module_entry);
		}
		CloseHandle(module_snapshot);
next_process:
		res = Process32NextW(process_snapshot, &process_entry);
	}

	CloseHandle(process_snapshot);

	return ret;
}

static int recycle(WCHAR *path)
{
	int len = wcslen(path), ret;
	WCHAR *list;
	SHFILEOPSTRUCTW opt;

	list = malloc((len + 2) * sizeof(WCHAR));
	if (!list)
		return -1;
	memcpy(list, path, len * sizeof(WCHAR));
	list[len] = list[len + 1] = L'\0';

	memset(&opt, 0, sizeof(SHFILEOPSTRUCTW));
	opt.pFrom = list;
	opt.hwnd = NULL;
	opt.wFunc = FO_DELETE;
	opt.fFlags = FOF_SILENT | FOF_NOERRORUI | FOF_ALLOWUNDO |
		FOF_NOCONFIRMMKDIR | FOF_NOCONFIRMATION;

	ret = SHFileOperationW(&opt);

	free(list);
	return ret;
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE prev, LPSTR command_line,
		int show)
{
	int wargc, ret;
	WCHAR **wargv = CommandLineToArgvW(GetCommandLineW(), &wargc);

	if (wargc == 3 && !wcscmp(L"blocking-pids", wargv[1])) {
		int len;

		for (len = 0; wargv[2][len]; len++)
			if (wargv[2][len] == L'/')
				wargv[2][len] = L'\\';

		if (len && wargv[2][len - 1] == L'\\')
			len--;

		ret = !!find_pids_blocking_files(wargv[2], len);
	} else if (wargc == 3 && !wcscmp(L"recycle", wargv[1])) {
		ret = recycle(wargv[2]);
	} else {
		fprintf(stderr,
			"Usage: %S <command> [<arguments>...]\n"
			"Commands:\n"
			"\tblocking-pids <top-level-directory>\n"
			"\trecycle <path>\n",
			wargv[0]);
		ret = 1;
	}

	LocalFree(wargv);
	return ret;
}

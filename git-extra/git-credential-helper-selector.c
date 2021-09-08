#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <commctrl.h>

static HINSTANCE instance;
static HWND main_window;
static LPWSTR *helper_name, *helper_path, previously_selected_helper;
static size_t helper_nr, selected_helper;
static int persist;
static LPWSTR persist_to_config_option, persist_tooltip;

#define ID_ENTER   IDOK
#define ID_ABORT   IDCANCEL
#define ID_ESCAPE  1000
#define ID_PERSIST 1001
#define ID_USER    2000

static LPWSTR parse_script_interpreter(LPWSTR path)
{
#define MAX_SHEBANG 100
	static WCHAR wbuf[2 * MAX_SHEBANG + 16];
	char buf[MAX_SHEBANG + 5];
	DWORD len = 0, eol = 0, count;
	HANDLE h;

	/* Skip detection for .exe, .bat, and .cmd */
	count = wcslen(path);
	if (count > 4 && path[count - 4] == L'.' &&
	    (!wcsicmp(path + count - 3, L"exe") ||
	     !wcsicmp(path + count - 3, L"bat") ||
	     !wcsicmp(path + count - 3, L"cmd")))
		return NULL;

	h = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL,
			OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (h == INVALID_HANDLE_VALUE)
		return NULL;

	while (len < MAX_SHEBANG && eol == len) {
		if (!ReadFile(h, buf + len, MAX_SHEBANG - len,
			      &count, NULL))
			break;
		len += count;
		if (len > 2 && (buf[0] != '#' || buf[1] != '!'))
			break;
		for (; eol < len; eol++)
			if (buf[eol] == '\r' || buf[eol] == L'\n')
				break;
	}
	CloseHandle(h);

	if (eol == len || buf[0] != '#' || buf[1] != '!')
		return NULL;

	for (len = eol; len > 0; len--)
		if (buf[len - 1] == L'\\' || buf[len - 1] == L'/')
			break;
	if (len > 0) {
		eol -= len;
		memmove(buf, buf + len, eol * sizeof(WCHAR));
	}
	strcpy(buf + eol, ".exe");
	MultiByteToWideChar(CP_UTF8, 0, buf, eol + 5, wbuf, MAX_SHEBANG);

	return wbuf;
}

static LPWSTR find_exe(LPWSTR exe_name)
{
	static LPWSTR path;
	static size_t alloc;
	WCHAR env[_MAX_ENV + 1], *p;
	size_t exe_name_len = wcslen(exe_name), env_size;

	env_size = GetEnvironmentVariableW(L"PATH", env, _MAX_ENV + 1);
	if (!env_size || env_size > _MAX_ENV) {
		MessageBoxW(NULL, L"PATH too large", L"Error", MB_OK);
		exit(1);
	}

	for (p = env; *p; ) {
		WCHAR *q = wcschr(p, L';');
		DWORD res;
		size_t len = q ? q - p : wcslen(p);

		if (!len)
			goto next_path_component;

		if (len + exe_name_len + 2 >= alloc) {
			alloc = len + exe_name_len + 64;
			path = realloc(path, alloc * sizeof(WCHAR));
			if (!path) {
				MessageBoxW(NULL, L"Out of memory!", L"Error",
					    MB_OK);
				exit(1);
			}
		}

		memcpy(path, p, len * sizeof(WCHAR));
		if (path[len - 1] != L'\\')
			path[len++] = L'\\';
		wcscpy(path + len, exe_name);

		res = GetFileAttributesW(path);
		if (res != INVALID_FILE_ATTRIBUTES &&
		    !(res & FILE_ATTRIBUTE_DIRECTORY))
			return path;

next_path_component:
		if (!q)
			break;
		p = q + 1;
	}
	MessageBoxW(NULL, L"Could not find exe", exe_name, MB_OK);
	exit(1);
}

struct capture_stdout_data {
	HANDLE handle;
	char *buffer;
	size_t len, alloc;
};

static DWORD WINAPI capture_stdout(LPVOID lParam)
{
	struct capture_stdout_data *data = lParam;

	for (;;) {
		DWORD count;

		if (data->len + 8192 > data->alloc) {
			data->alloc = data->len + 8192;
			data->buffer = realloc(data->buffer, data->alloc);
			if (!data->buffer) {
				MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
				CloseHandle(data->handle);
				return -1;
			}
		}
		if (!ReadFile(data->handle, data->buffer + data->len, 8192, &count, NULL))
			break;
		data->len += count;
	}
	data->buffer[data->len] = '\0';

	CloseHandle(data->handle);
	return 0;
}

static int spawn_process(LPWSTR exe, LPWSTR cmdline,
			 int exit_code_may_be_nonzero,
			 int pipe_thru_stdin_and_stdout,
			 LPWSTR *capture_output)
{
	struct capture_stdout_data data = { NULL };
	STARTUPINFOW si;
	PROCESS_INFORMATION pi;
	DWORD exit_code;
	int res = 0;

	if (pipe_thru_stdin_and_stdout && capture_output) {
		fwprintf(stderr, L"cannot pipe through *and* capture\n");
		exit(1);
	}

	ZeroMemory(&pi, sizeof(PROCESS_INFORMATION));
	ZeroMemory(&si, sizeof(STARTUPINFO));

	si.cb = sizeof(si);
	si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

	if (pipe_thru_stdin_and_stdout)
		si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
	else
		si.hStdInput = INVALID_HANDLE_VALUE;

	if (!capture_output)
		si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
	else {
		if (!CreatePipe(&data.handle, &si.hStdOutput, NULL, 8192))
			return -1;

		/* Make handle intended for the child inheritable */
		if (!DuplicateHandle(GetCurrentProcess(), si.hStdOutput,
				     GetCurrentProcess(), &si.hStdOutput,
				     DUPLICATE_SAME_ACCESS, TRUE,
				     DUPLICATE_CLOSE_SOURCE))
			return -1;

		if (!CreateThread(NULL, 0, capture_stdout, &data, 0, NULL))
			return -1;
	}

	if (!CreateProcessW(exe, cmdline,
			    NULL, NULL, TRUE,
			    CREATE_NO_WINDOW,
			    NULL, NULL,
			    &si, &pi)) {
		fwprintf(stderr, L"Could not spawn `%ls`: %d\n",
			 cmdline, (int)GetLastError());
		res = -1;
		goto spawn_process_finish;
	}
	if (pipe_thru_stdin_and_stdout)
		CloseHandle(si.hStdInput);
	if (pipe_thru_stdin_and_stdout || capture_output)
		CloseHandle(si.hStdOutput);
	CloseHandle(pi.hThread);
	WaitForSingleObject(pi.hProcess, INFINITE);

	if (!GetExitCodeProcess(pi.hProcess, &exit_code))
		return 1;
	if (!exit_code_may_be_nonzero && exit_code)
		res = exit_code;

	if (capture_output && data.len && !res) {
		size_t wcs_alloc = 2 * data.len + 1, wcs_len;

		*capture_output = malloc(wcs_alloc * sizeof(WCHAR));
		if (!*capture_output) {
			MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
			res = -1;
			goto spawn_process_finish;
		}

		while (data.len > 0 &&
		       (data.buffer[data.len - 1] == '\r' || data.buffer[data.len - 1] == '\n'))
			data.len--;

		SetLastError(ERROR_SUCCESS);
		wcs_len = !data.len ? 0 :
			MultiByteToWideChar(CP_UTF8, 0, data.buffer, data.len,
					    *capture_output, wcs_alloc);
		(*capture_output)[wcs_len] = L'\0';
		if (!wcs_len && data.len) {
			WCHAR err[65536];
			swprintf(err, 65535,
				 L"Could not convert output of `%ls` to Unicode",
				 cmdline);
			err[65535] = L'\0';
			MessageBoxW(NULL, err, L"Error", MB_OK);
			res = -1;
		}
	}

spawn_process_finish:
	CloseHandle(pi.hProcess);
	free(data.buffer);

	return res;
}

static int read_config(int exit_code_may_be_nonzero)
{
	LPWSTR output = NULL;
	int res;

	res = spawn_process(find_exe(L"git.exe"),
			    L"git config credential.helperselector.selected",
			    exit_code_may_be_nonzero, 0, &output);
	if (!res)
		previously_selected_helper = output;

	return res;
}

static int write_config(void)
{
	WCHAR command_line[32768];

	swprintf(command_line, sizeof(command_line) / sizeof(*command_line) - 1,
		 L"git config --global credential.helperselector.selected \"%ls\"", helper_name[selected_helper]);
	return spawn_process(find_exe(L"git.exe"), command_line, 0, 0, NULL);
}

static LPWSTR quote(LPWSTR string)
{
	LPWSTR result, p, q;
	int needs_quotes = !*string;
	size_t len = 0;

	for (p = string; *p; p++, len++) {
		if (*p == L'"')
			len++;
		else if (wcschr(L" \t\r\n*?{'", *p))
			needs_quotes = 1;
		else if (*p == L'\\') {
			LPWSTR end = p;
			while (end[1] == L'\\')
				end++;
			len += end - p;
			if (end[1] == L'"' ||
			    (needs_quotes && end[1] == L'\0'))
				len += end - p + 1;
			p = end;
		}
	}

	if (!needs_quotes && len == p - string)
		return string;

	q = result = malloc((len + 3) * sizeof(WCHAR));
	*(q++) = L'"';
	for (p = string; *p; p++) {
		if (*p == L'"')
			*(q++) = L'\\';
		else if (*p == L'\\') {
			LPWSTR end = p;
			while (end[1] == L'\\')
				end++;
			if (end != p) {
				memcpy(q, p, (end - p) * sizeof(WCHAR));
				q += end - p;
			}
			if (end[1] == L'"' || end[1] == L'\0') {
				memcpy(q, p, (end - p + 1) * sizeof(WCHAR));
				q += end - p + 1;
			}
			p = end;
		}
		*(q++) = *p;
	}
	wcscpy(q, L"\"");
	return result;
}

static int path_ends_with(LPWSTR bread, LPWSTR crumb)
{
	size_t len1 = wcslen(bread), len2 = wcslen(crumb);

	return len1 >= len2 && !wcsicmp(bread + len1 - len2, crumb);
}

static int can_write_lock_file(LPWSTR path)
{
	size_t len = wcslen(path);
	LPWSTR lock_file = malloc((len + 6) * sizeof(WCHAR));
	HANDLE h;
	FILE_DISPOSITION_INFO info = { TRUE };

	if (!lock_file) {
		MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
		exit(1);
	}
	wcscpy(lock_file, path);
	wcscpy(lock_file + len, L".lock");

	h = CreateFileW(lock_file, GENERIC_WRITE | DELETE, FILE_SHARE_WRITE,
			NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
	free(lock_file);
	if (h == INVALID_HANDLE_VALUE)
		return 0;

	SetFileInformationByHandle(h, FileDispositionInfo, &info, sizeof(info));
	CloseHandle(h);
	return 1;
}

static int discover_config_to_persist_to(void)
{
	/*
	 * If this helper is configured as credential.helper, we use the same
	 * config to persist the choice (by overriding that setting).
	 *
	 * Otherwise, we first test whether we can write to the system config,
	 * and use it if we can. We fall back to the user config if everything
	 * else fails.
	 */
	LPWSTR git_exe = find_exe(L"git.exe"), output, tab, quoted;
	size_t len, len2;
	WCHAR git_editor_backup[_MAX_ENV + 1];
	int git_editor_unset = 1, res;

	res = spawn_process(git_exe,
			    L"git config --show-origin credential.helper",
			    0, 0, &output);
	if (!res && !wcsncmp(output, L"file:", 5) &&
	    (tab = wcschr(output, L'\t')) &&
	    (!wcsicmp(tab + 1, L"helper-selector") ||
	     path_ends_with(tab + 1, L"\\git-credential-helper-selector.exe"))) {
		/*
		 * If it is relative, we might not be in the correct
		 * directory... Make sure that we are!
		 */
		if (!(output[5] == L'/' || output[5] == L'\\' ||
		      (iswalpha(output[5]) && output[6] == L':'))) {
			LPWSTR toplevel;
			if (spawn_process(git_exe, L"git rev-parse --show-cdup",
					  0, 0, &toplevel) == 0 && toplevel[0])
				_wchdir(toplevel);
			free(toplevel);
		}
		*tab = L'\0';
		if (can_write_lock_file(output + 5)) {
			quoted = quote(output + 5);
			if (quoted == output + 5)
				quoted = wcsdup(quoted);
			len = 4 + wcslen(quoted);
			persist_to_config_option = malloc(len * sizeof(WCHAR));
			len2 = 30 + wcslen(output + 5);
			persist_tooltip = malloc(len2 * sizeof(WCHAR));
			if (!persist_to_config_option || !persist_tooltip) {
				MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
				exit(1);
			}
			swprintf(persist_to_config_option, len, L"-f %ls", quoted);
			free(quoted);
			swprintf(persist_tooltip, len2,
				 L"Set credential.helper in '%ls'", output + 5);
			free(output);
			return 0;
		}
	}
	free(output);

	/* Now figure out where the system config is */
	SetLastError(ERROR_SUCCESS);
	if (GetEnvironmentVariableW(L"GIT_EDITOR", git_editor_backup, _MAX_ENV + 1) ||
	    GetLastError() == ERROR_SUCCESS)
		git_editor_unset = 0;
	SetEnvironmentVariableW(L"GIT_EDITOR", L"echo");
	res = spawn_process(git_exe, L"git -c "
			    "advice.waitingForEditor=0 config --system -e",
			    0, 0, &output);
	SetEnvironmentVariableW(L"GIT_EDITOR", git_editor_unset ? NULL : git_editor_backup);
	if (!res && can_write_lock_file(output)) {
		persist_to_config_option = L"--system";
		persist_tooltip = L"Set credential.helper in the system config";
	} else {
		persist_to_config_option = L"--global";
		persist_tooltip = L"Set credential.helper in the user config";
	}
	free(output);
	return 0;
}

static int persist_choice(void)
{
	WCHAR escaped[65536];
	WCHAR command_line[65536];
	LPWSTR p, q = escaped;

	/*
	 * Convert backslashes to forward slashes, as `git.exe` likes them
	 * better; Also prefix with an exclamation point and wrap in double
	 * quotes to support paths with spaces.
	 */
	if (!selected_helper)
		escaped[0] = L'\0';
	else {
		*(q++) = L'!';
		*(q++) = L'"';
		for (p = helper_path[selected_helper]; *p; p++)
			*(q++) = *p == L'\\' ? L'/' : *p;
		*(q++) = L'"';
		*(q++) = L'\0';
	}

	swprintf(command_line, 65535, L"git config %ls credential.helper %ls",
		 persist_to_config_option, quote(escaped));
	return spawn_process(find_exe(L"git.exe"), command_line, 0, 0, NULL);
}

static int discover_helpers(void)
{
	WCHAR *pattern_suffix = L"\\git-credential-*";
	size_t alloc = 16, env_size, pattern_len, pattern_suffix_len = wcslen(pattern_suffix);
	WCHAR env[_MAX_ENV + 1], pattern[_MAX_ENV + 1 + pattern_suffix_len], *p;
	HANDLE h;
	WIN32_FIND_DATAW find_data;

	env_size = GetEnvironmentVariableW(L"PATH", env, _MAX_ENV + 1);
	if (!env_size || env_size > _MAX_ENV) {
		MessageBoxW(NULL, L"PATH too large", L"Error", MB_OK);
		return -1;
	}

	helper_nr = 1;
	helper_name = malloc(alloc * sizeof(*helper_name));
	helper_path = malloc(alloc * sizeof(*helper_path));
	if (!helper_name || !helper_path) {
out_of_memory:
		free(helper_name);
		free(helper_path);
		MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
		return -1;
	}
	helper_name[0] = L"<no helper>";
	helper_path[0] = L"<none>";
	selected_helper = 0;

	if (!previously_selected_helper)
		previously_selected_helper = L"manager-core";

	for (p = env; *p; ) {
		WCHAR *q = wcschr(p, L';');

		pattern_len = q ? q - p : wcslen(p);
		if (pattern_len > 0 && p[pattern_len - 1] == L'\\')
			pattern_len--;
		p[pattern_len] = '\0';
		memcpy(pattern, p, pattern_len * sizeof(WCHAR));
		wcscpy(pattern + pattern_len, pattern_suffix);
		h = FindFirstFileW(pattern, &find_data);
		while (h != INVALID_HANDLE_VALUE) {
			size_t len = wcslen(find_data.cFileName), i;

			if (len < pattern_suffix_len - 2 || wcsnicmp(pattern_suffix + 1, find_data.cFileName, pattern_suffix_len - 2)) {
				fwprintf(stderr, L"Unexpected entry: '%ls'\n", find_data.cFileName);
				fflush(stderr);
				goto next_file;
			}
			if (path_ends_with(find_data.cFileName, L".html"))
				goto next_file; /* skip e.g. git-credential-manager.html */
			if (path_ends_with(find_data.cFileName, L".pdb"))
				goto next_file; /* skip e.g. git-credential-store.pdb */
			if (!wcsicmp(find_data.cFileName, L"git-credential-helper-selector.exe"))
				goto next_file; /* skip the credential helper selector itself */

			if (helper_nr + 1 >= alloc) {
				alloc += 16;
				if (helper_nr + 1 >= alloc)
					alloc = helper_nr + 16;
				helper_name = realloc(helper_name, alloc * sizeof(*helper_name));
				helper_path = realloc(helper_path, alloc * sizeof(*helper_path));
				if (!helper_name || !helper_path)
					goto out_of_memory;
			}

			helper_path[helper_nr] = malloc((pattern_len + 1 + len + 1) * sizeof(WCHAR));
			if (!helper_path[helper_nr])
				goto out_of_memory;
			memcpy(helper_path[helper_nr], pattern, pattern_len * sizeof(WCHAR));
			helper_path[helper_nr][pattern_len] = L'\\';
			memcpy(helper_path[helper_nr] + pattern_len + 1, find_data.cFileName, (len + 1) * sizeof(WCHAR));

			/* make sure that it is an executable or a script */
			if (path_ends_with(helper_path[helper_nr], L".exe") ||
			    path_ends_with(helper_path[helper_nr], L".bat") ||
			    path_ends_with(helper_path[helper_nr], L".cmd"))
				; /* is executable */
			else if (!parse_script_interpreter(helper_path[helper_nr])) {
				free(helper_path[helper_nr]);
				goto next_file;
			}

			helper_name[helper_nr] = malloc((len + 1 - (pattern_suffix_len - 2)) * sizeof(WCHAR));
			if (!helper_name[helper_nr])
				goto out_of_memory;
			memcpy(helper_name[helper_nr], find_data.cFileName + pattern_suffix_len - 2, (len + 1 - (pattern_suffix_len - 2)) * sizeof(WCHAR));
			if (len - (pattern_suffix_len - 2) > 4 && !wcsicmp(helper_name[helper_nr] + len - (pattern_suffix_len - 2) - 4, L".exe")) {
				len -= 4;
				helper_name[helper_nr][len - (pattern_suffix_len - 2)] = L'\0';
			}

			/* Avoid duplicate entries for duplicate PATH entries (i.e. the very same path) */
			for (i = 0; i < helper_nr; i++)
				if (!wcsicmp(helper_path[i], helper_path[helper_nr]))
					goto next_file;

			/* Special-case Git Credential Manager */
			if (!selected_helper && !wcsicmp(helper_name[helper_nr], previously_selected_helper))
				selected_helper = helper_nr;

			helper_nr++;

next_file:
			if (!FindNextFileW(h, &find_data))
				break;
		}

		if (h != INVALID_HANDLE_VALUE)
			FindClose(h);

		if (!q)
			break;
		p = q + 1;
	}

	return 0;
}

static void create_tooltip(HWND hwnd, LPWSTR tooltip_text) {
	static INITCOMMONCONTROLSEX iccex;
	static DWORD tooltip_nr;
	HWND tooltip;
	TOOLINFOW toolinfo = { 0 };

	if (!iccex.dwSize) {
		iccex.dwICC = ICC_WIN95_CLASSES;
		iccex.dwSize = sizeof(INITCOMMONCONTROLSEX);
		InitCommonControlsEx(&iccex);
	}

	tooltip = CreateWindowExW(WS_EX_TOPMOST, TOOLTIPS_CLASSW, NULL,
				 WS_POPUP | TTS_NOPREFIX | TTS_ALWAYSTIP,
				 CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
				 hwnd, NULL, instance, NULL);

	GetClientRect(hwnd, &toolinfo.rect);
	toolinfo.cbSize = sizeof(toolinfo);
	toolinfo.uFlags = TTF_SUBCLASS;
	toolinfo.hwnd = hwnd;
	toolinfo.uId = tooltip_nr++;
	toolinfo.lpszText = tooltip_text;

	SendMessage(tooltip, TTM_ADDTOOL, 0, (LPARAM) &toolinfo);
}

static int aborted = 1;
static int width = 400, height = 300;
static int offset_x = 10, offset_y = 10;
static int line_height = 25, line_offset_y = 5, button_width = 75;
static HFONT font = NULL;

static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wParam,
				    LPARAM lParam)
{
	switch (message) {
	case WM_CREATE: {
		RECT rect;
		int width;
		HWND hwnd3;
		size_t i;

		GetClientRect(hwnd, &rect);
		width = rect.right - rect.left;
		NONCLIENTMETRICSW non_client_metrics;
		non_client_metrics.cbSize = sizeof(non_client_metrics);
		if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, non_client_metrics.cbSize, &non_client_metrics, 0))
			font = CreateFontIndirectW(&non_client_metrics.lfMessageFont);
		if (!font) {
			font = CreateFontW(0, 0, 0, 0, FW_DONTCARE, FALSE, FALSE, FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS,
				CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, (DEFAULT_PITCH | FF_DONTCARE), TEXT("MS Shell Dlg 2"));
		}

		HWND select_helper_hwnd = CreateWindowW(L"Button", L"Select a credential helper",
			      WS_TABSTOP | WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
			      offset_x, offset_y,
			      width - 2 * offset_x,
			      line_height * helper_nr + 3 * offset_y,
			      hwnd, (HMENU) 0, instance, NULL);
		if (font)
			SendMessage(select_helper_hwnd, WM_SETFONT, (WPARAM) font, TRUE);

		for (i = 0; i < helper_nr; i++) {
			HWND hwnd2 = CreateWindowW(L"Button", helper_name[i],
						   WS_CHILD | WS_VISIBLE |
						   BS_AUTORADIOBUTTON | BS_NOTIFY,
						   2 * offset_x,
						   3 * offset_y + line_height * i,
						   width - 4 * offset_x,
						   line_height + line_offset_y,
						   hwnd, (HMENU)(ID_USER + i), instance, NULL);
			create_tooltip(hwnd2, helper_path[i]);
			if (font)
				SendMessage(hwnd2, WM_SETFONT, (WPARAM) font, TRUE);
			if (i == selected_helper) {
				SendMessage(hwnd2, BM_SETCHECK, BST_CHECKED, 1);
				SetFocus(hwnd2);
			}
		}

		hwnd3 = CreateWindowW(L"Button",
				      L"&Always use this from now on",
				      WS_TABSTOP | WS_VISIBLE | WS_CHILD |
				      BS_CHECKBOX,
				      2 * offset_x,
				      4 * offset_y + line_height * helper_nr,
				      width - 2 * offset_x,
				      line_height + line_offset_y,
				      hwnd, (HMENU) ID_PERSIST, NULL, NULL);
		create_tooltip(hwnd3, persist_tooltip);
		if (font)
			SendMessage(hwnd3, WM_SETFONT, (WPARAM) font, TRUE);

		HWND select_btn_hwnd = CreateWindowW(L"Button", L"Select",
			      WS_TABSTOP | WS_VISIBLE | WS_CHILD | BS_DEFPUSHBUTTON,
			      width - 2 * (button_width + offset_x),
			      5 * offset_y + line_height * (helper_nr + 1),
			      button_width,
			      line_height + line_offset_y,
			      hwnd, (HMENU) ID_ENTER, NULL, NULL);
		if (font)
			SendMessage(select_btn_hwnd, WM_SETFONT, (WPARAM) font, TRUE);

		HWND cancel_btn_hwnd = CreateWindowW(L"Button", L"Cancel",
			      WS_TABSTOP | WS_VISIBLE | WS_CHILD,
			      width - (button_width + offset_x),
			      5 * offset_y + line_height * (helper_nr + 1),
			      button_width,
			      line_height + line_offset_y,
			      hwnd, (HMENU) ID_ABORT, NULL, NULL);
		if (font)
			SendMessage(cancel_btn_hwnd, WM_SETFONT, (WPARAM) font, TRUE);

		break;
	}

	case WM_COMMAND:
		if (LOWORD(wParam) == ID_ENTER) {
			aborted = 0;
			SendMessage(hwnd, WM_CLOSE, 0, 0);
		} else if (wParam == ID_ABORT) {
			SendMessage(hwnd, WM_CLOSE, 0, 0);
		} else if (LOWORD(wParam) == ID_ESCAPE) {
			int res = MessageBoxW(main_window, L"Are you sure you want to quit?",
					      L"Quit?", MB_OKCANCEL);
			if (res == IDOK)
				SendMessage(hwnd, WM_CLOSE, 0, 0);
		} else if (HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) >= ID_USER) {
			selected_helper = LOWORD(wParam) - ID_USER;
		} else if (HIWORD(wParam) == BN_DBLCLK && LOWORD(wParam) >= ID_USER) {
			aborted = 0;
			selected_helper = LOWORD(wParam) - ID_USER;
			SendMessage(main_window, WM_CLOSE, 0, 0);
		} else if (wParam == ID_PERSIST) {
			persist = !IsDlgButtonChecked(hwnd, ID_PERSIST);
			CheckDlgButton(hwnd, ID_PERSIST, persist ? BST_CHECKED : BST_UNCHECKED);
		}
		break;

	case WM_DESTROY:
		if (font)
			DeleteObject(font);
		PostQuitMessage(0);
		break;
	}

	return DefWindowProcW(hwnd, message, wParam, lParam);
}

static ACCEL accelerators[] = {
	{ FVIRTKEY, VK_ESCAPE, ID_ESCAPE }
};

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
		    PWSTR lpCmdLine, int nCmdShow)
{
	WNDCLASSW window_class = { 0 };
	MSG message;
	HACCEL accelerator_handle;

	window_class.lpszClassName = L"CredentialHelperSelector";
	window_class.hInstance = hInstance;
	window_class.lpfnWndProc = window_proc;
	window_class.hbrBackground = GetSysColorBrush(COLOR_3DFACE);
	window_class.hCursor = LoadCursor(0, IDC_ARROW);

	if (read_config(1) < 0) {
		MessageBoxW(NULL, L"Could not read Git config", L"Error", MB_OK);
		return 1;
	}

	if (discover_config_to_persist_to() < 0) {
		MessageBoxW(NULL, L"Could not discover config source", L"Error", MB_OK);
		return 1;
	}

	if (discover_helpers() < 0) {
		MessageBoxW(NULL, L"Could not discover credential helpers", L"Error", MB_OK);
		return 1;
	}

	height = 5 * offset_y + line_height * (helper_nr + 4) + line_offset_y;

	instance = hInstance;
	RegisterClassW(&window_class);
	main_window = CreateWindowW(window_class.lpszClassName, L"CredentialHelperSelector",
				    WS_OVERLAPPEDWINDOW | WS_VISIBLE,
				    CW_USEDEFAULT, CW_USEDEFAULT,
				    width, height, 0, 0, hInstance, 0);

	accelerator_handle =
		CreateAcceleratorTableW(accelerators,
					sizeof(accelerators) / sizeof(accelerators[0]));

	while (GetMessage(&message, NULL, 0, 0)) {
		if (TranslateAcceleratorW(main_window, accelerator_handle, &message) || IsDialogMessage(main_window, &message))
			continue;
		TranslateMessage(&message);
		DispatchMessage(&message);
	}

	DestroyAcceleratorTable(accelerator_handle);

	if (!aborted) {
		if (selected_helper < 0 || selected_helper >= helper_nr)
			aborted = 1;
		else {
			size_t command_len = wcslen(lpCmdLine), helper_len, interpreter_len = 0, alloc;
			LPWSTR helper, exe, cmdline, p;
			LPWSTR interpreter = NULL, interpreter_unquoted;

			if (persist)
				persist_choice();
			else
				write_config();

			if (!selected_helper)
				return 1; /* no helper */

			exe = helper_path[selected_helper];
			helper = quote(exe);
			helper_len = wcslen(helper);
			alloc = helper_len + command_len + 2;

			interpreter_unquoted = parse_script_interpreter(helper);
			if (interpreter_unquoted) {
				interpreter = quote(interpreter);
				interpreter_len = wcslen(interpreter);
				alloc += interpreter_len + 1;
				exe = find_exe(interpreter);
			}

			cmdline = malloc(alloc * sizeof(WCHAR));
			if (!cmdline) {
				MessageBoxW(NULL, L"Out of memory!",
					    L"Error", MB_OK);
				exit(1);
			}

			p = cmdline;
			if (interpreter) {
				wcscpy(p, interpreter);
				p[interpreter_len] = L' ';
				p += interpreter_len + 1;
			}
			wcscpy(p, helper);
			if (command_len) {
				p[helper_len] = L' ';
				wcscpy(p + helper_len + 1, lpCmdLine);
			}

			aborted = spawn_process(exe, cmdline, 0, 1, NULL);
			if (aborted < 0)
				aborted = 1;
			if (helper != exe)
				free(helper);
			if (interpreter != interpreter_unquoted)
				free(interpreter);
			free(cmdline);
		}
	}

	return aborted;
}

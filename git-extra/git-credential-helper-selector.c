#include <windows.h>
#include <stdio.h>

static HINSTANCE instance;
static LPWSTR *helper_name, *helper_path;
static size_t helper_nr, selected_helper;

#define ID_ENTER   IDOK
#define ID_ABORT   IDCANCEL
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
	    (!wcscmp(path + count - 3, L"exe") ||
	     !wcscmp(path + count - 3, L"bat") ||
	     !wcscmp(path + count - 3, L"cmd")))
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

static int spawn_process(LPWSTR exe, LPWSTR cmdline)
{
	STARTUPINFOW si;
	PROCESS_INFORMATION pi;
	DWORD exit_code;
	int res = 0;

	ZeroMemory(&pi, sizeof(PROCESS_INFORMATION));
	ZeroMemory(&si, sizeof(STARTUPINFO));

	si.cb = sizeof(si);
	si.dwFlags = STARTF_USESTDHANDLES;
	si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
	si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
	si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

	if (!CreateProcessW(exe, cmdline,
			    NULL, NULL, TRUE,
			    CREATE_NO_WINDOW,
			    NULL, NULL,
			    &si, &pi)) {
		fwprintf(stderr, L"Could not spawn `%s`: %d\n",
			 cmdline, (int)GetLastError());
		res = -1;
		goto spawn_process_finish;
	}
	CloseHandle(si.hStdInput);
	CloseHandle(si.hStdOutput);
	CloseHandle(pi.hThread);
	WaitForSingleObject(pi.hProcess, INFINITE);

	if (!GetExitCodeProcess(pi.hProcess, &exit_code))
		return 1;
	if (exit_code)
		res = exit_code;

spawn_process_finish:
	CloseHandle(pi.hProcess);

	return res;
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

			if (len < pattern_suffix_len - 2 || wcsncmp(pattern_suffix + 1, find_data.cFileName, pattern_suffix_len - 2)) {
				fwprintf(stderr, L"Unexpected entry: '%s'\n", find_data.cFileName);
				fflush(stderr);
				goto next_file;
			}
			if (len > 5 && !wcscmp(find_data.cFileName + len - 5, L".html"))
				goto next_file; /* skip e.g. git-credential-manager.html */
			if (len > 4 && !wcscmp(find_data.cFileName + len - 4, L".pdb"))
				goto next_file; /* skip e.g. git-credential-store.pdb */

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

			helper_name[helper_nr] = malloc((len + 1 - (pattern_suffix_len - 2)) * sizeof(WCHAR));
			if (!helper_name[helper_nr])
				goto out_of_memory;
			memcpy(helper_name[helper_nr], find_data.cFileName + pattern_suffix_len - 2, (len + 1 - (pattern_suffix_len - 2)) * sizeof(WCHAR));
			if (len - (pattern_suffix_len - 2) > 4 && !wcscmp(helper_name[helper_nr] + len - (pattern_suffix_len - 2) - 4, L".exe")) {
				len -= 4;
				helper_name[helper_nr][len - (pattern_suffix_len - 2)] = L'\0';
			}

			/* Avoid duplicate entries for duplicate PATH entries (i.e. the very same path) */
			for (i = 0; i < helper_nr; i++)
				if (!wcscmp(helper_path[i], helper_path[helper_nr]))
					goto next_file;

			/* Special-case Git Credential Manager */
			if (!selected_helper && !wcscmp(helper_name[helper_nr], L"manager"))
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

static int aborted = 1;

static int width = 400, height = 300;
static int offset_x = 10, offset_y = 10;
static int line_height = 25, line_offset_y = 5, button_width = 75;

static LRESULT CALLBACK window_proc(HWND hwnd, UINT message, WPARAM wParam,
				    LPARAM lParam)
{
	switch (message) {
	case WM_CREATE: {
		RECT rect;
		int width;
		size_t i;

		GetClientRect(hwnd, &rect);
		width = rect.right - rect.left;
		CreateWindowW(L"Button", L"Select a credential helper",
			      WS_CHILD | WS_VISIBLE | BS_GROUPBOX,
			      offset_x, offset_y,
			      width - 2 * offset_x,
			      line_height * helper_nr + 3 * offset_y,
			      hwnd, (HMENU) 0, instance, NULL);
		for (i = 0; i < helper_nr; i++) {
			HWND hwnd2 = CreateWindowW(L"Button", helper_name[i],
						   WS_CHILD | WS_VISIBLE |
						   BS_AUTORADIOBUTTON,
						   2 * offset_x,
						   3 * offset_y + line_height * i,
						   width - 4 * offset_x,
						   line_height + line_offset_y,
						   hwnd, (HMENU)(ID_USER + i), instance, NULL);
			if (i == selected_helper) {
				SendMessage(hwnd2, BM_SETCHECK, BST_CHECKED, 1);
				SetFocus(hwnd2);
			}
		}

		CreateWindowW(L"Button", L"Select",
			      WS_VISIBLE | WS_CHILD,
			      width - 2 * (button_width + offset_x),
			      5 * offset_y + line_height * helper_nr,
			      button_width,
			      line_height + line_offset_y,
			      hwnd, (HMENU) ID_ENTER, NULL, NULL);

		CreateWindowW(L"Button", L"Cancel",
			      WS_VISIBLE | WS_CHILD,
			      width - (button_width + offset_x),
			      5 * offset_y + line_height * helper_nr,
			      button_width,
			      line_height + line_offset_y,
			      hwnd, (HMENU) ID_ABORT, NULL, NULL);
		break;
	}

	case WM_COMMAND:
		if (LOWORD(wParam) == ID_ENTER) {
			aborted = 0;
			SendMessage(hwnd, WM_CLOSE, 0, 0);
		} else if (wParam == ID_ABORT) {
			SendMessage(hwnd, WM_CLOSE, 0, 0);
		} else if (HIWORD(wParam) == BN_CLICKED && LOWORD(wParam) >= ID_USER) {
			selected_helper = LOWORD(wParam) - ID_USER;
		}
		break;

	case WM_DESTROY:
		PostQuitMessage(0);
		break;
	}

	return DefWindowProcW(hwnd, message, wParam, lParam);
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
		    PWSTR lpCmdLine, int nCmdShow)
{
	WNDCLASSW window_class = { 0 };
	MSG message;

	window_class.lpszClassName = L"CredentialHelperSelector";
	window_class.hInstance = hInstance;
	window_class.lpfnWndProc = window_proc;
	window_class.hbrBackground = GetSysColorBrush(COLOR_3DFACE);
	window_class.hCursor = LoadCursor(0, IDC_ARROW);

	if (discover_helpers() < 0) {
		MessageBoxW(NULL, L"Could not discover credential helpers", L"Error", MB_OK);
		return 1;
	}

	instance = hInstance;
	RegisterClassW(&window_class);
	CreateWindowW(window_class.lpszClassName, L"CredentialHelperSelector",
		      WS_OVERLAPPEDWINDOW | WS_VISIBLE,
		      CW_USEDEFAULT, CW_USEDEFAULT,
		      width, height, 0, 0, hInstance, 0);

	while (GetMessage(&message, NULL, 0, 0)) {
		TranslateMessage(&message);
		DispatchMessage(&message);
	}

	if (!aborted) {
		if (selected_helper < 0 || selected_helper >= helper_nr)
			aborted = 1;
		else {
			size_t command_len = wcslen(lpCmdLine), helper_len, interpreter_len = 0, alloc;
			LPWSTR helper, exe, cmdline, interpreter, p;

			if (!selected_helper)
				return 1; /* no helper */

			exe = helper = helper_path[selected_helper];
			helper_len = wcslen(helper);
			alloc = helper_len + command_len + 2;

			interpreter = parse_script_interpreter(helper);
			if (interpreter) {
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

			aborted = spawn_process(exe, cmdline);
			if (aborted < 0)
				aborted = 1;
			free(cmdline);
		}
	}

	return aborted;
}

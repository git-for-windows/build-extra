#include <windows.h>
#include <stdio.h>

static HINSTANCE instance;
static LPWSTR *helper_name, *helper_path;
static size_t helper_nr, selected_helper;

#define ID_ENTER   IDOK
#define ID_ABORT   IDCANCEL
#define ID_USER    2000

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

	return aborted;
}

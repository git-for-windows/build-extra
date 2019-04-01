#include <windows.h>

static HINSTANCE instance;
static LPWSTR *helper_name, *helper_path;
static size_t helper_nr, selected_helper;

#define ID_ENTER   IDOK
#define ID_ABORT   IDCANCEL
#define ID_USER    2000

static int discover_helpers(void)
{
	/* TODO: walk `PATH` to populate these */
	helper_nr = 2;
	helper_name = malloc(helper_nr * sizeof(*helper_name));
	helper_path = malloc(helper_nr * sizeof(*helper_path));
	if (!helper_name || !helper_path) {
		MessageBoxW(NULL, L"Out of memory!", L"Error", MB_OK);
		return -1;
	}
	helper_name[0] = L"<no helper>";
	helper_path[0] = L"<none>";
	helper_name[1] = L"manager";
	helper_path[1] = L"C:\\Program Files\\Git\\mingw64\\libexec\\git-core\\git-credential-manager.exe";

	selected_helper = 1;

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

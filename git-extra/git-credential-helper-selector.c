#include <windows.h>

#define ID_ENTER   IDOK
#define ID_ABORT   IDCANCEL

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

		GetClientRect(hwnd, &rect);
		width = rect.right - rect.left;

		CreateWindowW(L"Button", L"Select",
			      WS_VISIBLE | WS_CHILD,
			      width - 2 * (button_width + offset_x),
			      offset_y,
			      button_width,
			      line_height + line_offset_y,
			      hwnd, (HMENU) ID_ENTER, NULL, NULL);

		CreateWindowW(L"Button", L"Cancel",
			      WS_VISIBLE | WS_CHILD,
			      width - (button_width + offset_x),
			      offset_y,
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

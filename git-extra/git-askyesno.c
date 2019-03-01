#define WIN32_LEAN_AND_MEAN
#include <windows.h>

int wmain(int argc, wchar_t **wargv)
{
	int res;
	wchar_t *title = L"Question?";

	if (argc > 2 && !wcscmp(L"--title", wargv[1])) {
		title = wargv[2];
		argc -=2;
		wargv += 2;
	}

	if (argc != 2) {
		MessageBoxW(NULL, L"Usage: git askyesno <question>", L"Error!", MB_OK);
		return 1;
	}

	res = MessageBoxW(NULL, wargv[1], title, MB_YESNO);

	return res == IDYES ? 0 : 1;
}

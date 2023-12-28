#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdlib.h>

int wmain(int argc, wchar_t **wargv)
{
	int res;
	wchar_t *title = L"Question?", *prompt = NULL;

	if (argc > 2 && !wcscmp(L"--title", wargv[1])) {
		title = wargv[2];
		argc -=2;
		wargv += 2;
	}

	if (argc < 2) {
		MessageBoxW(NULL, L"Usage: git askyesno <question>", L"Error!", MB_OK);
		return 1;
	}

	if (argc > 2) {
		size_t count = wcslen(wargv[1]), i;

		for (i = 2; i < argc; i++)
			count += 1 + wcslen(wargv[i]);

		prompt = malloc((count + 1) * sizeof(*prompt));
		if (!prompt) {
			MessageBoxW(NULL, L"Out of memory asking a question", L"Error!", MB_OK);
			return 1;
		}

		wcscpy(prompt, wargv[1]);
		count = wcslen(wargv[1]);

		for (i = 2; i < argc; i++) {
			prompt[count++] = L' ';
			wcscpy(prompt + count, wargv[i]);
			count += wcslen(wargv[i]);
		}
	}

	res = MessageBoxW(NULL, prompt ? prompt : wargv[1], title, MB_YESNO);

	free(prompt);
	return res == IDYES ? 0 : 1;
}

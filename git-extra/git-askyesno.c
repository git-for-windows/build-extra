#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int wmain(int argc, wchar_t **wargv)
{
	int res;
	HANDLE mutex = NULL;
	wchar_t *title = L"Question?", *prompt = NULL, *mutex_name = NULL;

	while (argc > 2) {
		if (!wcscmp(L"--title", wargv[1]))
			title = wargv[2];
		else if (!wcscmp(L"--mutex", wargv[1]))
			mutex_name = wargv[2];
		else
			break;
		argc -=2;
		wargv += 2;
	}

	if (argc < 2) {
		MessageBoxW(NULL,
			    L"Usage: git askyesno [--title <title>] "
			    L"[--mutex <name>] <question>", L"Error!", MB_OK);
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

	if (mutex_name) {
		DWORD error;

		mutex = CreateMutexW(NULL, FALSE, mutex_name);
		error = GetLastError();
		if (!mutex) {
			wchar_t message[128];

			swprintf(message, sizeof(message) / sizeof(*message),
				 L"Could not create prompt mutex (error %lu)",
				 error);
			MessageBoxW(NULL, message, L"Error!", MB_OK | MB_ICONERROR);
			free(prompt);
			return 3;
		}
		if (error == ERROR_ALREADY_EXISTS) {
			CloseHandle(mutex);
			free(prompt);
			/* No user decision: another prompt holds the mutex. */
			return 2;
		}
	}

	res = MessageBoxW(NULL, prompt ? prompt : wargv[1], title, MB_YESNO);

	if (mutex)
		CloseHandle(mutex);
	free(prompt);
	return res == IDYES ? 0 : 1;
}

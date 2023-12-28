#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include "git-askpass.h"

INT_PTR CALLBACK PasswordProc(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
	wchar_t *lpszPassword = NULL;
	WORD cchPassword;

	switch (message)
	{
		case WM_INITDIALOG:
			/* Display the prompt */
			SetDlgItemTextW(hDlg, IDC_PROMPT, (wchar_t *) lParam);
			if (GetDlgCtrlID((HWND) wParam) != IDE_PASSWORDEDIT) {
				SetFocus(GetDlgItem(hDlg, IDE_PASSWORDEDIT));
				return FALSE;
			}
			return TRUE;
		case WM_COMMAND:
			switch(wParam)
			{
				case IDOK:
					/* Get number of characters. */
					cchPassword = (WORD) SendDlgItemMessage(hDlg,
										IDE_PASSWORDEDIT,
										EM_LINELENGTH,
										(WPARAM) 0,
										(LPARAM) 0);

					lpszPassword = (wchar_t *) malloc(sizeof(wchar_t) * (cchPassword + 1));
					if (!lpszPassword) {
						MessageBoxW(NULL, L"Out of memory asking for a password", L"Error!", MB_OK);
						EndDialog(hDlg, FALSE);
						return TRUE;
					}
					/* Put the number of characters into first word of buffer. */
					*((LPWORD)lpszPassword) = cchPassword;

					/* Get the characters. */
					SendDlgItemMessageW(hDlg,
							    IDE_PASSWORDEDIT,
							    EM_GETLINE,
							    (WPARAM) 0,       /* line 0 */
							    (LPARAM) lpszPassword);

					/* Null-terminate the string. */
					lpszPassword[cchPassword] = 0;

					wprintf(L"%ls\n", lpszPassword);

					EndDialog(hDlg, TRUE);
					free(lpszPassword);
					return TRUE;

				case IDCANCEL:
					EndDialog(hDlg, FALSE);
					return TRUE;
			}
			return 0;
	}
	return FALSE;

	UNREFERENCED_PARAMETER(lParam);
}

int wmain(int argc, wchar_t **wargv)
{
	INT_PTR res;
	wchar_t *prompt = NULL;
	wchar_t *default_prompt = L"Please enter your password:";

	if (argc > 1) {
		size_t count = wcslen(wargv[1]), i;

		for (i = 2; i < argc; i++)
			count += 1 + wcslen(wargv[i]);

		prompt = malloc((count + 1) * sizeof(*prompt));
		if (!prompt) {
			MessageBoxW(NULL, L"Out of memory asking for a password", L"Error!", MB_OK);
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

	res = DialogBoxParamW(NULL,                    /* application instance */
		MAKEINTRESOURCEW(IDD_PASSWORD), /* dialog box resource */
		NULL,                          /* owner window */
		PasswordProc,                  /* dialog box window procedure */
		(LPARAM) (prompt ? prompt : default_prompt));

	free(prompt);
	return !res;
}

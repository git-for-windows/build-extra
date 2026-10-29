#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <fcntl.h>
#include <io.h>

struct dialog {
	DWORD pid;
	HWND window;
};

static int error(const char *message)
{
	fprintf(stderr, "%s (Windows error %lu)\n", message, GetLastError());
	return 1;
}

static BOOL CALLBACK find_dialog(HWND window, LPARAM parameter)
{
	struct dialog *dialog = (struct dialog *)parameter;
	DWORD pid;
	wchar_t name[32];

	GetWindowThreadProcessId(window, &pid);
	if (pid != dialog->pid || !IsWindowVisible(window))
		return TRUE;
	if (!GetClassNameW(window, name, 32) || wcscmp(name, L"#32770"))
		return TRUE;
	if (!GetDlgItem(window, IDYES) && !GetDlgItem(window, IDOK) &&
	    !GetDlgItem(window, IDCANCEL))
		return TRUE;
	dialog->window = window;
	return FALSE;
}

static int print_text(HWND window)
{
	wchar_t text[1024];
	char output[4096];

	SetLastError(0);
	if (!GetWindowTextW(window, text, 1024) && GetLastError())
		return error("Could not read test dialog");
	if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1,
				 output, sizeof(output), NULL, NULL))
		return error("Could not encode test dialog text");
	if (puts(output) == EOF) {
		perror("Could not write test dialog text");
		return 1;
	}
	return 0;
}

static int run(wchar_t *executable)
{
	JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = { 0 };
	STARTUPINFOW startup = { 0 };
	PROCESS_INFORMATION process = { 0 };
	wchar_t *command = GetCommandLineW(), name[128];
	HANDLE job;
	DWORD result = 125;
	int i, quoted;

	/* Forward the original quoting after the executable and "run". */
	for (i = 0; i < 2; i++) {
		for (quoted = 0; *command; command++) {
			if (*command == L'"')
				quoted = !quoted;
			else if (!quoted && (*command == L' ' || *command == L'\t'))
				break;
		}
		while (*command == L' ' || *command == L'\t')
			command++;
	}

	swprintf(name, 128, L"Local\\GitAskYesNo.Test.%lu.%llu",
		 GetCurrentProcessId(), (unsigned long long)GetTickCount64());
	job = CreateJobObjectW(NULL, name);
	if (!job) {
		error("Could not create test job");
		return 125;
	}
	if (GetLastError() == ERROR_ALREADY_EXISTS) {
		fprintf(stderr, "Test job name is already in use\n");
		CloseHandle(job);
		return 125;
	}
	limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
	if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation,
				     &limits, sizeof(limits))) {
		error("Could not configure test job");
		goto done;
	}
	startup.cb = sizeof(startup);
	if (!CreateProcessW(executable, command, NULL, NULL, FALSE,
			    CREATE_SUSPENDED, NULL, NULL, &startup, &process)) {
		error("Could not start test prompt");
		goto done;
	}
	if (!AssignProcessToJobObject(job, process.hProcess) ||
	    ResumeThread(process.hThread) == (DWORD)-1) {
		error("Could not attach test prompt to its job");
		TerminateProcess(process.hProcess, 99);
		goto done;
	}
	if (printf("%lu %ls\n", process.dwProcessId, name) < 0 || fflush(stdout)) {
		fprintf(stderr, "Could not report test prompt PID\n");
		goto done;
	}
	if (WaitForSingleObject(process.hProcess, 30000) != WAIT_OBJECT_0) {
		fprintf(stderr, "Test prompt %lu did not exit within 30 seconds\n",
			process.dwProcessId);
		goto done;
	}
	if (!GetExitCodeProcess(process.hProcess, &result)) {
		error("Could not read test prompt exit code");
		result = 125;
	}
done:
	CloseHandle(job);
	if (process.hProcess) {
		WaitForSingleObject(process.hProcess, 5000);
		CloseHandle(process.hProcess);
		CloseHandle(process.hThread);
	}
	return result;
}

int wmain(int argc, wchar_t **argv)
{
	struct dialog dialog = { 0 };
	HANDLE process;
	wchar_t *end;
	DWORD status, start;
	int button, result = 1;

	if (_setmode(_fileno(stdout), _O_BINARY) == -1) {
		perror("Could not configure test output");
		return 125;
	}
	if (argc >= 3 && !wcscmp(argv[1], L"run"))
		return run(argv[2]);
	if (argc != 3) {
		fprintf(stderr, "Usage: test-askyesno <run executable ...|wait PID|"
			"text PID|close PID|yes PID|kill job>\n");
		return 1;
	}
	if (!wcscmp(argv[1], L"kill")) {
		HANDLE job = OpenJobObjectW(JOB_OBJECT_TERMINATE, FALSE, argv[2]);

		if (!job)
			return GetLastError() == ERROR_FILE_NOT_FOUND ? 0 :
				error("Could not open test job");
		result = TerminateJobObject(job, 99) ? 0 :
			error("Could not terminate test job");
		CloseHandle(job);
		return result;
	}
	dialog.pid = wcstoul(argv[2], &end, 10);
	if (!dialog.pid || *end) {
		fprintf(stderr, "Invalid test prompt PID\n");
		return 1;
	}
	process = OpenProcess(SYNCHRONIZE, FALSE, dialog.pid);
	if (!process)
		return error("Could not open test prompt");
	start = GetTickCount();
	do {
		EnumWindows(find_dialog, (LPARAM)&dialog);
		if (dialog.window)
			break;
		status = WaitForSingleObject(process, 25);
		if (status != WAIT_TIMEOUT) {
			fprintf(stderr, "Test prompt %lu exited before its dialog\n",
				dialog.pid);
			goto done;
		}
	} while ((DWORD)(GetTickCount() - start) < 10000);
	if (!dialog.window) {
		fprintf(stderr, "Test prompt %lu did not show a dialog\n", dialog.pid);
		goto done;
	}
	if (!wcscmp(argv[1], L"wait")) {
		result = 0;
	} else if (!wcscmp(argv[1], L"text")) {
		result = print_text(dialog.window) ||
			print_text(GetDlgItem(dialog.window, 65535));
	} else if (!wcscmp(argv[1], L"close") || !wcscmp(argv[1], L"yes")) {
		button = !wcscmp(argv[1], L"yes") ? IDYES :
			GetDlgItem(dialog.window, IDNO) ? IDNO :
			GetDlgItem(dialog.window, IDOK) ? IDOK : IDCANCEL;
		if (!PostMessageW(dialog.window, WM_COMMAND, button, 0))
			error("Could not answer test prompt");
		else
			result = 0;
	} else {
		fprintf(stderr, "Unknown test command\n");
	}
done:
	CloseHandle(process);
	return result;
}

#include <stdio.h>
#include <shlobj.h>

void die(HRESULT hres, const char *message)
{
	DWORD err_code = (DWORD) hres;
	char err_msg[1024];

	CoUninitialize();
	if (!FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
			   NULL, err_code, 0, err_msg, sizeof err_msg, NULL))
		sprintf(err_msg, "N/A (0x%08lX)\n", err_code);
	fprintf(stderr, "%s\nError: %s", message, err_msg);
	exit(1);
}

void check_hres(HRESULT hres, const char* message)
{
	if (FAILED(hres))
		die(hres, message);
}

int main(int argc, char **argv)
{
	const char *progname = argv[0];
	const char *work_dir = NULL, *arguments = NULL, *icon_file = NULL;
	const char *description = NULL;
	int show_cmd = 1, desktop_shortcut = 0, dry_run = 0;
	size_t len;

	static WCHAR wsz[1024];
	HRESULT hres;
	IShellLink* psl;
	IPersistFile* ppf;

	while (argc > 2) {
		if (argv[1][0] != '-')
			break;
		if (!strcmp(argv[1], "--work-dir"))
			work_dir = argv[2];
		else if (!strcmp(argv[1], "--arguments"))
			arguments = argv[2];
		else if (!strcmp(argv[1], "--show-cmd"))
			show_cmd = atoi(argv[2]);
		else if (!strcmp(argv[1], "--icon-file"))
			icon_file = argv[2];
		else if (!strcmp(argv[1], "--description"))
			description = argv[2];
		else if (!strcmp(argv[1], "--desktop-shortcut")) {
			desktop_shortcut = 1;
			argc--;
			argv++;
			continue;
		} else if (!strcmp(argv[1], "-n") || !strcmp(argv[1], "--dry-run")) {
			dry_run = 1;
			argc--;
			argv++;
			continue;
		} else {
			fprintf(stderr, "Unknown option: %s\n", argv[1]);
			return 1;
		}

		argc -= 2;
		argv += 2;
	}

	if (argc > 1 && !strcmp(argv[1], "--")) {
		argc--;
		argv++;
	}

	if (argc != 3) {
		fprintf(stderr, "Usage: %s [options] <source> <destination>\n",
			progname);
		return 1;
	}

	if ((len = strlen(argv[2])) < 5 || strcasecmp(argv[2] + len - 4, ".lnk")) {
		fprintf(stderr, "Can only create .lnk files ('%s' was specified)\n", argv[2]);
		return 1;
	}

	if (dry_run) {
		printf("source: %s\n", argv[1]);

		if (work_dir)
			printf("work_dir: %s\n", work_dir);

		if (show_cmd)
			printf("show_cmd: %d\n", show_cmd);

		if (icon_file)
			printf("icon_file: %s\n", icon_file);

		if (arguments)
			printf("arguments: %s\n", arguments);

		if (description)
			printf("description: %s\n", description);

		if (desktop_shortcut) {
			PWSTR p;

			hres = SHGetKnownFolderPath(&FOLDERID_Desktop,
						    KF_FLAG_DONT_UNEXPAND, NULL, &p);
			check_hres(hres, "could not get desktop path");

			printf("destination: %ls\\%s\n", p, argv[2]);

			CoTaskMemFree(p);
		} else
			printf("destination: %s\n", argv[2]);

		return 0;
	}

	hres = CoInitialize(NULL);
	check_hres(hres, "Could not initialize OLE");

	hres = CoCreateInstance(&CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER,
			&IID_IShellLink, (void **)&psl);
	check_hres(hres, "Could not get ShellLink interface");

	hres = psl->lpVtbl->QueryInterface(psl, &IID_IPersistFile,
			(void **) &ppf);
	check_hres(hres, "Could not get PersistFile interface");

	hres = psl->lpVtbl->SetPath(psl, argv[1]);
	check_hres(hres, "Could not set path");

	if (work_dir)
		psl->lpVtbl->SetWorkingDirectory(psl, work_dir);

	if (show_cmd)
		psl->lpVtbl->SetShowCmd(psl, show_cmd);

	if (icon_file)
		psl->lpVtbl->SetIconLocation(psl, icon_file, 0);
	if (arguments)
		psl->lpVtbl->SetArguments(psl, arguments);
	if (description)
		psl->lpVtbl->SetDescription(psl, description);

	if (!desktop_shortcut)
		wsz[0] = 0;
	else {
		PWSTR p;

		hres = SHGetKnownFolderPath(&FOLDERID_Desktop,
					    KF_FLAG_DONT_UNEXPAND, NULL, &p);
		check_hres(hres, "Could not get desktop path");

		desktop_shortcut = wcslen(p);
		if (desktop_shortcut + 2 + strlen(argv[2]) * 3 >
		    sizeof(wsz) / sizeof(WCHAR)) {
			fwprintf(stderr,
				 L"Error: Too long Desktop path: %s\n", p);
			exit(1);
		}
		memcpy(wsz, p, sizeof(WCHAR) * desktop_shortcut);
		wsz[desktop_shortcut++] = L'\\';
		wsz[desktop_shortcut] = L'\0';
		CoTaskMemFree(p);
	}
	MultiByteToWideChar(CP_ACP, 0, argv[2], -1,
			    wsz + desktop_shortcut,
			    sizeof(wsz) / sizeof(WCHAR) - desktop_shortcut);
	hres = ppf->lpVtbl->Save(ppf,
			(const WCHAR*)wsz, TRUE);

	ppf->lpVtbl->Release(ppf);
	psl->lpVtbl->Release(psl);

	check_hres(hres, "Could not save link");

	CoUninitialize();
	return 0;
}

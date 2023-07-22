@REM This script is intended to be run after installation of Git for Windows
@REM (including the portable version)

@REM If run manually, it should be run via
@REM   git-bash.exe --no-needs-console --hide --no-cd --command=post-install.bat
@REM to hide the console.

@REM Change to the directory in which this script lives.
@REM https://technet.microsoft.com/en-us/library/bb490909.aspx says:
@REM <percent>~dpI Expands <percent>I to a drive letter and path only.
@REM <percent>~fI Expands <percent>I to a fully qualified path name.
@FOR /F "delims=" %%D IN ("%~dp0") DO @CD %%~fD

@SET /A "version=0" & FOR /F "tokens=2 delims=[]" %%i IN ('"VER"') DO @(
	@FOR /F "tokens=2 delims=. " %%v IN ("%%~i") DO @(
		@SET /A "version=%%~v + 0"
	)
)

@REM If this is a 32-bit Git for Windows, adjust the DLL address ranges.
@REM We cannot use %PROCESSOR_ARCHITECTURE% for this test because it is
@REM allowed to install a 32-bit Git for Windows into a 64-bit system.
@IF EXIST mingw32\bin\git.exe @(
	@REM We need to rebase just to make sure that it still works even with
	@REM 32-bit Windows 10
	@IF %version% GEQ 10 @(
		@REM We copy `rebase.exe` because it links to `msys-2.0.dll`
		@REM (and @REM thus prevents modifying it). It is okay to
		@REM execute `rebase.exe`, though, because the DLL base address
		@REM problems only really show when other processes are
		@REM `fork()`ed and `rebase.exe` does no such thing.
		@IF NOT EXIST bin\rebase.exe @(
			@IF NOT EXIST bin @MKDIR bin
			@COPY usr\bin\rebase.exe bin\rebase.exe
		)
		@IF NOT EXIST bin\msys-2.0.dll @(
			@COPY usr\bin\msys-2.0.dll bin\msys-2.0.dll
		)
		@bin\rebase.exe -b 0x64000000 usr\bin\msys-2.0.dll
	)

	usr\bin\dash.exe -c '/usr/bin/dash usr/bin/rebaseall -p'
)

@REM Checks if this script is running with administrative privileges and if not ask the user if they wish to attempt privilege escalation using a message box.
@REM This is required in case this script was called by the portable installer.
@REM
@REM Then if running with administrative privileges adds mandatory ASLR security exceptions for the executables in the "usr/bin" directory.
@REM This is required for Git Bash to work when running on a Windows system with mandatory ASLR enabled.
@REM
@REM Mandatory ASLR is a Windows security feature that is disabled by default.
@REM https://learn.microsoft.com/microsoft-365/security/defender-endpoint/exploit-protection-reference?view=o365-worldwide#force-randomization-for-images-mandatory-aslr
@REM
@REM Doing this significantly slows down the load time of the program settings list in the exploit protection section of the Windows security application but it will load eventually.
@REM
@REM This is all done with PowerShell because Batch doesn't have native message box or exploit protection management functionality.
@SET commands=Add-Type -AssemblyName PresentationFramework,System.Windows.Forms;^
function Main()^
{^
	while (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))^
	{^
    	$title = 'Git Installer';^
    	$icon = [System.Windows.Forms.MessageBoxIcon]::Question;^
    	$body =  \"Administrative privileges are required to add mandatory ASLR security exceptions for the executables in the `\"usr/bin`\" directory.`n`nThis is required for Git Bash to work when running on a Windows system with mandatory ASLR enabled.`n`nMandatory ASLR is a Windows security feature that is disabled by default.`n`nDoing this significantly slows down the load time of the program settings list in the exploit protection section of the Windows security application but it will load eventually.`n`nWould you like to attempt privilege escalation to add these exceptions?\";^
    	$buttons = 'YesNo';^
    	$response = [System.Windows.MessageBox]::Show($body, $title, $buttons, $icon);^
    	if ($response -eq 'Yes')^
    	{^
			break;^
		}^
		else^
		{^
			exit;^
		}^
	}^
	$process = Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -PassThru -Wait -ArgumentList '-Command \"cd ''%cd%''; Get-ChildItem -Path usr/bin -Filter *.exe -File | ForEach-Object { Set-ProcessMitigation -Name $_.FullName -Disable ForceRelocateImages }\"';^
	if ($process.ExitCode -ne 0)^
	{^
    	Main;^
	}^
}^
Main

powershell.exe -command %commands%

@echo "running post-install"
@REM Run the post-install scripts
@usr\bin\bash.exe --norc -c "export PATH=/usr/bin:$PATH; export SYSCONFDIR=/etc; for p in $(export LC_COLLATE=C; echo /etc/post-install/*.post); do test -e \"$p\" && . \"$p\"; done"

@REM Unset environment variables set by this script
@SET "version="

@REM Remove this script
@DEL post-install.bat

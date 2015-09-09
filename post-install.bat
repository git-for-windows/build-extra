@REM This script is intended to be run after installation of Git for Windows
@REM (including the portable version)

@REM If run manually, it should be run via
@REM   git-bash.exe --no-needs-console --hide --no-cd --command=post-install.cmd
@REM to hide the console.

@REM Change to the directory in which this script lives.
@REM https://technet.microsoft.com/en-us/library/bb490909.aspx says:
@REM <percent>~dpI Expands <percent>I to a drive letter and path only.
@REM <percent>~fI Expands <percent>I to a fully qualified path name.
@FOR /F "delims=" %%D IN ("%~dp0") DO @CD %%~fD

@REM If this is a 32-bit Git for Windows, adjust the DLL address ranges.
@REM We cannot use %PROCESSOR_ARCHITECTURE% for this test because it is
@REM allowed to install a 32-bit Git for Windows into a 64-bit system.
@IF EXIST mingw32\bin\git.exe @(
	usr\bin\dash.exe -c '/usr/bin/dash usr/bin/rebaseall -p'
)

@REM Run the post-install scripts
@usr\bin\bash.exe --login -c exit

@REM Remove this script
@DEL post-install.bat

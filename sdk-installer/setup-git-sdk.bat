@REM Set up the Git SDK

@REM determine root directory

@REM https://technet.microsoft.com/en-us/library/bb490909.aspx says:
@REM <percent>~dpI Expands <percent>I to a drive letter and path only.
@REM <percent>~fI Expands <percent>I to a fully qualified path name.
@FOR /F "delims=" %%D in ("%~dp0") do @set cwd=%%~fD

@CD "%cwd%"
@IF ERRORLEVEL 1 GOTO DIE

@REM set PATH
@set PATH=%cwd%\mini\mingw@@BITNESS@@\bin;%PATH%

@ECHO Cloning the Git for Windows SDK...
@git init
@IF ERRORLEVEL 1 GOTO DIE
@git config http.sslbackend schannel
@IF ERRORLEVEL 1 GOTO DIE
@git remote add origin @@GIT_SDK_URL@@
@IF ERRORLEVEL 1 GOTO DIE
@git fetch --depth 1 origin
@IF ERRORLEVEL 1 GOTO DIE
@git -c core.fscache=true checkout -t origin/main
@IF ERRORLEVEL 1 GOTO DIE

@REM Cleaning up temporary git.exe
@RMDIR /Q /S mini
@IF ERRORLEVEL 1 GOTO DIE

@REM Avoid overlapping address ranges
@IF 32 == @@BITNESS@@ @(
	ECHO Auto-rebasing .dll files
	CALL autorebase.bat
)

@REM Before running a shell, let's prevent complaints about "permission denied"
@REM from MSYS2's /etc/post-install/01-devices.post
@MKDIR dev\shm 2> NUL
@MKDIR dev\mqueue 2> NUL

@START /B git-bash.exe
@EXIT /B 0

:DIE
@ECHO Installation of Git for Windows' SDK failed!
@PAUSE
@EXIT /B 1


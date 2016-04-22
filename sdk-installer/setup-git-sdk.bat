@REM Set up the Git SDK

@REM determine root directory

@REM https://technet.microsoft.com/en-us/library/bb490909.aspx says:
@REM <percent>~dpI Expands <percent>I to a drive letter and path only.
@REM <percent>~fI Expands <percent>I to a fully qualified path name.
@FOR /F "delims=" %%D in ("%~dp0") do @set cwd=%%~fD

@REM set PATH
@set PATH=%cwd%\usr\bin;%PATH%

@REM set MSYSTEM so that MSYS2 starts up in the correct mode
@set MSYSTEM=MINGW@@BITNESS@@

@REM need to rebase just to make sure that it still works even with Windows 10
@SET initialrebase=false
@FOR /F "tokens=4 delims=.[XP " %%i IN ('ver') DO @SET ver=%%i
@IF 10 LEQ %ver @(
	@SET initialrebase=false
)

@IF %initialrebase% == true @(
	@REM we copy `rebase.exe` because it links to `msys-2.0.dll`.
	@IF NOT EXIST "%cwd%"\bin\rebase.exe @(
		@IF NOT EXIST "%cwd%"\bin @MKDIR "%cwd%"\bin
		@COPY "%cwd%"\usr\bin\rebase.exe "%cwd%"\bin\rebase.exe
	)
	@IF NOT EXIST bin\msys-2.0.dll @(
		@COPY usr\bin\msys-2.0.dll bin\msys-2.0.dll
	)
	@"%cwd%"\bin\rebase.exe -b 0x63000000 "%cwd%"\usr\bin\msys-2.0.dll
)

@SET /A counter=0
:INSTALL_RUNTIME
@SET /A counter+=1
@IF %counter% GEQ 5 @(
	@ECHO Could not install msys2-runtime
	@PAUSE
	@EXIT 1
)

@REM Maybe we need a proxy?
@IF %counter% GEQ 2 @(
	@ECHO.
	@ECHO There was a problem accessing the MSYS2 repositories
	@ECHO If your setup requires an HTTP proxy to access the web,
	@ECHO please specify it here, otherwise leave it empty.
	@ECHO.
	@SET /p proxy= "HTTP proxy: "
)
@REM Check the proxy variable here because of delayed expansion
@IF NOT "%proxy%" == "" @(
	@SET http_proxy=%proxy%
	@SET https_proxy=%proxy%
	@IF %counter% EQU 2 @(
		@COPY "%cwd%"\etc\pacman.conf.proxy "%cwd%"\etc\pacman.conf
	)
)

@REM update the Pacman package indices first, then force-install msys2-runtime
@REM (we ship with a stripped-down msys2-runtime, gpg and pacman), so that
@REM pacman's post-install scripts run without complaining about heap problems
@"%cwd%"\usr\bin\pacman -Sy --needed --force --noconfirm msys2-runtime

@REM need to rebase just to make sure that it still works even with Windows 10
@IF %initialrebase% == true @(
	@"%cwd%"\bin\rebase.exe -b 0x63000000 "%cwd%"\usr\bin\msys-2.0.dll
)

@IF ERRORLEVEL 1 GOTO INSTALL_RUNTIME

@SET /A counter=0
:INSTALL_BASH
@SET /A counter+=1
@IF %counter% GEQ 5 @(
	@ECHO Could not install bash
	@PAUSE
	@EXIT 1
)

@REM next, force update bash
@"%cwd%"\usr\bin\pacman -S --needed --force --noconfirm bash

@SET /A counter=0
:INSTALL_INFO
@SET /A counter+=1
@IF %counter% GEQ 5 @(
	@ECHO Could not install info
	@PAUSE
	@EXIT 1
)

@REM we need a /tmp directory, just for the time being
@MKDIR "%cwd%"\tmp

@REM next, initialize pacman's keyring
@"%cwd%"\usr\bin\bash.exe -l -c '/usr/bin/bash /usr/bin/pacman-key --init'
@IF ERRORLEVEL 1 PAUSE

@REM next, force update info
@"%cwd%"\usr\bin\pacman -S --needed --force --noconfirm info

@IF ERRORLEVEL 1 GOTO INSTALL_INFO

@SET /A counter=0
:INSTALL_PACMAN
@SET /A counter+=1
@IF %counter% GEQ 5 @(
	@ECHO Could not install pacman
	@PAUSE
	@EXIT 1
)

@REM next, force update pacman
@"%cwd%"\usr\bin\pacman -S --needed --force --noconfirm pacman

@IF ERRORLEVEL 1 GOTO INSTALL_PACMAN

@SET /A counter=0
:INSTALL_REST
@SET /A counter+=1
@IF %counter% GEQ 5 @(
	@ECHO Could not install the remaining packages
	@PAUSE
	@EXIT 1
)

@REM now update the rest
@"%cwd%"\usr\bin\pacman -S --needed --force --noconfirm ^
	base python less openssh patch make tar diffutils ca-certificates ^
	git perl-Error perl perl-Authen-SASL perl-libwww perl-MIME-tools ^
	perl-Net-SMTP-SSL perl-TermReadKey dos2unix asciidoc xmlto ^
	subversion mintty vim git-extra p7zip markdown winpty ^
	mingw-w64-@@ARCH@@-git-doc-html ^
	mingw-w64-@@ARCH@@-git mingw-w64-@@ARCH@@-toolchain ^
	mingw-w64-@@ARCH@@-curl mingw-w64-@@ARCH@@-expat ^
	mingw-w64-@@ARCH@@-openssl mingw-w64-@@ARCH@@-tcl ^
	mingw-w64-@@ARCH@@-pcre mingw-w64-@@ARCH@@-connect ^
	git-flow ssh-pageant

@IF ERRORLEVEL 1 GOTO INSTALL_REST

@REM Avoid overlapping address ranges
@IF MINGW32 == %MSYSTEM% @(
	ECHO Auto-rebasing .dll files
	CALL "%cwd%"\autorebase.bat
)

@REM If an HTTP proxy is required, configure it for Git Bash sessions,
@REM but only if the environment variable was not already set globally
@IF DEFINED proxy @(
	@ECHO http_proxy=%proxy% > etc\profile.d\proxy.sh
	@ECHO https_proxy=%proxy% >> etc\profile.d\proxy.sh
	@ECHO export http_proxy https_proxy >> etc\profile.d\proxy.sh
	@ECHO.
	@ECHO Installed /etc/profile.d/proxy.sh to set proxy in Git Bash
)

@REM Before running a shell, let's prevent complaints about "permission denied"
@REM from MSYS2's /etc/post-install/01-devices.post
@MKDIR "%cwd%"\dev\shm 2> NUL
@MKDIR "%cwd%"\dev\mqueue 2> NUL

@IF NOT DEFINED JENKINS_URL @(
	@REM Install shortcut on the desktop
	@ECHO.
	@ECHO Installing the 'Git SDK @@BITNESS@@-bit' shortcut on the Desktop
	@bash --login -c 'SHORTCUT="$HOME/Desktop/Git SDK @@BITNESS@@-bit.lnk"; test -f "$SHORTCUT" ^|^| create-shortcut.exe --icon-file /msys2.ico --work-dir / /git-bash.exe "$SHORTCUT"'

	@REM now clone the Git sources, build it, and start an interactive shell
	@bash --login -c "mkdir -p /usr/src && cd /usr/src && for project in MINGW-packages MSYS2-packages build-extra; do test ! -d $project && mkdir -p $project && (cd $project && git init && git config core.autocrlf false && git remote add origin https://github.com/git-for-windows/$project); done; if test ! -d git; then git clone -b @@GIT_BRANCH@@ -c core.autocrlf=false https://github.com/git-for-windows/git; fi && cd git && make install"

	@IF ERRORLEVEL 1 PAUSE

	@start mintty -i /msys2.ico -t "Git SDK @@BITNESS@@-bit" bash --login -i
)

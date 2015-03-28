@REM Set up the Git SDK

@REM determine root directory

@REM https://technet.microsoft.com/en-us/library/bb490909.aspx says:
@REM <percent>~dpI Expands <percent>I to a drive letter and path only.
@REM <percent>~fI Expands <percent>I to a fully qualified path name.
@FOR /F "delims=" %%D in ("%~dp0") do @set cwd=%%~fD

@REM set PATH
@set PATH=%cwd%\usr\bin;%PATH%

@REM set MSYSTEM so that MSys2 starts up in the correct mode
@set MSYSTEM=MINGW@@BITNESS@@

@SET /A counter=0
:INSTALL_RUNTIME
@SET /A counter+=1
@IF %counter% GEQ 5 (
	@ECHO "Could not install msys2-runtime"
	@PAUSE
	@EXIT 1
)

@REM update the Pacman package indices first, then force-install msys2-runtime
@REM (we ship with a stripped-down msys2-runtime, gpg and pacman), so that
@REM pacman's post-install scripts run without complaining about heap problems
@%cwd%\usr\bin\pacman -Sy --force --noconfirm msys2-runtime

@IF ERRORLEVEL 1 GOTO INSTALL_RUNTIME

@SET /A counter=0
:INSTALL_PACMAN
@SET /A counter+=1
@IF %counter% GEQ 5 (
	@ECHO "Could not install pacman"
	@PAUSE
	@EXIT 1
)

@REM next, force update pacman, but first we need bash and info for that.
@%cwd%\usr\bin\pacman -S --force --noconfirm bash info pacman

@IF ERRORLEVEL 1 GOTO INSTALL_PACMAN

@SET /A counter=0
:INSTALL_REST
@SET /A counter+=1
@IF %counter% GEQ 5 (
	@ECHO "Could not install the remaining packages"
	@PAUSE
	@EXIT 1
)

@REM now update the rest
@%cwd%\usr\bin\pacman -S --force --noconfirm ^
	base python less openssh patch make tar diffutils ca-certificates ^
	perl-Error perl perl-Authen-SASL perl-libwww perl-MIME-tools ^
	perl-Net-SMTP-SSL perl-TermReadKey dos2unix subversion ^
	mintty vim git-extra ^
	mingw-w64-@@ARCH@@-git mingw-w64-@@ARCH@@-toolchain ^
	mingw-w64-@@ARCH@@-curl mingw-w64-@@ARCH@@-expat ^
	mingw-w64-@@ARCH@@-openssl mingw-w64-@@ARCH@@-tcl ^
	mingw-w64-@@ARCH@@-pcre

@IF ERRORLEVEL 1 GOTO INSTALL_REST

@REM Avoid overlapping address ranges
@IF MINGW32 == %MSYSTEM% (
	ECHO "Auto-rebasing .dll files"
	CALL %cwd%\autorebase.bat
)

@REM Install shortcut on the desktop
@bash --login -c 'SHORTCUT="$HOME/Desktop/Git SDK @@BITNESS@@-bit.lnk"; test -f "$SHORTCUT" ^|^| create-shortcut.exe --icon-file /msys2.ico --work-dir / /git-bash.exe "$SHORTCUT"'

@REM now clone the Git sources, build it, and start an interactive shell
@mintty -i /msys2.ico bash --login -c "test -s /mingw@@BITNESS@@/ssl/certs/ca-bundle.crt || pacman -S --noconfirm mingw-w64-@@ARCH@@-ca-certificates; mkdir -p /usr/src && cd /usr/src && for project in MINGW-packages MSYS2-packages build-extra; do mkdir -p $project && (cd $project && git init && git config core.autocrlf false && git remote add origin https://github.com/git-for-windows/$project); done; git clone -b @@GIT_BRANCH@@ -c core.autocrlf=false https://github.com/git-for-windows/git && cd git && make install; bash --login -i"

@IF ERRORLEVEL 1 PAUSE

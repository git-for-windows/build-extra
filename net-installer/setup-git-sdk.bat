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

@REM update the Pacman package indices first, then force-install msys2-runtime
@REM (we ship with a stripped-down msys2-runtime, gpg and pacman), so that
@REM pacman's post-install scripts run without complaining about heap problems
@%cwd%\usr\bin\pacman -Sy --force --noconfirm msys2-runtime

@REM next, force update pacman
@%cwd%\usr\bin\pacman -S --force --noconfirm pacman

@REM now update the rest
@%cwd%\usr\bin\pacman -S --force --noconfirm ^
	base python less openssh patch make tar diffutils ca-certificates ^
	perl-Error perl perl-Authen-SASL perl-libwww perl-MIME-tools ^
	perl-Net-SMTP-SSL perl-TermReadKey ^
	mintty vim git-extra ^
	mingw-w64-@@ARCH@@-git mingw-w64-@@ARCH@@-toolchain ^
	mingw-w64-@@ARCH@@-curl mingw-w64-@@ARCH@@-expat ^
	mingw-w64-@@ARCH@@-openssl mingw-w64-@@ARCH@@-tcl ^
	mingw-w64-@@ARCH@@-pcre

@REM Avoid overlapping address ranges
@IF MINGW32 == %MSYSTEM% ECHO "Auto-rebasing .dll files"
@IF MINGW32 == %MSYSTEM% CALL %cwd%\autorebase.bat

@REM now clone the Git sources, build it, and start an interactive shell
@bash --login -c "mkdir -p /usr/src && cd /usr/src && counter=1; while test $counter -lt 5; do git -c core.autocrlf=false clone -b @@GIT_BRANCH@@ https://github.com/git-for-windows/git; status=$?; test $status = 0 && break; test $status = 128 || exit $status; counter=$(($counter+1)); done && cd git && git config core.autocrlf false && make install; bash -i"

@IF NOT ERRORLEVEL 0 bash --login -i

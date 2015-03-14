@REM This script ensures that a complete SDK to develop, build and test
@REM Git for Windows is available.
@REM
@REM Must be called in the top-level directory of an installed MSys2 setup

@IF exist usr\bin\sh.exe GOTO haveshell

@ECHO Please start this script in the top-level directory of an MSys2 setup.
@EXIT /b 1

:haveshell

@usr\bin\ps | usr\bin\grep /bash$
@IF 1==%ERRORLEVEL% GOTO notinuse

@ECHO Unfortunately, the MSys2 shell is in use. Please quit it and restart.
@EXIT /b 1

:notinuse

@usr\bin\grep git-for-windows etc/pacman.conf
@IF 0==%ERRORLEVEL% GOTO haverepo

@usr\bin\sed -i.bup -e '/^\[mingw32\]/i\^
[git-for-windows]\n^
Server = https://dl.bintray.com/$repo/pacman/$arch\n^
SigLevel = Optional\n^
' etc/pacman.conf

:haverepo

@usr\bin\pacman -Sy --noconfirm msys2-runtime

@FOR /f "delims=" %%a IN ('usr\bin\uname -m') DO SET arch=%%a
@IF "i686"=="%arch%" GOTO setmingw32

@set MSYSTEM=MINGW64

@GOTO runinstall

:setmingw32

@set MSYSTEM=MINGW32

:runinstall

@usr\bin\sh -c "export PATH=/usr/bin:$PATH && pacman -Syu --noconfirm

@set dependencies=git mingw-w64-%arch%-toolchain ^
 python less openssh patch make tar diffutils ca-certificates ^
 perl-Error perl perl-Authen-SASL perl-libwww perl-MIME-tools ^
 perl-Net-SMTP-SSL perl-TermReadKey winpty-git ^
 mingw-w64-%arch%-curl mingw-w64-%arch%-expat ^
 mingw-w64-%arch%-openssl mingw-w64-%arch%-tcl ^
 mingw-w64-%arch%-pcre

@usr\bin\sh -c "export PATH=/usr/bin:$PATH && pacman -S --noconfirm %dependencies%"

@SET thisscript=%~f0
@SET sdk64=c:\git-sdk-64
@SET sdk32=c:\git-sdk-32

@IF ("%1"=="") (
	@ECHO Could not run "%1"
	EXIT 1
)

@SET subcommand=%1
@SHIFT
@CD %sdk64%
@CALL :%subcommand% %1 %2 %3 %4 %5 %6 %7 %8 %9
@IF ERRORLEVEL 1 (
	@ECHO Could not run %1 for 64-bit
	@EXIT 1
)
@CD %sdk32%
@CALL :%subcommand% %1 %2 %3 %4 %5 %6 %7 %8 %9
@IF ERRORLEVEL 1 (
	@ECHO Could not run %1 for 32-bit
	@EXIT 1
)
@EXIT 0

:verifyboth


@GOTO :EOF

:buildruntime

@FOR /F "delims=" %%D in (".") do @set ROOT=%%~fD
@CD usr\src\MSYS2-packages\msys2-runtime
@SET MSYSTEM=MSYS
@%ROOT%\usr\bin\bash --login -c "PARALLEL_BUILD=-j15 /usr/bin/time makepkg --noconfirm -s"

@GOTO :EOF

:updatepackages

@ECHO Updating msys2-runtime
@REM pacman requires the msys2-runtime, but can somehow manage to quit just
@REM after updating it, though not much else
usr\bin\pacman -Syq --noprogressbar --needed --force --noconfirm ^
	msys2-runtime msys2-runtime-devel

@ECHO Updating Pacman
@REM post-install scripts cannot be run in the same session that upgraded Bash
@usr\bin\pacman -Sq --noprogressbar --needed --force --noconfirm ^
	bash

@ECHO Updating Bash
@REM After upgrading pacman, the pacman executable only manages to quit, but
@REM that's it
@usr\bin\pacman -Sq --noprogressbar --needed --force --noconfirm ^
	pacman

@ECHO Finally upgrade all remaining (i.e. uncontentious) packages
@usr\bin\pacman -Suq --noprogressbar --force --noconfirm

@ECHO Upgraded packages!
@GOTO :EOF

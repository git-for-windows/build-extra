@REM This script updates a Git for Windows SDK via Pacman.
@REM
@REM Note: an alternative would be to clone the SDK from the Git mirrors at
@REM https://github.com/git-for-windows/git-sdk-64 or
@REM https://github.com/git-for-windows/git-sdk-32 and then update it via
@REM `git pull` (but that must be done outside of the Git SDK, e.g. via a
@REM regular Git for Windows Bash that was installed using the official Git for
@REM Windows installer).
@REM
@REM At this time, it is not recommended to mix both methods. Either use Git,
@REM or use Pacman, but not both, to update your Git for Windows SDK.

@REM Enable extensions
@REM the `verify other 2>nul` is a trick from the setlocal help
@VERIFY other 2>nul
@SETLOCAL enableDelayedExpansion

@IF ERRORLEVEL 1 (
    @ECHO Unable to enable delayed expansion!
    @EXIT /B 1
)

@REM Get the absolute path to the current directory (i.e. the SDK root)
@FOR /F "delims=" %%I IN ("%~dp0..") do @set git_sdk_root=%%~fI
@SET PATH=%~dp0\usr\bin;%PATH%

@REM Set to MSYS mode
@SET MSYSTEM=MSYS

@ECHO Run Pacman
@pacman -Syyu --noconfirm
@IF ERRORLEVEL 1 GOTO DIE

@REM If Pacman updated "core" packages, e.g. the MSYS2 runtime, it stops
@REM (because Pacman itself depends on the MSYS2 runtime, and continuing would
@REM result in crashes or hangs). In such a case, we simply need to upgrade
@REM *again*.
@REM
@REM To detect that, we look at Pacman's log and search for the needle
@REM
@REM 	[PACMAN] starting <upgrade-type> system upgrade
@REM
@REM If the last such line has the upgrade type `full`, we're fine, and do not
@REM need to run Pacman again. Otherwise we will have to run it again, letting
@REM it upgrade the non-core packages.
@REM
@REM Since this condition is pretty much impossible to determine in a plain
@REM `.bat` script, we call out to the Bash to search for that needle. The
@REM actual command looks a bit ugly because there are *two* levels of
@REM escaping:
@REM
@REM - The "outer" one, for CMD, via carets (`^`), for every double
@REM   quote (`"`), ampersand (`&`) and pipe symbol (`|`).
@REM
@REM - The "inner" one, for Bash, via backslashes (`\`), for "inner" double
@REM   quotes (i.e. *not* for the double quotes enclosing the script snippet
@REM   that is passed to Bash itself) and for brackets (`[` and `]`).
@REM
@REM   The inner double quotes must therefore be escaped twice: `\^"`.
@REM
@REM The carets at the end of the line are continuation symbols, to allow for
@REM specifying a long script snippet on multiple lines.
@REM
@REM Also note that `IF ERRORLEVEL 0 GOTO LABEL` jumps to said label when the
@REM error level is 0 *or higher*, i.e. it would always jump. Not what we want.
@REM So we *must* make it an "error" when everything is upgraded already.

@git-cmd.exe --command=usr\bin\bash.exe -lc ^" ^
	needle=\^"$(tail -c 16384 /var/log/pacman.log ^| ^
		   grep '\[PACMAN\] starting .* system upgrade' ^| ^
		   tail -n 1)\^" ^&^& ^
	test -n \^"$needle\^" ^&^& ^
	test \^"a$needle\^" = \^"a${needle#*full system upgrade}\^"^"

@IF ERRORLEVEL 1 GOTO FINISH

@ECHO "Run Pacman again to upgrade the remaining (non-core) packages"
@pacman -Su --noconfirm
@IF ERRORLEVEL 1 GOTO DIE

:FINISH
@REM Wrapping up: re-install git-extra
@pacman -S --noconfirm git-extra
@IF ERRORLEVEL 1 GOTO DIE

@ECHO All done!
@EXIT /B 0

:DIE
@ECHO Pacman update failed!
@PAUSE
@EXIT /B 1



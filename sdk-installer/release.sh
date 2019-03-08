#!/bin/sh

# Recreate git-sdk-$VERSION.exe

test -z "$1" && {
	echo "Usage: $0 <version>"
	exit 1
}

die () {
	echo "$*" >&2
	exit 1
}

ARCH="$(uname -m)"
case "$ARCH" in
i686)
	BITNESS=32
	;;
x86_64)
	BITNESS=64
	;;
*)
	die "Unhandled architecture: $ARCH"
	;;
esac

GIT_SDK_URL=https://github.com/git-for-windows/git-sdk-$BITNESS 

FAKEROOTDIR="$(cd "$(dirname "$0")" && pwd)/root"
TARGET="$HOME"/git-sdk-installer-"$1"-$BITNESS.7z.exe
OPTS7="-m0=lzma -mx=9 -md=64M"
TMPPACK=/tmp.7z
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR=/mingw$BITNESS/bin

echo "Enumerating required files..." >&2
# First, enumerate the .dll files needed by the .exe files, then, enumerate all
# the .dll files in bin/, then filter out the duplicates (which are the .dll
# files in bin/ which are needed by the .exe files).
exes_and_dlls=
todo="git.exe ../libexec/git-core/git-remote-https.exe "
# Add DLLs' transitive dependencies
while test -n "$todo"
do
	file=${todo%% *}
        todo=${todo#* }
	exes_and_dlls="$exes_and_dlls$file "

        for dll in $(ldd "$BIN_DIR/$file" |
		sed -ne "s|.*> $BIN_DIR/\\([^ ]*\\).*|\\1|p" \
			-e "s|.*> ${BIN_DIR%bin}\\(libexec/git-core/[^ ]*\\).*|../\\1|p")
        do
                case " $exes_and_dlls $todo " in
                *" $dll "*) ;; # already found/queued
                *" ${dll#../libexec/git-core/} "*) ;; # already found/queued
                *" ../libexec/git-core/$dll "*) ;; # already found/queued
                *) test ! -f "$BIN_DIR/$dll" || todo="$todo$dll ";;
                esac
        done
done

echo "Copying and compressing files..." >&2
rm -rf "$FAKEROOTDIR" &&
mkdir -p "$FAKEROOTDIR/mini$BIN_DIR" ||
die "Could not create $FAKEROOTDIR$BIN_DIR directory"

sed -e "s|@@ARCH@@|$ARCH|g" \
	-e "s|@@BITNESS@@|$BITNESS|g" \
	-e "s|@@GIT_SDK_URL@@|$GIT_SDK_URL|g" \
<"$SCRIPT_PATH"/setup-git-sdk.bat >"$FAKEROOTDIR"/setup-git-sdk.bat ||
die "Could not generate setup script"

(cd $BIN_DIR && cp $exes_and_dlls "$FAKEROOTDIR/mini$BIN_DIR") ||
die "Could not copy .exe and .dll files into fake root"

type 7za ||
pacman -Sy --noconfirm p7zip ||
die "Could not install 7-Zip"

echo "Creating archive" &&
(cd "$FAKEROOTDIR" && 7za -x'!var/lib/pacman/*' a $OPTS7 "$TMPPACK" *) &&
(cat "$SCRIPT_PATH/../7-Zip/7zSD.sfx" &&
 echo ';!@Install@!UTF-8!' &&
 echo 'Title="Git for Windows '$BITNESS'-bit SDK"' &&
 echo 'BeginPrompt="This archive extracts an SDK to build, test and package Git for Windows '$BITNESS'-bit"' &&
 echo 'CancelPrompt="Do you want to cancel the Git SDK installation?"' &&
 echo 'ExtractDialogText="Please, wait..."' &&
 echo 'ExtractPathText="Where do you want to install the Git SDK?"' &&
 echo 'ExtractTitle="Extracting..."' &&
 echo 'GUIFlags="8+32+64+256+4096"' &&
 echo 'GUIMode="1"' &&
 echo 'InstallPath="C:\\git-sdk-'$BITNESS'"' &&
 echo 'OverwriteMode="2"' &&
 echo 'ExecuteFile="setup-git-sdk.bat"' &&
 echo 'Delete="setup-git-sdk.bat"' &&
 echo ';!@InstallEnd@!' &&
 cat "$TMPPACK") > "$TARGET" &&
echo "Success! You will find the new installer at \"$TARGET\"." &&
echo "It is a self-extracting .7z archive." &&
rm $TMPPACK

#!/bin/sh

# Recreate git-sdk-$VERSION.exe

test -z "$1" && {
	echo "Usage: $0 <version> [<gitbranch>]"
	exit 1
}

die () {
	echo "$*" >&1
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

GIT_BRANCH="${2:-master}"
GIT_CLONE_URL=https://github.com/git-for-windows/git

TARGET="$HOME"/git-sdk-installer-"$1".7z.exe
OPTS7="-m0=lzma -mx=9 -md=64M"
TMPPACK=/tmp.7z
SHARE="$(cd "$(dirname "$0")" && pwd)"

sed -e "s|@@ARCH@@|$ARCH|g" \
	-e "s|@@BITNESS@@|$BITNESS|g" \
	-e "s|@@GIT_BRANCH@@|$GIT_BRANCH|g" \
	-e "s|@@GIT_CLONE_URL@@|$GIT_CLONE_URL|g" \
< "$SHARE"/setup-git-sdk.bat > /setup-git-sdk.bat ||
die "Could not generate setup script"

fileList="$(cd / && echo \
	etc/pacman.* \
	usr/bin/gpg.exe \
	usr/bin/pacman.exe \
	$(ldd /usr/bin/gpg.exe |
	  sed -n 's/.* \/\(usr\/bin\/.*\.dll\) .*/\1/p') \
	usr/bin/msys-crypto-*.dll \
	usr/bin/msys-ssl-*.dll \
	usr/ssl/certs/ca-bundle.crt \
	var/lib/pacman \
	setup-git-sdk.bat)"

type 7za ||
pacman -S p7zip ||
die "Could not install 7-Zip"

echo "Creating archive" &&
(cd / && 7za -x'!var/lib/pacman/*' a $OPTS7 "$TMPPACK" $fileList) &&
(cat "$SHARE/7zSD.sfx" &&
 echo ';!@Install@!UTF-8!' &&
 echo 'Title="Git for Windows '$BITNESS'-bit SDK"' &&
 echo 'BeginPrompt="This archive bootstraps an SDK to build, test and package Git for Windows '$BITNESS'-bit"' &&
 echo 'CancelPrompt="Do you want to cancel the Git '$BITNESS'-bit SDK installation?"' &&
 echo 'ExtractDialogText="Please, wait..."' &&
 echo 'ExtractPathText="Where do you want to install the Git '$BITNESS'-bit SDK?"' &&
 echo 'ExtractTitle="Extracting..."' &&
 echo 'GUIFlags="8+32+64+256+4096"' &&
 echo 'GUIMode="1"' &&
 echo 'InstallPath="C:\\git-sdk-'$BITNESS'"' &&
 echo 'OverwriteMode="2"' &&
 echo 'RunProgram="cmd /c \"%%T\setup-git-sdk.bat\""' &&
 echo 'Delete="%%T\setup-git-sdk.bat"' &&
 echo ';!@InstallEnd@!' &&
 cat "$TMPPACK") > "$TARGET" &&
echo "Success! You will find the new installer at \"$TARGET\"." &&
echo "It is a self-extracting .7z archive (just append .exe to the filename)" &&
rm $TMPPACK

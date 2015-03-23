#!/bin/sh

# Build the portable Git for Windows.

test -z "$1" && {
	echo "Usage: $0 <version> [optional components]"
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
VERSION=$1
shift
TARGET="$HOME"/PortableGit-"$VERSION".7z.exe
OPTS7="-m0=lzma -mx=9 -md=64M"
TMPPACK=/tmp.7z
SHARE="$(cd "$(dirname "$0")" && pwd)"

case "$SHARE" in
*" "*)
	die "This script cannot handle spaces in $SHARE"
	;;
esac


# Generate a couple of files dynamically

mkdir -p "$SHARE/root/tmp" ||
die "Could not make tmp/ directory"

mkdir -p "$SHARE/root/cmd" &&
cp /mingw$BITNESS/libexec/git-core/git-log.exe "$SHARE/root/cmd/git.exe" ||
die "Could not copy Git wrapper"

sed "s/@@BITNESS@@/$BITNESS/g" \
< "$SHARE/git-cmd.bat.in" > "$SHARE/root/git-cmd.bat" ||
die "Could not generate git-cmd.bat"

sed "s/@@BITNESS@@/$BITNESS/g" \
< "$SHARE/git-bash.bat.in" > "$SHARE/root/git-bash.bat" ||
die "Could not generate git-bash.bat"


# Make a list of files to include

pacman_list () {
	pacman -Ql $(for arg
		do
			pactree -u "$arg"
		done |
		sort |
		uniq) |
	grep -v '/$' |
	sed 's/^[^ ]* //'
}

LIST="$(pacman_list mingw-w64-$ARCH-git git-extra ncurses mintty vim \
	sed awk less grep gnupg findutils coreutils \
	dos2unix which $@|
	grep -v -e '\.[acho]$' -e '/aclocal/' \
		-e '/man/' \
		-e '^/usr/include/' -e '^/mingw32/include/' \
		-e '^/usr/share/doc/' -e '^/mingw32/share/doc/' \
		-e '^/usr/share/info/' -e '^/mingw32/share/info/' |
	sed 's/^\///')"

LIST="$LIST etc/profile etc/bash.bash_logout etc/bash.bashrc etc/fstab"
LIST="$LIST mingw$BITNESS/etc/gitconfig"

# 7-Zip will strip absolute paths completely... therefore, we can add another
# root directory like this:

LIST="$LIST $SHARE/root/*"


# Make the self-extracting package

type 7za ||
pacman -S p7zip ||
die "Could not install 7-Zip"

echo "Creating archive" &&
(cd / && 7za a $OPTS7 $TMPPACK $LIST) &&
(cat "$SHARE/../net-installer/7zSD.sfx" &&
 echo ';!@Install@!UTF-8!' &&
 echo 'Progress="yes"' &&
 echo 'Title="Portable Git for Windows"' &&
 echo 'BeginPrompt="This program installs a complete Git for Windows"' &&
 echo 'CancelPrompt="Do you want to cancel Git installation?"' &&
 echo 'ExtractDialogText="Please, wait..."' &&
 echo 'ExtractPathText="Where do you want to install Git for Windows?"' &&
 echo 'ExtractTitle="Extracting..."' &&
 echo 'GUIFlags="8+32+64+256+4096"' &&
 echo 'GUIMode="1"' &&
 echo 'InstallPath="%PROGRAMFILES%\\Git"' &&
 echo 'OverwriteMode="0"' &&
 echo ';!@InstallEnd@!7z' &&
 cat "$TMPPACK") > "$TARGET" &&
echo "Success! You will find the new installer at \"$TARGET\"." &&
echo "It is a self-extracting .7z archive (just append .exe to the filename)" &&
rm $TMPPACK


#!/bin/sh

# Build the "really minimal" Git for Windows.

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
TARGET="$HOME"/MinGit-"$VERSION"-"$BITNESS"-bit.zip
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

case "$SCRIPT_PATH" in
*" "*)
	die "This script cannot handle spaces in $SCRIPT_PATH"
	;;
esac

sed 's/$/\r/' <"$SCRIPT_PATH"/../LICENSE.txt >"$SCRIPT_PATH"/LICENSE.txt ||
die "Could not copy license file"

mkdir -p "$SCRIPT_PATH"/etc ||
die "Could not make etc/"

# Make a list of files to include
LIST="$(ARCH=$ARCH BITNESS=$BITNESS MINIMAL_GIT=1 \
	PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/etc/package-versions.txt \
	sh "$SCRIPT_PATH"/../make-file-list.sh "$@")" ||
die "Could not generate file list"

# Make the archive

type zip ||
pacman -Sy --noconfirm zip ||
die "Could not install Zip"

test ! -f "$TARGET" || rm "$TARGET" || die "Could not remove $TARGET"

echo "Creating .zip archive" &&
(cd "$SCRIPT_PATH" && zip -9r "$TARGET" LICENSE.txt etc/package-versions.txt) &&
(cd / && zip -9r "$TARGET" $LIST) &&
echo "Success! You will find the new MinGit at \"$TARGET\"."

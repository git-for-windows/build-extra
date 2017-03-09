#!/bin/sh

# Build the "really minimal" Git for Windows.

test -z "$1" && {
	echo "Usage: $0 [--output=<directory>] <version> [optional components]"
	exit 1
}

die () {
	echo "$*" >&1
	exit 1
}

output_directory="$HOME"
while case "$1" in
--output=*)
	output_directory="$(cd "${1#*=}" && pwd)" ||
	die "Directory inaccessible: '${1#*=}'"
	;;
-*) die "Unknown option: %s\n" "$1";;
*) break;;
esac; do shift; done
test $# = 1 ||
die "Expect a version, got $# arguments"

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
TARGET="$output_directory"/MinGit-"$VERSION"-"$BITNESS"-bit.zip
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

echo "$LIST" | sort >"$SCRIPT_PATH"/sorted-all &&
pacman -Ql mingw-w64-$ARCH-git |
sed 's|^[^ ]* /||' |
grep "^mingw$BITNESS/libexec/git-core/.*\.exe$" |
sort >"$SCRIPT_PATH"/sorted-libexec-exes &&
MOVED_FILE=etc/libexec-moved.txt &&
comm -12 "$SCRIPT_PATH"/sorted-all "$SCRIPT_PATH"/sorted-libexec-exes \
	>"$SCRIPT_PATH"/$MOVED_FILE &&
if test ! -s "$SCRIPT_PATH"/$MOVED_FILE
then
	die "Could not find any .exe files in libexec/git-core/"
fi &&
BIN_DIR=mingw$BITNESS/bin &&
rm -rf "$SCRIPT_PATH"/$BIN_DIR &&
mkdir -p "$SCRIPT_PATH"/$BIN_DIR &&
(cd / && cp $(cat "$SCRIPT_PATH"/$MOVED_FILE) "$SCRIPT_PATH"/$BIN_DIR/) &&
LIST="$(comm -23 "$SCRIPT_PATH"/sorted-all "$SCRIPT_PATH"/$MOVED_FILE)" ||
die "Could not copy libexec/git-core/*.exe"

test ! -f "$TARGET" || rm "$TARGET" || die "Could not remove $TARGET"

echo "Creating .zip archive" &&
(cd "$SCRIPT_PATH" &&
 zip -9r "$TARGET" LICENSE.txt etc/package-versions.txt $MOVED_FILE $BIN_DIR/) &&
(cd / && zip -9r "$TARGET" $LIST) &&
echo "Success! You will find the new MinGit at \"$TARGET\"."

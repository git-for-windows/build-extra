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

rm -rf "$SCRIPT_PATH"/root &&
mkdir -p "$SCRIPT_PATH"/root ||
die "Could not create overlay directory"

sed 's/$/\r/' <"$SCRIPT_PATH"/../LICENSE.txt >"$SCRIPT_PATH"/root/LICENSE.txt ||
die "Could not copy license file"

mkdir -p "$SCRIPT_PATH"/root/etc ||
die "Could not make etc/"

# Make a list of files to include
LIST="$(ARCH=$ARCH BITNESS=$BITNESS MINIMAL_GIT=1 \
	PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/root/etc/package-versions.txt \
	sh "$SCRIPT_PATH"/../make-file-list.sh "$@")" ||
die "Could not generate file list"

# Make the archive

type 7za ||
pacman -Sy --noconfirm p7zip ||
die "Could not install 7-Zip"

echo "$LIST" | sort >"$SCRIPT_PATH"/sorted-all &&
pacman -Ql mingw-w64-$ARCH-git |
sed 's|^[^ ]* /||' |
grep "^mingw$BITNESS/libexec/git-core/.*\.exe$" |
sort >"$SCRIPT_PATH"/sorted-libexec-exes &&
MOVED_FILE=etc/libexec-moved.txt &&
comm -12 "$SCRIPT_PATH"/sorted-all "$SCRIPT_PATH"/sorted-libexec-exes \
	>"$SCRIPT_PATH"/root/$MOVED_FILE &&
if test ! -s "$SCRIPT_PATH"/root/$MOVED_FILE
then
	die "Could not find any .exe files in libexec/git-core/"
fi &&
BIN_DIR=mingw$BITNESS/bin &&
mkdir -p "$SCRIPT_PATH"/root/$BIN_DIR &&
(cd / &&
 cp $(cat "$SCRIPT_PATH"/root/$MOVED_FILE) "$SCRIPT_PATH"/root/$BIN_DIR/) &&
sed -e 's|\(.*/\)libexec/git-core\(/.*\)|\1bin\2\n&|' \
	<"$SCRIPT_PATH"/root/$MOVED_FILE |
sort >"$SCRIPT_PATH"/exclude-list &&
LIST="$(comm -23 "$SCRIPT_PATH"/sorted-all "$SCRIPT_PATH"/exclude-list)" ||
die "Could not copy libexec/git-core/*.exe"

test ! -f "$TARGET" || rm "$TARGET" || die "Could not remove $TARGET"

echo "Creating .zip archive" &&
(cd / && 7za a -mx9 "$TARGET" $LIST "$SCRIPT_PATH"/root/*) &&
echo "Success! You will find the new MinGit at \"$TARGET\"."

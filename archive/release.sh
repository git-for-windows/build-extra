#!/bin/sh

# Build a .tar.bz2 archive of Git for Windows with post-install steps already applied.

test -z "$1" && {
	echo "Usage: $0 <version> [optional components]"
	exit 1
}

die () {
	echo "$*" >&1
	exit 1
}

output_directory="$HOME"
while test $# -gt 0
do
	case "$1" in
	--output)
		shift
		output_directory="$1"
		;;
	--output=*)
		output_directory="${1#*=}"
		;;
	-*)
		die "Unknown option: $1"
		;;
	*)
		break
	esac
	shift
done
VERSION=$1
shift

case "$MSYSTEM" in
MINGW32)
	ARCH=i686
	ARTIFACT_SUFFIX="32-bit"
	;;
MINGW64)
	ARCH=x86_64
	ARTIFACT_SUFFIX="64-bit"
	;;
CLANGARM64)
	ARCH=aarch64
	ARTIFACT_SUFFIX=arm64
	;;
*)
	die "Unhandled MSYSTEM: $MSYSTEM"
	;;
esac
MSYSTEM_LOWER=${MSYSTEM,,}
TARGET="$(cygpath -au "$output_directory")"/Git-"$VERSION"-"$ARTIFACT_SUFFIX".tar.bz2
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

case "$SCRIPT_PATH" in
*" "*)
	die "This script cannot handle spaces in $SCRIPT_PATH"
	;;
esac


# Generate a couple of files dynamically

ln -sf /proc/mounts "$SCRIPT_PATH/root/etc/mtab"

rm -rf "$SCRIPT_PATH/root/tmp" 
mkdir "$SCRIPT_PATH/root/tmp" ||
die "Could not make tmp/ directory"

rm -rf "$SCRIPT_PATH/root/bin"
mkdir "$SCRIPT_PATH/root/bin" ||
die "Could not make bin/ directory"

rm -rf "$SCRIPT_PATH/root/dev"
mkdir -m 755 "$SCRIPT_PATH/root/dev" ||
die "Could not make dev/ directory"

ln -sf /proc/self/fd/0 "$SCRIPT_PATH/root/dev/stdin"
ln -sf /proc/self/fd/1 "$SCRIPT_PATH/root/dev/stdout"
ln -sf /proc/self/fd/2 "$SCRIPT_PATH/root/dev/stderr"
ln -sf /proc/self/fd   "$SCRIPT_PATH/root/dev/fd"

mkdir "$SCRIPT_PATH/root/dev/shm" ||
die "Could not make dev/shm/ directory"
chmod 1777 "$SCRIPT_PATH/root/dev/shm"

mkdir "$SCRIPT_PATH/root/dev/mqueue" ||
die "Could not make dev/mqueue/ directory"
chmod 1777 "$SCRIPT_PATH/root/dev/mqueue"

cp /cmd/git.exe "$SCRIPT_PATH/root/bin/git.exe" &&
cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/bash.exe" &&
cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/sh.exe" ||
die "Could not install bin/ redirectors"

hardlink_all_dlls () {
	exec_path=$SCRIPT_PATH/root/$MSYSTEM_LOWER/libexec/git-core
	mkdir -p $exec_path ||
	die "Could not make $exec_path directory"

	for dll in /$MSYSTEM_LOWER/bin/*.dll
	do
		test -f "$exec_path"/${dll##*/} ||
		ln "$dll" "$exec_path" ||
		die "ERROR: could not link $dll"
	done
}

hardlink_all_dlls

# Make a list of files to include
LIST="$(ARCH=$ARCH \
	PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/root/etc/package-versions.txt \
	sh "$SCRIPT_PATH"/../make-file-list.sh "$@")" ||
die "Could not generate file list"

# Create the archive

type tar ||
pacman -Sy --noconfirm tar ||
die "Could not install tar"

echo "Creating .tar.bz2 archive" &&
if ! tar -c -j -f "$TARGET" --directory=/ --exclude=etc/post-install/* $LIST --directory=$SCRIPT_PATH/root bin dev etc tmp $MSYSTEM_LOWER && test $? = 1
then
	tar -c -j -f "$TARGET" --directory=/ --exclude=etc/post-install/* $LIST --directory=$SCRIPT_PATH/root bin dev etc tmp $MSYSTEM_LOWER
fi &&
echo "Success! You will find the new archive at \"$TARGET\"."

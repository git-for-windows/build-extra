#!/bin/sh

# Build the portable Git for Windows.

die () {
	echo "$*" >&1
	exit 1
}

output_directory="$HOME"
include_pdbs=
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
	--include-pdbs)
		include_pdbs=t
		;;
	-*)
		die "Unknown option: $1"
		;;
	*)
		break
	esac
	shift
done

test $# -gt 0 ||
die "Usage: $0 [--output=<directory>] <version> [optional components]"

test -d "$output_directory" ||
die "Directory inaccessible: '$output_directory'"

case "$MSYSTEM" in
MINGW32)
	BITNESS=32
	ARCH=i686
	ARTIFACT_SUFFIX="32-bit"
	MD_ARG=128M
	MINGW_PREFIX=mingw-w64-i686-
	;;
MINGW64)
	BITNESS=64
	ARCH=x86_64
	ARTIFACT_SUFFIX="64-bit"
	MD_ARG=256M
	MINGW_PREFIX=mingw-w64-x86_64-
	;;
CLANGARM64)
	BITNESS=64
	ARCH=aarch64
	ARTIFACT_SUFFIX=arm64
	MD_ARG=256M
	MINGW_PREFIX=mingw-w64-clang-aarch64-
	;;
*)
	die "Unhandled MSYSTEM: $MSYSTEM"
	;;
esac
MSYSTEM_LOWER=${MSYSTEM,,}
VERSION=$1
shift
TARGET="$output_directory"/PortableGit-"$VERSION"-"$ARTIFACT_SUFFIX".7z.exe
OPTS7="-m0=lzma -mqs -mlc=8 -mx=9 -md=$MD_ARG -mfb=273 -ms=256M "
TMPPACK=/tmp.7z
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

case "$SCRIPT_PATH" in
*" "*)
	die "This script cannot handle spaces in $SCRIPT_PATH"
	;;
esac


# Generate a couple of files dynamically

cp "$SCRIPT_PATH/../LICENSE.txt" "$SCRIPT_PATH/root/" ||
die "Could not copy license file"

mkdir -p "$SCRIPT_PATH/root/dev/mqueue" ||
die "Could not make /dev/mqueue directory"

mkdir -p "$SCRIPT_PATH/root/dev/shm" ||
die "Could not make /dev/shm/ directory"

mkdir -p "$SCRIPT_PATH/root/etc" ||
die "Could not make etc/ directory"

mkdir -p "$SCRIPT_PATH/root/tmp" ||
die "Could not make tmp/ directory"

mkdir -p "$SCRIPT_PATH/root/bin" ||
die "Could not make bin/ directory"

cp /cmd/git.exe "$SCRIPT_PATH/root/bin/git.exe" &&
cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/bash.exe" &&
cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/sh.exe" ||
die "Could not install bin/ redirectors"

cp "$SCRIPT_PATH/../post-install.bat" "$SCRIPT_PATH/root/" ||
die "Could not copy post-install script"

etc_gitconfig="$(git -c core.editor=echo config --system -e 2>/dev/null)" &&
etc_gitconfig="$(cygpath -au "$etc_gitconfig")" &&
etc_gitconfig="${etc_gitconfig#/}" ||
die "Could not determine the path of the system config"

# Make a list of files to include
LIST="$(ARCH=$ARCH ETC_GITCONFIG="$etc_gitconfig" \
	PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/root/etc/package-versions.txt \
	sh "$SCRIPT_PATH"/../make-file-list.sh "$@" |
	grep -v "^$etc_gitconfig$")" ||
die "Could not generate file list"

mkdir -p "$SCRIPT_PATH/root/${etc_gitconfig%/*}" &&
cp /"$etc_gitconfig" "$SCRIPT_PATH/root/$etc_gitconfig" &&
git config -f "$SCRIPT_PATH/root/$etc_gitconfig" \
	credential.helper manager ||
die "Could not configure Git-Credential-Manager as default"
test 64 != $BITNESS ||
git config -f "$SCRIPT_PATH/root/$etc_gitconfig" --unset pack.packSizeLimit
git config -f "$SCRIPT_PATH/root/$etc_gitconfig" core.fscache true

case "$LIST" in
*/git-credential-helper-selector.exe*)
	git config -f "$SCRIPT_PATH/root/$etc_gitconfig" \
		credential.helper helper-selector
	;;
esac

git_core="$SCRIPT_PATH/root/$MSYSTEM_LOWER/libexec/git-core" &&
rm -rf "$git_core" &&
mkdir -p "$git_core" &&
if test "$(stat -c %D /$MSYSTEM_LOWER/bin)" = "$(stat -c %D "$git_core")"
then
	ln_or_cp=ln
else
	ln_or_cp=cp
fi &&
$ln_or_cp $(echo "$LIST" | sed -n "s|^$MSYSTEM_LOWER/bin/[^/]*\.dll$|/&|p") "$git_core" ||
die "Could not copy .dll files into libexec/git-core/"

test -z "$include_pdbs" || {
	find "$SCRIPT_PATH/root" -name \*.pdb -exec rm {} \; &&
	"$SCRIPT_PATH"/../please.sh bundle-pdbs \
		--arch=$ARCH --unpack="$SCRIPT_PATH"/root
} ||
die "Could not unpack .pdb files"

TITLE="$BITNESS-bit"
test $ARCH == "aarch64" && TITLE="ARM64"


# Make the self-extracting package

type 7z ||
pacman -Sy --noconfirm $MINGW_PREFIX-7zip ||
die "Could not install 7-Zip"

echo "Creating archive" &&
echo $LIST | tr ' ' '\n' >$TMPPACK.list &&
# 7-Zip will strip absolute paths completely... therefore, we can add another
# root directory like this:
echo "$(cygpath -aw "$SCRIPT_PATH/root")\\*" >>$TMPPACK.list &&
(cd / && 7z a $OPTS7 $TMPPACK @${TMPPACK#/}.list) &&
if test -z "$(7z l $TMPPACK etc/package-versions.txt)"
then
	die "/etc/package-versions.txt is missing?!?"
fi &&
(cat "$SCRIPT_PATH/../7-Zip/7zS.sfx" &&
 echo ';!@Install@!UTF-8!' &&
 echo 'Title="Portable Git for Windows '$TITLE'"' &&
 echo 'BeginPrompt="This archive extracts a complete Git for Windows '$TITLE'"' &&
 echo 'CancelPrompt="Do you want to cancel the portable Git installation?"' &&
 echo 'ExtractDialogText="Please, wait..."' &&
 echo 'ExtractPathText="Where do you want to install portable Git?"' &&
 echo 'ExtractTitle="Extracting..."' &&
 echo 'GUIFlags="8+32+64+256+4096"' &&
 echo 'GUIMode="1"' &&
 echo 'InstallPath="%%S\\PortableGit"' &&
 echo 'OverwriteMode="0"' &&
 echo "RunProgram=\"git-bash.exe --needs-console --hide --no-cd --command=post-install.bat\"" &&
 echo ';!@InstallEnd@!' &&
 cat "$TMPPACK") > "$TARGET" &&
echo "Success! You will find the new installer at \"$TARGET\"." &&
echo "It is a self-extracting .7z archive." &&
rm $TMPPACK $TMPPACK.list

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
TARGET="$output_directory"/PortableGit-"$VERSION"-"$ARTIFACT_SUFFIX".msix
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

case "$SCRIPT_PATH" in
*" "*)
	die "This script cannot handle spaces in $SCRIPT_PATH"
	;;
esac


# Generate a couple of files dynamically

mkdir -p "$SCRIPT_PATH/root/" ||
die "Could not make root"

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

# Create MSIX

MAPFILE=$SCRIPT_PATH/root/files.map
MANIFESTIN=$SCRIPT_PATH/appxmanifest.xml.in
MANIFESTOUT=$SCRIPT_PATH/root/appxmanifest.xml

echo "Create MSIX"

sed -e "s/@@VERSION@@/$VERSION/g" <"$MANIFESTIN" >"$MANIFESTOUT"

echo "[Files]" >"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/root/appxmanifest.xml\" \"AppxManifest.xml\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/root/bin/git.exe\" \"bin/git.exe\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/root/bin/sh.exe\" \"bin/sh.exe\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/root/bin/bash.exe\" \"bin/bash.exe\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/LockScreenLogo.png\" \"Assets/LockScreenLogo.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/LockScreenLogo.scale-200.png\" \"Assets/LockScreenLogo.scale-200.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/Square150x150Logo.png\" \"Assets/Square150x150Logo.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/Square150x150Logo.scale-200.png\" \"Assets/Square150x150Logo.scale-200.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/Square44x44Logo.png\" \"Assets/Square44x44Logo.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/Square44x44Logo.scale-200.png\" \"Assets/Square44x44Logo.scale-200.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/Square44x44Logo.targetsize-24_altform-unplated.png\" \"Assets/Square44x44Logo.targetsize-24_altform-unplated.png\"" >>"$MAPFILE" &&
echo "\"$(cygpath -aw "$SCRIPT_PATH")/Assets/StoreLogo.png\" \"Assets/StoreLogo.png\"" >>"$MAPFILE" &&
echo "$LIST" |
sed -e 'y/\//\\/' -e 's/.*/"&" "&"/' >>"$MAPFILE"

PWSH_COMMAND=". \"C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\makeappx.exe\" pack /v /o /f $(cygpath -aw "$MAPFILE") /p $(cygpath -aw "$TARGET")"
set -x
/c/Program\ Files/WindowsApps/Microsoft.PowerShell_7.5.4.0_x64__8wekyb3d8bbwe/pwsh.exe -wd "$(cygpath -aw "/")" -nop -noni -nol -c "iex '$PWSH_COMMAND'"
set +x
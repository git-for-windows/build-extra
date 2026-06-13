#!/bin/sh

# Build the MSIX package for Git for Windows.

. "$(dirname "$0")/../release-common.sh"

case "$MSYSTEM" in
MINGW32)  ARTIFACT_SUFFIX="x86";;
MINGW64)  ARTIFACT_SUFFIX="x64";;
CLANGARM64) ARTIFACT_SUFFIX=arm64;;
esac

# MSIX requires version in X.X.X.X format (numeric only)
# Convert Git for Windows versions like "2.47.1.windows.1" to "2.47.1.1"
# and test versions like "0-test" to "0.0.0.0"
MSIX_VERSION="$(echo "$VERSION" | sed -e 's/\.windows\./\./' -e 's/[^0-9.]//g')"
# Ensure we have exactly 4 numeric segments
while test "$(echo "$MSIX_VERSION" | tr -cd '.' | wc -c)" -lt 3
do
	MSIX_VERSION="$MSIX_VERSION.0"
done

TARGET="$output_directory"/Git.GitforWindows_"$VERSION"_"$ARTIFACT_SUFFIX".msix

# Generate MSIX asset images from SVG
ASSETS_DIR="$SCRIPT_PATH/Assets"
mkdir -p "$ASSETS_DIR" ||
die "Could not create Assets directory"

type rsvg-convert ||
case "$ARCH" in
i686) pacman -Sy --noconfirm mingw-w64-i686-librsvg;;
x86_64) pacman -Sy --noconfirm mingw-w64-x86_64-librsvg;;
aarch64) pacman -Sy --noconfirm mingw-w64-clang-aarch64-librsvg;;
esac ||
die "Could not install librsvg"

SVG_SOURCE="$SCRIPT_PATH/../git-for-windows.svg"
for spec in \
	LockScreenLogo.png:24 \
	LockScreenLogo.scale-200.png:48 \
	Square150x150Logo.png:150 \
	Square150x150Logo.scale-200.png:300 \
	Square44x44Logo.png:44 \
	Square44x44Logo.scale-200.png:88 \
	Square44x44Logo.targetsize-24_altform-unplated.png:24 \
	StoreLogo.png:50
do
	name="${spec%%:*}"
	size="${spec##*:}"
	rsvg-convert -w "$size" -h "$size" "$SVG_SOURCE" \
		-o "$ASSETS_DIR/$name" ||
	die "Could not generate $name"
done

prepare_root

init_etc_gitconfig
generate_file_list "$@"
copy_dlls_to_libexec
unpack_pdbs

# Find makeappx.exe from the Windows SDK
MAKEAPPX=
for sdk_dir in "/c/Program Files (x86)/Windows Kits/10/bin"/*/
do
	case "$ARCH" in
	x86_64) sdk_arch=x64;;
	i686) sdk_arch=x86;;
	aarch64) sdk_arch=arm64;;
	esac
	if test -f "$sdk_dir$sdk_arch/makeappx.exe"
	then
		MAKEAPPX="$sdk_dir$sdk_arch/makeappx.exe"
	fi
done
test -n "$MAKEAPPX" ||
die "Could not find makeappx.exe in the Windows SDK"

# Create MSIX

MAPFILE=$SCRIPT_PATH/root/files.map
MANIFESTIN=$SCRIPT_PATH/appxmanifest.xml.in
MANIFESTOUT=$SCRIPT_PATH/root/appxmanifest.xml

echo "Create MSIX"

sed -e "s/@@VERSION@@/$MSIX_VERSION/g" <"$MANIFESTIN" >"$MANIFESTOUT"

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
MSYS_ROOT="$(cygpath -aw /)" &&
echo "$LIST" | while IFS= read -r entry; do
	winpath="${entry//\//\\}"
	echo "\"$MSYS_ROOT\\$winpath\" \"$winpath\""
done >>"$MAPFILE"

MSYS_NO_PATHCONV=1 "$MAKEAPPX" pack /v /o /f "$(cygpath -aw "$MAPFILE")" /p "$(cygpath -aw "$TARGET")" &&
echo "Package created at $TARGET"
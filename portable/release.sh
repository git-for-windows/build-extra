#!/bin/sh

# Build the portable Git for Windows.

. "$(dirname "$0")/../release-common.sh"

case "$MSYSTEM" in
MINGW32)  ARTIFACT_SUFFIX="32-bit";;
MINGW64)  ARTIFACT_SUFFIX="64-bit";;
CLANGARM64) ARTIFACT_SUFFIX=arm64;;
esac

TARGET="$output_directory"/PortableGit-"$VERSION"-"$ARTIFACT_SUFFIX".7z.exe
OPTS7="-m0=lzma -mqs -mlc=8 -mx=9 -md=$MD_ARG -mfb=273 -ms=256M "
TMPPACK=/tmp.7z

prepare_root

cp "$SCRIPT_PATH/../post-install.bat" "$SCRIPT_PATH/root/" ||
die "Could not copy post-install script"

init_etc_gitconfig
generate_file_list "$@"
copy_dlls_to_libexec
unpack_pdbs

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

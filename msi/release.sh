#!/bin/sh

# Build Git for Windows' .msi files

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
TARGET="$HOME"/Git-"$VERSION"-"$BITNESS"-bit.msi
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_PATH" ||
die "Could not switch directory to $SCRIPT_PATH"

# Make a list of files to include
LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
	PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/package-versions.txt \
	sh ../make-file-list.sh "$@")" ||
die "Could not generate file list"

# Write the GitComponents.wxs file containing the file list
SCRIPT_WINPATH="$(cd "$SCRIPT_PATH" && pwd -W | tr / \\\\)"
BUILD_EXTRA_WINPATH="$(cd "$SCRIPT_PATH"/.. && pwd -W | tr / \\\\)"
(cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
    <Fragment>
        <ComponentGroup Id="GitComponents">
            <Component Directory="BinFolder">
                <File Id="GitExe" Source="cmd\\git.exe"
		    Name="git.exe" />
            </Component>
            <Component Directory="BinFolder">
                <File Source="mingw64\\share\\git\\compat-bash.exe"
		    Name="sh.exe" />
            </Component>
            <Component Directory="INSTALLFOLDER:\\etc\\">
                <File Source="$SCRIPT_WINPATH\\package-versions.txt"
		    Name="package-versions.txt" />
            </Component>
            <Component Directory="INSTALLFOLDER">
                <File Source="$BUILD_EXTRA_WINPATH\\post-install.bat"
		    Name="post-install.bat" />
            </Component>
EOF
echo "$LIST" |
tr / \\\\ |
sed 's/\(.*\)\\\(.*\)/            <Component Directory="INSTALLFOLDER:\\\1\\">\
                <File Source="&" \/>\
            <\/Component>/'
cat <<EOF
        </ComponentGroup>
    </Fragment>
</Wix>
EOF
)>GitComponents.wxs

# Make the .msi file
mkdir -p obj &&
wix/candle.exe GitProduct.wxs GitComponents.wxs -o obj\\ \
	-ext WixUtilExtension &&
wix/light.exe \
	obj/GitProduct.wixobj \
	obj/GitComponents.wixobj \
	-o $TARGET -ext WixUtilExtension \
	-b / -b ../installer -sval &&
echo "Success! You will find the new .msi at \"$TARGET\"." ||
die "Could not generate $TARGET"

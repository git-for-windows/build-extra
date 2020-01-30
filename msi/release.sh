#!/bin/sh

usage () {
	cat <<EOF

Usage: $0 [-o <dir>] <version> [<optional-package>...]

    <version>
        The version of Git for Windows for which to create an installer.
        The version must be specified in the format shown below. The
        <Build/Patch> component is optional and may be omitted. Each version
        component must be numeric:

                <Major>.<Minor>.<Revision>.<Build/Patch>

    -o <dir>, -o=<dir>, -outputDir=<dir>
        The location the completed installer should be written to. If a
        relative path is used, the location is relative to the location of
        this script. If this option is not specified, the installer will be
        created in your home directory.

    [<optional-package>...]
        A list of additional packages you want bundled with your Git for Windows
        distribution installer.

        For example, if you want to install emacs with your Git for Windows
        installation, you would run the command:

                $0 <version> mingw-w64-emacs-git

        where <version> is the version of the Git for Windows installer to
        create.

EOF
	exit 1
}

die () {
	echo "$*" >&2
	exit 1
}

parse_version () {
	echo "$1" | grep -Px '\d+(\.(0|[1-9]+)){2,3}' ||
	die "
Either the version format was incorrect or no version was specified.
Try '$0 --help' for more information.
"
}

# Build Git for Windows' .msi file
test -z "$1" && usage

ARCH="$(uname -m)"
case "$ARCH" in
i686)
	BITNESS=32
	WIX_ARCH=x86
	;;
x86_64)
	BITNESS=64
	WIX_ARCH=x64
	;;
*)
	die "Unhandled architecture: $ARCH"
	;;
esac

for arg
do
	case "$1" in
	-h|--help)
		usage
		;;
	-o=*|--outputDir=*)
		TARGET="${1#*=}"
		shift
		;;
	-o)
		shift
		TARGET="$1"
		shift
		;;
	-*)
		die "
Unrecognized option: $1
Try '$0 --help' for more information.
"
		;;
	*)
		test -n "$VERSION" && break || VERSION="$(parse_version $1)" && shift || exit
		;;
	esac
done

# We have to know if this is a "custom MSI build"
# That's because we'll need to update the MSI Product ID Guid in some way
# so that 1) we don't wipe out a user's custom git installation; and
# more importantly 2) a user doesn't "hijack" a standard git installation,
# either maliciously or unintentionally.
#
# This needs to be discussed further.
test $# = 0 || CUSTOM=1

TARGET="${TARGET-$HOME}"/Git-"$VERSION"-"$BITNESS"-bit.msi

echo
echo "Creating Git for Windows MSI Installer:"
echo "---------------------------------------------------------------------"
echo "    Output to: $TARGET"
echo "    Version: $VERSION"
echo "    Build Type: $( (test -n "$CUSTOM" && test "$CUSTOM" -eq 1 && echo "Custom") || (test -n "$TEST" && test "$TEST" -eq "1" && echo "Test") || echo "Release")"
echo

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_PATH" ||
die "Could not switch directory to $SCRIPT_PATH"

# Generate the ReleaseNotes.html file
../render-release-notes.sh --css usr/share/git/ ||
die "Could not generate ReleaseNotes.html."

# Compile edit-git-bash.exe
make -C ../ edit-git-bash.exe ||
die "Could not build edit-git-bash.exe."

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
                <File Id="GitExe" Source="cmd\\git.exe" />
            </Component>
            <Component Directory="BinFolder">
                <File Source="mingw$BITNESS\\share\\git\\compat-bash.exe" Name="sh.exe" />
            </Component>
            <Component Directory="BinFolder">
                <File Id="BashExe" Source="mingw$BITNESS\\share\\git\\compat-bash.exe" Name="bash.exe" />
            </Component>
            <Component Directory="INSTALLFOLDER:\\etc\\">
                <File Source="$SCRIPT_WINPATH\\package-versions.txt" />
            </Component>
            <Component Directory="INSTALLFOLDER" Guid="">
                <File Id="PostInstallBat" Source="$BUILD_EXTRA_WINPATH\\post-install.bat" KeyPath="yes" />
            </Component>
            <Component Directory="INSTALLFOLDER">
                <File Id="ReleaseNotes" Source="$SCRIPT_WINPATH\\ReleaseNotes.html" />
                <Shortcut Id="ReleaseNotes" Name="Release Notes" Directory="GitProgramMenuFolder" Advertise="yes" />
            </Component>
            <Component Directory="INSTALLFOLDER:\\usr\\share\\git\\">
                <File Id="ReleaseNotes_Css" Source="$BUILD_EXTRA_WINPATH\\ReleaseNotes.css" />
            </Component>
            <Component Directory="INSTALLFOLDER" Guid="">
                <Condition>TERMINAL = "CmdPrompt"</Condition>
                <File DoNotBind Id="EditGitBash" Source="$BUILD_EXTRA_WINPATH\\edit-git-bash.exe" KeyPath="yes" />
            </Component>
EOF
echo "$LIST" |
sort |
uniq |
tr / \\\\ |
sed -e 's/\(.*\)\\\(.*\)/            <Component Directory="INSTALLFOLDER:\\\1\\">\
                <File Source="&" \/>\
            <\/Component>/' \
	-e 's/^\([^\\]*\)$/            <Component Directory="INSTALLFOLDER">\
                <File Source="&" \/>\
            <\/Component>/' \
	-e "s/<File Source=\"\(mingw$BITNESS.*\(ca\)-\(bundle\.crt\)\)\" \/>/<File Id=\"\2_\3\" Source=\"\1\" \/>/"\
	-e 's/\(<File Source="git-bash.exe"[^>]*\) \/>/\1 \/><Shortcut Name="Git Bash" Icon="git.ico" Directory="GitProgramMenuFolder" WorkingDirectory="INSTALLFOLDER" Arguments="--cd-to-home" Advertise="yes" \/>/' \
	-e 's/\(<File Source="git-cmd.exe"[^>]*\) \/>/\1 \/><Shortcut Name="Git CMD" Icon="git.ico" Directory="GitProgramMenuFolder" WorkingDirectory="INSTALLFOLDER" Arguments="--cd-to-home" Advertise="yes" \/>/' \
	-e 's/\(<File Source="cmd\\git-gui.exe"[^>]*\) \/>/\1 \/><Shortcut Name="Git GUI" Icon="git.ico" Directory="GitProgramMenuFolder" WorkingDirectory="INSTALLFOLDER" Arguments="--cd-to-home" Advertise="yes" \/>/' \
	-e 's/\(Source="git-bash.exe" \)\([^>]\)*/Id="GitBash" \1\2/' \
	-e 's/\(<Component Directory="INSTALLFOLDER:\\etc\\post-install\\"\)>/\1 Guid="" >/' \
	-e 's/\(<File Source="etc\\post-install\\.*\.post"\) \/>/\1 KeyPath="yes" \/>/'
cat <<EOF
        </ComponentGroup>
    </Fragment>
</Wix>
EOF
) | sed -e 's/\(<File \(Id=".*" \)\?Source="\)\(.*\(compat-\)\?\(ba\)\?sh\.exe\|.*git.*\.exe\)\([^>]\)* \/>/\1\3" BindPath="[BindImagePaths]\6 \/>/' \
	-e 's/\(<File \)\(DoNotBind\) \([^>]*\)>/\1\3>/' >GitComponents.wxs

# Make the .msi file
mkdir -p obj &&
wix/candle.exe -dVersion="${VERSION%%-*}" \
	-arch $WIX_ARCH \
	GitProduct.wxs GitComponents.wxs \
	GitChooseEnvironmentDlg.wxs GitChooseTerminalDlg.wxs \
	GitCustomizeLineEndingsDlg.wxs GitLineEndingsDlg.wxs \
	GitMaintenanceTypeDlg.wxs GitAdditionalOptionsDlg.wxs \
	GitShellOptionsDlg.wxs \
	-o obj\\ \
	-ext WixUtilExtension -ext WixTagExtension \
	-ext WixUIExtension -ext WixNetFxExtension &&
wix/light.exe \
	obj/GitProduct.wixobj \
	obj/GitComponents.wixobj \
	obj/GitChooseEnvironmentDlg.wixobj \
	obj/GitChooseTerminalDlg.wixobj \
	obj/GitCustomizeLineEndingsDlg.wixobj \
	obj/GitLineEndingsDlg.wixobj \
	obj/GitMaintenanceTypeDlg.wixobj \
	obj/GitAdditionalOptionsDlg.wixobj \
	obj/GitShellOptionsDlg.wixobj \
	-o "$TARGET" -ext WixUtilExtension -ext WixTagExtension \
	-ext WixUIExtension -ext WixNetFxExtension \
	-loc GitUI_en-us.wxl \
	-cultures:en-us \
	-spdb \
	-b / -b ../ &&
echo "Success! You will find the new .msi at \"$TARGET\"." ||
die "Could not generate $TARGET"

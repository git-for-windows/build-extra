#!/bin/bash

die () {
	echo "$*" >&2
	exit 1
}

# change directory to the script's directory
cd "$(dirname "$0")" ||
die "Could not switch directory"

force=
inno_defines=
skip_files=
test_installer=
while test $# -gt 0
do
	case "$1" in
	-f|--force)
		force=t
		;;
	--skip-files)
		skip_files=t
		;;
	--window-title-version=*)
		inno_defines="$(printf "%s\n%s" "$inno_defines" \
			"#define WINDOW_TITLE_VERSION '${1#*=}'")"
		;;
	-d=*|--debug-wizard-page=*)
		page="${1#*=}"
		case "$page" in *Page);; *)page=${page}Page;; esac
		test_installer=t
		if ! grep "^ *$page:TWizardPage;$" install.iss >/dev/null
		then
			echo "Unknown page '$page'. Known pages:" >&2
			sed -n 's/:TWizardPage;$//p' <install.iss >&2
			exit 1
		fi
		inno_defines="$(printf "%s\n%s\n%s" "$inno_defines" \
			"#define DEBUG_WIZARD_PAGE '$page'" \
			"#define OUTPUT_TO_TEMP ''")"
		skip_files=t
		;;
	--output=*)
		output_directory="$(cygpath -m "${1#*=}")" ||
		die "Directory inaccessible: '${1#*=}'"

		inno_defines="$(printf "%s\n%s" "$inno_defines" \
			"#define OUTPUT_DIRECTORY '$output_directory'")"
		;;
	*)
		break
	esac
	shift
done

if test -n "$test_installer"
then
	version=0-test
else
	version=$1
	shift
fi

test $# = 0 ||
die "Usage: $0 [-f | --force] [--output=<directory>] ( --debug-wizard-page=<page> | <version> )"

displayver="$(echo "${version#prerelease-}" |
	sed -e 's/\.[^0-9]*\.[^0-9]*\./\./g' \
		-e 's/\.[^.0-9]*\./\./g' -e 's/\.rc/\./g')"
case "$displayver" in
[0-9]*) ;; # okay
*) die "InnoSetup requires a version that begins with a digit ($displayver)";;
esac

# Evaluate architecture
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

echo "Generating release notes to be included in the installer ..."
../render-release-notes.sh --css usr/share/git/ ||
die "Could not generate release notes"

echo "Compiling edit-git-bash.exe ..."
make -C ../ edit-git-bash.exe ||
die "Could not build edit-git-bash.exe"

if test t = "$skip_files"
then
	LIST=
else
	echo "Generating file list to be included in the installer ..."
	LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
		PACKAGE_VERSIONS_FILE=package-versions.txt \
		sh ../make-file-list.sh)" ||
	die "Could not generate file list"
fi

printf "; List of files\n%s\n%s\n%s\n%s\n%s\n" \
	"Source: \"{#SourcePath}\\package-versions.txt\"; DestDir: {app}\\etc; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"{#SourcePath}\\..\\ReleaseNotes.css\"; DestDir: {app}\\usr\\share\\git; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"cmd\\git.exe\"; DestDir: {app}\\bin; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"mingw$BITNESS\\share\\git\\compat-bash.exe\"; DestName: bash.exe; DestDir: {app}\\bin; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"mingw$BITNESS\\share\\git\\compat-bash.exe\"; DestName: sh.exe; DestDir: {app}\\bin; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"{#SourcePath}\\..\\post-install.bat\"; DestName: post-install.bat; DestDir: {app}; Flags: replacesameversion" \
>file-list.iss ||
die "Could not write to file-list.iss"

case "$LIST" in
*/libexec/git-core/git-legacy-difftool*)
	inno_defines="$(printf "%s\n%s" "$inno_defines" \
		"#define WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL 1")"
	;;
esac

test -z "$LIST" ||
echo "$LIST" |
sed -e 's|/|\\|g' \
	-e 's|^\([^\\]*\)$|Source: \1; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore|' \
	-e 's|^\(.*\)\\\([^\\]*\)$|Source: \1\\\2; DestDir: {app}\\\1; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore|' \
	>> file-list.iss

echo "Generating bindimage.txt"
pacman -Ql mingw-w64-$ARCH-git |
sed -n -e 's|^[^ ]* /\(.*\.exe\)$|\1|p' \
	-e 's|^[^ ]* /\(.*\.dll\)$|\1|p' > bindimage.txt
echo "Source: \"{#SourcePath}\\bindimage.txt\"; DestDir: {app}\\mingw$BITNESS\\share\git\bindimage.txt; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" >> file-list.iss

printf "%s\n%s\n%s%s" \
	"#define APP_VERSION '$displayver'" \
	"#define FILENAME_VERSION '$version'" \
	"#define BITNESS '$BITNESS'" \
	"$inno_defines" \
	>config.iss

signtool=
test -z "$(git config alias.signtool)" ||
signtool="//Ssigntool=\"git signtool \\\$f\" //DSIGNTOOL"

echo "Launching Inno Setup compiler ..." &&
eval ./InnoSetup/ISCC.exe "$signtool" install.iss >install.log ||
die "Could not make installer"

if test -n "$test_installer"
then
	echo "Launching $TEMP/$version.exe"
	exec "$TEMP/$version.exe"
	exit
fi

echo "Tagging Git for Windows installer release ..."
if git rev-parse Git-$version >/dev/null 2>&1; then
	echo "-> installer release 'Git-$version' was already tagged."
else
	git tag -a -m "Git for Windows $version" Git-$version
fi

echo "Installer is available as $(tail -n 1 install.log)"

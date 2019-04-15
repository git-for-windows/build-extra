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
include_pdbs=
LF='
'
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
		inno_defines="$inno_defines$LF#define WINDOW_TITLE_VERSION '${1#*=}'"
		;;
	-d=*|--debug-wizard-page=*|-d)
		case "$1" in *=*) page="${1#*=}";; *) shift; page="$1";; esac
		case "$page" in *Page);; *)page=${page}Page;; esac
		test_installer=t
		if ! grep "^ *$page:TWizardPage;$" install.iss >/dev/null && ! grep "^ *$page:TInputFileWizardPage;$" install.iss >/dev/null
		then
			echo "Unknown page '$page'. Known pages:" >&2
			sed -n -e 's/:TWizardPage;$//p' -e 's/:TInputFileWizardPage;$//p' <install.iss >&2
			exit 1
		fi
		inno_defines="$inno_defines$LF#define DEBUG_WIZARD_PAGE '$page'$LF#define OUTPUT_TO_TEMP ''"
		skip_files=t
		;;
	--output=*)
		output_directory="$(cygpath -m "${1#*=}")" ||
		die "Directory inaccessible: '${1#*=}'"

		inno_defines="$inno_defines$LF#define OUTPUT_DIRECTORY '$output_directory'"
		;;
	--include-pdbs)
		include_pdbs=t
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
	# make sure the file exists, as the installer wants it
	touch package-versions.txt
	LIST=
else
	echo "Generating file list to be included in the installer ..."
	LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
		PACKAGE_VERSIONS_FILE=package-versions.txt \
		INCLUDE_GIT_UPDATE=1 \
		sh ../make-file-list.sh)" ||
	die "Could not generate file list"
fi

printf '; List of files\n%s\n%s\n%s\n%s\n%s\n%s\n' \
	"Source: \"mingw$BITNESS\\bin\\blocked-file-util.exe\"; Flags: dontcopy" \
	"Source: \"{#SourcePath}\\package-versions.txt\"; DestDir: {app}\\etc; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"{#SourcePath}\\..\\ReleaseNotes.css\"; DestDir: {app}\\usr\\share\\git; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"cmd\\git.exe\"; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"mingw$BITNESS\\share\\git\\compat-bash.exe\"; DestName: bash.exe; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"mingw$BITNESS\\share\\git\\compat-bash.exe\"; DestName: sh.exe; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"{#SourcePath}\\..\\post-install.bat\"; DestName: post-install.bat; DestDir: {app}; Flags: replacesameversion restartreplace" \
>file-list.iss ||
die "Could not write to file-list.iss"

case "$LIST" in
*/libexec/git-core/git-legacy-difftool*)
	inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_BUILTIN_DIFFTOOL 1"
	;;
esac

case "$LIST" in
*/libexec/git-core/git-legacy-rebase*)
	case "$(git -c rebase.usebuiltin rebase -h 2>&1)" in
	*Actions:*)
		inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_BUILTIN_REBASE 1"
		;;
	esac
	;;
esac

case "$LIST" in
*/libexec/git-core/git-legacy-stash*)
	case "$(git -c stash.usebuiltin stash -h 2>&1)" in
	*legacy-stash:*)
		inno_defines="$inno_defines#LF#define WITH_EXPERIMENTAL_BUILTIN_STASH 1"
		;;
	esac
	;;
esac

GITCONFIG_PATH="$(echo "$LIST" | grep "^mingw$BITNESS/etc/gitconfig\$")"
printf '' >programdata-config.template
test -z "$GITCONFIG_PATH" || {
	cp "/$GITCONFIG_PATH" programdata-config.template &&
	keys="$(git config -f programdata-config.template -l --name-only)" &&
	gitconfig="$LF[Code]${LF}function GitSystemConfigSet(Key,Value:String):Boolean; forward;$LF" &&
	gitconfig="$gitconfig${LF}function SetSystemConfigDefaults():Boolean;${LF}begin${LF}    Result:=True;${LF}" &&
	for key in $keys
	do
		case "$key" in
		pack.packsizelimit|diff.astextplain.*|filter.lfs.*|http.sslcainfo)
			# set in the system-wide config
			value="$(git config -f programdata-config.template "$key")" &&
			case "$key$value" in *"'"*) die "Cannot handle $key=$value because of the single quote";; esac &&
			git config -f programdata-config.template --unset "$key" &&
			case "$key" in
			filter.lfs.*) extra=" IsComponentSelected('gitlfs') And";;
			pack.packsizelimit) test $BITNESS = 32 || continue; value=2g;;
			*) extra=;;
			esac &&
			gitconfig="$gitconfig$LF    if$extra not GitSystemConfigSet('$key','$value') then$LF        Result:=False;" ||
			break
			;;
		esac || break
	done &&
	sed -i '/^\[/{:1;$d;N;/^.[^[]*$/b;s/^.*\[/[/;b1}' \
		programdata-config.template ||
	die "Could not split gitconfig"

	gitconfig="$gitconfig${LF}end;$LF"
	inno_defines="$inno_defines$LF$gitconfig"

	LIST="$(echo "$LIST" | grep -v "^$GITCONFIG_PATH\$")"
}

printf '%s\n' \
	'Source: {#SourcePath}\programdata-config.template; Flags: dontcopy' \
	>>file-list.iss ||
die "Could not append gitconfig to file list"

test -z "$LIST" ||
echo "$LIST" |
sed -e 's|/|\\|g' \
	-e 's|^\([^\\]*\)$|Source: \1; DestDir: {app}; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore|' \
	-e 's|^\(.*\)\\\([^\\]*\)$|Source: \1\\\2; DestDir: {app}\\\1; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore|' \
	>> file-list.iss

test -z "$include_pdbs" || {
	rm -rf root &&
	mkdir root &&
	../please.sh bundle-pdbs --arch=$ARCH --unpack=root/ &&
	find root -name \*.pdb |
	sed -e 's|/|\\|g' \
		-e 's|^root\\\([^\\]*\)$|Source: "{#SourcePath}\\root\\\1"; DestDir: {app}; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore|' \
		-e 's|^root\\\(.*\)\\\([^\\]*\)$|Source: "{#SourcePath}\\root\\\1\\\2"; DestDir: {app}\\\1; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore|' \
		>> file-list.iss
} ||
die "Could not include .pdb files"

printf "%s\n%s\n%s\n%s%s" \
	"#define APP_VERSION '$displayver'" \
	"#define FILENAME_VERSION '$version'" \
	"#define BITNESS '$BITNESS'" \
	"#define SOURCE_DIR '$(cygpath -aw /)'" \
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

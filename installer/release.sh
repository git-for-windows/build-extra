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
test_installer_options=
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
		case "$page" in
		components|wpSelectComponents)
			page=wpSelectComponents
			page_id=$page
			;;
		*Page)
			page_id="$page.ID"
			;;
		*)
			page=${page}Page
			page_id="$page.ID"
			;;
		 esac
		test_installer=t
		if test x"${page#wp}" = x"$page" &&
		   ! grep "^ *$page:TWizardPage;$" install.iss >/dev/null &&
		   ! grep "^ *$page:TInputFileWizardPage;$" install.iss >/dev/null
		then
			echo "Unknown page '$page'. Known pages:" >&2
			sed -n -e 's/:TWizardPage;$//p' -e 's/:TInputFileWizardPage;$//p' <install.iss >&2
			exit 1
		fi
		inno_defines="$inno_defines$LF#define DEBUG_WIZARD_PAGE '$page_id'$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		inno_defines="$inno_defines$LF[Code]${LF}function SetSystemConfigDefaults():Boolean;${LF}begin${LF}    Result:=True;${LF}end;${LF}${LF}"
		skip_files=t
		;;
	--test)
		test_installer=t
		inno_defines="$inno_defines$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		inno_defines="$inno_defines$LF[Code]${LF}function SetSystemConfigDefaults():Boolean;${LF}begin${LF}    Result:=True;${LF}end;$LF"
		;;
	--silent-test)
		test_installer=t
		test_installer_options="//SILENT //NORESTART"
		skip_files=t
		inno_defines="$inno_defines$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		inno_defines="$inno_defines$LF[Code]${LF}function SetSystemConfigDefaults():Boolean;${LF}begin${LF}    Result:=True;${LF}end;$LF"
		;;
	--output=*)
		output_directory="$(cygpath -m "${1#*=}")" ||
		die "Directory inaccessible: '${1#*=}'"

		inno_defines="$inno_defines$LF#define OUTPUT_DIRECTORY '$output_directory'"
		;;
	--include-pdbs)
		include_pdbs=t
		;;
	--include-arm64-artifacts=*)
		case "${1#*=}" in
		/*) ;; # absolute path, okay
		*) die "Need an absolute path: $1";;
		esac
		arm64_artifacts_directory="${1#*=}"
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

if grep -q edit-git-bash /var/lib/pacman/local/mingw-w64-$ARCH-git-[1-9]*/files
then
	INCLUDE_EDIT_GIT_BASH=
else
	INCLUDE_EDIT_GIT_BASH=1
	inno_defines="$inno_defines$LF#define INCLUDE_EDIT_GIT_BASH$LF"
	echo "Compiling edit-git-bash.exe ..."
	make -C ../ edit-git-bash.exe ||
	die "Could not build edit-git-bash.exe"
fi

etc_gitconfig="$(git -c core.editor=echo config --system -e 2>/dev/null)" &&
etc_gitconfig="$(cygpath -au "$etc_gitconfig")" &&
etc_gitconfig="${etc_gitconfig#/}" ||
die "Could not determine the path of the system config"

if test t = "$skip_files"
then
	# make sure the file exists, as the installer wants it
	touch package-versions.txt
	LIST=
else
	echo "Generating file list to be included in the installer ..."
	LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
		ETC_GITCONFIG="$etc_gitconfig" \
		PACKAGE_VERSIONS_FILE=package-versions.txt \
		INCLUDE_GIT_UPDATE=1 \
		sh ../make-file-list.sh)" ||
	die "Could not generate file list"
fi

cmd_git="$(echo "$LIST" | grep '^cmd/git\.exe$')"
test -z "$cmd_git" || {
	git_version="$("/$cmd_git" version)" &&
	inno_defines="$inno_defines$LF#define GIT_VERSION '$git_version'"
} ||
die "Could not execute 'git version'"

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
		inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_BUILTIN_STASH 1"
		;;
	esac
	;;
esac

if test "$(GIT_CONFIG_NOSYSTEM=1 HOME=. git add --patch=123 2>&1)" != \
	"$(git -c add.interactive.usebuiltin=1 add --patch=123 2>&1)"
then
	inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_BUILTIN_ADD_I 1"
fi

if grep -q enable_pcon /usr/bin/msys-2.0.dll
then
	inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_PCON 1"
fi

if test -n "$(git version --build-options | grep fsmonitor--daemon)"
then
	inno_defines="$inno_defines$LF#define WITH_EXPERIMENTAL_BUILTIN_FSMONITOR 1"
fi

case "$LIST" in
*/scalar.exe*)
	inno_defines="$inno_defines$LF#define WITH_SCALAR 1"
	;;
esac

GITCONFIG_PATH="$(echo "$LIST" | grep "^$etc_gitconfig\$")"
test -z "$GITCONFIG_PATH" || {
	keys="$(git config -f "/$GITCONFIG_PATH" -l --name-only)" &&
	gitconfig="$LF[Code]${LF}function GitSystemConfigSet(Key,Value:String):Boolean; forward;$LF" &&
	gitconfig="$gitconfig${LF}function SetSystemConfigDefaults():Boolean;${LF}begin${LF}    Result:=True;${LF}" &&
	for key in $keys
	do
		case "$key" in
		pack.packsizelimit|diff.astextplain.*|filter.lfs.*|http.sslcainfo)
			# set in the system-wide config
			value="$(git config -f "/$GITCONFIG_PATH" "$key")" &&
			case "$key$value" in *"'"*) die "Cannot handle $key=$value because of the single quote";; esac &&
			case "$key" in
			filter.lfs.*) extra=" IsComponentSelected('gitlfs') And";;
			pack.packsizelimit) test $BITNESS = 32 || continue; value=2g; extra=;;
			*) extra=;;
			esac &&
			gitconfig="$gitconfig$LF    if$extra not GitSystemConfigSet('$key','$value') then$LF        Result:=False;" ||
			break
			;;
		esac || break
	done ||
	die "Could not split gitconfig"

	gitconfig="$gitconfig${LF}end;$LF"
	inno_defines="$inno_defines$LF$gitconfig"

	LIST="$(echo "$LIST" | grep -v "^$GITCONFIG_PATH\$")"
}

if test -n "$cmd_git"
then
	if test ! -f init.defaultBranch ||
		test "$git_version" != "$(cat init.defaultBranch.gitVersion 2>/dev/null)"
	then
		echo "$git_version" >init.defaultBranch.gitVersion &&
		d=init.defaultBranch.$$ &&
		rm -f $d &&
		GIT_CONFIG_NOSYSTEM=true HOME=$d XDG_CONFIG_HOME=$d GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME= git init --bare $d &&
		default_branch_name="$(git -C $d symbolic-ref --short HEAD)" &&
		rm -rf $d &&
		test -n "$default_branch_name" &&
		echo "$default_branch_name" >init.defaultBranch ||
		die "Could not determine default branch name"
	fi

	inno_defines="$inno_defines$LF#define DEFAULT_BRANCH_NAME '$(cat init.defaultBranch)'"
fi

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

test -z "$arm64_artifacts_directory" || {
	echo "Including ARM64 artifacts from $arm64_artifacts_directory" &&
	inno_defines="$inno_defines$LF#define INSTALLER_FILENAME_SUFFIX 'arm64'" &&
	mixed="$(cygpath -m "$arm64_artifacts_directory")" &&
	find "$arm64_artifacts_directory" -type f |
	sed -e "s|^$arm64_artifacts_directory\\(/.*\)\?/\([^/]*\)$|Source: \"$mixed\\1/\\2\"; DestDir: {app}/arm64\\1; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore|" \
		-e 's|/|\\|g' \
		>> file-list.iss
} ||
die "Could not include ARM64 artifacts"

etc_gitconfig_dir="${etc_gitconfig%/gitconfig}"
printf "%s\n%s\n%s\n%s\n%s%s" \
	"#define APP_VERSION '$displayver'" \
	"#define FILENAME_VERSION '$version'" \
	"#define BITNESS '$BITNESS'" \
	"#define SOURCE_DIR '$(cygpath -aw /)'" \
	"#define ETC_GITCONFIG_DIR '${etc_gitconfig_dir//\//\\}'" \
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
	exec "$TEMP/$version.exe" $test_installer_options
	exit
fi

echo "Installer is available as $(tail -n 1 install.log)"

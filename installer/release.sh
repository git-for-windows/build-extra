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
			printf 'Unknown page "%s". Known pages:\n    %s\n' "$page" wpSelectComponents >&2
			sed -n -e 's/:TWizardPage;$//p' -e 's/:TInputFileWizardPage;$//p' <install.iss >&2
			exit 1
		fi
		inno_defines="$inno_defines$LF#define DEBUG_WIZARD_PAGE '$page_id'$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		skip_files=t
		;;
	--test)
		test_installer=t
		inno_defines="$inno_defines$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		;;
	--silent-test)
		test_installer=t
		test_installer_options="//SILENT //NORESTART"
		skip_files=t
		inno_defines="$inno_defines$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		;;
	--include-self-check)
		inno_defines="$inno_defines$LF#define INCLUDE_SELF_CHECK 1"
		;;
	--self-check)
		test_installer=t
		skip_files=t
		inno_defines="$inno_defines$LF#define OUTPUT_TO_TEMP ''"
		inno_defines="$inno_defines$LF#define DO_NOT_INSTALL 1"
		inno_defines="$inno_defines$LF#define INCLUDE_SELF_CHECK 1"
		inno_defines="$inno_defines$LF#define EXIT_AFTER_SELF_CHECK 1"
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
case "$MSYSTEM" in
MINGW32)
	BITNESS=32
	ARCH=i686
	;;
MINGW64)
	BITNESS=64
	ARCH=x86_64
	;;
CLANGARM64)
	BITNESS=64
	ARCH=aarch64
	inno_defines="$inno_defines$LF#define INSTALLER_FILENAME_SUFFIX 'arm64'"
	;;
*)
	die "Unhandled MSYSTEM: $MSYSTEM"
	;;
esac
MSYSTEM_LOWER=${MSYSTEM,,}

if test -n "$page_id"
then
	echo "Space intentionally left empty" >ReleaseNotes.html
else
	echo "Generating release notes to be included in the installer ..."
	../render-release-notes.sh --css usr/share/git/
fi ||
die "Could not generate release notes"

test ! -d /var/lib/pacman/local/ ||
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
	LIST="$(ARCH=$ARCH \
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
	"Source: \"$MSYSTEM_LOWER\\bin\\blocked-file-util.exe\"; Flags: dontcopy" \
	"Source: \"{#SourcePath}\\package-versions.txt\"; DestDir: {app}\\etc; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"{#SourcePath}\\..\\ReleaseNotes.css\"; DestDir: {app}\\usr\\share\\git; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"cmd\\git.exe\"; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"$MSYSTEM_LOWER\\share\\git\\compat-bash.exe\"; DestName: bash.exe; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
	"Source: \"$MSYSTEM_LOWER\\share\\git\\compat-bash.exe\"; DestName: sh.exe; DestDir: {app}\\bin; Flags: replacesameversion restartreplace; AfterInstall: DeleteFromVirtualStore" \
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

if grep -q enable_pcon /usr/bin/msys-2.0.dll &&
	case "$(uname -r)" in 3.[0-4]*) true;; *) false;; esac # pcon in v3.5+ is no longer experimental
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

	gitconfig="$gitconfig${LF}end;$LF#define HAVE_SET_SYSTEM_CONFIG_DEFAULTS 1$LF"
	inno_defines="$inno_defines$LF$gitconfig"

	LIST="$(echo "$LIST" | grep -v "^$GITCONFIG_PATH\$")"
}

if test -n "$cmd_git"
then
	# Find out Git's default branch name
	case "${git_version#git version }" in
	[01].*|2.[0-9].*|2.[12][0-9].*|2.3[0-4].*) false;; # does not support `git var GIT_DEFAULT_BRANCH`
	*) default_branch_name="$(GIT_CONFIG_NOSYSTEM=1 \
		HOME=.git/x XDG_CONFIG_HOME=.git/x GIT_DIR=.git/x \
		git var GIT_DEFAULT_BRANCH)";;
	esac ||
	if test -f init.defaultBranch &&
		test "$git_version" = "$(cat init.defaultBranch.gitVersion 2>/dev/null)"
	then
		default_branch_name="$(cat init.defaultBranch)"
	else
		echo "$git_version" >init.defaultBranch.gitVersion &&
		d=init.defaultBranch.$$ &&
		rm -f $d &&
		GIT_CONFIG_NOSYSTEM=true HOME=$d XDG_CONFIG_HOME=$d GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME= git init --bare $d &&
		git config -f $d/.gitconfig --add safe.directory "$(cygpath -am $d)" &&
		default_branch_name="$(HOME=$d git -C $d symbolic-ref --short HEAD)" &&
		rm -rf $d &&
		test -n "$default_branch_name" &&
		echo "$default_branch_name" >init.defaultBranch ||
		die "Could not determine default branch name"
	fi

	inno_defines="$inno_defines$LF#define DEFAULT_BRANCH_NAME '$default_branch_name'"
fi

# 1. Collect all SSH related files from $LIST and pacman, sort each and then return the overlap
# 2. Convert paths to Windows filesystem compatible ones and construct the function body for the DeleteOpenSSHFiles function; one DeleteFile operation per file found
# 3. Construct DeleteOpenSSHFiles function signature to be used in install.iss
# 4. Assemble function body and compile flag to be used as guard in install.iss
echo "$LIST" | sort >sorted-file-list.txt
if type -p pacman.exe >/dev/null 2>&1
then
	pacman -Ql openssh 2>pacman.stderr | sed -n 's|^openssh /\(.*[^/]\)$|\1|p' | sort >sorted-openssh-file-list.txt
	grep -v 'database file for .* does not exist' <pacman.stderr >&2
	openssh_deletes="$(comm -12 sorted-file-list.txt sorted-openssh-file-list.txt |
		sed -e 'y/\//\\/' -e "s|.*|    if not DeleteFile(AppDir+'\\\\&') then\n        Result:=False;|")"
	inno_defines="$inno_defines$LF[Code]${LF}function DeleteOpenSSHFiles():Boolean;${LF}var$LF    AppDir:String;${LF}begin$LF    AppDir:=ExpandConstant('{app}');$LF    Result:=True;"
	inno_defines="$inno_defines$LF$openssh_deletes${LF}end;$LF#define DELETE_OPENSSH_FILES 1"
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

etc_gitconfig_dir="${etc_gitconfig%/gitconfig}"
printf "%s\n%s\n%s\n%s\n%s\n%s%s" \
	"#define APP_VERSION '$displayver'" \
	"#define FILENAME_VERSION '$version'" \
	"#define BITNESS '$BITNESS'" \
	"#define MINGW_BITNESS '$MSYSTEM_LOWER'" \
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

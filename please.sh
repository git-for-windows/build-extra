#!/bin/sh

# This script is meant to help maintain Git for Windows. It automates large
# parts of the release engineering.
#
# The major trick is to be able to update and build 32-bit as well as 64-bit
# packages. This is particularly problematic when trying to update files that
# are in use, such as msys-2.0.dll or bash.exe. To that end, this script is
# intended to run from a *separate* Bash, such as Git Bash.

# Note: functions whose arguments are documented on the function name's own
# line are actually subcommands, and running this script without any argument
# will list all subcommands.

die () {
	printf "$@" >&2
	exit 1
}

sdk_path () { # <bitness>
	result="$(git config windows.sdk"$1".path)" && test -n "$result" ||
	result="C:/git-sdk-$1"

	test -e "$result" ||
	die "%s\n\n%s\n%s\n" \
		"Could not determine location of Git for Windows SDK $1-bit" \
		"Default location: C:/git-sdk-$1" \
		"Config variable to override: windows.sdk$1.path"

	echo "$result"
}

sdk64="$(sdk_path 64)"
sdk32="$(sdk_path 32)"

in_use () { # <sdk> <path>
	test -n "$($1/mingw??/bin/WhoUses.exe -m "$1$path" |
		grep '^[^-P]')"
}

# require_not_in_use <sdk> <path>
require_not_in_use () {
	! in_use "$@" ||
	die "%s: in use\n" "$1/$2"
}

independent_shell=
is_independent_shell () { #
	test -n "$independent_shell" || {
		normalized64="$(cygpath -w "$sdk64")"
		normalized32="$(cygpath -w "$sdk32")"
		case "$(cygpath -w "$(which sh.exe)")" in
		"$normalized64\\"*|"$normalized32\\"*)
			independent_shell=f
			;;
		*)
			independent_shell=t
			;;
		esac
	}
	test t = "$independent_shell"
}

info () { #
	is_independent_shell && warning= ||
	warning="WARNING: Current shell is not independent"

	printf "%s\n%s\n%s" \
		"Git for Windows 64-bit SDK: $sdk64" \
		"Git for Windows 32-bit SDK: $sdk32" \
		"$warning"
}

sync () { #
	for sdk in "$sdk32" "$sdk64"
	do
		"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe -Sy ||
		die "Cannot run pacman in %s\n" "$sdk"

		for p in bash pacman "msys2-runtime msys2-runtime-devel"
		do
			"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe \
				-S --noconfirm --needed $p ||
			die "Could not update %s in %s\n" "$p" "$sdk"
		done

		"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe \
			-Su --noconfirm ||
		die "Cannot update packages in %s\n" "$sdk"
	done
}

# set_package <package>
set_package () {
	package="$1"
	extra_packages=
	case "$package" in
	git-extra)
		type=MINGW
		path=/usr/src/build-extra/git-extra
		;;
	git)
		package=mingw-w64-git
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
		type=MINGW
		path=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-git)
		type=MINGW
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
		path=/usr/src/MINGW-packages/$package
		;;
	msys2-runtime)
		type=MSYS
		extra_packages="msys2-runtime-devel"
		path=/usr/src/MSYS2-packages/$package
		;;
	*)
		die "Unknown package: %s\n" "$package"
		;;
	esac
}

# foreach_sdk <function> [<args>]
foreach_sdk () {
	# No uncommitted changes?
	for sdk in "$sdk32" "$sdk64"
	do
		# MINGW packages are compiled in the 64-bit SDK only
		test "a$sdk64" = "a$sdk" ||
		test MINGW != "$type" ||
		continue

		(cd "$sdk/$path" ||
		 die "%s does not exist\n" "$sdk/$path"

		 "$@") || exit
	done
}

require_clean_worktree () {
	git update-index -q --ignore-submodules --refresh &&
	git diff-files --quiet --ignore-submodules &&
	git diff-index --cached --quiet --ignore-submodules HEAD ||
	die "%s not up-to-date" "$sdk/$path"
}

ff_master () {
	test refs/heads/master = "$(git rev-parse --symbolic-full-name HEAD)" ||
	die "%s: Not on 'master'\n" "$sdk/$path"

	require_clean_worktree

	git pull --ff-only origin master ||
	die "%s: cannot fast-forward 'master'\n" "$sdk/$path"
}

update () { # <package>
	set_package "$1"

	foreach_sdk ff_master
}

# require <metapackage> <telltale>
require () {
	test -d "$sdk"/var/lib/pacman/local/"$2"-[0-9]* ||
	"$sdk"/git-cmd.exe --command=usr\\bin\\pacman.exe \
		-Sy --needed --noconfirm "$1" ||
	die "Could not install %s\n" "$1"
}

pkg_build () {
	require_clean_worktree

	test "a$sdk" = "a$sdk32" &&
	arch=i686 ||
	arch=x86_64

	case "$type" in
	MINGW)
		require mingw-w64-toolchain mingw-w64-$arch-make

		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'MAKEFLAGS=-j5 makepkg-mingw -s --noconfirm &&
			 MINGW_INSTALLS=mingw64 makepkg-mingw --allsource' ||
		die "%s: could not build\n" "$sdk/$path"

		git commit -s -m "$package: new version" PKGBUILD ||
		die "%s: could not commit after build\n" "$sdk/$path"
		;;
	MSYS)
		require msys2-devel binutils
		test msys2-runtime != "$package" ||
		require mingw-w64-cross-gcc mingw-w64-cross-gcc

		"$sdk/git-cmd" --command=usr\\bin\\sh.exe -l -c \
			'export MSYSTEM=MSYS &&
			 export PATH=/usr/bin:/opt/bin:$PATH &&
			 MAKEFLAGS=-j5 makepkg -s --noconfirm &&
			 makepkg --allsource' ||
		die "%s: could not build\n" "$sdk/$path"

		if test "a$sdk32" = "a$sdk"
		then
			git diff-files --quiet --ignore-submodules PKGBUILD ||
			git commit -s -m "$package: new version" PKGBUILD ||
			die "%s: could not commit after build\n" "$sdk/$path"
		else
			git add PKGBUILD &&
			git pull "$sdk32/${path%/*}/.git" \
				"$(git rev-parse --symbolic-full-name HEAD)" &&
			require_clean_worktree ||
			die "%s: unexpected difference between 32/64-bit\n" \
				"$path"
		fi
		;;
	esac
}

# up_to_date <path>
up_to_date () {
	# test that repos at <path> are up-to-date in both 64-bit and 32-bit
	path="$1"

	commit32="$(cd "$sdk32/$path" && git rev-parse --verify HEAD)" &&
	commit64="$(cd "$sdk64/$path" && git rev-parse --verify HEAD)" ||
	die "Could not determine HEAD commit in %s\n" "$path"

	test "a$commit32" = "a$commit64" ||
	die "%s: commit %s (32-bit) != %s (64-bit)\n" \
		"$path" "$commit32" "$commit64"

	foreach_sdk require_clean_worktree
}

build () { # <package>
	set_package "$1"

	test MINGW = "$type" ||
	up_to_date "$path" ||
	die "%s: not up-to-date\n" "$path"

	foreach_sdk pkg_build
}

test $# -gt 0 &&
test help != "$*" ||
die "Usage: $0 <command>\n\nCommands:\n%s" \
	"$(sed -n 's/^\([a-z]*\) () { #\(.*\)/\t\1\2/p' <"$0")"

command="$1"
shift

usage="$(sed -n "s/^$command () { # \?/ /p" <"$0")"
test -n "$usage" ||
die "Unknown command: %s\n" "$command"

test $# = $(echo "$usage" | tr -dc '<' | wc -c) ||
die "Usage: %s %s%s\n" "$0" "$command" "$usage"

"$command" "$@"

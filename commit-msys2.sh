#!/bin/sh

# To help Continuous Integration, this script commits the files installed via
# MSYS2 packages into the Git for Windows SDK. The resulting repository can be
# easily cloned and cached by build agents.

die () {
	echo "$*" >&2
	exit 1
}

root="$(cd "$(dirname "$0")/../../.." && pwd)" ||
die "Could not determine root directory"


list_packages () {
	(cd "${root%/}"/var/lib/pacman/local &&
	 # order by ctime
	 ls -rtc | grep -v ALPM_DB_VERSION)
}

commit_package () {
	(cd "$root" ||
	 die "Could not cd to $root"

	 git update-index -q --refresh &&
	 git diff-index --cached --quiet HEAD -- ||
	 die "There are uncommitted changes in $root"

	 package="$(echo var/cache/pacman/pkg/"$1"*.pkg.tar.xz)"

	 test -f "$package" || die "Could not find the package of $1"

	 if git rev-parse -q --verify refs/heads/import-tars >/dev/null
	 then
		git branch -D import-tars
	 fi &&
	 "$import_tars" "$package" &&
	 git ls-tree -r import-tars |
	 sed -n 's/^\([0-9]* \)blob \([0-9a-f]*\)\(\t[^.].*\)/\1\2\3/p' |
	 git update-index --index-info &&
	 git add "${root%/}"/var/lib/pacman/local/"$1" &&
	 git commit -s -m "$1" ||
	 die "Could not commit $1") ||
	exit
}

case "$1" in
init)
	import_tars="${root%/}"/usr/src/git/contrib/fast-import/import-tars.perl
	test -x "$import_tars" ||
	die "You need to run this script in a Git for Windows SDK"

	if test ! -d "${root%/}"/.git
	then
		(cd "$root" && git init) ||
		die "Could not initialize Git repository"
	fi

	if test false != "$(git -C "$root" config core.autocrlf)"
	then
		git -C "$root" config core.autocrlf false ||
		die "Could not force core.autocrlf = false"
	fi

	for package in $(list_packages)
	do
		commit_package $package || exit
	done

	(cd "$root" &&
	 git add var/lib/pacman/sync &&
	 git commit -s -m "Pacman package index") ||
	die "Could not conclude initial commits"
	;;
commit)
	(cd "$root" &&
	 if test false != "$(git config core.autocrlf)"
	 then
		git config core.autocrlf false ||
		die "Could not force core.autocrlf = false"
	 fi &&
	 git add -A . &&
	 git diff-index --exit-code --cached HEAD ||
	 git commit -q -s -m "Update $(date +%Y%m%d-%H%M%S)") ||
	die "Could not commit changes"
	;;
*)
	die "Unknown command: $1"
	;;
esac

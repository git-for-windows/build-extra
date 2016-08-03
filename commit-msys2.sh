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

import_tars="$root"/usr/src/git/contrib/fast-import/import-tars.perl
test -x "$import_tars" ||
die "You need to run this script in a Git for Windows SDK"

list_packages () {
	(cd "$root"/var/lib/pacman/local &&
	 ls | grep -v ALPM_DB_VERSION)
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
	 git add "$root"/var/lib/pacman/local/"$1" &&
	 git commit -s -m "$1" ||
	 die "Could not commit $1") ||
	exit
}

for package in $(list_packages)
do
	commit_package $package
done

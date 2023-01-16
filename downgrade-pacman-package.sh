#!/bin/sh

die () {
    echo "$*" >&2
    exit 1
}

test $# -gt 1 ||
die "Usage: $0 <test-scriptlet> <package>..."

test="$1"; shift

git -C / update-index --ignore-submodules --refresh &&
git -C / diff-files --ignore-submodules &&
git -C / diff-index --cached --ignore-submodules HEAD ||
die "Uncommitted changes"

msg=
for package
do
	dir="$(ls -d /var/lib/pacman/local/$package-[0-9]*)" ||
	die "Package '$package' not installed?"

	current_version=${dir#*/$package-}

	sdk_commit="$(git -C / log --format=%H -1 --diff-filter=A $dir/mtree)" &&
	test -n "$sdk_commit" ||
	die "Could not identify commit that upgraded '$package'"

	previous_version="$(git -C / diff --name-only --diff-filter=D $sdk_commit^! |
		sed -n "s|^var/lib/pacman/local/$package-\\([0-9].*\\)/mtree$|\\1|p")" &&
	test -n "$previous_version" ||
	die "Could not determine previous version of '$package'"

	echo "Downgrading '$package' from $current_version to $previous_version"
	test ! -f "$dir/install" || (
		. "$dir/install"
		test function = "$(type -t pre_upgrade)" || exit 0
		echo "Running pre_upgrade in '$package'" >&2
		pre_upgrade $current_version $previous_version
	) ||
	die "pre_upgrade failed with code $?"

	# `sed` script to extract the actual list of files from `/var/lib/<package>/files`
	files_sed_script='/^%FILES%$/,/^$/{
		/^%FILES%$/d # ignore the section header
		/^$/d        # ignore empty lines
		/\/$/d       # ignore directories
		/\.pyc/d     # compiled Python files are ignored via `/.gitignore`
		/^mingw.*\/bin\/.*\.bat/d # .bat files in /mingw*/bin/ are removed by `git-extra.install`
		p
	}'

	echo "Removing files of $package-$current_version" >&2
	sed -n "$file_sed_script" <"$dir/files" |
	xargs -rd '\n' git -C / rm &&
	git -C / rm -r "$dir" ||
	die "Could not remove files of '$package'"

	echo "Adding files of $package-$previous_version" >&2
	dir=/var/lib/pacman/local/$package-$previous_version &&
	git -C / checkout $sdk_commit^ $dir/ &&
	sed -n "$files_sed_script" <"$dir/files" |
	xargs -rd '\n' git -C / checkout $sdk_commit^ -- ||
	die "Could not add files of '$package'"
	test ! -f "$dir/install" || (
		. "$dir/install"
		test function = "$(type -t pre_upgrade)" || exit 0
		echo "Running post_upgrade in '$package'" >&2
		post_upgrade $current_version $previous_version
	) ||
	die "post_upgrade failed with code $?"

	sed -i \
		-e 's/^# *\(IgnorePkg *=\)/\1/' \
		-e "/^IgnorePkg *=/{/\(=\| \)$package\( \|$\)/b;s/$/ $package/}" \
		/etc/pacman.conf ||
	die "Could not edit /etc/pacman.conf"

	msg="${msg+$msg
}$package $current_version -> $previous_version"
done

eval "$test" ||
die "test failed with code $?"

git -C / add etc/pacman.conf &&
git -C / commit \
	-m "$(test $# -gt 1 && echo "Downgrade $# packages" || echo "Downgrade $1")" \
	-m "$msg"

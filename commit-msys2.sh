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

root_gitdir="$(git -C "$root" rev-parse --absolute-git-dir)" &&
test -d "$root_gitdir" ||
die "Could not determine root gitdir"

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

generate_package_gitignore () {
	dir="$(cd "${root%/}"/var/lib/pacman/local/ &&
		case "$1" in
		mingw-w64-x86_64-libusb-compat-git)
			echo "$1"-r[0-9]*
			;;
		*)
			echo "$1"-[0-9]*
			;;
		esac)" &&
	case "$dir" in
	*' '*)
		die "Multiple packages: $dir"
		;;
	'')
		die "$1: not installed?"
		;;
	*)
		test -d "${root%/}/var/lib/pacman/local/$dir" ||
		die "$1: not installed?"

		printf '\n# Package: %s\n%s\n' \
			"$dir" "/var/lib/pacman/local/$dir/" &&
		sed -n 's|^[^%].*[^/]$|/&|p' \
			"${root%/}/var/lib/pacman/local/$dir/files"
		;;
	esac
}

summarize_commit () {
	test $# -le 1 ||
	die "summarize_commit: too many arguments ($*)"

	if test -z "$1"
	then
		git diff --cached -M50 --raw -- var/lib/pacman/local/\*/desc
	else
		git show "$1" --format=%H \
			-M15 --raw -- var/lib/pacman/local/\*/desc
	fi |
	sed -ne '/.* M\tvar\/lib\/pacman\/local\/git-extra-[1-9].*\/desc$/d' \
	 -e '/ R[0-9]*\t/{s/-\([0-9]\)/ (\1/;h;s|-\([0-9][^/]*\)/desc$|\t\1)|;s|.*\t| -> |;x;s|/desc\t.*||;s|.*\t[^\t]*/||;G;s|\n||g;p}' \
	 -e '/ A\t/{s|.*local/\([^/]*\)/desc|\1|;s|-\([0-9].*\)| (new: \1)|p}' \
	 -e '/ D\t/{s|.*local/\([^/]*\)/desc|\1|;s|-\([0-9].*\)| (removed)|p}'
}

case "$1" in
init)
	import_tars="${root%/}"/usr/src/git/contrib/fast-import/import-tars.perl
	test -x "$import_tars" ||
	die "You need to run this script in a Git for Windows SDK"

	if test ! -d "$root_gitdir"
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
add)
	shift &&
	(cd "$root" &&
	 if test false != "$(git config core.autocrlf)"
	 then
		git config core.autocrlf false ||
		die "Could not force core.autocrlf = false"
	 fi &&
	 packages="$(for package; do
		case "$package" in
		mingw-w64-*) echo mingw-w64-$(uname -m)${package#mingw-w64};;
		*) echo "$package";;
		esac; done)" &&
	 pacman -Syy --noconfirm $packages &&
	 git add -A . ||
	 die "Could not add $*"

	 git diff-index --exit-code --cached HEAD ||
	 git commit -q -s -m "Add $*") ||
	die "Could not commit changes"
	;;
summary)
	shift
	summarize_commit "$@"
	;;
commit)
	(cd "$root" &&
	 if test false != "$(git config core.autocrlf)"
	 then
		git config core.autocrlf false ||
		die "Could not force core.autocrlf = false"
	 fi &&
	 git add -A . &&
	 if git diff-index --exit-code --cached HEAD -- \
		':(exclude)var/lib/pacman/sync/' \
		':(exclude)var/lib/pacman/local/git-extra-*/desc' \
		':(exclude)etc/rebase.db*'
	 then
		# No changes, really, but maybe a new Pacman db
		git reset --hard
	 else
		summary="$(summarize_commit)"
		count=$(echo "$summary" | wc -l) &&
		if test $count -lt 2
		then
			oneline="Update $count package"
		else
			oneline="Update $count packages"
		fi &&
		git commit -q -s -m "$oneline" -m "$summary"
	 fi) ||
	die "Could not commit changes"
	;;
ignore)
	shift

	case "$*" in
	-a|--all)
		set -- $(git -C "${root%/}"/ ls-files --exclude-standard  \
				--other var/lib/pacman/local/ |
			sed -n 's|^var/lib/pacman/local/\([^/]*\)-r\?[0-9][-0-9a-z_.]*-[1-9][0-9]*/.*|\1|p' |
			uniq)
		;;
	esac

	mkdir -p "$root_gitdir"/info &&
	touch "$root_gitdir"/info/exclude ||
	die "Could not ensure that .git/info/exclude exists"

	for pkg
	do
		# Remove existing entries, if any
		sed -i '/^$/{
			:1
			N
			/^\n# \(Package: \)\?'$pkg'\(-[0-9][-0-9a-z_.]*\)\?$/{
				:2
				N
				s/.*\n//
				/./b2
				b1
			}
		}' "$root_gitdir"/info/exclude &&
		generate_package_gitignore "$pkg" \
			>>"$root_gitdir"/info/exclude ||
		die "Could not ignore $pkg"
	done
	;;
*)
	die "Unknown command: $1"
	;;
esac

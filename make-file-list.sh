#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test -n "$ARCH" &&
test -n "$BITNESS" ||
die "Need ARCH and BITNESS to be set"

pacman_list () {
	package_list=$(for arg
		do
			pactree -u "$arg"
		done |
		sort |
		uniq) &&
	if test -n "$PACKAGE_VERSIONS_FILE"
	then
		pacman -Q $package_list >"$PACKAGE_VERSIONS_FILE"
	fi &&
	pacman -Ql $package_list |
	grep -v '/$' |
	sed 's/^[^ ]* //'
}

pacman_list mingw-w64-$ARCH-git mingw-w64-$ARCH-git-doc-html \
	git-extra ncurses mintty vim \
	sed awk less grep gnupg findutils coreutils \
	dos2unix which subversion mingw-w64-$ARCH-tk "$@" |
grep -v -e '\.[acho]$' -e '/aclocal/' \
	-e '/man/' \
	-e '/mingw32/share/doc/git-doc/.*\.txt$' \
	-e '^/usr/include/' -e '^/mingw32/include/' \
	-e '^/usr/share/doc/' -e '^/mingw32/share/doc/' \
	-e '^/usr/share/info/' -e '^/mingw32/share/info/' |
sed 's/^\///'

cat <<EOF
etc/profile
etc/bash.bash_logout
etc/bash.bashrc
etc/fstab
etc/nsswitch.conf
mingw$BITNESS/etc/gitconfig
EOF

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
		grep -v -e '^db$' -e '^info$' -e '^heimdal$' |
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
	git-extra ncurses mintty vim openssh winpty \
	sed awk less grep gnupg tar findutils coreutils diffutils \
	dos2unix which subversion getopt mingw-w64-$ARCH-tk "$@" |
grep -v -e '\.[acho]$' -e '\.l[ao]$' -e '/aclocal/' \
	-e '/man/' -e '/pkgconfig/' -e '/emacs/' \
	-e '^/usr/lib/python' -e '^/usr/lib/ruby' \
	-e '^/usr/share/awk' -e '^/usr/share/subversion' \
	-e '^/etc/skel/' -e '^/mingw../etc/skel/' \
	-e '^/usr/bin/svn' \
	-e '^/mingw../share/doc/gettext/' \
	-e '^/mingw../share/doc/lib' \
	-e '^/mingw../share/doc/pcre/' \
	-e '^/mingw../share/doc/git-doc/.*\.txt$' \
	-e '^/mingw../lib/gettext/' -e '^/mingw../share/gettext/' \
	-e '^/usr/include/' -e '^/mingw../include/' \
	-e '^/usr/share/doc/' \
	-e '^/usr/share/info/' -e '^/mingw../share/info/' |
sed 's/^\///'

cat <<EOF
etc/profile
etc/bash.bash_logout
etc/bash.bashrc
etc/fstab
etc/nsswitch.conf
mingw$BITNESS/etc/gitconfig
etc/post-install/01-devices.post
etc/post-install/03-mtab.post
etc/post-install/06-windows-files.post
usr/bin/start
usr/bin/dash.exe
usr/bin/getopt.exe
usr/bin/rebase.exe
usr/bin/rebaseall
EOF

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
		grep -v -e '^db$' -e '^info$' -e '^heimdal$' \
			-e '^git$' -e '^util-linux$' |
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

# Packages that have been added after Git SDK 1.0.0 was released...
required=
for req in mingw-w64-$ARCH-connect git-flow unzip docx2txt \
	mingw-w64-$ARCH-antiword mingw-w64-$ARCH-xpdf
do
	test -d /var/lib/pacman/local/$req-[0-9]* ||
	required="$required $req"
done
test -z "$required" ||
pacman -S --noconfirm $required >&2 ||
die "Could not install required packages: $required"

pacman_list mingw-w64-$ARCH-git mingw-w64-$ARCH-git-doc-html \
	git-extra ncurses mintty vim openssh winpty \
	sed awk less grep gnupg tar findutils coreutils diffutils patch \
	dos2unix which subversion mingw-w64-$ARCH-tk \
	mingw-w64-$ARCH-connect git-flow docx2txt mingw-w64-$ARCH-antiword "$@" |
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
	-e '^/usr/share/info/' -e '^/mingw../share/info/' \
	-e '^/mingw../share/git-doc/technical/' \
	-e '^/mingw../itcl/' \
	-e '^/mingw../t\(cl\|k\)[^/]*/\(demos\|msgs\|encoding\|tzdata\)/' \
	-e '^/mingw../bin/\(autopoint\|[a-z]*-config\)$' \
	-e '^/mingw../bin/lib\(asprintf\|gettext\|gnutlsxx\|pcre[0-9a-z]\|quadmath\|stdc++\)[^/]*\.dll$' \
	-e '^/mingw../bin/\(asn1\|gnutls\|idn\|mini\|msg\|nettle\|ngettext\|ocsp\|pcre\|rtmp\|xgettext\)[^/]*\.exe$' \
	-e '^/mingw../.*/git-\(remote-testsvn\|shell\)\.exe$' \
	-e '^/mingw../lib/tdbc' \
	-e '^/mingw../share/git\(k\|-gui\)/lib/msgs/' \
	-e '^/usr/bin/msys-\(db\|icu\|gfortran\|stdc++\|quadmath\)[^/]*\.dll$' \
	-e '^/usr/bin/dumper\.exe$' \
	-e '^/usr/share.*/magic$' \
	-e '^/usr/share/perl5/core_perl/Unicode/Collate/Locale/' \
	-e '^/usr/share/perl5/core_perl/pods/' \
	-e '^/usr/share/vim/vim74/lang/' \
	-e '^/etc/profile.d/git-sdk.sh$' |
if test -n "$WITH_L10N"
then
	cat
else
	grep -v \
		-e '^/mingw../share/locale/' \
		-e '^/usr/share/locale/'
fi |
grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|xterm.*)$)' |
sed 's/^\///'

test -z "$PACKAGE_VERSIONS_FILE" ||
pacman -Q filesystem dash rebase util-linux unzip \
	mingw-w64-$ARCH-xpdf >>"$PACKAGE_VERSIONS_FILE"

cat <<EOF
etc/profile
etc/profile.d/lang.sh
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
usr/bin/rebase.exe
usr/bin/rebaseall
usr/bin/getopt.exe
mingw$BITNESS/etc/gitattributes
mingw$BITNESS/bin/pdftotext.exe
mingw$BITNESS/bin/libstdc++-6.dll
usr/bin/column.exe
EOF

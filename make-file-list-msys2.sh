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
		grep -v "^\\($(echo $PACKAGE_EXCLUDES | sed \
			-e 's/ /\\|/g' \
			-e 's/mingw-w64-/&\\(i686\\|x86_64\\)-/g')\\)\$" |
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

install_required () {
	# TODO some of these might not be wanted
	# Packages that have been added after Git SDK 1.0.0 was released...
	required=
	for req in mingw-w64-$ARCH-git-credential-manager $SH_FOR_REBASE
	do
		test -d /var/lib/pacman/local/$req-[0-9]* ||
		test -d /var/lib/pacman/local/$req-git-[0-9]* ||
		required="$required $req"
	done
	test -z "$required" ||
	pacman -Sy --noconfirm $required >&2 ||
	die "Could not install required packages: $required"
}

this_script_dir="$(cd "$(dirname "$0")" && pwd -W)" ||
die "Could not determine this script's dir"

install_required

SH_FOR_REBASE=dash

BASE_PACKAGES="$(pacman -Qg base | awk '{print $2}' | tr '\n' ' ')"
GIT_PACKAGES="mingw-w64-$ARCH-git mingw-w64-$ARCH-git-credential-manager git-extra openssh"
UTIL_PACKAGES=
packages="$BASE_PACKAGES $GIT_PACKAGES $UTIL_PACKAGES"

# TODO need this? should be a parameter? Use BITNESS? 
PACKAGE_EXCLUDES="db info heimdal git util-linux curl git-for-windows-keyring
	mingw-w64-p11-kit filesystem msys2-launcher-git rebase"
# TODO 05-home-dir.post required by filesystem package but is missing from SDK
# TODO should we exlude all the tz stuff?
EXTRA_FILE_EXCLUDES="/etc/post-install/05-home-dir.post
	/mingw$BITNESS/libexec/git-core/git-update-git-for-windows"

pacman_list $packages "$@" |
grep -v -e '\.[acho]$' -e '\.l[ao]$' -e '/aclocal/' \
	-e '/man/' -e '/pkgconfig/' -e '/emacs/' \
	-e '^/usr/lib/python' -e '^/usr/lib/ruby' \
	-e '^/usr/share/subversion' \
	-e '^/etc/skel/' -e '^/mingw../etc/skel/' \
	-e '^/usr/bin/svn' \
	-e '^/usr/bin/xml.*exe$' \
	-e '^/usr/bin/xslt.*$' \
	-e '^/mingw../share/doc/openssl/' \
	-e '^/mingw../share/doc/gettext/' \
	-e '^/mingw../share/doc/lib' \
	-e '^/mingw../share/doc/pcre2\?/' \
	-e '^/mingw../share/doc/git-doc/.*\.txt$' \
	-e '^/mingw../lib/gettext/' -e '^/mingw../share/gettext/' \
	-e '^/usr/include/' -e '^/mingw../include/' \
	-e '^/usr/share/doc/' \
	-e '^/usr/share/info/' -e '^/mingw../share/info/' \
	-e '^/mingw../share/git-doc/technical/' \
	-e '^/mingw../itcl/' \
	-e '^/mingw../t\(cl\|k\)[^/]*/\(demos\|msgs\|encoding\|tzdata\)/' \
	-e '^/mingw../bin/\(autopoint\|[a-z]*-config\)$' \
	-e '^/mingw../bin/lib\(asprintf\|gettext\|gnutlsxx\|pcre[013-9a-oq-z]\|quadmath\|stdc++\)[^/]*\.dll$' \
	-e '^/mingw../bin/\(asn1\|gnutls\|idn\|mini\|msg\|nettle\|ngettext\|ocsp\|pcre\|rtmp\|xgettext\)[^/]*\.exe$' \
	-e '^/mingw../.*/git-\(remote-testsvn\|shell\)\.exe$' \
	-e '^/mingw../.*/git-cvsserver.*$' \
	-e '^/mingw../.*/gitweb/' \
	-e '^/mingw../lib/tdbc' \
	-e '^/mingw../libexec/git-core/git-archimport$' \
	-e '^/mingw../share/doc/git-doc/git-archimport' \
	-e '^/mingw../libexec/git-core/git-cvsimport$' \
	-e '^/mingw../share/doc/git-doc/git-cvsexport' \
	-e '^/mingw../libexec/git-core/git-cvsexport' \
	-e '^/mingw../share/doc/git-doc/git-cvsimport' \
	-e '^/mingw../share/git\(k\|-gui\)/lib/msgs/' \
	-e '^/mingw../share/nghttp2/' \
	-e '^/usr/bin/msys-\(db\|icu\|gfortran\|stdc++\|quadmath\)[^/]*\.dll$' \
	-e '^/usr/bin/dumper\.exe$' \
	-e '^/usr/share.*/magic$' \
	-e '^/usr/share/perl5/core_perl/Unicode/' \
	-e '^/usr/share/perl5/core_perl/pods/' \
	-e '^/usr/share/perl5/core_perl/Locale/' \
	-e '^/usr/share/perl5/core_perl/Pod/' \
	-e '^/usr/share/perl5/core_perl/ExtUtils/' \
	-e '^/usr/share/perl5/core_perl/CPAN/' \
	-e '^/usr/share/perl5/core_perl/TAP/' \
	-e '^/usr/share/vim/vim74/lang/' \
	-e '^/etc/profile.d/git-sdk.sh$' |
grep -v \
	-e '^/mingw../share/locale/' \
	-e '^/usr/share/locale/' |
grep -v \
	-e "^\\($(echo $EXTRA_FILE_EXCLUDES |
		 sed 's/ /\\|/g')\\)\$" |
sort |
grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|screen.*|xterm.*)$)' |
sed 's/^\///'

# TODO - need this?
test -z "$PACKAGE_VERSIONS_FILE" ||
pacman -Q filesystem $SH_FOR_REBASE rebase \
	util-linux unzip mingw-w64-$ARCH-xpdf-tools \
	>>"$PACKAGE_VERSIONS_FILE"

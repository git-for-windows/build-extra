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
PACKAGE_EXCLUDES="db info heimdal git util-linux curl git-for-windows-keyring
	mingw-w64-p11-kit mingw-w64-bzip2 mingw-w64-c-ares
	mingw-w64-libsystre mingw-w64-libtre-git
	mingw-w64-tcl mingw-w64-tk mingw-w64-wineditline gdbm icu libdb
	libedit libgdbm perl perl-.*"
# TODO following required by filesystem package but is missing
# TODO should we exlude all the tz stuff?
EXTRA_FILE_EXCLUDES="/etc/post-install/05-home-dir.post"

BASE_PACKAGES="$(pacman -Qg base | awk '{print $2}' | tr '\n' ' ')"
GIT_PACKAGES="mingw-w64-$ARCH-git mingw-w64-$ARCH-git-credential-manager git-extra openssh"
UTIL_PACKAGES=
packages="$BASE_PACKAGES $GIT_PACKAGES $UTIL_PACKAGES"

# echo $packages !!!

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
	-e '^/cmd/start-.*$' -e '^/cmd/\(git-gui\|gitk\).exe$' \
	-e '^/etc/\(DIR_COLORS\|inputrc\|vimrc\)$' \
	-e '^/etc/profile\.d/\(aliases\|env\|git-prompt\)\.sh$' \
	-e '^/git-\(bash\|cmd\)\.exe$' \
	-e '^/mingw../bin/\(certtool\.exe\|create-shortcut\.exe\)$' \
	-e '^/mingw../bin/\(curl\.exe\|envsubst\.exe\|gettext\.exe\)$' \
	-e '^/mingw../bin/\(gettext\.sh\|gettextize\)$' \
	-e '^/mingw../bin/\(gitk\|git-upload-archive\.exe\)$' \
	-e '^/mingw../bin/lib\(atomic\|charset\)-.*\.dll$' \
	-e '^/mingw../bin/lib\(gcc_s_seh\|gmpxx\)-.*\.dll$' \
	-e '^/mingw../bin/lib\(gomp\|jansson\|minizip\)-.*\.dll$' \
	-e '^/mingw../bin/libvtv.*\.dll$' \
	-e '^/mingw../bin/libpcreposix.*\.dll$' \
	-e '^/mingw../bin/\(.*\.def\|update-ca-trust\)$' \
	-e '^/mingw../bin/\(openssl\|p11tool\|pkcs1-conv\)\.exe$' \
	-e '^/mingw../bin/\(psktool\|recode-.*\|sexp.*\|srp.*\)\.exe$' \
	-e '^/mingw../bin/\(WhoUses\|xmlwf\)\.exe$' \
	-e '^/mingw../etc/pki' -e '^/mingw../lib/p11-kit/' \
	-e '/git-\(add--interactive\|archimport\|citool\|cvs.*\)$' \
	-e '/git-\(difftool.*\|gui.*\|instaweb\|p4\|relink\)$' \
	-e '/git-\(send-email\|svn\)$' \
	-e '/mingw../libexec/git-core/git-\(imap-send\|daemon\)\.exe$' \
	-e '/mingw../libexec/git-core/git-remote-ftp.*\.exe$' \
	-e '/mingw../libexec/git-core/git-http-backend\.exe$' \
	-e "/mingw../libexec/git-core/git-\\($(sed \
		-e 's/^git-//' -e 's/\.exe$//' -e 's/$/\\/' \
			</mingw$BITNESS/share/git/builtins.txt |
		tr '\n' '|')\\)\\.exe\$" \
	-e '^/mingw../share/doc/nghttp2/' \
	-e '^/mingw../share/gettext-' \
	-e '^/mingw../share/git/\(builtins\|compat\|completion\)' \
	-e '^/mingw../share/git/.*\.ico$' \
	-e '^/mingw../share/\(git-gui\|gitweb\)/' \
	-e '^/mingw../share/perl' \
	-e '^/mingw../share/pki/' \
	-e '/zsh/' \
	-e '^/usr/bin/\(astextplain\|bashbug\|c_rehash\|egrep\)$' \
	-e '^/usr/bin/\(fgrep\|findssl\.sh\|igawk\|notepad\)$' \
	-e '^/usr/bin/\(ssh-copy-id\|updatedb\|vi\|wordpad\)$' \
	-e '^/usr/bin/\(\[\|arch\|base32\|base64\|bash\|chcon\)\.exe$' \
	-e '^/usr/bin/\(chgrp\|chmod\|chown\|chroot\|cksum\)\.exe$' \
	-e '^/usr/bin/\(csplit\|cygcheck\|cygpath\|cygwin-.*\)\.exe$' \
	-e '^/usr/bin/\(dd\|df\|dir\|dircolors\|du\|expand\)\.exe$' \
	-e '^/usr/bin/\(factor\|fmt\|fold\|gawk.*\|getconf\)\.exe$' \
	-e '^/usr/bin/\(getfacl\.exe\|gkill\|groups\|host.*\)\.exe$' \
	-e '^/usr/bin/\(iconv\|id\|install\|join\|kill\|ldd\)\.exe$' \
	-e '^/usr/bin/\(ldh\|link\|ln\|locale\|locate\|yes\)\.exe$' \
	-e '^/usr/bin/\(logname\|md5sum\|minidumper\|mkfifo\)\.exe$' \
	-e '^/usr/bin/\(mkgroup\|mknod\|mkpasswd\|mount\|nice\)\.exe$' \
	-e '^/usr/bin/\(nl\|nohup\|nproc\|numfmt\|od\|openssl\)\.exe$' \
	-e '^/usr/bin/\(passwd\|paste\|patchchk\|pinky\|pldd\)\.exe$' \
	-e '^/usr/bin/\(pr\|printenv\|ps\|ptx\|realpath\)\.exe$' \
	-e '^/usr/bin/\(regtool\|runcon\|scp\|seq\|setfacl\)\.exe$' \
	-e '^/usr/bin/\(setmetamode\|sftp\|sha.*sum\|shred\)\.exe$' \
	-e '^/usr/bin/\(shuf\|sleep\|slogin\|split\|sshd\)\.exe$' \
	-e '^/usr/bin/\(ssh-key.*\|ssp\|stat\|stdbuf\|strace\)\.exe$' \
	-e '^/usr/bin/\(stty\|sum\|sync\|tac\|tee\|timeout\)\.exe$' \
	-e '^/usr/bin/\(truncate\|tsort\|tty\|tzset\|umount\)\.exe$' \
	-e '^/usr/bin/\(unexpand\|unlink\|users\|vdir\|who.*\)\.exe$' \
	-e '^/usr/bin/msys-\(atomic\|charset\|cilkrts\)-.*\.dll$' \
	-e '^/usr/bin/msys-\(hdb\|kadm5\|kafs\|kdc\|otp\|sl\).*\.dll$' \
	-e '^/usr/bin/msys-sqlite3[a-z].*\.dll$' \
	-e '^/usr/bin/msys-\(gmpxx\|gomp.*\|vtv.*\)-.*\.dll$' \
	-e '^/usr/lib/\(awk\|coreutils\|gawk\|openssl\|ssh\)/' \
	-e '^/usr/libexec/\(bigram\|code\|frcode\)\.exe$' \
	-e '^/usr/share/\(cygwin\|git\)/' \
	-e '^/usr/ssl/misc/' \
	-e '^/usr/bin/\(captoinfo\|clear\|infocmp\|infotocap\)\.exe$' \
	-e '^/usr/bin/\(reset\|tabs\|tic\|toe\|tput\|tset\)\.exe$' \
	-e '^/usr/bin/msys-\(formw6\|menuw6\|ncurses++w6\)\.dll$' \
	-e '^/usr/bin/msys-\(panelw6\|ticw6\)\.dll$' \
	-e '^/usr/\(lib\|share\)/terminfo/' -e '^/usr/share/tabset/' \
	-e "^\\($(echo $EXTRA_FILE_EXCLUDES | sed 's/ /\\|/g')\\)\$" |
sort |
grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|screen.*|xterm.*)$)' |
sed 's/^\///'

# TODO - need this?
test -z "$PACKAGE_VERSIONS_FILE" ||
pacman -Q filesystem $SH_FOR_REBASE rebase \
	>>"$PACKAGE_VERSIONS_FILE"

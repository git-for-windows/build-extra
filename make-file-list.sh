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
			-e '^git$' -e '^util-linux$' -e '^curl$' |
		if test -z "$MINIMAL_GIT"
		then
			cat
		else
			grep -v -e '^\(.*-bzip2\|.*-c-ares\|.*-libsystre\)$' \
				-e '^\(.*libtre-git\)$' \
				-e '^\(.*-tcl\|.*-tk\|.*-wineditline\)$' \
				-e '^\(gdbm\|icu\|libdb\|libedit\|libgdbm\)$' \
				-e '^\(perl\|perl-.*\)$'
		fi |
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
for req in mingw-w64-$ARCH-git-credential-manager \
	$(test -n "$MINIMAL_GIT" || echo \
		mingw-w64-$ARCH-connect git-flow unzip docx2txt \
		mingw-w64-$ARCH-antiword mingw-w64-$ARCH-xpdf ssh-pageant \
		mingw-w64-$ARCH-git-lfs mingw-w64-$ARCH-curl-winssl-bin)
do
	test -d /var/lib/pacman/local/$req-[0-9]* ||
	test -d /var/lib/pacman/local/$req-git-[0-9]* ||
	required="$required $req"
done
test -z "$required" ||
pacman -Sy --noconfirm $required >&2 ||
die "Could not install required packages: $required"

packages="mingw-w64-$ARCH-git mingw-w64-$ARCH-git-credential-manager
git-extra openssh sed awk grep findutils coreutils
mingw-w64-$ARCH-curl-winssl-bin"
if test -z "$MINIMAL_GIT"
then
	packages="$packages mingw-w64-$ARCH-git-doc-html ncurses mintty vim
		winpty less gnupg tar diffutils patch dos2unix which subversion
		mingw-w64-$ARCH-tk mingw-w64-$ARCH-connect git-flow docx2txt
		mingw-w64-$ARCH-antiword ssh-pageant mingw-w64-$ARCH-git-lfs"
fi
pacman_list $packages "$@" |

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
if test -n "$WITH_L10N" && test -z "$MINIMAL_GIT"
then
	cat
else
	grep -v \
		-e '^/mingw../share/locale/' \
		-e '^/usr/share/locale/'
fi |
if test -z "$MINIMAL_GIT"
then
	cat
else
	grep -v -e '^/cmd/start-.*$' -e '^/cmd/\(git-gui\|gitk\).exe$' \
		-e '^/etc/\(DIR_COLORS\|inputrc\|vimrc\)$' \
		-e '^/etc/profile\.d/\(aliases\|env\|git-prompt\)\.sh$' \
		-e '^/git-\(bash\|cmd\)\.exe$' \
		-e '^/mingw../bin/\(certtool\.exe\|create-shortcut\.exe\)$' \
		-e '^/mingw../bin/\(curl\.exe\|envsubst\.exe\|gettext\.exe\)$' \
		-e '^/mingw../bin/\(gettext\.sh\|gettextize\|git-cvsserver\)$' \
		-e '^/mingw../bin/\(gitk\|git-upload-archive\.exe\)$' \
		-e '^/mingw../bin/lib\(atomic\|charset\)-.*\.dll$' \
		-e '^/mingw../bin/lib\(gcc_s_seh\|libgmpxx\)-.*\.dll$' \
		-e '^/mingw../bin/lib\(gomp\|jansson\|minizip\)-.*\.dll$' \
		-e '^/mingw../bin/libvtv.*\.dll$' \
		-e '^/mingw../bin/\(.*\.def\|update-ca-trust\)$' \
		-e '^/mingw../bin/\(openssl\|p11tool\|pkcs1-conv\)\.exe$' \
		-e '^/mingw../bin/\(psktool\|recode-.*\|sexp.*\|srp.*\)\.exe$' \
		-e '^/mingw../bin/\(WhoUses\|xmlwf\)\.exe$' \
		-e '^/mingw../etc/pki' -e '^/mingw../lib/p11-kit/' \
		-e '/git-\(add--interactive\|archimport\|citool\|cvs.*\)$' \
		-e '/git-\(difftool.*\|git-gui.*\|instaweb\|p4\|relink\)$' \
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
		-e '^/mingw../bin/curl-winssl/curl\.exe$'
fi | sort |
grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|xterm.*)$)' |
sed 's/^\///'

test -z "$PACKAGE_VERSIONS_FILE" ||
pacman -Q filesystem dash rebase \
	$(test -n "$MINIMAL_GIT" || echo util-linux unzip mingw-w64-$ARCH-xpdf) \
	>>"$PACKAGE_VERSIONS_FILE"

cat <<EOF
etc/profile
etc/profile.d/lang.sh
etc/bash.bash_logout
etc/bash.bashrc
etc/fstab
etc/msystem
etc/nsswitch.conf
mingw$BITNESS/etc/gitconfig
usr/bin/dash.exe
usr/bin/rebase.exe
usr/bin/rebaseall
usr/bin/getopt.exe
mingw$BITNESS/etc/gitattributes
EOF

test -n "$MINIMAL_GIT" || cat <<EOF
etc/post-install/01-devices.post
etc/post-install/03-mtab.post
etc/post-install/06-windows-files.post
usr/bin/start
mingw$BITNESS/bin/pdftotext.exe
mingw$BITNESS/bin/libstdc++-6.dll
usr/bin/column.exe
EOF

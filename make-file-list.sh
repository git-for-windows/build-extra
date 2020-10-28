#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test -n "$ARCH" &&
test -n "$BITNESS" ||
die "Need ARCH and BITNESS to be set"

SH_FOR_REBASE=dash
PACKAGE_EXCLUDES="db info heimdal git util-linux curl git-for-windows-keyring
	mingw-w64-p11-kit"
EXTRA_FILE_EXCLUDES=
UTIL_PACKAGES="sed awk grep findutils coreutils"
if test -n "$MINIMAL_GIT_WITH_BUSYBOX"
then
	PACKAGE_EXCLUDES="$PACKAGE_EXCLUDES bash coreutils mingw-w64-busybox
		libiconv libintl libreadline ncurses openssl
		mingw-w64-libmetalink mingw-w64-spdylay"

	EXTRA_FILE_EXCLUDES="/etc/post-install/.* /usr/bin/getfacl.exe
		/usr/bin/msys-\(gmp\|ssl\)-.*.dll
		/mingw$BITNESS/bin/$ARCH-w64-mingw32-deflatehd.exe
		/mingw$BITNESS/bin/$ARCH-w64-mingw32-inflatehd.exe"

	UTIL_PACKAGES=
	SH_FOR_REBASE=mingw-w64-$ARCH-busybox
	MINIMAL_GIT=1
fi
if test -n "$MINIMAL_GIT"
then
	PACKAGE_EXCLUDES="$PACKAGE_EXCLUDES mingw-w64-bzip2 mingw-w64-c-ares
		mingw-w64-libsystre mingw-w64-libtre-git
		mingw-w64-tcl mingw-w64-tk mingw-w64-wineditline gdbm icu libdb
		libedit libgdbm perl perl-.*"
fi
if test -z "$INCLUDE_GIT_UPDATE"
then
	EXTRA_FILE_EXCLUDES="$EXTRA_FILE_EXCLUDES
		/mingw$BITNESS/libexec/git-core/git-update-git-for-windows"
	GIT_UPDATE_EXTRA_PACKAGES=
else
	GIT_UPDATE_EXTRA_PACKAGES=mingw-w64-$ARCH-wintoast
fi
if test -n "$INCLUDE_TMUX"
then
	UTIL_PACKAGES="$UTIL_PACKAGES tmux libevent"
fi

this_script_dir="$(cd "$(dirname "$0")" && pwd -W)" ||
die "Could not determine this script's dir"

pacman_list () {
	test -n "$MINIMAL_GIT" ||
	cat "$this_script_dir/keep-despite-upgrade.txt" 2>/dev/null |
	if test 64 = "$BITNESS"
	then
		grep -v '^mingw32/'
	else
		grep -v '^mingw64/'
	fi

	package_list=$(for arg
		do
			pactree -u "$arg"
		done |
		grep -v "^\\($(echo $PACKAGE_EXCLUDES | sed \
			-e 's/ /\\|/g' \
			-e 's/mingw-w64-/&\\(i686\\|x86_64\\)-/g')\\)\$" |
		sort |
		uniq) &&

	case "$package_list" in
	*mingw-w64-$ARCH-curl*mingw-w64-$ARCH-zstd*) ;; # okay
	*mingw-w64-$ARCH-curl*)
		# mingw-w64-zstd is a dependency of mingw-w64-curl, but
		# v7.72 of the latter is not listing that dependency
		# (by mistake). Let's make sure that we don't forget
		# about that dependency.
		package_list="$package_list
mingw-w64-$ARCH-zstd"
		;;
	esac &&

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
for req in mingw-w64-$ARCH-git-credential-manager mingw-w64-$ARCH-git-credential-manager-core $SH_FOR_REBASE \
	$(test -n "$MINIMAL_GIT" || echo \
		mingw-w64-$ARCH-connect git-flow unzip docx2txt \
		mingw-w64-$ARCH-antiword mingw-w64-$ARCH-odt2txt \
		mingw-w64-$ARCH-xpdf-tools ssh-pageant mingw-w64-$ARCH-git-lfs \
		tig nano perl-JSON $GIT_UPDATE_EXTRA_PACKAGES)
do
	test -d /var/lib/pacman/local/$req-[0-9]* ||
	test -d /var/lib/pacman/local/$req-git-[0-9]* ||
	required="$required $req"
done
test -z "$required" ||
pacman -Sy --noconfirm $required >&2 ||
die "Could not install required packages: $required"

packages="mingw-w64-$ARCH-git mingw-w64-$ARCH-git-credential-manager mingw-w64-$ARCH-git-credential-manager-core
git-extra openssh $UTIL_PACKAGES"
if test -z "$MINIMAL_GIT"
then
	packages="$packages mingw-w64-$ARCH-git-doc-html ncurses mintty vim nano
		winpty less gnupg tar diffutils patch dos2unix which subversion perl-JSON
		mingw-w64-$ARCH-tk mingw-w64-$ARCH-connect git-flow docx2txt
		mingw-w64-$ARCH-antiword mingw-w64-$ARCH-odt2txt ssh-pageant
		mingw-w64-$ARCH-git-lfs mingw-w64-$ARCH-xz tig $GIT_UPDATE_EXTRA_PACKAGES"
fi
pacman_list $packages "$@" |

grep -v -e '\.[acho]$' -e '\.l[ao]$' -e '/aclocal/' \
	-e '/man/' -e '/pkgconfig/' -e '/emacs/' \
	-e '^/usr/lib/python' -e '^/usr/lib/ruby' \
	-e '^/usr/share/subversion' \
	-e '^/etc/skel/' -e '^/mingw../etc/skel/' \
	-e '^/usr/bin/svn' \
	-e '^/usr/bin/xml.*exe$' \
	-e '^/usr/bin/xslt.*$' \
	-e '^/mingw../bin/.*zstd\.exe$' \
	-e '^/mingw../share/doc/openssl/' \
	-e '^/mingw../share/doc/gettext/' \
	-e '^/mingw../share/doc/lib' \
	-e '^/mingw../share/doc/pcre2\?/' \
	-e '^/mingw../share/doc/git-doc/.*\.txt$' \
	-e '^/mingw../share/doc/zstd/' \
	-e '^/mingw../lib/gettext/' -e '^/mingw../share/gettext/' \
	-e '^/usr/include/' -e '^/mingw../include/' \
	-e '^/usr/share/doc/' \
	-e '^/usr/share/info/' -e '^/mingw../share/info/' \
	-e '^/mingw../share/git-doc/technical/' \
	-e '^/mingw../lib/cmake/' \
	-e '^/mingw../itcl/' \
	-e '^/mingw../t\(cl\|k\)[^/]*/\(demos\|msgs\|encoding\|tzdata\)/' \
	-e '^/mingw../bin/\(autopoint\|[a-z]*-config\)$' \
	-e '^/mingw../bin/lib\(asprintf\|brotlienc\|gettext\|gnutls\|gnutlsxx\|gmpxx\|pcre[013-9a-oq-z]\|pcre2-[13p]\|quadmath\|stdc++\|zip\)[^/]*\.dll$' \
	-e '^/mingw../bin/lib\(atomic\|charset\|ffi\|gomp\|systre\|tasn1\)-[0-9]*\.dll$' \
	-e '^/mingw../bin/\(asn1\|gnutls\|idn\|mini\|msg\|nettle\|ngettext\|ocsp\|pcre\|rtmp\|xgettext\)[^/]*\.exe$' \
	-e '^/mingw../bin/recode-sr-latin.exe$' \
	-e '^/mingw../bin/\(cert\|p11\|psk\|srp\)tool.exe$' \
	-e '^/mingw../.*/git-\(remote-testsvn\|shell\)\.exe$' \
	-e '^/mingw../.*/git-cvsserver.*$' \
	-e '^/mingw../.*/gitweb/' \
	-e '^/mingw../lib/\(dde\|itcl\|sqlite\|tdbc\)' \
	-e '^/mingw../libexec/git-core/git-archimport$' \
	-e '^/mingw../share/doc/git-doc/git-archimport' \
	-e '^/mingw../libexec/git-core/git-cvsimport$' \
	-e '^/mingw../share/doc/git-doc/git-cvsexport' \
	-e '^/mingw../libexec/git-core/git-cvsexport' \
	-e '^/mingw../share/doc/git-doc/git-cvsimport' \
	-e '^/mingw../share/git\(k\|-gui\)/lib/msgs/' \
	-e '^/mingw../share/nghttp2/' \
	-e '^/usr/bin/msys-\(db\|curl\|icu\|gfortran\|stdc++\|quadmath\)[^/]*\.dll$' \
	-e '^/usr/bin/msys-\('$(if test i686 = "$ARCH"
	    then
		echo 'uuid\|'
	    else
		echo 'lzma\|'
	    fi)'fdisk\|gettextpo\|gmpxx\|gnutlsxx\|gomp\|xml2\|xslt\|exslt\)-.*\.dll$' \
	-e '^/usr/bin/msys-\(hdb\|history8\|kadm5\|kdc\|otp\|sl\).*\.dll$' \
	-e '^/usr/bin/msys-\(atomic\|blkid\|charset\|gthread\|metalink\|nghttp2\|pcre2-8\|ssh2\)-.*\.dll$' \
	-e '^/usr/bin/msys-\(ncurses++w6\|asprintf-[0-9]*\|\)\.dll$' \
	-e '^/usr/bin/msys-\(formw6\|menuw6\|panelw6\)\.dll$' \
	-e '^/usr/bin/msys-svn_swig_\(py\|ruby\)-.*\.dll$' \
	-e '^/usr/bin/\(dumper\|sasl.*\)\.exe$' \
	-e '^/usr/lib/gio/' -e '^/usr/lib/sasl2/msys-sasldb-.*\.dll$' \
	-e '^/usr/lib/\(itcl\|tdbc\|pkcs11/p11-kit-client\|thread\)' \
	-e '^/usr/share.*/magic$' \
	-e '^/usr/share/perl5/core_perl/Unicode/' \
	-e '^/usr/share/perl5/core_perl/pods/' \
	-e '^/usr/share/perl5/core_perl/Locale/' \
	-e '^/usr/share/perl5/core_perl/Pod/' \
	-e '^/usr/share/perl5/core_perl/ExtUtils/' \
	-e '^/usr/share/perl5/core_perl/CPAN/' \
	-e '^/usr/share/perl5/core_perl/TAP/' \
	-e '^/usr/share/vim/vim74/lang/' \
	-e '^/update-via-pacman.bat$' \
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
		-e '^/mingw../bin/.*-\(inflate\|deflate\)hd\.exe$' \
		-e '^/mingw../bin/\(gettext\.sh\|gettextize\)$' \
		-e '^/mingw../bin/\(gitk\|git-upload-archive\.exe\)$' \
		-e '^/mingw../bin/libgcc_s_seh-.*\.dll$' \
		-e '^/mingw../bin/libjemalloc\.dll$' \
		-e '^/mingw../bin/lib\(gmp\|gomp\|jansson\|metalink\|minizip\)-.*\.dll$' \
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
		-e '^/usr/bin/\(csplit\|cygcheck\|cygpath\)\.exe$' \
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
		-e '^/usr/bin/msys-\(cilkrts\|kafs\|ssl\)-.*\.dll$' \
		-e '^/usr/bin/msys-sqlite3[a-z].*\.dll$' \
		-e '^/usr/bin/msys-\(gomp.*\|vtv.*\)-.*\.dll$' \
		-e '^/usr/lib/\(awk\|coreutils\|gawk\|openssl\|pkcs11\|ssh\)/' \
		-e '^/usr/libexec/\(bigram\|code\|frcode\)\.exe$' \
		-e '^/usr/share/\(cygwin\|git\)/' \
		-e '^/usr/ssl/misc/' \
		-e '^/usr/bin/\(captoinfo\|clear\|infocmp\|infotocap\)\.exe$' \
		-e '^/usr/bin/\(reset\|tabs\|tic\|toe\|tput\|tset\)\.exe$' \
		-e '^/usr/bin/msys-ticw6\.dll$' \
		-e '^/usr/\(lib\|share\)/terminfo/' -e '^/usr/share/tabset/' \
		-e "^\\($(echo $EXTRA_FILE_EXCLUDES |
			sed 's/ /\\|/g')\\)\$"
fi |
grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|screen.*|xterm.*)$)' |
sed 's/^\///' | sort | uniq

test -z "$PACKAGE_VERSIONS_FILE" ||
pacman -Q filesystem $SH_FOR_REBASE rebase \
	$(test -n "$MINIMAL_GIT" || echo util-linux unzip \
		mingw-w64-$ARCH-xpdf-tools) \
	>>"$PACKAGE_VERSIONS_FILE"

test -n "$ETC_GITCONFIG" ||
ETC_GITCONFIG=etc/gitconfig

test etc/gitconfig != "$ETC_GITCONFIG" ||
test -f /etc/gitconfig ||
test ! -f /mingw$BITNESS/etc/gitconfig ||
{ mkdir -p /etc && cp /mingw$BITNESS/etc/gitconfig /etc/gitconfig; } ||
die "Could not copy system gitconfig into new location"

test -n "$ETC_GITATTRIBUTES" ||
ETC_GITATTRIBUTES="${ETC_GITCONFIG%/*}/gitattributes"

test etc/gitattributes != "$ETC_GITATTRIBUTES" ||
test -f /etc/gitattributes ||
test ! -f /mingw$BITNESS/etc/gitattributes ||
cp /mingw$BITNESS/etc/gitattributes /etc/gitattributes ||
die "Could not copy system gitattributes into new location"

cat <<EOF
etc/fstab
etc/nsswitch.conf
$ETC_GITATTRIBUTES
usr/bin/rebase.exe
usr/bin/rebaseall
EOF

test -z "$MINIMAL_GIT_WITH_BUSYBOX" ||
echo mingw$BITNESS/bin/busybox.exe

test -n "$MINIMAL_GIT_WITH_BUSYBOX" || cat <<EOF
etc/profile
etc/profile.d/lang.sh
etc/bash.bash_logout
etc/bash.bashrc
etc/msystem
usr/bin/dash.exe
usr/bin/getopt.exe
EOF

test -n "$MINIMAL_GIT" || cat <<EOF
$ETC_GITCONFIG
etc/post-install/01-devices.post
etc/post-install/03-mtab.post
etc/post-install/06-windows-files.post
usr/bin/start
mingw$BITNESS/bin/pdftotext.exe
mingw$BITNESS/bin/libstdc++-6.dll
usr/bin/column.exe
EOF

test -z "$INCLUDE_TMUX" || cat <<EOF
usr/bin/tmux.exe
$(ldd /usr/bin/tmux.exe | sed -n 's/.*> \/\(.*msys-event[^ ]*\).*/\1/p')
EOF

#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test -n "$ARCH" ||
die "Need ARCH to be set"

case "$ARCH" in
x86_64)
	MSYSTEM_LOWER=mingw64
	PACMAN_ARCH=x86_64
	;;
i686)
	MSYSTEM_LOWER=mingw32
	PACMAN_ARCH=i686
	;;
aarch64)
	MSYSTEM_LOWER=clangarm64
	PACMAN_ARCH=clang-aarch64
	;;
*)
	die "Architecture ${ARCH} not supported"
	;;
esac

SH_FOR_REBASE=dash
PACKAGE_EXCLUDES="db info heimdal tcl git util-linux curl git-for-windows-keyring
	mingw-w64-p11-kit"
EXTRA_FILE_EXCLUDES=
UTIL_PACKAGES="sed awk grep findutils coreutils"
if test -n "$MINIMAL_GIT_WITH_BUSYBOX"
then
	PACKAGE_EXCLUDES="$PACKAGE_EXCLUDES bash sh coreutils mingw-w64-busybox
		libiconv libintl libreadline ncurses openssl
		mingw-w64-libmetalink mingw-w64-spdylay diffutils"

	EXTRA_FILE_EXCLUDES="/etc/post-install/.* /usr/bin/getfacl.exe
		/usr/bin/msys-\(gmp\|ssl\)-.*.dll
		/$MSYSTEM_LOWER/bin/$ARCH-w64-mingw32-deflatehd.exe
		/$MSYSTEM_LOWER/bin/$ARCH-w64-mingw32-inflatehd.exe"

	UTIL_PACKAGES=
	SH_FOR_REBASE=mingw-w64-$PACMAN_ARCH-busybox
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
		/$MSYSTEM_LOWER/libexec/git-core/git-update-git-for-windows"
	GIT_UPDATE_EXTRA_PACKAGES=
else
	GIT_UPDATE_EXTRA_PACKAGES=mingw-w64-$PACMAN_ARCH-wintoast
fi
if test -n "$INCLUDE_TMUX"
then
	UTIL_PACKAGES="$UTIL_PACKAGES tmux libevent"
fi

# It is totally okay to exclude built-in commands, e.g. via
# `make -C /usr/src/git SKIP_DASHED_BUILT_INS=YesPlease install`
EXCLUDE_MISSING_BUILTINS=
if test -f "/$MSYSTEM_LOWER/share/git/builtins.txt"
then
	BUILTINS_ON_RECORD="$(sed "s|^|/$MSYSTEM_LOWER/libexec/git-core/|" <"/$MSYSTEM_LOWER/share/git/builtins.txt" | sort)" &&
	BUILTINS_ON_DISK="$(find "/$MSYSTEM_LOWER/libexec/git-core" -name git-\*.exe | sort)" &&
	# emulate `comm -23 <(...<on-disk>...) <(...<on-record>...)`,
	# i.e. list the entries that are on record but not on disk,
	# because `dash` does not understand the `<(...)` syntax.
	EXCLUDE_MISSING_BUILTINS="$(printf '%s\n' "$BUILTINS_ON_RECORD" "$BUILTINS_ON_DISK" "$BUILTINS_ON_DISK" |
		sort | uniq -u)" ||
	die "Could not exclude missing dashed versions of the built-in commands"
fi

# Newer `git.exe` no longer link to `libssp-0.dll` that has been made obsolete
# by recent GCC updates
EXCLUDE_LIBSSP=
test ! -f "/$MSYSTEM_LOWER/bin/git.exe" ||
grep -q libssp "/$MSYSTEM_LOWER/bin/git.exe" ||
EXCLUDE_LIBSSP='\|ssp'

this_script_dir="$(cd "$(dirname "$0")" && pwd -W)" ||
die "Could not determine this script's dir"

pacman_stderr="/tmp/pacman-stderr.$$.txt"
trap "rm \"$pacman_stderr\"" EXIT

pacman_list () {
	test -n "$MINIMAL_GIT" ||
	cat "$this_script_dir/keep-despite-upgrade.txt" 2>/dev/null |
	if test "x86_64" = "$ARCH"
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
			-e 's/mingw-w64-/&\\(i686\\|x86_64\\|clang-aarch64\\)-/g')\\)\$" |
		sort |
		uniq) &&

	case "$package_list" in
	*mingw-w64-$PACMAN_ARCH-curl*mingw-w64-$PACMAN_ARCH-zstd*) ;; # okay
	*mingw-w64-$PACMAN_ARCH-curl*)
		# mingw-w64-zstd is a dependency of mingw-w64-curl, but
		# v7.72 of the latter is not listing that dependency
		# (by mistake). Let's make sure that we don't forget
		# about that dependency.
		package_list="$package_list
mingw-w64-$PACMAN_ARCH-zstd"
		;;
	esac &&

	if test -n "$PACKAGE_VERSIONS_FILE"
	then
		pacman -Q $package_list >"$PACKAGE_VERSIONS_FILE" 2>"$pacman_stderr"
		res=$?
		grep -v 'database file for .* does not exist' <"$pacman_stderr" >&2
		test $res = 0
	fi &&
	pacman -Ql $package_list 2>"$pacman_stderr" |
	grep -v '/$' |
	sed 's/^[^ ]* //'
	res=$?

	grep -v 'database file for .* does not exist' <"$pacman_stderr" >&2
	return $res
}

has_pacman_package () {
	for dir in /var/lib/pacman/local/$1-[0-9]*
	do
		# Be careful in case a package name contains `-<digit>`
		test /var/lib/pacman/local/$1 = ${dir%-*-*} &&
		return 0
	done
	return 1
}

has_pacman_package mingw-w64-$PACMAN_ARCH-curl-winssl &&
LIBCURL_EXTRA=mingw-w64-$PACMAN_ARCH-curl-openssl-alternate ||
LIBCURL_EXTRA=

# Packages that have been added after Git SDK 1.0.0 was released...
required=
for req in mingw-w64-$PACMAN_ARCH-git-credential-manager $SH_FOR_REBASE $LIBCURL_EXTRA \
	$(test -n "$MINIMAL_GIT" || echo \
		mingw-w64-$PACMAN_ARCH-connect git-flow unzip docx2txt \
		mingw-w64-$PACMAN_ARCH-antiword mingw-w64-$PACMAN_ARCH-odt2txt \
		mingw-w64-$PACMAN_ARCH-xpdf-tools ssh-pageant mingw-w64-$PACMAN_ARCH-git-lfs \
		tig nano perl-JSON libpcre2_8 libpcre2posix $GIT_UPDATE_EXTRA_PACKAGES)
do
	has_pacman_package $req ||
	has_pacman_package $req-git ||
	required="$required $req"
done
test -z "$required" || {
	pacman -Sy --noconfirm $required 2>"$pacman_stderr" >&2 || {
		cat "$pacman_stderr" >&2
		die "Could not install required packages: $required"
	}
	grep -v 'database file for .* does not exist' <"$pacman_stderr" >&2
}

packages="mingw-w64-$PACMAN_ARCH-git mingw-w64-$PACMAN_ARCH-git-credential-manager
mingw-w64-$PACMAN_ARCH-git-extra openssh $UTIL_PACKAGES $LIBCURL_EXTRA"
if test -z "$MINIMAL_GIT"
then
	packages="$packages mingw-w64-$PACMAN_ARCH-git-doc-html ncurses mintty vim nano
		winpty less gnupg tar diffutils patch dos2unix which subversion perl-JSON
		mingw-w64-$PACMAN_ARCH-tk mingw-w64-$PACMAN_ARCH-connect git-flow docx2txt
		mingw-w64-$PACMAN_ARCH-antiword mingw-w64-$PACMAN_ARCH-odt2txt ssh-pageant
		mingw-w64-$PACMAN_ARCH-git-lfs mingw-w64-$PACMAN_ARCH-xz tig $GIT_UPDATE_EXTRA_PACKAGES"
fi
pacman_list $packages "$@" |

grep -v -e '\.[acho]$' -e '\.l[ao]$' -e '/aclocal/' \
	-e '/man/' -e '/pkgconfig/' -e '/emacs/' \
	-e '^/usr/lib/python' -e '^/usr/lib/ruby' -e '^/\(mingw\|clang\)[^/]*/lib/python' \
	-e '^/usr/share/subversion' \
	-e '^/etc/skel/' -e '^/\(mingw\|clang\)[^/]*/etc/skel/' \
	-e '^/usr/bin/svn' \
	-e '^/usr/bin/xml.*exe$' \
	-e '^/usr/bin/xslt.*$' \
	-e '^/usr/bin/b*zmore$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/.*zstd\.exe$' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/openssl/' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/gettext/' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/lib' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/pcre2\?/' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/git-doc/.*\.txt$' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/zstd/' \
	-e '^/\(mingw\|clang\)[^/]*/lib/gettext/' -e '^/\(mingw\|clang\)[^/]*/share/gettext/' \
	-e '^/usr/include/' -e '^/\(mingw\|clang\)[^/]*/include/' \
	-e '^/usr/share/doc/' \
	-e '^/usr/share/info/' -e '^/\(mingw\|clang\)[^/]*/share/info/' \
	-e '^/mingw32/bin/lib\(ffi\|tasn1\)-.*\.dll$' \
	-e '^/\(mingw\|clang\)[^/]*/share/git-doc/technical/' \
	-e '^/\(mingw\|clang\)[^/]*/lib/cmake/' \
	-e '^/\(mingw\|clang\)[^/]*/itcl/' \
	-e '^/\(mingw\|clang\)[^/]*/t\(cl\|k\)[^/]*/\(demos\|msgs\|encoding\|tzdata\)/' \
	-e '^/\(mingw\|clang\)[^/]*/bin/\(autopoint\|[a-z]*-config\)$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/lib\(asprintf\|gettext\|gnutls\|gnutlsxx\|gmpxx\|pcre[013-9a-oq-z]\|pcre2-[13p]\|quadmath\|stdc++\|zip\)[^/]*\.dll$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/lib\(atomic\|charset\|gomp\|systre'"$EXCLUDE_LIBSSP"'\)-[0-9]*\.dll$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/\(asn1\|gnutls\|idn\|mini\|msg\|nettle\|ngettext\|ocsp\|pcre\|rtmp\|xgettext\|zip\)[^/]*\.exe$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/recode-sr-latin.exe$' \
	-e '^/\(mingw\|clang\)[^/]*/bin/\(cert\|p11\|psk\|srp\)tool.exe$' \
	-e '^/\(mingw\|clang\)[^/]*/.*/git-\(remote-testsvn\|shell\)\.exe$' \
	-e '^/\(mingw\|clang\)[^/]*/.*/git-cvsserver.*$' \
	-e '^/\(mingw\|clang\)[^/]*/.*/gitweb/' \
	-e '^/\(mingw\|clang\)[^/]*/lib/\(dde\|itcl\|sqlite\|tdbc\)' \
	-e '^/\(mingw\|clang\)[^/]*/libexec/git-core/git-archimport$' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/git-doc/git-archimport' \
	-e '^/\(mingw\|clang\)[^/]*/libexec/git-core/git-cvsimport$' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/git-doc/git-cvsexport' \
	-e '^/\(mingw\|clang\)[^/]*/libexec/git-core/git-cvsexport' \
	-e '^/\(mingw\|clang\)[^/]*/share/doc/git-doc/git-cvsimport' \
	-e "^\\($(echo $EXCLUDE_MISSING_BUILTINS | sed 's/ /\\|/g')\\)\$" \
	-e '^/\(mingw\|clang\)[^/]*/share/gtk-doc/' \
	-e '^/\(mingw\|clang\)[^/]*/share/nghttp2/' \
	-e '^/usr/bin/msys-\(db\|curl\|icu\|gfortran\|stdc++\|quadmath\)[^/]*\.dll$' \
	-e '^/usr/bin/msys-\('$(if test i686 = "$ARCH"
	    then
		echo 'uuid\|lzma\|'
	    fi)'fdisk\|gettextpo\|gmpxx\|gnutlsxx\|gomp\|xml2\|xslt\|exslt\)-.*\.dll$' \
	-e '^/usr/bin/msys-\(hdb\|history8\|kadm5\|kdc\|otp\|sl\).*\.dll$' \
	-e '^/usr/bin/msys-\(atomic\|blkid\|charset\|gthread\|metalink\|nghttp2\|ssh2\)-.*\.dll$' \
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
	-e '^/usr/share/\(bash-completion\|makepkg\)/' \
	-e '^/update-via-pacman.bat$' \
	-e '^/etc/profile.d/git-sdk.sh$' |
if test -n "$WITH_L10N" && test -z "$MINIMAL_GIT"
then
	cat
else
	grep -v \
		-e '^/\(mingw\|clang\)[^/]*/share/locale/' \
		-e '^/\(mingw\|clang\)[^/]*/share/git\(k\|-gui\)/lib/msgs/' \
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
		-e '^/\(mingw\|clang\)[^/]*/bin/\(certtool\.exe\|create-shortcut\.exe\)$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(curl\.exe\|envsubst\.exe\|gettext\.exe\)$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/.*-\(inflate\|deflate\)hd\.exe$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(gettext\.sh\|gettextize\)$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(gitk\|git-upload-archive\.exe\)$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/libgcc_s_seh-.*\.dll$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/libjemalloc\.dll$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/lib\(ffi\|gmp\|gomp\|jansson\|metalink\|minizip\|tasn1\)-.*\.dll$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/libvtv.*\.dll$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/libpcreposix.*\.dll$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(.*\.def\|update-ca-trust\)$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(openssl\|p11tool\|pkcs1-conv\)\.exe$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(psktool\|recode-.*\|sexp.*\|srp.*\)\.exe$' \
		-e '^/\(mingw\|clang\)[^/]*/bin/\(WhoUses\|xmlwf\)\.exe$' \
		-e '^/\(mingw\|clang\)[^/]*/etc/pki' -e '^/\(mingw\|clang\)[^/]*/lib/p11-kit/' \
		-e '/git-\(add--interactive\|archimport\|citool\|cvs.*\)$' \
		-e '/git-\(gui.*\|instaweb\|p4\|relink\)$' \
		-e '/git-\(send-email\|svn\)$' \
		-e '/\(mingw\|clang\)[^/]*/libexec/git-core/git-\(imap-send\|daemon\)\.exe$' \
		-e '/\(mingw\|clang\)[^/]*/libexec/git-core/git-remote-ftp.*\.exe$' \
		-e '/\(mingw\|clang\)[^/]*/libexec/git-core/git-http-backend\.exe$' \
		-e "/\(mingw\|clang\)[^/]*/libexec/git-core/git-\\($(sed \
			-e 's/^git-//' -e 's/\.exe$//' -e 's/$/\\/' \
				</$MSYSTEM_LOWER/share/git/builtins.txt |
			tr '\n' '|')\\)\\.exe\$" \
		-e '^/\(mingw\|clang\)[^/]*/share/doc/nghttp2/' \
		-e '^/\(mingw\|clang\)[^/]*/share/gettext-' \
		-e '^/\(mingw\|clang\)[^/]*/share/git/\(builtins\|compat\|completion\)' \
		-e '^/\(mingw\|clang\)[^/]*/share/git/.*\.ico$' \
		-e '^/\(mingw\|clang\)[^/]*/share/\(git-gui\|gitweb\)/' \
		-e '^/\(mingw\|clang\)[^/]*/share/perl' \
		-e '^/\(mingw\|clang\)[^/]*/share/pki/' \
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
		-e '^/usr/lib/\(awk\|coreutils\|gawk\|openssl\|pkcs11\)/' \
		-e '^/usr/lib/ssh/\(sftp\|sshd\($\|-\)\)' \
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
LC_CTYPE=C.UTF-8 grep --perl-regexp -v -e '^/usr/(lib|share)/terminfo/(?!.*/(cygwin|dumb|ms-terminal|screen.*|xterm.*)$)' |
sed 's/^\///' | sort | uniq

test -z "$PACKAGE_VERSIONS_FILE" || {
	pacman -Q filesystem $SH_FOR_REBASE rebase \
		$(test -n "$MINIMAL_GIT" || echo util-linux unzip \
			mingw-w64-$PACMAN_ARCH-xpdf-tools) \
		>>"$PACKAGE_VERSIONS_FILE" 2>"$pacman_stderr" || {
		cat "$pacman_stderr" >&2
		die "Could not generate '$PACKAGE_VERSIONS_FILE'"
	}
	grep -v 'database file for .* does not exist' <"$pacman_stderr" >&2
}

test -n "$ETC_GITCONFIG" ||
ETC_GITCONFIG=etc/gitconfig

test etc/gitconfig != "$ETC_GITCONFIG" ||
test -f /etc/gitconfig ||
test ! -f /$MSYSTEM_LOWER/etc/gitconfig ||
{ mkdir -p /etc && cp /$MSYSTEM_LOWER/etc/gitconfig /etc/gitconfig; } ||
die "Could not copy system gitconfig into new location"

test -n "$ETC_GITATTRIBUTES" ||
ETC_GITATTRIBUTES="${ETC_GITCONFIG%/*}/gitattributes"

test etc/gitattributes != "$ETC_GITATTRIBUTES" ||
test -f /etc/gitattributes ||
test ! -f /$MSYSTEM_LOWER/etc/gitattributes ||
cp /$MSYSTEM_LOWER/etc/gitattributes /etc/gitattributes ||
die "Could not copy system gitattributes into new location"

cat <<EOF
etc/fstab
etc/nsswitch.conf
$ETC_GITATTRIBUTES
usr/bin/rebase.exe
usr/bin/rebaseall
EOF

test -z "$MINIMAL_GIT_WITH_BUSYBOX" ||
echo $MSYSTEM_LOWER/bin/busybox.exe

test -n "$MINIMAL_GIT_WITH_BUSYBOX" || cat <<EOF
etc/profile
etc/profile.d/lang.sh
etc/bash.bash_logout
etc/bash.bashrc
etc/msystem
usr/bin/dash.exe
usr/bin/getopt.exe
EOF

case $MSYSTEM_LOWER in
mingw*)
	PDFTOTEXT_FILES="$MSYSTEM_LOWER/bin/pdftotext.exe
$MSYSTEM_LOWER/bin/libstdc++-6.dll"
	;;
*)
	# In the clang version, we do not need the libstdc++ DLL
	PDFTOTEXT_FILES="$MSYSTEM_LOWER/bin/pdftotext.exe"
	;;
esac

test -n "$MINIMAL_GIT" || cat <<EOF
$ETC_GITCONFIG
etc/post-install/01-devices.post
etc/post-install/03-mtab.post
etc/post-install/06-windows-files.post
usr/bin/start
$PDFTOTEXT_FILES
usr/bin/column.exe
EOF

test -z "$INCLUDE_TMUX" || cat <<EOF
usr/bin/tmux.exe
$(ldd /usr/bin/tmux.exe | sed -n 's/.*> \/\(.*msys-event[^ ]*\).*/\1/p')
EOF

test -z "$INCLUDE_OBJDUMP" || echo usr/bin/objdump.exe

#!/bin/sh

# This script is meant to help maintain Git for Windows. It automates large
# parts of the release engineering.
#
# Most of these functions are called from automation, i.e. from Azure Pipelines
# and from GitHub workflows

# Note: functions whose arguments are documented on the function name's own
# line are actually subcommands, and running this script without any argument
# will list all subcommands.

die () {
	printf "$@" >&2
	exit 1
}

# Never allow the SDKs to change directory to $HOME
export CHERE_INVOKING=1

# Never allow ORIGINAL_PATH to mess up our PATH
unset ORIGINAL_PATH

# Do not follow MSYS2's switch to zstd, at least for now
PKGEXT='.pkg.tar.xz'
export PKGEXT
SRCEXT='.src.tar.gz'
export SRCEXT

# In MinGit, there is no `cygpath`...
# We really only use -w, -am and -au in please.sh, so that's what we
# support here

cygpath () { # [<short-options>] <path>
	test $# = 2 ||
	die "This minimal cygpath drop-in cannot handle '%s'\n" "$*"

	case "$1" in
	-w)
		case "$2" in
		/[a-zA-Z]/*)
			echo "$2" |
			sed -e 's|^/\(.\)\(.*\)|\u\1:\2|' -e 's|/|\\|g'
			;;
		[a-zA-Z]:[\\/]*)
			echo "$2" |
			sed -e 's|^\(.\)|\u\1|' -e 's|/|\\|g'
			;;
		/*)
			echo "$(cd / && pwd -W)$2" |
			sed -e 's|/|\\|g'
			;;
		*)
			echo "$2" |
			sed -e 's|/|\\|g'
			;;
		esac
		;;
	-am)
		case "$2" in
		/[a-zA-Z]/*)
			echo "$2" |
			sed -e 's|^/\(.\)\(.*\)|\u\1:\2|' -e 's|\\|/|g'
			;;
		[a-zA-Z]:[\\/]*)
			echo "$2" |
			sed -e 's|^\(.\)|\u\1|' -e 's|\\|/|g'
			;;
		/*)
			echo "$(cd / && pwd -W)$2" |
			sed -e 's|\\|/|g'
			;;
		*)
			echo "$(pwd -W)/$2" |
			sed -e 's|\\|/|g' -e 's|//*|/|g'
			;;
		esac
		;;
	-au)
		case "$2" in
		/[a-zA-Z]/*)
			echo "$2" |
			sed -e 's|^/\(.\)\(.*\)|/\l\1\2|' -e 's|\\|/|g'
			;;
		[a-zA-Z]:[\\/]*)
			echo "$2" |
			sed -e 's|^\(.\):|/\l\1|' -e 's|\\|/|g'
			;;
		/*)
			echo "$2" |
			sed -e 's|\\|/|g'
			;;
		*)
			echo "$(pwd)/$2" |
			sed -e 's|\\|/|g' -e 's|//*|/|g'
			;;
		esac
		;;
	*)
		die "Unhandled cygpath option: '%s'\n" "$1"
		;;
	esac
}

sdk_path () { # <bitness>
	result="$(git config windows.sdk"$1".path)" || {
		result="C:/git-sdk-$1" && test -e "$result" ||
		die "%s\n\n\t%s\n%s\n" \
			"No $1-bit Git for Windows SDK found at location:" \
			"C:/git-sdk-$1" \
			"Config variable to override: windows.sdk$1.path"
	}

	echo "$result"
}

sdk64="$(sdk_path 64)"
sdk32="$(sdk_path 32)"

in_use () { # <sdk> <path>
	test -n "$(case "$1" in
		"$sdk32") "$1/mingw32/bin/WhoUses.exe" -m "$1$2";;
		*) "$1/mingw64/bin/WhoUses.exe" -m "$1$2";;
		esac | grep '^[^-P]')"
}

# require_not_in_use <sdk> <path>
require_not_in_use () {
	! in_use "$@" ||
	die "%s: in use\n" "$1/$2"
}

independent_shell=
is_independent_shell () { #
	test -n "$independent_shell" || {
		normalized64="$(cygpath -w "$sdk64")"
		normalized32="$(cygpath -w "$sdk32")"
		case "$(cygpath -w "$(which sh.exe)")" in
		"$normalized64\\"*|"$normalized32\\"*)
			independent_shell=f
			;;
		*)
			independent_shell=t
			;;
		esac
	}
	test t = "$independent_shell"
}

prepare_keep_despite_upgrade () { # <sdk-path>
	keep_despite_upgrade="$(cat "${this_script_path%/*}/keep-despite-upgrade.txt")" ||
	die 'Could not read keep-despite-upgrade.txt\n'

	case "$keep_despite_upgrade" in *' '*) die 'keep-despite-upgrade.txt contains spaces!\n';; esac

	test "$sdk64" = "$1" ||
	keep_despite_upgrade="$(echo "$keep_despite_upgrade" | sed '/^mingw64/d')"

	rm -rf "$1/.keep" &&
	{ test -n "$keep_despite_upgrade" || return 0; } &&
	mkdir -p "$1/.keep" &&
	for f in $keep_despite_upgrade
	do
		d=${f%/*}
		test $d = $f ||
		mkdir -p "$1/.keep/$d"
		cp "$1/$f" "$1/.keep/$d/" ||
		break
	done
}

process_keep_despite_upgrade () { # [--keep] <sdk-path>
	test --keep != "$1" || {
		test -d "$2/.keep" || return 0
		cp -Ru "$2/.keep/"* "$2/"
		return $?
	}

	test -d "$1/.keep" || return 0
	cp -Ru "$1/.keep/"* "$1/" &&
	rm -rf "$1/.keep"
}

mount_sdks () { #
	test -d /sdk32 || mount "$sdk32" /sdk32
	test -d /sdk64 || mount "$sdk64" /sdk64
}

# set_package <package>
set_package () {
	package="$1"
	extra_packages=
	extra_makepkg_opts=
	case "$package" in
	git-extra|mingw-w64-git-extra)
		package=mingw-w64-git-extra
		type=MINGW
		# This will need to be replaced with mingw-w64-git-extra once the folder has been renamed
		pkgpath=/usr/src/build-extra/git-extra
		;;
	git-for-windows-keyring)
		type=MSYS
		pkgpath=/usr/src/build-extra/$package
		;;
	git)
		package=mingw-w64-git
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man mingw-w64-git-test-artifacts mingw-w64-git-pdb"
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-git)
		type=MINGW
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man mingw-w64-git-test-artifacts mingw-w64-git-pdb"
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-git-credential-manager)
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-git-credential-manager
		;;
	gcm|credential-manager|git-credential-manager)
		package=mingw-w64-git-credential-manager
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-git-credential-manager
		;;
	lfs|git-lfs|mingw-w64-git-lfs)
		package=mingw-w64-git-lfs
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-git-lfs
		;;
	git-sizer|mingw-w64-git-sizer)
		package=mingw-w64-git-sizer
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-git-sizer
		;;
	cv2pdb|mingw-w64-cv2pdb)
		package=mingw-w64-cv2pdb
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-cv2pdb
		;;
	pcre2|mingw-w64-pcre2)
		package=mingw-w64-pcre2
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/mingw-w64-pcre2
		;;
	busybox|mingw-w64-busybox)
		package=mingw-w64-busybox
		type=MINGW
		extra_packages="mingw-w64-busybox-pdb"
		pkgpath=/usr/src/MINGW-packages/mingw-w64-busybox
		;;
	msys2-runtime)
		type=MSYS
		extra_packages="msys2-runtime-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	mintty)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	w3m)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	openssh)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	openssl)
		type=MSYS
		extra_packages="libopenssl openssl-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		extra_makepkg_opts=--nocheck
		;;
	mingw-w64-openssl)
		type=MINGW
		extra_packages="mingw-w64-openssl-pdb"
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	gnutls)
		type=MSYS
		extra_packages="libgnutls libgnutls-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	mingw-w64-gnutls)
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	curl)
		type=MSYS
		extra_packages="libcurl libcurl-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	mingw-w64-curl)
		type=MINGW
		extra_packages="mingw-w64-curl-pdb"
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	git-flow)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	p7zip)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	mingw-w64-asciidoctor-extensions)
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	wintoast|mingw-w64-wintoast)
		package=mingw-w64-wintoast
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-wintoast
		;;
	bash)
		type=MSYS
		extra_packages="$package-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	heimdal)
		type=MSYS
		extra_packages="$package-libs $package-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	perl)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		extra_makepkg_opts=--nocheck
		;;
	perl-Net-SSLeay|perl-HTML-Parser|perl-TermReadKey|perl-Locale-Gettext|perl-XML-Parser|perl-YAML-Syck|perl-Clone)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	tig)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	subversion)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	gawk)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		extra_makepkg_opts=--nocheck
		;;
	nodejs|mingw-w64-nodejs)
		package=mingw-w64-nodejs
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/mingw-w64-nodejs
		extra_makepkg_opts=--nocheck
		;;
	xpdf|xpdf-tools|mingw-w64-xpdf-tools)
		package=mingw-w64-xpdf-tools
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/mingw-w64-xpdf
		;;
	serf)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	pkgconf)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	libgpg-error)
		type=MSYS
		extra_packages="libgpg-error-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	libgcrypt)
		type=MSYS
		extra_packages="libgcrypt-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	gnupg)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	libcbor)
		type=MSYS
		extra_packages="$package-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	libfido2)
		type=MSYS
		extra_packages="$package-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	*)
		die "Unknown package: %s\n" "$package"
		;;
	esac
}

require_clean_worktree () {
	git update-index --ignore-submodules --refresh &&
	git diff-files --ignore-submodules &&
	git diff-index --cached --ignore-submodules HEAD ||
	die "%s not up-to-date\n" "$sdk$pkgpath"
}

ff_main_branch () {
	case "$(git rev-parse --symbolic-full-name HEAD)" in
	refs/heads/main) ;; # okay
	refs/heads/master)
		git branch -m main ||
		die "%s: could not rename the main branch\n" "$sdk$pkgpath"
		;;
	*)
		die "%s: Not on 'main'\n" "$sdk$pkgpath"
		;;
	esac

	require_clean_worktree

	git pull --ff-only origin HEAD ||
	test 0 -eq $(git rev-list --count ..FETCH_HEAD) ||
	die "%s: cannot fast-forward main branch\n" "$sdk$pkgpath"
}

# require <metapackage> <telltale>
require () {
	test -d "$sdk"/var/lib/pacman/local/"${2:-$1}"-[0-9]* ||
	"$sdk"/git-cmd.exe --command=usr\\bin\\pacman.exe \
		-Sy --needed --noconfirm "$1" ||
	die "Could not install %s\n" "$1"
}

install_git_32bit_prereqs () {
	require mingw-w64-i686-asciidoctor-extensions
}

pkg_build () {
	require_clean_worktree

	test "a$sdk" = "a$sdk32" &&
	arch=i686 ||
	arch=x86_64

	# Git for Windows' packages are only visible to the SDK of the
	# matching architecture. However, we want to build Git for both
	# 32-bit and 64-bit in the 64-bit SDK at the same time, therefore
	# we need even the prerequisite asciidoctor-extensions for 32-bit.
	# Let's just steal it from the 32-bit SDK
	test mingw-w64-git != $package ||
	test x86_64 != $arch ||
	install_git_32bit_prereqs

	case "$type" in
	MINGW)
		require mingw-w64-toolchain mingw-w64-$arch-make

		if test mingw-w64-git = "$package"
		then
			tag="$(git --git-dir=src/git/.git for-each-ref \
				--format='%(refname:short)' --sort=-taggerdate \
				--count=1 'refs/tags/*.windows.*')" &&
			test -n "$tag" ||
			die "Could not determine latest tag\n"

			sed -i "s/^\(tag=\).*/\1${tag#v}/" PKGBUILD ||
			die "Could not edit tag\n"
		fi

		if test -z "$(git --git-dir="$sdk64/usr/src/build-extra/.git" \
			config alias.signtool)"
		then
			extra=
		else
			extra="SIGNTOOL=\"git --git-dir=\\\"$sdk64/usr/src"
			extra="$extra/build-extra/.git\\\" signtool\" "
		fi
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'MAKEFLAGS=-j5 MINGW_ARCH=mingw32\ mingw64 \
				'"$extra"'makepkg-mingw -s --noconfirm \
					'"$extra_makepkg_opts"' &&
			 if test mingw-w64-git = "'"$package"'"
			 then
				git -C src/git push "$PWD/git" \
					refs/tags/"'"$tag"'"
			 fi &&
			 MINGW_ARCH=mingw64 makepkg-mingw --allsource \
				'"$extra_makepkg_opts" ||
		die "%s: could not build\n" "$sdk$pkgpath"

		git update-index -q --refresh &&
		git diff-files --quiet --ignore-submodules PKGBUILD ||
		git commit -s -m "$package: new version" PKGBUILD ||
		die "%s: could not commit after build\n" "$sdk$pkgpath"
		;;
	MSYS)
		require msys2-devel binutils
		opt_j=-j5
		if test -z "$(git --git-dir="$sdk64/usr/src/build-extra/.git" \
			config alias.signtool)"
		then
			extra=
		else
			extra="SIGNTOOL=\"git --git-dir=\\\"$sdk64/usr/src"
			extra="$extra/build-extra/.git\\\" signtool\" "
		fi
		if test msys2-runtime = "$package"
		then
			opt_j=-j1
			require mingw-w64-cross-crt-git mingw-w64-cross-gcc
			test ! -d msys2-runtime ||
			git -C msys2-runtime fetch ||
			die "Could not fetch from origin"
			test ! -d src/msys2-runtime/.git ||
			(cd src/msys2-runtime &&
			 case "$(test -x /usr/bin/git && cat .git/objects/info/alternates 2>/dev/null)" in
			 /*)
				echo "dissociating worktree, to allow MINGW Git to access the worktree" >&2 &&
				/usr/bin/git repack -ad &&
				rm .git/objects/info/alternates
				;;
			 esac &&
			 if test -n "$(git config remote.upstream.url)"
			 then
				git fetch upstream
			 else
				git remote add -f upstream \
					https://github.com/Alexpux/Cygwin
			 fi &&
			 if test -n "$(git config remote.cygwin.url)"
			 then
				git fetch --tags cygwin
			 else
				git remote add -f cygwin \
				    git://sourceware.org/git/newlib-cygwin.git
			 fi) ||
			die "Could not update msys2-runtime's upstream\n"
		fi

		"$sdk/git-cmd" --command=usr\\bin\\sh.exe -l -c \
			'cd '"$pkgpath"' &&
			 export MSYSTEM=MSYS &&
			 export PATH=/usr/bin:/opt/bin:/mingw64/bin:/mingw32/bin:$PATH &&
			 unset ORIGINAL_PATH &&
			 . /etc/profile &&
			 MAKEFLAGS='"$opt_j"' '"$extra"'makepkg -s --noconfirm \
				'"$extra_makepkg_opts"' &&
			 makepkg --allsource '"$extra_makepkg_opts" ||
		die "%s: could not build\n" "$sdk$pkgpath"

		if test "a$sdk32" = "a$sdk"
		then
			git update-index -q --refresh &&
			git diff-files --quiet --ignore-submodules PKGBUILD ||
			git commit -s -m "$package: new version" PKGBUILD ||
			die "%s: could not commit after build\n" "$sdk$pkgpath"
		else
			git add PKGBUILD &&
			git pull "$sdk32/${pkgpath%/*}/.git" \
				"$(git rev-parse --symbolic-full-name HEAD)" &&
			require_clean_worktree ||
			die "%s: unexpected difference between 32/64-bit\n" \
				"$pkgpath"
		fi
		;;
	esac
}

fast_forward () {
	if test -d "$2"/.git
	then
		git -C "$1" fetch "$2" refs/heads/main
	else
		git -C "$1" fetch "$2"/.. refs/heads/main
	fi &&
	git -C "$1" merge --ff-only "$3" &&
	test "a$3" = "a$(git -C "$1" rev-parse --verify HEAD)"
}

# up_to_date <path>
up_to_date () {
	# test that repos at <path> are up-to-date in both 64-bit and 32-bit
	pkgpath="$1"

	sdk= require_clean_worktree

	commit32="$(cd "$sdk32$pkgpath" && git rev-parse --verify HEAD)" &&
	commit64="$(cd "$sdk64$pkgpath" && git rev-parse --verify HEAD)" ||
	die "Could not determine HEAD commit in %s\n" "$pkgpath"

	if test "a$commit32" != "a$commit64"
	then
		fast_forward "$sdk32$pkgpath" "$sdk64$pkgpath" "$commit64" ||
		fast_forward "$sdk64$pkgpath" "$sdk32$pkgpath" "$commit32" ||
		die "%s: commit %s (32-bit) != %s (64-bit)\n" \
			"$pkgpath" "$commit32" "$commit64"
	fi
}

# require_remote <nickname> <url>
require_remote () {
	if test -z "$(git config remote."$1".url)"
	then
		git remote add -f "$1" "$2"
	else
		test "$2" = "$(git config remote."$1".url)" ||
		die "Incorrect URL for %s: %s\n" \
			"$1" "$(git config remote."$1".url)"

		git fetch "$1"
	fi ||
	die "Could not fetch from %s\n" "$1"
}

# require_push_url # [<remote>]
require_push_url () {
	remote=${1:-origin}
	if ! grep -q '^Host github.com$' "$HOME/.ssh/config" 2>/dev/null
	then
		# Allow build agents to use Personal Access Tokens
		url="$(git config remote."$remote".url)" &&
		case "$(git config http."$url".extraHeader)" in
		Authorization:*) true;; # okay
		*) false;;
		esac ||
		die "No github.com entry in ~/.ssh/config\n"
	elif test -z "$(git config remote."$remote".pushurl)"
	then
		pushurl="$(git config remote."$remote".url |
			sed -n 's|^https://github.com/\(.*\)|github.com:\1|p')"
		test -n "$pushurl" ||
		die "Not a GitHub remote: %s\n" "$remote"

		git remote set-url --push "$remote" "$pushurl" ||
		die "Could not set push URL of %s to %s\n" "$remote" "$pushurl"
	fi
}

whatis () {
	git show -s --pretty='tformat:%h (%s, %ad)' --date=short "$@"
}

is_rebasing () {
	test -d "$(git rev-parse --git-path rebase-merge)"
}

has_merge_conflicts () {
	test -n "$(git ls-files --unmerged)"
}

# ensure_valid_login_shell <bitness>
ensure_valid_login_shell () {
	# Only perform this stunt for special accounts, such as NETWORK SERVICE
	test 256 -gt "$UID" ||
	return 0

	sdk="$(eval "echo \$sdk$1")"
	"$sdk/git-cmd" --command=usr\\bin\\sh.exe -c '
		# use `strace` to avoid segmentation faults for special accounts
		line="$(strace -o /dev/null mkpasswd -c | grep -v ^create)"
		case "$line" in
		*/nologin)
			if ! grep -q "^${line%%:*}" /etc/passwd 2>/dev/null
			then
				echo "${line%:*}:/usr/bin/bash" >>/etc/passwd
			fi
			;;
		esac' >&2
}

require_git_src_dir () {
	sdk="$sdk64"
	if test ! -d "$git_src_dir"
	then
		if test ! -d "${git_src_dir%/src/git}"
		then
			mingw_packages_dir="${git_src_dir%/*/src/git}"
			if test ! -d "$mingw_packages_dir"
			then
				case "$mingw_packages_dir" in
				*/MINGW-packages)
					o=https://github.com/git-for-windows &&
					git -C "${mingw_packages_dir%/*}" \
						clone $o/MINGW-packages ||
					die "Could not clone into %s\n" \
						"$mingw_packages_dir"
					;;
				*)
					die "Do not know how to clone %s\n" \
						"$mingw_packages_dir"
					;;
				esac
			else
				git -C "$mingw_packages_dir" fetch &&
				git -C "$mingw_packages_dir" \
					checkout -t origin/main ||
				die "Could not check out %s\n" \
					"$mingw_packages_dir"
			fi
		fi
		(cd "${git_src_dir%/src/git}" &&
		 echo "Checking out Git (not making it)" >&2 &&
		 "$sdk64/git-cmd" --command=usr\\bin\\sh.exe -l -c \
			'makepkg-mingw --noconfirm -s -o' &&
		 case "$(test -x /usr/bin/git && cat src/git/.git/objects/info/alternates 2>/dev/null)" in
		 /*)
			echo "Dissociating worktree, to allow MINGW git to access the worktree" >&2 &&
			/usr/bin/git -C src/git/ repack -ad &&
			rm src/git/.git/objects/info/alternates
			;;
		 esac) ||
		die "Could not initialize %s\n" "$git_src_dir"
	fi

	test ! -f "$git_src_dir/PKGBUILD" ||
	(cd "$git_src_dir/../.." &&
	 sdk= pkgpath=$PWD ff_main_branch) ||
	die "MINGW-packages not up-to-date\n"

	test false = "$(git -C "$git_src_dir" config core.autoCRLF)" ||
	(cd "$git_src_dir" &&
	 git config core.autoCRLF false &&
	 rm .git/index
	 git reset --hard) ||
	die "Could not make sure Git sources are checked out LF-only\n"
}

# build_and_test_64; intended to build and test 64-bit Git in MINGW-packages
build_and_test_64 () {
	skip_tests=
	filter_make_test=" | perl -ne '"'
		s/^ok \d+ # skip/skipped:/;
		unless (
			/^1..[0-9]*/ or
			/^ok [0-9]*/ or
			/^# passed all [0-9]* test\(s\)/ or
			/^# passed all remaining [0-9]* test\(s\)/ or
			/^# still have [0-9]* known breakage\(s\)/
		) {
			s/^not ok \d+ -(.*)# TODO known breakage/known e:$1/;
			s/^\*\*\* (.+) \*\*\*/$1/;
			s/(.+)/    $1/ unless /^t\d{4}-|^make/;
			print;
		};
	'"'; grep '^failed [^0]' t/test-results/*.counts"
	test_opts=--quiet
	no_svn_tests="NO_SVN_TESTS=1"
	while case "$1" in
	--skip-tests)
		skip_tests=--skip-tests
		;;
	--full-log)
		test_opts=
		filter_make_test=
		;;
	--with-svn-tests)
		no_svn_tests=
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	make_t_prefix=
	test -z "$test_opts" ||
	make_t_prefix="GIT_TEST_OPTS=\"$test_opts\" $make_t_prefix"
	test -z "$no_svn_tests" ||
	make_t_prefix="$no_svn_tests $make_t_prefix"

	ls //localhost/c$ >/dev/null 2>&1 || {
		echo "Administrative shares unavailable; skipping t5580" >&2
		export GIT_SKIP_TESTS="${GIT_SKIP_TESTS:+$GIT_SKIP_TESTS }t5580"
	}

	ensure_valid_login_shell 64 &&
	GIT_CONFIG_PARAMETERS= \
	"$sdk64/git-cmd" --command=usr\\bin\\sh.exe -l -c '
		: make sure that the .dll files are correctly resolved: &&
		cd $PWD &&
		rm -f t/test-results/*.{counts,tee} &&
		printf "\nBuilding Git...\n" >&2 &&
		if ! make -j5 -k DEVELOPER=1
		then
			echo "Re-running build (to show failures)" >&2
			make -k DEVELOPER=1 || {
				echo "Build failed!" >&2
				exit 1
			}
		fi &&
		printf "\nTesting Git...\n" >&2 &&
		if '"$(if test -z "$skip_tests"
			then
				printf '! %smake -C t -j5 -k%s\n' \
					"$make_t_prefix" "$filter_make_test"
			else
				echo 'false'
			fi)"'
		then
			cd t &&
			failed_tests="$(cd test-results &&
				grep -l "^failed [1-9]" t[0-9]*.counts)" || {
				echo "No failed tests ?!?" >&2
				exit 1
			}
			still_failing="$(git rev-parse --git-dir)/failing.txt"
			rm -f "$still_failing"
			for t in $failed_tests
			do
				t=${t%*.counts}
				test -f "$t.sh" || {
					t=${t%*-[1-9]*}
					test -f "$t.sh" ||
					echo "Cannot find script for $t" >&2
					exit 1
				}
				echo "Re-running $t" >&2
				time bash $t.sh -i -v -x ||
				echo "$t.sh" >>"$still_failing"
			done
			test ! -s "$still_failing" || {
				printf "Still failing:\n\n%s\n" \
					"$(cat "$still_failing")" >&2
				exit 1
			}
		fi'
}

needs_upload_permissions () {
	grep -q '^machine api\.github\.com$' "$HOME"/_netrc &&
	grep -q '^machine uploads\.github\.com$' "$HOME"/_netrc ||
	die "Missing GitHub entries in ~/_netrc\n"
}

# <coverity-token>
init_or_update_coverity_tool () {
	# check once per week whether there is a new version
	coverity_tool=.git/coverity-tool
	test ! -d $coverity_tool ||
	test $(($(date +%s)-$(stat -c %Y $coverity_tool))) \
		-gt $((7*24*60*60)) || return 0
	echo "Downloading current Coverity Scan Self-Build tool" >&2
	if test -f .git/coverity_tool.zip
	then
		timecond=.git/coverity_tool.zip
	else
		timecond="19700101 +0000"
	fi
	curl --form "token=$1" \
		--form "project=git-for-windows" \
		--time-cond "$timecond" \
		-o .git/coverity_tool.zip.new \
		https://scan.coverity.com/download/win64 &&
	test -f .git/coverity_tool.zip.new || {
		echo "Nothing downloaded; will try again in another week" >&2
		touch $coverity_tool
		return
	}
											mv -f .git/coverity_tool.zip.new .git/coverity_tool.zip ||
	die "Could not overwrite coverity_tool.zip"

	mkdir $coverity_tool.new &&
	(cd $coverity_tool.new &&
	 unzip ../coverity_tool.zip) ||
	die "Could not unpack coverity_tool.zip"
											rm -rf $coverity_tool &&
	mv $coverity_tool.new $coverity_tool ||
	die "Could not switch to new Coverity tool version"
}

submit_build_to_coverity () { # [--worktree=<dir>] <upstream-branch-or-tag>
	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	while case "$1" in
	--worktree=*)
		git_src_dir=${1#*=}
		test -d "$git_src_dir" ||
		die "Worktree does not exist: %s\n" "$git_src_dir"
		git rev-parse -q --verify e83c5163316f89bfbde7d ||
		die "Does not appear to be a Git checkout: %s\n" "$git_src_dir"
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"
	branch="$1"

	coverity_username="$(git config coverity.username)"
	test -n "$coverity_username" ||
	die "Need a username to access Coverity's services\n"

	coverity_token="$(git config coverity.token)"
	test -n "$coverity_token" ||
	die "Need a token to access Coverity's services\n"

	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	sdk="$sdk64"

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_main_branch) ||
	die "Could not update build-extra\n"

	require_git_src_dir

	(cd "$git_src_dir" &&
	 case "$branch" in
	 git-for-windows/*|v[1-9]*.windows.[1-9]*)
		require_remote git-for-windows \
			https://github.com/git-for-windows/git
		case "$branch" in git-for-windows/refs/pull/[0-9]*)
			git fetch git-for-windows \
			    "${branch#git-for-windows/}:refs/remotes/$branch" ||
			die "Could not fetch %s from git-for-windows\n" \
				"${branch#git-for-windows/}"
			;;
		esac
		;;
	 upstream/*|v[1-9]*)
		require_remote upstream https://github.com/git/git
		case "$branch" in upstream/refs/pull/[0-9]*)
			git fetch upstream "${branch#upstream/}:refs/remotes/$branch" ||
			die "Could not fetch %s from upstream\n" \
				"${branch#upstream/}"
			;;
		esac
		;;
	 esac &&
	 git checkout -f "$branch" &&
	 git reset --hard &&
	 sed -i -e 's/^\(char strbuf_slopbuf\[\)1\]/\165536]/' strbuf.c &&
	 init_or_update_coverity_tool "$coverity_token" &&
	 coverity_bin_dir=$(echo $PWD/$coverity_tool/*/bin) &&
	 if ! test -x "$coverity_bin_dir/cov-build.exe"
	 then
		die "Unusable Coverity bin/ directory: '%s'\n" \
			"$coverity_bin_dir"
	 fi &&
	 PATH="$coverity_bin_dir:$PATH" &&
	 cov-configure --gcc &&
	 # Coverity has a long-standing bug where it fails to parse two-digit
	 # major versions of GCC incorrectly Since Synopsys seems to
	 # be hardly in a rush to fix this (there's no response at
	 # https://community.synopsys.com/s/question/0D52H000058Z6KvSAK/
	 # since May 2020), we meddle with Coverity's config files
	 gcc10_workaround="$(test -d cov-int || gcc -v 2>&1 |
		sed -n 's/^gcc version \([1-9]\)\([0-9]\)\.\([0-9][0-9]*\)\.\([0-9][0-9]*\).*/s|\\<\\(\1\\)\\?\\(\2\\.\3\\.\4\\)\\>|\1\\2|g/p')" &&
	 if test -n "$gcc10_workaround"
	 then
		rm -f version.o &&
		cov-build --dir cov-int make DEVELOPER=1 version.o &&
		find cov-int/emit/* -name \*.xml -exec sed -i "$gcc10_workaround" {} \; &&
		rm -f version.o
	 fi &&
	 cov-build --dir cov-int \
		make -j15 DEVELOPER=1 CPPFLAGS="-DFLEX_ARRAY=65536 -DSUPPRESS_ANNOTATED_LEAKS" &&
	 tar caf git-for-windows.lzma cov-int &&
	 curl --form token="$coverity_token" \
		--form email="$coverity_username" \
		--form file=@git-for-windows.lzma \
		--form version="$(git rev-parse HEAD)" \
		--form version="$(date +%Y-%m-%s-%H-%M-%S)" \
		https://scan.coverity.com/builds?project=git-for-windows) ||
	die "Could not submit build to Coverity\n"
}

tag_git () { # [--force]
	force=
	branch_to_use=
	while case "$1" in
	-f|--force)
		force=--force
		;;
	--use-branch=*) branch_to_use="${1#*=}";;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	sdk="$sdk64" require w3m

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_main_branch) ||
	die "Could not update build-extra\n"

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	(cd "$git_src_dir" &&
	 require_remote upstream https://github.com/git/git &&
	 require_remote git-for-windows \
		https://github.com/git-for-windows/git) || exit

	case "$branch_to_use" in
	*@*)
		git "$dir_option" fetch --tags \
			"${branch_to_use#*@}" "${branch_to_use%%@*}" ||
		die "Could not fetch '%s' from '%s'\n" \
			"${branch_to_use%%@*}" "${branch_to_use#*@}"
		branch_to_use=FETCH_HEAD
		;;
	esac
	branch_to_use="${branch_to_use:-git-for-windows/main}"

	next_version="$(sed -ne \
		'1s/.* \(v[0-9][.0-9]*\(-rc[0-9]*\)\?\)(\([0-9][0-9]*\)) .*/\1.windows.\3/p' \
		-e '1s/.* \(v[0-9][.0-9]*\(-rc[0-9]*\)\?\) .*/\1.windows.1/p' \
		<"$build_extra_dir/ReleaseNotes.md")"
	! git --git-dir="$git_src_dir" rev-parse --verify \
		refs/tags/"$next_version" >/dev/null 2>&1 ||
	test -n "$force" ||
	die "Already tagged: %s\n" "$next_version"

	notes="$("$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'markdown </usr/src/build-extra/ReleaseNotes.md |
		 LC_CTYPE=C w3m -dump -cols 72 -T text/html | \
		 sed -n "/^Changes since/,\${:1;p;n;/^Changes/q;b1}"')"

	tag_message="$(printf "%s\n\n%s" \
		"$(sed -n '1s/.*\(Git for Windows v[^ ]*\).*/\1/p' \
		<"$build_extra_dir/ReleaseNotes.md")" "$notes")" &&
	(cd "$git_src_dir" &&
	 sign_option= &&
	 if git config user.signingKey >/dev/null; then sign_option=-s; fi &&
	 git tag -m "$tag_message" -a $sign_option $force \
		"$next_version" $branch_to_use) ||
	die "Could not tag %s in %s\n" "$next_version" "$git_src_dir"

	echo "Created tag $next_version" >&2
}

version_from_pkgbuild () { # <PKGBUILD>
	sed -ne \
		'/^_base_\?ver=/{N;N;s/.*=\([0-9].*\)\n.*\npkgrel=\(.*\)/\1-\2/p}' \
		-e '/^_ver=/{N;N;N;s/.*=\([.0-9]*\)\([a-z][a-z]*\)\n.*\n.*\npkgrel=\(.*\)/\1.\2-\3/p}' \
		-e '/^_\?pkgver=/{N;N;s/.*=\([0-9].*\)\npkgrel=\([0-9]*\)\nepoch=\([0-9\*\)/\3~\1-\2/p;s/.*=\([0-9].*\)\npkgrel=\([0-9]*\).*/\1-\2/p;N;s/.*=\([0-9].*\)\n.*\npkgrel=\([0-9]*\).*/\1-\2/p}' \
		-e '/^_\?pkgver=/{N;N;s/[^=]*=\([0-9].*\)\npkgrel=\([0-9]*\)\nepoch=\([0-9]*\).*/\3~\1-\2/p;s/[^=]*=\([0-9].*\)\npkgrel=\([0-9]*\).*/\1-\2/p}' \
		-e '/^_basever=/{N;s/^_basever=\([0-9].*\)\n_patchlevel=\([0-9]*\) .*\n.*\npkgrel=\([0-9]*\).*/\1.\2-\3/p}' \
		<"$1"
}

pkg_files () {
	pkgver="$(version_from_pkgbuild PKGBUILD)"
	test -n "$pkgver" ||
	die "%s: could not determine pkgver\n" "$sdk$pkgpath"

	test a--for-upload != "a$1" ||
	echo $package-$pkgver.src.tar.gz

	if test -z "$sdk"
	then
		arch="$(uname -m)"
	elif test "a$sdk" = "a$sdk32"
	then
		arch=i686
	else
		arch=x86_64
	fi

	for p in $package $extra_packages
	do
		case "$p" in
		mingw-w64-git-test-artifacts|mingw-w64-git-pdb)
			test "--for-upload" = "$1" || continue;;
		esac

		case "$p" in
		mingw-w64-*)
			suffix=-${p#mingw-w64-}-$pkgver-any.pkg.tar.xz
			case "$1" in
			--for-upload)
				printf " mingw-w64-i686$suffix"
				printf " mingw-w64-x86_64$suffix"
				;;
			--i686|--x86_64)
				printf " mingw-w64${1#-}$suffix"
				;;
			'')
				printf " mingw-w64-$arch$suffix"
				;;
			*)
				die "Whoops: unknown option %s\n" "$1"
				;;
			esac
			;;
		git-extra)
			prefix=$p-$pkgver
			suffix=.pkg.tar.xz
			case "$1" in
			--for-upload)
				printf " $prefix-i686$suffix"
				printf " $prefix-x86_64$suffix"
				;;
			--i686|--x86_64)
				printf " $prefix${1#-}$suffix"
				;;
			'')
				printf " $prefix-$arch$suffix"
				;;
			*)
				die "Whoops: unknown option %s\n" "$1"
				;;
			esac
			;;
		*)
			printf " $p-$pkgver-$arch.pkg.tar.xz"
			;;
		esac
	done
}

pkg_install () {
	require_clean_worktree

	files="$(pkg_files)" || exit

	case "$package" in
	msys2-runtime)
		require_not_in_use "$sdk" "usr/bin/msys-2.0.dll"
		;;
	bash)
		require_not_in_use "$sdk" "usr/bin/sh.exe"
		require_not_in_use "$sdk" "usr/bin/bash.exe"
		;;
	esac

	prepare_keep_despite_upgrade "$sdk" ||
	die 'Could not keep files as planned\n'

	"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"pacman -U --noconfirm $files"

	process_keep_despite_upgrade "$sdk" ||
	die 'Could not keep files as planned\n'

	if test MINGW = "$type"
	then
		prepare_keep_despite_upgrade "$sdk32" ||
		die 'Could not keep files as planned\n'

		"$sdk32/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"pacman -U --noconfirm $(pkg_files --i686)"

		process_keep_despite_upgrade "$sdk32" ||
		die 'Could not keep files as planned\n'
	fi
}

# origin HEAD
really_push () {
	if ! git push "$@"
	then
		if test "origin HEAD" = "$*"
		then
			git pull origin main
		else
			git pull "$@"
		fi &&
		git push "$@" ||
		return 1
	fi
	return 0
}

pacman_helper () {
	"$sdk64/git-cmd.exe" --command=usr\\bin\\bash.exe -l \
		"$sdk64/usr/src/build-extra/pacman-helper.sh" "$@"
}

maybe_init_repository () {
	test ! -d "$1" || return 0

	top_dir="${1%/*}"
	case "$top_dir" in
	*/MSYS2-packages|*/MINGW-packages|*/build-extra)
		url=https://github.com/git-for-windows/"${top_dir##*/}" &&
		if test ! -d "$top_dir"
		then
			git -C "${top_dir%/*}" clone $url ||
			die "Could not clone/fetch %s into %s\n" \
				"$url" "$top_dir"
		else
			test -d "$top_dir/.git" || git -C "$top_dir" init ||
			die "Could not initialize '%s'" "$top_dir"

			git -C "$top_dir" config remote.origin.url >/dev/null ||
			git -C "$top_dir" remote add origin $url ||
			die "Could not add remote to '%s'" "$top_dir"

			git -C "$top_dir" fetch origin &&
			git -C "$top_dir" checkout -t origin/main ||
			die "Could not check out main branch in '%s'" "$top_dir"
		fi
		;;
	*)
		die "Cannot initialize '%s'\n" "$1"
		;;
	esac
}

create_bundle_artifact () {
	test -n "$artifactsdir" || return 0
	upstream_main_branch="$(git rev-parse --verify -q git-for-windows/main)" ||
	upstream_main_branch="$(git rev-parse --verify -q origin/main)" ||
	return
	repo_name=$(git rev-parse --show-toplevel) &&
	repo_name=${repo_name##*/} &&
	if ! main_branch="$(git symbolic-ref --short HEAD)"
	then
		main_branch=main &&
		git switch -C $main_branch
	fi &&
	range="$upstream_main_branch..$main_branch" &&
	if test 0 -lt $(git rev-list --count "$range")
	then
		git bundle create "$artifactsdir"/$repo_name.bundle "$range"
	else
		echo "Range $range is empty" >"$artifactsdir/$repo_name.empty"
	fi
}

pkg_copy_artifacts () {
	test -n "$artifactsdir" || return 0
	files="$(pkg_files --for-upload)" || exit
	cp $files "$artifactsdir/" &&
	create_bundle_artifact
}

# <pkgrel>
maybe_force_pkgrel () {
	if test -n "$1"
	then
		test -z "$(echo "$1" | tr -d 0-9)" ||
		die "Invalid pkgrel: '%s'\n" "$1"

		sed -i "s/^\\(pkgrel=\\).*/\\1$1/" PKGBUILD
	elif git diff --exit-code -G'^(_ver|_realver|pkgver|_pkgver|_base_ver)=' -- PKGBUILD # version was not changed
	then
		# Maybe there have been changes since the latest release?
		blame_ver="$(MSYS_NO_PATHCONV=1 git blame -L '/^pkgver=/,+1' -- ./PKGBUILD)" &&
		blame_ver="$(echo "$blame_ver" | sed -e 's/ .*//' -e 's/^0*$//')" &&
		blame="$(MSYS_NO_PATHCONV=1 git blame -L '/^pkgrel=/,+1' HEAD -- ./PKGBUILD)" &&
		blame="$(echo "$blame" | sed -e '/^00* /d')" &&
		if test -n "$blame_ver" &&
		   test 0 -lt $(git rev-list --count ${blame:+${blame%% *}..} ${blame_ver:+$blame_ver..} -- PKGBUILD)
		then
			sed -i "s/^\\(pkgrel=\\).*/\\1"$((1+${blame##*=}))/ PKGBUILD
		else
			case "${PWD##*/MSYS2-packages/}" in
			perl-*|subversion)
				# Handle perl dependencees: if perl changed, increment pkgrel
				blame_perl="$(MSYS_NO_PATHCONV=1 git blame -L '/^pkgver=/,+1' -- ../perl/PKGBUILD)" &&
				blame_perl="$(echo "$blame_perl" | sed -e 's/ .*//' -e 's/^0*$//')" &&
				blame_perl_pkgrel="$(MSYS_NO_PATHCONV=1 git blame -L '/^pkgrel=/,+1' "$blame_perl.." -- ../perl/PKGBUILD)" &&
				if test -n "$blame_perl_pkgrel"
				then
					blame_perl="$(echo "$blame_perl_pkgrel" | sed -e 's/ .*//' -e 's/^0*$//')"
				fi &&
				if test -n "$blame_perl" &&
				   test 0 = $(git rev-list --count $blame_perl.. -- ./PKGBUILD)
				then
					sed -i "s/^\\(pkgrel=\\).*/\\1"$((1+${blame##*=}))/ PKGBUILD
				fi
				;;
			esac
		fi
	else
		# version changed; verify that pkgrel is 0 or 1
		case "$(sed -n 's/^pkgrel=\([0-9][0-9]*\)$/\1/p' PKGBUILD)" in
		0|1) return 0;; # okay
		*)
			die 'pkgrel needs to be reset to 1 when changing the version:\n\n%s\n' \
				"$(git diff HEAD -- PKGBUILD)"
			;;
		esac
	fi

	# make sure that we did not downgrade
	if test 0 -gt $(($(git diff HEAD -- PKGBUILD |
		sed -n 's/^\([-+]\)pkgrel=\([0-9]*\)$/\1\2/p' | tr -d '\n')))
	then
		die 'pkgrel must not be downgraded:\n\n%s\n' \
			"$(git diff HEAD -- PKGBUILD)"
	fi
}

# --force overwrites existing an Git tag, or existing package files
upgrade () { # [--directory=<artifacts-directory>] [--only-mingw] [--no-build] [--no-upload] [--force] [--release-date=<date>] [--use-branch=<branch>[@<URL>]] [--force-pkgrel=<pkgrel>] [--cleanbuild] <package>
	artifactsdir=
	skip_build=
	skip_upload=
	force=
	delete_existing_tag=
	release_date=
	use_branch=
	force_pkgrel=
	cleanbuild=
	only_mingw=
	skip_mingw=
	while case "$1" in
	--directory=*)
		artifactsdir="$(cygpath -am "${1#*=}")" || exit
		test -d "$artifactsdir" ||
		mkdir "$artifactsdir" ||
		die "Could not create artifacts directory: %s\n" "$artifactsdir"
		;;
	--directory)
		shift
		artifactsdir="$(cygpath -am "$1")" || exit
		test -d "$artifactsdir" ||
		mkdir "$artifactsdir" ||
		die "Could not create artifacts directory: %s\n" "$artifactsdir"
		;;
	--no-build)
		skip_build=t
		skip_upload=t
		;;
	--no-upload)
		skip_upload=t
		;;
	--only-mingw)
		only_mingw=t
		;;
	--skip-mingw)
		skip_mingw=t
		;;
	-f|--force)
		force=--force
		delete_existing_tag=--delete-existing-tag
		;;
	--release-date=*)
		release_date="$(echo "$1" | tr ' ' _)"
		;;
	--use-branch=*)
		use_branch="$1"
		;;
	--force-pkgrel=*)
		force_pkgrel="${1#*=}"
		;;
	--cleanbuild)
		cleanbuild=--cleanbuild
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	test -n "$skip_build" ||
	test -n "$GPGKEY" ||
	die "Need GPGKEY to upload packages\n"

	test -n "$skip_upload" ||
	test -s "$HOME"/.azure-blobs-token ||
	die "Missing token in ~/.azure-blobs-token\n"

	set_package "$1"

	test -z "$only_mingw" ||
	test curl = "$package" ||
	test openssl = "$package" ||
	test gnutls = "$package" ||
	test MINGW = "$type" ||
	die "The --only-mingw option is supported only for openssl/gnutls/curl\n"

	test -z "$skip_mingw" ||
	test openssl = "$package" ||
	test gnutls = "$package" ||
	test curl = "$package" ||
	test MSYS = "$type" ||
	die "The --skip-mingw option is supported only for openssl/gnutls/curl\n"

	test -z "$only_mingw" || test -z "$skip_mingw" ||
	die "--only-mingw and --skip-mingw are mutually exclusive\n"

	test -z "$release_date" ||
	test mingw-w64-git = "$package" ||
	die "The --release-date option is supported only for git\n"

	test -z "$use_branch" ||
	test mingw-w64-git = "$package" ||
	die "The --use-branch option is supported only for git\n"

	test -n "$skip_build" ||
	case "$package" in
	msys2-runtime)
		require_not_in_use "$sdk32" "usr/bin/msys-2.0.dll"
		require_not_in_use "$sdk64" "usr/bin/msys-2.0.dll"
		;;
	bash)
		require_not_in_use "$sdk32" "usr/bin/sh.exe"
		require_not_in_use "$sdk32" "usr/bin/bash.exe"
		require_not_in_use "$sdk64" "usr/bin/sh.exe"
		require_not_in_use "$sdk64" "usr/bin/bash.exe"
		;;
	esac

	maybe_init_repository "$sdk64$pkgpath"
	test -n "$skip_build" || test MSYS != "$type" || maybe_init_repository "$sdk32$pkgpath"

	test -n "$skip_upload" ||
	(cd "$sdk64$pkgpath" &&
	 require_push_url origin &&
	 sdk="$sdk64" ff_main_branch) || exit

	release_notes_feature=
	case "$package" in
	mingw-w64-git-credential-manager)
		repo=GitCredentialManager/git-credential-manager
		url=https://api.github.com/repos/$repo/releases
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		tag_name="$(echo "$release" |
			sed -n 's/^    "tag_name": "\(.*\)",\?$/\1/p' | head -n 1)"
		zip_name="$(echo "$release" | sed -ne 's/gcm[^"]*-symbols\.zip//' -e \
			's/.*"browser_download_url":.*\/\(gcm.*\.zip\).*/\1/p' | head -n 1)"
		version=${zip_name#gcmcore-win-x86-}
		version=${zip_name#gcm-win-x86-}
		version=${version%.zip}
		zip_prefix=${zip_name%$version.zip}
		if test "$zip_prefix" = "$zip_name"
		then
			# The version in the tag and the zip file name differ
			zip_replace='s/^\(zip_url=.*\/\)gcm[^"]*/\1'$zip_name/
		else
			zip_replace='s/^\(zip_url=.*\/\)gcm[^"]*/\1'$zip_prefix'${_realver}.zip/'
		fi
		(cd "$sdk64$pkgpath" &&
		 sed -i -e "s/^\\(pkgver=\\).*/\1$version/" -e "$zip_replace" \
		 -e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 updpkgsums &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD &&
		 create_bundle_artifact) &&
		url=https://github.com/$repo/releases/tag/$tag_name &&
		release_notes_feature='Comes with [Git Credential Manager Core v'$version']('"$url"').'
		;;
	git-for-windows-keyring)
		(cd "$sdk64$pkgpath" &&
		 updpkgsums &&
		 git update-index -q --refresh &&
		 if ! git diff-files --quiet -- PKGBUILD
		 then
			git commit -s -m "$package: adjust checksums" PKGBUILD &&
			create_bundle_artifact
		 fi &&
		"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'makepkg --nobuild -s --noconfirm' &&
		 if ! git diff-files --quiet -- PKGBUILD
		 then
			git commit -s -m "$package: update pkgver" PKGBUILD &&
			create_bundle_artifact
		 fi)
		;;
	git-extra)
		(cd "$sdk64$pkgpath" &&
		 updpkgsums &&
		 git update-index -q --refresh &&
		 if ! git diff-files --quiet -- PKGBUILD
		 then
			git commit -s -m "git-extra: adjust checksums" PKGBUILD &&
			create_bundle_artifact
		 fi &&
		 if test git-extra.install.in -nt git-extra.install
		 then
			MINGW_ARCH=mingw64 \
			"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
				'makepkg-mingw --nobuild -s --noconfirm' &&
			git checkout HEAD -- PKGBUILD &&
			git update-index -q --refresh &&
			if ! git diff-files --quiet -- git-extra.install
			then
				git commit -s -m \
					"git-extra: regenerate .install file" \
					git-extra.install
			fi
		 fi)
		;;
	curl)
		version="$(curl -Ls https://curl.haxx.se/download.html |
		sed -n 's/.*<a href="\/download\/curl-\([1-9]*[^"]*\)\.tar\.bz2".*/\1/p')"
		test -n "$version" ||
		die "Could not determine newest cURL version\n"

		ensure_gpg_key B71E12C2 || exit

		test -n "$only_mingw" ||
		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify curl-$version.tar.bz2.asc curl-$version.tar.bz2 &&
		 git commit -s -m "curl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		test -n "$only_mingw" ||
		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main &&

		case "$version,$force_pkgrel" in 7.58.0,|7.62.0,)
			: skip because of partially successful upgrade
			;;
		*)
		(if test -n "$skip_mingw"
		 then
			 exit 0
		 fi &&
		 set_package mingw-w64-$1 &&
		 maybe_init_repository "$sdk64$pkgpath" &&
		 cd "$sdk64$pkgpath" &&
		 { test -n "$skip_upload" ||
		   require_push_url origin; } &&
		 sdk="$sdk64" ff_main_branch || exit

		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify curl-$version.tar.bz2.asc curl-$version.tar.bz2 &&
		 git commit -s -m "curl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact &&

		 if test -z "$skip_build"
		 then
			build $force $cleanbuild "$package" &&
			sdk="$sdk64" pkg_copy_artifacts &&
			install "$package" &&
			if test -z "$skip_upload"
			then
				upload "$package"
			fi
		 fi)
			;;
		esac &&

		url=https://curl.haxx.se/changes.html &&
		url="$url$(echo "#$version" | tr . _)" &&
		v="$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature='Comes with [cURL v'$v']('"$url"').'
		;;
	mingw-w64-git)
		finalize $delete_existing_tag $release_date $use_branch \
			release-notes &&
		tag_git $force $use_branch &&
		if test -n "$artifactsdir"
		then
			echo "$next_version" >"$artifactsdir/next_version" &&
			echo "$display_version" >"$artifactsdir/display_version" &&
			set_version_from_tag_name "$next_version" &&
			echo "$ver" >"$artifactsdir/ver" &&
			git -C "$git_src_dir" bundle create \
				"$artifactsdir/git.bundle" \
				git-for-windows/main..$next_version &&
			git -C "$sdk64/usr/src/build-extra" bundle create \
				"$artifactsdir/build-extra.bundle" \
				-9 main
		fi &&
		rm -rf "$git_src_dir"/sha1collisiondetection
		;;
	mingw-w64-git-lfs)
		repo=git-lfs/git-lfs
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "v\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"
		needle1='^  "body": ".* SHA-256 hashes.*git-lfs-windows'
		# Git LFS sometimes lists SHA-256 sums below, sometimes
		# above the file names. Work around that particular issue
		if test -n "$(echo "$release" |
			grep "$needle1"'.*\\n[0-9a-z]\{64\}\(\\r\)\?\(\\n\)\?",\?$')"
		then
			# The SHA-256 sums are listed below the file names
			needle2="$version\\.zip[^0-9a-f]*\\([0-9a-f]*\\).*"
		else
			needle1='^  "body": ".* SHA-256 hashes.*[^0-9a-f]'
			needle1="$needle1\\([0-9a-f]\\+\\)"
			needle1="$needle1[^0-9a-f]*git-lfs-windows"
			needle2="$version\\.zip.*"
		fi
		sha256_32="$(echo "$release" |
			sed -n "s/$needle1-386-$needle2/\1/p")"
		extra_v=
		test -n "$sha256_32" || {
			sha256_32="$(echo "$release" |
				sed -n "s/$needle1-386-v$needle2/\1/p")"
			test -n "$sha256_32" ||
			die 'Could not find version in %s\n' \
				"$(echo "$release" | sed -n "/$needle1/p")"
			extra_v=v
		}
		test 64 = $(echo -n "$sha256_32" | wc -c) ||
		die "Could not determine SHA-256 of 32-bit %s\n" "$package"

		# Incorrect SHA-256 for 32-bit 2.2.1:
		# see https://github.com/git-lfs/git-lfs/issues/2408
		test 2.2.1,1142055d51a7d70b3c2fbf184db41100457f170a532b638253991821890927b5 != "$version,$sha256_32" || sha256_32=0d6347bbdf25946f14949b50f18b9929183aefe55f6b626f8a618ae53c2220bb

		sha256_64="$(echo "$release" |
			sed -n "s/$needle1-amd64-$extra_v$needle2/\1/p")"
		test 64 = $(echo -n "$sha256_64" | wc -c) ||
		die "Could not determine SHA-256 of 64-bit %s\n" "$package"
		(cd "$sdk64$pkgpath" &&
		 url=https://github.com/$repo/releases/download/v$version/ &&
		 zip32="git-lfs-windows-386-$extra_v$version.zip" &&
		 zip64="git-lfs-windows-amd64-$extra_v$version.zip" &&
		 curl -LO $url$zip32 &&
		 curl -LO $url$zip64 &&
		 printf "%s *%s\n%s *%s\n" \
			"$sha256_32" "$zip32" "$sha256_64" "$zip64" |
		 sha256sum -c - &&
		 exesuffix32="$(unzip -l $zip32 | sed -n 's/.*git-lfs\([^\/]*\)\.exe$/\1/p')" &&
		 exesuffix64="$(unzip -l $zip64 | sed -n 's/.*git-lfs\([^\/]*\)\.exe$/\1/p')" &&
		 dir32="$(unzip -l $zip32 |
			 sed -n 's/^.\{28\} *\(.*\)\/\?git-lfs'"$exesuffix32"'\.exe$/\1/p' |
			 sed -e 's/^$/./' -e 's/\//\\&/g')" &&
		 dir64="$(unzip -l $zip64 |
			 sed -n 's/^.\{28\} *\(.*\)\/\?git-lfs'"$exesuffix64"'\.exe/\1/p' |
			 sed -e 's/^$/./' -e 's/\//\\&/g')" &&
		 s1='s/\(folder=\)[^\n]*/\1' &&
		 s2='s/\(sha256sum=\)[0-9a-f]*/\1' &&
		 s3='s/\(386-\|amd64-\)v\?\(\$pkgver\.zip\)/\1'$extra_v'\2/' &&
		 s4_32='s/\(exesuffix=\).*/\1'"$exesuffix32"'/' &&
		 s4_64='s/\(exesuffix=\).*/\1'"$exesuffix64"'/' &&
		 sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
		 -e "s/^\\(pkgrel=\\).*/\\11/" \
		 -e "/^i686)/{N;N;N;N;$s1$dir32/;$s2$sha256_32/;$s3;$s4_32}" \
		 -e "/^x86_64)/{N;N;N;N;$s1$dir64/;$s2$sha256_64/;$s3;$s4_64}" \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD &&
		 create_bundle_artifact) &&
		url=https://github.com/$repo/releases/tag/v$version &&
		release_notes_feature='Comes with [Git LFS v'$version']('"$url"').'
		;;
	msys2-runtime)
		(cd "$sdk64/usr/src/MSYS2-packages/msys2-runtime" &&
		 if test ! -d src/msys2-runtime
		 then
			MSYSTEM=msys PATH="$sdk64/usr/bin:$PATH" \
			"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
				'makepkg -s --noconfirm --nobuild -s'
		 fi ||
		 die "Could not initialize worktree for '%s\n" "$package"

		 cd src/msys2-runtime ||
		 die "Invalid worktree for '%s'\n" "$package"

		 case "$(test -x /usr/bin/git && cat .git/objects/info/alternates 2>/dev/null)" in
		 /*)
			echo "dissociating worktree, to allow MINGW Git to access the worktree" >&2 &&
			/usr/bin/git repack -ad &&
			rm .git/objects/info/alternates ||
			die "Could not dissociate src/msys2-runtime\n"
			;;
		 esac

		 require_remote cygwin \
			git://sourceware.org/git/newlib-cygwin.git &&
		 git fetch --tags cygwin &&
		 require_remote git-for-windows \
			https://github.com/git-for-windows/msys2-runtime ||
		 die "Could not connect remotes for '%s'\n" "$package"

		 tag=$(git for-each-ref --sort=-taggerdate --count=1 \
			--format='%(refname)' refs/tags/cygwin-\*-release) &&
		 test -n "$tag" ||
		 die "Could not determine latest tag of '%s'\n" "$package"

		 # Git for Windows will skip v3.2.0 and stay on v3.1.7 until v3.2.1 comes out
		 test refs/tags/cygwin-3_2_0-release != "$tag" || tag=refs/tags/cygwin-3_1_7-release

		 version="$(echo "$tag" | sed -ne 'y/_/./' -e \
		    's|^refs/tags/cygwin-\([1-9][.0-9]*\)-release$|\1|p')" &&
		 test -n "$version" ||
		 die "Invalid version '%s' for '%s'\n" "$version" "$package"

		 # rebase if necessary
		 git reset --hard &&
		 git checkout git-for-windows/main &&
		 if test 0 -lt $(git rev-list --count \
			git-for-windows/main..$tag)
		 then
			{ test -n "$skip_upload" ||
			  require_push_url git-for-windows; } &&
			GIT_EDITOR=true \
			"$sdk64"/usr/src/build-extra/shears.sh \
				--merging --onto "$tag" merging-rebase &&
			create_bundle_artifact &&
			{ test -n "$skip_upload" ||
			  git push git-for-windows HEAD:main; } ||
			die "Could not rebase '%s' to '%s'\n" "$package" "$tag"
		 fi

		 test -n "$force_pkgrel" ||
		 case "$(version_from_pkgbuild ../../PKGBUILD)" in
		 $version-[1-9]*)
			 msys2_runtime_mtime=$(git log -1 --format=%ct \
				git-for-windows/main --) &&
			 msys2_package_mtime=$(git -C ../.. log -1 \
				--format=%ct -G'pkg(rel|ver)' -- PKGBUILD) &&
			 test $msys2_runtime_mtime -gt $msys2_package_mtime
			 ;;
		 esac ||
		 die "Package '%s' already up-to-date\n\t%s: %s\n\t%s: %s\n" \
			"$package" \
			"Most recent source code update" \
			"$(date --date="@$msys2_runtime_mtime")" \
			"Most recent package update" \
			"$(date --date="@$msys2_package_mtime")"

		 if test 2.11.2 = "$version"
		 then
			cygwin_url=https://cygwin.com/ml/cygwin-announce/2018-11/msg00007.html
		 elif test 3.1.7 = "$version"
		 then
			cygwin_url=https://cygwin.com/pipermail/cygwin-announce/2020-August/009678.html
		 else
		 	cygwin_url="$(curl -s https://cygwin.com/ |
			 sed -n '/The most recent version of the Cygwin DLL is/{
			    N;s/.*<a href="\([^"]*\)">'"$version"'<\/a>.*/\1/p
			 }')"
			test -n "$cygwin_url" ||
			cygwin_url="$(curl -Lis https://cygwin.com/ml/cygwin-announce/current |
			 sed -ne '/^[Ll]ocation: /{s/^location: //;s/[^\/]*$//;x}' \
			  -e '/<[Aa] \([Nn][Aa][Mm][Ee]=[^ ]* \)\?[Hh][Rr][Ee][Ff]=[^>]*>[Cc]ygwin '"$(echo "$version" |
				sed 's/\./\\&/g')"'/{s/.* [Hh][Rr][Ee][Ff]="\([^"]*\).*/\1/;H;x;s/\n//;p;q}')"
		 fi &&

		 test -n "$cygwin_url" ||
		 die "Could not retrieve Cygwin mail about v%s\n" "$version"

		 commit_url=https://github.com/git-for-windows/msys2-runtime &&
		 commit_url=$commit_url/commit/$(git rev-parse HEAD) &&
		 cd ../.. &&
		 if test "$version" = "$(sed -n 's/^pkgver=//p' <PKGBUILD)"
		 then
			pkgrel=$(($(sed -n 's/^pkgrel=//p' <PKGBUILD)+1)) &&
			printf 'Comes with %s%s [%s](%s).' \
			 "[patch level $pkgrel]($commit_url) of the " \
			 'MSYS2 runtime (Git for Windows flavor) based on' \
			 "Cygwin $version" "$cygwin_url" >../.git/release_notes &&
			sed -i "s/^\\(pkgrel=\\).*/\\1$pkgrel/" PKGBUILD
		 else
			pkgrel=
			printf 'Comes with %s [%s](%s).' \
			 'MSYS2 runtime (Git for Windows flavor) based on' \
			 "Cygwin $version" "$cygwin_url" >../.git/release_notes &&
			sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
				-e "s/^\\(pkgrel=\\).*/\\11/" PKGBUILD
		 fi &&
		 git commit -s -m "$package: update to v$version${pkgrel:+ ($pkgrel)}" PKGBUILD &&
		 MSYSTEM=msys PATH="$sdk64/usr/bin:$PATH" \
		 "$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			./update-patches.sh &&
		 git commit --amend --no-edit -C HEAD &&
		 create_bundle_artifact ||
		 die "Could not update PKGBUILD of '%s' to version %s\n" \
			"$package" "$version" &&
		 git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main
		) || exit
		release_notes_feature="$(cat "$sdk64$pkgpath/../.git/release_notes")"
		;;
	mingw-w64-busybox)
		(cd "$sdk64$pkgpath" &&
		 if test ! -d src/busybox-w32
		 then
			MINGW_ARCH=mingw64 \
			"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
				'makepkg-mingw --nobuild --noprepare -s --noconfirm'
		 fi &&
		 case "$(test -x /usr/bin/git && cat src/busybox-w32/.git/objects/info/alternates 2>/dev/null)" in
		 /*)
			echo "dissociating worktree, to allow MINGW Git to access the worktree" >&2 &&
			/usr/bin/git -C src/busybox-w32 repack -ad &&
			rm src/busybox-w32/.git/objects/info/alternates
			;;
		 esac &&
		 git stash &&
		 url=https://github.com/git-for-windows/busybox-w32 &&
		 (cd src/busybox-w32 &&
		  require_remote git-for-windows "$url" &&
		  require_remote rmyorston \
			https://github.com/rmyorston/busybox-w32 ||
		  die "Could not connect remotes for '%s'\n" "$package"
		  base_rev=$(git for-each-ref --format='%(objectname)' --sort=-taggerdate \
			  --count=1 refs/tags/FRP-\*) ||
		  die "Could not determine base revision\n"
		  if test 0 -lt $(git rev-list --count \
			git-for-windows/main..$base_rev)
		  then
			{ test -n "$skip_upload" ||
			  require_push_url git-for-windows; } &&
			git reset --hard &&
			git checkout git-for-windows/main &&
			GIT_EDITOR=true \
			"$sdk64"/usr/src/build-extra/shears.sh --merging \
				--onto $base_rev merging-rebase &&
			create_bundle_artifact &&
			{ test -n "$skip_upload" ||
			  git push git-for-windows HEAD:main; } ||
			die "Could not rebase '%s' to '%s'\n" \
				"$package" "rmyorston/HEAD"
		  fi) ||
		 die "Could not initialize/rebase '%s'\n" "$package"

		 built_from_commit="$(sed -n \
			's/^pkgver=.*\.\([0-9a-f]*\)$/\1/p' <PKGBUILD)" &&
		 test 0 -lt $(git -C src/busybox-w32 rev-list --count \
			"$built_from_commit"..git-for-windows/main) ||
		 die "Package '%s' already up-to-date at commit '%s'\n" \
			"$package" "$built_from_commit"

		 base_rev=$(git -C src/busybox-w32 for-each-ref \
			--format='%(objectname)' --sort=-taggerdate \
			--count=1 refs/tags/FRP-\*) &&
		 base_tag=$(git -C src/busybox-w32 for-each-ref \
			--format='%(refname:short)' --sort=-committerdate --count=1 \
			--merged $base_rev "refs/tags/[1-9]*") &&
		 _ver_base=$(echo "$base_tag" | tr _ .) ||
		 die "Could not determine base revision or version\n"

		 sed -i "s/^\(_ver_base=\).*/\1$_ver_base/" PKGBUILD &&
		 git -C src/busybox-w32 switch -C makepkg git-for-windows/main &&
		 version="$(bash -c "srcdir=src && . ./PKGBUILD && pkgver")" &&
		 sed -i -e "s/^\(pkgver=\).*/\1$version/" \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 git commit -s -m "busybox: upgrade to $version" PKGBUILD &&
		 create_bundle_artifact &&
		 url=$url/commit/${version##*.} &&
		 echo "Comes with [BusyBox v$version]($url)." \
			>../.git/release_notes) || exit
		release_notes_feature="$(cat "$sdk64$pkgpath/../.git/release_notes")"
		;;
	openssh)
		url=https://www.openssh.com
		notes="$(curl -s $url/releasenotes.html)" ||
		die 'Could not obtain release notes from %s\n' \
			"$url/releasenotes.html"
		newest="$(echo "$notes" |
			sed -n '/OpenSSH [1-9].*href=.txt\/.*[0-9]p[1-9]/{
			  s/.*href=.\(txt\/[^ ]*\). .*>\([1-9][^<]*\).*/\1 \2/p
			  q
			}')"
		version=${newest#* }
		test -n "$version" ||
		die "Could not determine newest OpenSSH version\n"
		url=$url/${newest% *}
		release_notes_feature='Comes with [OpenSSH v'$version']('"$url"').'
		sha256="$(echo "$notes" |
			sed -n "s/.*SHA256 (openssh-$version\\.tar\\.gz) = \([^ ]*\).*/\\1/p" |
			base64 -d | hexdump -e '1/1 "%02x"')"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 grep "sha256sums.*$sha256" PKGBUILD &&
		 git commit -s -m "openssh: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	openssl)
		version="$(curl -s https://www.openssl.org/source/ |
		sed -n 's/.*<a href="openssl-\(1\.1\.1[^"]*\)\.tar\.gz".*/\1/p')"
		test -n "$version" ||
		die "Could not determine newest OpenSSL version\n"

		test -n "$skip_build" || ensure_gpg_key 0E604491 || exit

		test -n "$only_mingw" ||
		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(_ver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify openssl-$version.tar.gz.asc \
		 	openssl-$version.tar.gz &&
		 git commit -s -m "openssl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) &&
		test 0 = $? ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main &&

		(if test -n "$skip_mingw"
		 then
			 exit 0
		 fi &&
		 set_package mingw-w64-$1 &&
		 maybe_init_repository "$sdk64$pkgpath" &&
		 cd "$sdk64$pkgpath" &&
		 { test -n "$skip_upload" ||
		   require_push_url origin; } &&
		 sdk="$sdk64" ff_main_branch || exit

		 sed -i -e 's/^\(_ver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify openssl-$version.tar.gz.asc \
		 	openssl-$version.tar.gz &&
		 git commit -s -m "openssl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact &&

		 if test -z "$skip_build"
		 then
			build $force $cleanbuild "$package" &&
			sdk="$sdk64" pkg_copy_artifacts &&
			install "$package" &&
			if test -z "$skip_upload"
			then
				upload "$package"
			fi
		 fi) &&
		test 0 = $? &&

		v="$(echo "$version" | tr -dc 0-9.)" &&
		url=https://www.openssl.org/news/openssl-$v-notes.html &&
		release_notes_feature='Comes with [OpenSSL v'$version']('"$url"').'
		;;
	gnutls)
		feed="$(curl -s https://gnutls.org/news.atom)" &&
		version="$(echo "$feed" |
			sed -n '/<title>G[Nn][Uu] \?TLS [1-9]/{s/.*TLS \([1-9][0-9.]*\).*/\1/p;q}')" &&
		test -n "$version" ||
		die "Could not determine newest GNU TLS version\n"

		test -n "$only_mingw" ||
		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(_base_ver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) &&
		test 0 = $? ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main &&

		(if test -n "$skip_mingw"
		 then
			 exit 0
		 fi &&
		 set_package mingw-w64-$1 &&
		 maybe_init_repository "$sdk64$pkgpath" &&
		 cd "$sdk64$pkgpath" &&
		 { test -n "$skip_upload" ||
		   require_push_url origin; } &&
		 sdk="$sdk64" ff_main_branch || exit

		 sed -i -e 's/^\(_pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "${package#mingw-w64-}: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact &&

		 if test -z "$skip_build"
		 then
			build $force $cleanbuild "$package" &&
			sdk="$sdk64" pkg_copy_artifacts &&
			install "$package" &&
			if test -z "$skip_upload"
			then
				upload "$package"
			fi
		 fi) &&
		test 0 = $? &&

		v="$(echo "$version" | tr -dc 0-9.)" &&
		url="$(echo "$feed" |
			sed -n '/<a href=[^>]*>G[Nn][Uu] \?TLS [1-9]/{s/.*<a href="\?\([^>"]*\).*/\1/p;q}')" &&
		release_notes_feature='Comes with [GNU TLS v'$version']('"$url"').'
		;;
	mingw-w64-wintoast|mingw-w64-cv2pdb)
		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 MINGW_ARCH=mingw64 \
		 "$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'makepkg-mingw --nobuild -s --noconfirm' &&
		 version="$(sed -n 's/^pkgver=\(.*\)$/\1/p' <PKGBUILD)" &&
		 if test "1.0.0.181.9b0663d" != "$version" &&
			test "0.44.18.g0198534" != "$version"
		 then
			git commit -s -m \
				"${package#mingw-w64-}: upgrade to $version" \
				PKGBUILD &&
			create_bundle_artifact
		 fi &&
		 git update-index -q --refresh &&
		 git diff-files --quiet --)
		;;
	bash)
		url="http://git.savannah.gnu.org/cgit/bash.git/commit/?id=HEAD" &&
		version=5.2 &&
		patchlevel="$(curl $url | sed -n \
			's/.*+#define PATCHLEVEL \([1-9][0-9]*\).*/\1/p')" &&
		if test -z "$patchlevel"
		then
			patchlevel=0
		fi &&
		patchlevel="$(printf "%03d" $patchlevel)" &&
		(cd "$sdk64/usr/src/MSYS2-packages/bash" &&
		 sed -i -e 's/^\(_basever=\).*/\1'$version/ \
			-e 's/^\(_patchlevel=\)[0-9]*\(.*\)/\1'$patchlevel'\2/' \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 v="$version.$patchlevel${force_pkgrel:+-$force_pkgrel}" &&
		 git commit -s -m "bash: new version ($v)" PKGBUILD &&
		 create_bundle_artifact) ||
		exit
		v="$version patchlevel $patchlevel ${force_pkgrel:+ ($force_pkgrel)}" &&
		url=https://tiswww.case.edu/php/chet/bash/NEWS &&
		release_notes_feature='Comes with [Bash v'$v']('"$url"').'
		;;
	heimdal)
		releases="$(curl http://h5l.org/releases.html)" ||
		die "Could not download release notes for Heimdal\n"

		ver="$(echo "$releases" | sed -n '/ - Heimdal [1-9][0-9]*\./{
			s/.*Heimdal \([1-9][0-9.]*\).*/\1/p;q
		}')"
		test -n "$ver" ||
		die "Could not determine latest Heimdal version\n"

		# 7.5.0 is the initial version shipped by Git for Windows
		test 7.5.0 = "$ver$force_pkgrel" ||
		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$ver/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "heimdal: new version ($ver)" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=http://h5l.org/releases.html &&
		release_notes_feature='Comes with [Heimdal v'$ver']('"$url"').'
		;;
	perl)
		tags="$(curl https://api.github.com/repos/Perl/perl5/tags)" ||
		die "Could not download Perl tags\n"
		ver="$(echo "$tags" | sed -n \
			'/^    "name": "v5\.[0-9]*[02468]\.[0-9][0-9]*"/{s/.*"v\(.*\)".*/\1/p;q}')"
		test -n "$ver" ||
		die "Could not determine latest Perl version\n"

		# work around stale https://dev.perl.org/perl5/
		test 5.26.1 != "$ver" || ver=5.26.2

		(cd "$sdk64$pkgpath" &&
		 dll=msys-perl"$(echo "$ver" | tr . _)".dll &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$ver/ \
			-e 's/^pkgrel=.*/pkgrel=1/' \
			-e 's/msys-perl[1-9][0-9.]*\.dll/'$dll/ PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "perl: new version ($ver)" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=http://search.cpan.org/dist/perl-$ver/pod/perldelta.pod &&
		release_notes_feature='Comes with [Perl v'$ver']('"$url"').'
		;;
	perl-Net-SSLeay|perl-HTML-Parser|perl-TermReadKey|perl-Locale-Gettext|perl-XML-Parser|perl-YAML-Syck|perl-Clone)
		metaname=${package#perl-}
		case $metaname in
		Locale-Gettext) metaname=gettext;;
		esac
		meta="$(curl -Ls https://metacpan.org/dist/$metaname)" ||
		die "Could not download release notes for $package\n"

		ver="$(echo "$meta" | sed -n \
			'/<option/{N;N;N;s/.*<option[^a-z]*selected.*value="\([^"]*\/'"$metaname"'\)-\([0-9.]*\)".*/\1 \2/p}')"
		test -n "$ver" ||
		die "Could not determine latest $package version\n"

		metapath=${ver% *}
		ver=${ver##* }

		author_part="$(echo "$meta" | sed -n \
			's/.*<a itemprop="downloadUrl" href="https:\/\/cpan.metacpan.org\/authors\/id\/\(.*\)\/[^/]*".*/\1/p')"
		test -n "$author_part" || author_part='&'

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$ver/ \
			-e 's/^pkgrel=.*/pkgrel=1/' \
			-e 's|\(https://www.cpan.org/authors/id/\)\([A-Z]*/\)\{3\}|\1'"$author_part/|" \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($ver)" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=https://metacpan.org/source/$metapath-$ver/Changes &&
		release_notes_feature="Comes with [$package v$ver]($url)."
		;;
	tig)
		repo=jonas/tig
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"

		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "tig-\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=https://github.com/jonas/tig/releases/tag/tig-$version &&
		release_notes_feature="Comes with [$package v$version]($url)."
		;;
	subversion)
		url=https://subversion.apache.org/download.cgi
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"

		version="$(echo "$release" | sed -n \
		  '/.*subversion-[1-9][0-9.]*\.zip.*/{s/.*subversion-\([1-9][0-9.]*\)\.zip.*/\1/p;q}')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=https://svn.apache.org/repos/asf/subversion/tags/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url/CHANGES)."
		;;
	gawk)
		url=https://git.savannah.gnu.org/cgit/gawk.git/refs/tags
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"

		version="$(echo "$release" | sed -n \
		 '/<a href.*gawk-\([1-9][0-9.]*\)/{s/.*<a [^>]*gawk-\([1-9][0-9.]*[0-9]\).*/\1/p;q}')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=http://git.savannah.gnu.org/cgit/gawk.git/plain &&
		url=$url/NEWS?h=gawk-$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url)."
		;;
	mingw-w64-git-sizer)
		repo=github/git-sizer
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "v\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 url=https://github.com/$repo/releases/download/v$version/ &&
		 zip32="git-sizer-$version-windows-386.zip" &&
		 zip64="git-sizer-$version-windows-amd64.zip" &&
		 curl -LO $url$zip32 &&
		 curl -LO $url$zip64 &&
		 sha256_32=$(sha256sum $zip32 | cut -c-64) &&
		 sha256_64=$(sha256sum $zip64 | cut -c-64) &&
		 s1='s/\(sha256sum=\)[0-9a-f]*/\1' &&
		 sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
		 -e "s/^\\(pkgrel=\\).*/\\11/" \
		 -e "/^i686)/{N;N;$s1$sha256_32/}" \
		 -e "/^x86_64)/{N;N;$s1$sha256_64/}" \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD &&
		 create_bundle_artifact)
		;;
	mingw-w64-nodejs)
		url=https://nodejs.org/en/download/
		downloads="$(curl $url)" ||
		die "Could not download node.js' Downloads page\n"

		version="$(echo "$downloads" | sed -n -e \
			's|.*https://nodejs.org/dist/v\([0-9.]*\)/.*|\1|p' |
			uniq)"
		test -n "$version" ||
		die "Could not determine current node.js version\n"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=https://nodejs.org/en/blog/release/v$version/ &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url)."
		;;
	mingw-w64-xpdf-tools)
		# If we ever have to upgrade beyond xpdf 4.00, we will
		# implement this part. But no sooner.
		;;
	mintty)
		repo=mintty/mintty
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
		 -e "s/^\\(pkgrel=\\).*/\\11/" \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD &&
		 create_bundle_artifact)
		;;
	git-flow)
		repo=petervanderdoes/gitflow-avh
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		# git-flow 1.12.2 was somehow released as tag only, without
		# release notes, so we would only find 1.12.1...
		# see https://github.com/petervanderdoes/gitflow-avh/issues/406
		# for details.
		test 1.12.1 != "$version" ||
		version=1.12.2

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"

		url=https://github.com/$repo/releases/tag/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url)."
		;;
	serf)
		url=https://serf.apache.org/download
		notes="$(curl -s $url)" ||
		die 'Could not obtain download page from %s\n' \
			"$url"
		version="$(echo "$notes" |
			sed -n 's|.*The latest stable release of Serf is \(<b>\)\?\([1-9][.0-9]*\).*|\2|p')"
		test -n "$version" ||
		die "Could not determine newest $package version\n"
		url=https://svn.apache.org/repos/asf/serf/trunk/CHANGES
		release_notes_feature='Comes with ['$package' v'$version']('"$url"').'

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	pkgconf)
		url=https://api.github.com/repos/pkgconf/pkgconf/tags
		tags="$(curl --netrc -s $url)"
		test -n "$tags" ||
		die "Could not get tags of %s\n" "$package"
		version="$(echo "$tags" |
			sed -n 's/^    "name": "pkgconf-\(.*\)",\?$/\1/p' |
			sort -rnt. -k1,1 -k2,2 -k3,3 |
			head -n 1)"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	libgpg-error)
		url='https://dev.gnupg.org/source/libgpg-error/tags/'
		tags="$(curl -s "$url")" ||
		test $? = 56 ||
		die 'Could not obtain download page from %s\n' "$url"
		version="$(echo "$tags" |
			sed 'y/</\n/' |
			sed -n '/ href=[^>]*>libgpg-error-[1-9][.0-9]*$/{s/.*>libgpg-error-\([.0-9]*\).*/\1/p}' |
			sort -rnt. -k1,1 -k2,2 -k3,3 |
			head -n 1)"
		test -n "$version" ||
		die "Could not determine newest $package version\n"
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	libgcrypt)
		url='https://dev.gnupg.org/source/libgcrypt/tags/'
		tags="$(curl -s "$url")" ||
		test $? = 56 ||
		die 'Could not obtain download page from %s\n' "$url"
		version="$(echo "$tags" |
			sed 'y/</\n/' |
			sed -n '/ href=[^>]*>libgcrypt-[1-9][.0-9]*$/{s/.*>libgcrypt-\([.0-9]*\).*/\1/p}' |
			sort -rnt. -k1,1 -k2,2 -k3,3 |
			head -n 1)"
		test -n "$version" ||
		die "Could not determine newest $package version\n"
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	gnupg)
		url='https://dev.gnupg.org/source/gnupg/tags/'
		tags="$(curl -s "$url")" ||
		test $? = 56 ||
		die 'Could not obtain download page from %s\n' "$url"
		version="$(echo "$tags" |
			sed -n '/ href=[^>]*>gnupg-[1-9][.0-9]*</{s/>gnupg-\([.0-9]*\).*/>\1/;s/.*>//p;q}')"
		test -n "$version" ||
		die "Could not determine newest $package version\n"
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&

		announce_url=
		url2=https://lists.gnupg.org/pipermail/gnupg-announce/
		mails="$(curl -s "$url2")" ||
		die 'Could not obtain download page from %s\n' "$url2"
		for d in $(echo "$mails" | sed -n 's/.*<A href="\(2[^/]*\/date.html\).*/\1/p')
		do
			m="$(curl -s "$url2/$d")" ||
			die "Could not download %s\n" "$url2$d"
			m="$(echo "$m" |
				sed -n '/<A HREF.*>.*GnuPG '"$(echo "$version" |
					sed 's/\./\\./g'
				)"'/{s/.* HREF="\([^"]*\).*/\1/p;q}')"
			test -n "$m" || continue
			announce_url="$url2${d%/*}/$m"
			break
		done
		test -n "$announce_url" ||
		die "Did not find announcement mail for GNU Privacy Guard %s\n" "$v"
		release_notes_feature='Comes with [GNU Privacy Guard '"$v"']('"$announce_url"').'

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"
		;;
	mingw-w64-pcre2)
		repo=PCRE2Project/pcre2
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -Ls $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		tag="$(echo "$release" |
			sed -n 's/^  "tag_name": "\(.*\)",\?$/\1/p')"
		version=${tag#pcre2-}
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD &&
		 create_bundle_artifact) ||
		exit

		url=https://raw.githubusercontent.com/$repo/$tag/ChangeLog
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [PCRE2 $v]($url)."
		;;
	libcbor)
		repo=PJK/libcbor
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^  "tag_name": "v\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"

		url=https://github.com/$repo/releases/tag/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url)."
		;;
	libfido2)
		repo=Yubico/libfido2
		url=https://api.github.com/repos/$repo/tags?per_page=1
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		version="$(echo "$release" |
			sed -n 's/^    "name": "\(.*\)",\?$/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&
		 create_bundle_artifact) ||
		die "Could not update %s\n" "$sdk64$pkgpath/PKGBUILD"

		git -C "$sdk32$pkgpath" pull "$sdk64$pkgpath/.." main ||
		die "Could not update $sdk32$pkgpath"

		url=https://github.com/$repo/releases/tag/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		release_notes_feature="Comes with [$package $v]($url)."
		;;
	*)
		die "Unhandled package: %s\n" "$package"
		;;
	esac &&

	if test -n "$release_notes_feature" && test -z "$skip_upload"
	then
		(cd "$sdk64/usr/src/build-extra" &&
		 require_push_url origin)
	fi &&

	if { test -z "$only_mingw" || test MINGW = $type; } && test -z "$skip_build"
	then
		build $force $cleanbuild "$package" &&
		sdk= pkg_copy_artifacts &&
		install "$package" &&
		if test -z "$skip_upload"; then upload "$package"; fi
	fi &&

	if test -n "$release_notes_feature"
	then
		(cd "$sdk64/usr/src/build-extra" &&
		 git pull origin main &&
		 mention --may-be-already-there feature \
			"$release_notes_feature" &&
		 create_bundle_artifact &&
		 if test -z "$skip_upload"
		 then
			really_push origin HEAD
		 fi)
	fi
}

set_version_from_tag_name () {
	version="${1#refs/tags/}"
	version="${version#v}"
	ver="$(echo "$version" | sed -n \
		's/^\([0-9]*\.[0-9]*\.[0-9]*\(-rc[0-9]*\)\?\)\.windows\(\.1\|\(\.[0-9]*\)\)$/\1\4/p')"
	test -n "$ver" ||
	die "Unexpected version format: %s\n" "$version"

	display_version="$ver"
	case "$display_version" in
	*.*.*.*)
		display_version="${display_version%.*}(${display_version##*.})"
		;;
	esac
}

version_from_release_notes () {
	sed -e '1s/^# Git for Windows v\(.*\) Release Notes$/\1/' -e 1q \
		"$sdk64/usr/src/build-extra/ReleaseNotes.md"
}

today () {
	LC_ALL=C date +"%B %-d %Y" |
	sed -e 's/\( [2-9]\?[4-90]\| 1[0-9]\) /\1th /' \
		-e 's/1 /1st /' -e 's/2 /2nd /' -e 's/3 /3rd /'
}

mention () { # [--may-be-already-there] <what, e.g. bug-fix, new-feature> <release-notes-item>
	may_be_already_there=
	test --may-be-already-there != "$1" || {
		may_be_already_there=t
		shift
	}
	case "$1" in
	bug|bugfix|bug-fix) what="Bug Fixes";;
	new|feature|new-feature) what="New Features";;
	*) die "Don't know how to mention %s\n" "$1";;
	esac
	shift

	quoted="* $(echo "$*" | sed "s/[\\\/\"'&]/\\\\&/g")"

	if test ! -d "$sdk32$pkgpath"; then
		(cd "$sdk64$pkgpath" && require_clean_worktree)
	fi ||
	up_to_date /usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	release_notes="$sdk64"/usr/src/build-extra/ReleaseNotes.md
	latest="$(version_from_release_notes)"
	if test "$latest" != "$(previous_version_from_release_notes)"
	then
		# insert whole "Changes since" section
		date="$(sed -n -e '2s/Latest update: //p' -e 2q \
			<"$release_notes")"
		quoted="v$latest ($date)\\n\\n### $what\\n\\n$quoted"
		quoted="## Changes since Git for Windows $quoted"
		sed -i -e "/^## Changes since/{s/^/$quoted\n\n/;:1;n;b1}" \
			"$release_notes"
	else
		search=$(echo "$quoted" | sed -r -e 's#.*Comes with \[(.* v|patch level).*#\1#' -e 's#[][]#\\&#g')
		sed -i -e '/^## Changes since/{
			:1;n;
			/^### '"$what"'/b3;
			/^### Bug Fixes/b2;
			/^## Changes since/b2;
			b1;

			:2;s/^/### '"$what"'\n\n'"$quoted"'\n\n/;b7;

			:3;/^\*/b4;n;b3;

			:4;/'"$search"'/b5;n;b6;:5;N;s/^.*\n//;:6;/^\*/b4;

			s/^/'"$quoted"'\n/;

			:7;n;b7}' "$release_notes"
	fi ||
	die "Could not edit release notes\n"

	# make sure that the Git version is always reported first
	case "$*" in
	'Comes with [Git v'*)
		sed -i -ne '/^### New Features/{
			p;n;
			/^$/{p;n};
			:1;
			/^\* Comes with \[Git v/{G;:2;p;n;b2};
			x;/./{G;x};n;b1;
			}' -e p "$release_notes"
		;;
	esac

	test -z "$may_be_already_there" ||
	! git -C "$sdk64"/usr/src/build-extra --no-pager \
		diff --exit-code --quiet HEAD ||
	return 0 # already added; nothing to be done anymore

	(cd "$sdk64"/usr/src/build-extra &&
	 what_singular="$(echo "$what" |
		 sed -e 's/Fixes/Fix/' -e 's/Features/Feature/')" &&
	 git commit -s -m "Mention $what_singular in release notes" \
		-m "$(echo "$*" | fmt -72)" ReleaseNotes.md) ||
	die "Could not commit release note edits\n"

	test ! -d "$sdk32"/usr/src/build-extra ||
	(cd "$sdk32"/usr/src/build-extra &&
	 git pull --ff-only "$sdk64"/usr/src/build-extra main) ||
	die "Could not synchronize release note edits to 32-bit SDK\n"
}

finalize () { # [--delete-existing-tag] <what, e.g. release-notes>
	delete_existing_tag=
	release_date=
	branch_to_use=
	while case "$1" in
	--delete-existing-tag) delete_existing_tag=t;;
	--release-date=*) release_date="$(echo "${1#*=}" | tr +_ ' ')";;
	--use-branch=*) branch_to_use="${1#*=}";;
	*) break;;
	esac; do shift; done

	case "$1" in
	rel|rel-notes|release-notes) ;;
	*) die "I don't know how to finalize %s\n" "$1";;
	esac

	up_to_date /usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	update git &&
	git_src_dir="$sdk64$pkgpath"/src/git &&
	require_git_src_dir &&
	(cd "$git_src_dir"/.git &&
	 require_remote upstream https://github.com/git/git &&
	 require_remote git-for-windows \
		https://github.com/git-for-windows/git) &&
	dir_option="--git-dir=$sdk64$pkgpath"/src/git/.git &&
	git "$dir_option" fetch --tags git-for-windows &&
	git "$dir_option" fetch --tags upstream ||
	die "Could not update Git\n"

	case "$branch_to_use" in
	*@*)
		git "$dir_option" fetch --tags --prune-tags \
			"${branch_to_use#*@}" "${branch_to_use%%@*}" ||
		die "Could not fetch '%s' from '%s'\n" \
			"${branch_to_use%%@*}" "${branch_to_use#*@}"
		branch_to_use=FETCH_HEAD
		;;
	esac
	branch_to_use="${branch_to_use:-git-for-windows/main}"

	ver="$(git "$dir_option" \
		describe --first-parent --match 'v[0-9]*[0-9]' \
		"$branch_to_use")" ||
	die "Cannot describe current revision of Git\n"

	ver=${ver%%-[1-9]*}

	# With --delete-existing-tag, delete previously generated tags, e.g.
	# from failed automated builds
	while test -n "$delete_existing_tag" &&
		test 0 = $(git "$dir_option" rev-list --count \
			"$ver".."$branch_to_use")
	do
		case "$ver" in
		*.windows.*) ;; # delete and continue
		*) break;;
		esac

		git "$dir_option" tag -d "$ver" ||
		die "Could not delete tag '%s'\n" "$ver"

		ver="$(git "$dir_option" \
			describe --first-parent --match 'v[0-9]*[0-9]' \
			"$branch_to_use")" ||
		die "Cannot describe current revision of Git\n"

		ver=${ver%%-*}
	done

	case "$ver" in
	*.windows.*)
		test 0 -lt $(git "$dir_option" rev-list --count \
			"$ver".."$branch_to_use") ||
		die "Already tagged: %s\n" "$ver"

		next_version=${ver%.windows.*}.windows.$((${ver##*.windows.}+1))
		display_version="${ver%.windows.*}(${next_version##*.windows.})"
		;;
	*)
		i=1
		display_version="$ver"
		while git "$dir_option" \
			rev-parse --verify $ver.windows.$i >/dev/null 2>&1
		do
			i=$(($i+1))
			display_version="$ver($i)"
		done
		next_version=$ver.windows.$i
		;;
	esac
	display_version=${display_version#v}

	test "$display_version" != "$(version_from_release_notes)" ||
	die "Version %s already in the release notes\n" "$display_version"

	case "$next_version" in
	*.windows.1)
		v=${next_version%.windows.1} &&
		if ! grep -q "^\\* Comes with \\[Git $v\\]" \
			"$sdk64"/usr/src/build-extra/ReleaseNotes.md
		then
			url=https://github.com/git/git/blob/$v &&
			txt="$(echo "${v#v}" | sed 's/-rc[0-9]*$//').txt" &&
			url=$url/Documentation/RelNotes/$txt &&
			mention feature 'Comes with [Git '$v']('$url').'
		fi ||
		die "Could not mention that Git was upgraded to $v\n"
		;;
	esac

	test -n "$release_date" ||
	release_date="$(today)"

	sed -i -e "1s/.*/# Git for Windows v$display_version Release Notes/" \
		-e "2s/.*/Latest update: $release_date/" \
		"$sdk64"/usr/src/build-extra/ReleaseNotes.md ||
	die "Could not edit release notes\n"

	(cd "$sdk64"/usr/src/build-extra &&
	 git commit -s -m "Prepare release notes for v$display_version" \
		ReleaseNotes.md) ||
	die "Could not commit finalized release notes\n"

	(cd "$sdk32"/usr/src/build-extra &&
	 git pull --ff-only "$sdk64"/usr/src/build-extra main) ||
	die "Could not update 32-bit SDK's release notes\n"
}

sign_files () {
	if test -z "$(git --git-dir="$sdk64/usr/src/build-extra/.git" \
		config alias.signtool)"
	then
		printf "\n%s\n\n%s\n\n\t%s %s\n\n%s\n\n\t%s\n" \
			"WARNING: No signing performed!" \
			"To fix this, set alias.signtool to something like" \
			"!'c:/PROGRA~1/MICROS~1/Windows/v7.1/Bin/signtool.exe" \
			"sign //v //f my-cert.p12 //p my-password'" \
			"The Windows Platform SDK contains the signtool.exe:" \
			http://go.microsoft.com/fwlink/p/?linkid=84091 >&2
	else
		for file in "$@"
		do
			git --git-dir="$sdk64/usr/src/build-extra/.git" \
				signtool "$file" ||
			die "Could not sign %s\n" "$file"
		done
	fi
}

bundle_pdbs () { # [--directory=<artifacts-directory] [--unpack=<directory>] [--arch=<arch>] [<package-versions>]
	packages="mingw-w64-git-pdb mingw-w64-curl-pdb mingw-w64-openssl-pdb"

	artifactsdir=
	architectures=
	unpack=
	while case "$1" in
	--directory=*)
		artifactsdir="$(cygpath -am "${1#*=}")" || exit
		test -d "$artifactsdir" ||
		mkdir "$artifactsdir" ||
		die "Could not create artifacts directory: %s\n" "$artifactsdir"
		;;
	--arch=*)
		architectures="${architectures:+$architectures }${1#*=}"
		;;
	--unpack=*)
		unpack="$(cygpath -am "${1#*=}")" || exit
		test -d "$unpack" ||
		die "Not a directory: %s\n" "$unpack"
		;;
	--*)
		die "Unknown option: %s\n" "$1"
		;;
	*)
		break
		;;
	esac; do shift; done

	test $# -le 1 ||
	die "Extra options: %s\n" "$*"

	test -z "$unpack" || test -z "$artifactsdir" ||
	die "--unpack and --directory are mutually exclusive\n"

	test -n "$unpack" ||
	test -n "$artifactsdir" ||
	artifactsdir="$(cygpath -am "$HOME")" || exit

	test -n "$architectures" ||
	architectures="i686 x86_64 aarch64"

	versions="$(case $# in 0) pacman -Q;; 1) cat "$1";; esac |
		sed 's/^\(mingw-w64\)\(-clang-[^-]*\|-[^-]*\)/\1/' | sort | uniq)"
	test -n "$versions" ||
	die 'Could not obtain package versions\n'

	git_version="$(echo "$versions" | sed -n 's/^mingw-w64-git //p')"

	test -n "$git_version" ||
		die "Could not determine Git version"

	dir="${this_script_path:+$(cygpath -au \
		"${this_script_path%/*}")/}"cached-source-packages
	test -n "$unpack" ||
	unpack=$dir/.unpack
	url=https://wingit.blob.core.windows.net

	mkdir -p "$dir" ||
	die "Could not create '%s'\n" "$dir"

	for arch in $architectures
	do
		echo "Unpacking .pdb files for $arch..." >&2

		case $arch in
			x86_64)
				oarch=x86-64
				pacman_arch=x86_64
				artifact_suffix=64-bit
				;;
			i686)
				oarch=i686
				pacman_arch=i686
				artifact_suffix=32-bit
				;;
			aarch64)
				oarch=aarch64
				pacman_arch=clang-aarch64
				artifact_suffix=arm64
				;;
			*)
				die "Unhandled architecture: $arch"
				;;
		esac

		test -z "$artifactsdir" ||
		test ! -d $unpack ||
		rm -rf $unpack ||
		die 'Could not remove %s\n' "$unpack"

		mkdir -p $unpack

		for package in $packages
		do
			name=${package%-*}
			version=$(echo "$versions" | sed -n "s/^$name //p")
			case "$package" in
			mingw-w64-*)
				tar=mingw-w64-$pacman_arch-${package#mingw-w64-}-$version-any.pkg.tar.xz
				dir2="/usr/src/MINGW-packages/$name"
				;;
			*)
				tar=$package-$version-$arch.pkg.tar.xz
				test i686 = $arch &&
				dir2="$sdk32/usr/src/MSYS2-packages/$name" ||
				dir2="$sdk64/usr/src/MSYS2-packages/$name"
				;;
			esac

			test -f "$dir/$tar" ||
			if test -f "$dir2/$tar"
			then
				cp "$dir2/$tar" "$dir/$tar" ||
				die 'Could not copy %s (%d)\n' "$tar" $?
			else
				echo "Retrieving $tar..." >&2
				curl -sfo "$dir/$tar" $url/$oarch/$tar
				case $? in
				0) ;; # okay
				56)
					while test 56 = $?
					do
						curl -sfo "$dir/$tar" \
							$url/$oarch/$tar ||
						die "curl error %s (%d)\n" \
							"$tar" $?
					done
					;;
				*)
					die 'curl error %s (%d)\n' "$tar" $?
					;;
				esac
			fi

			(cd "$unpack" &&
			 "/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
				"tar --wildcards -xf \"$dir/$tar\" \\*.pdb") ||
			die 'Could not unpack .pdb files from %s\n' "$tar"
		done

		test -n "$artifactsdir" || continue

		zip=pdbs-for-git-$artifact_suffix-$git_version.zip &&
		echo "Bundling .pdb files for $artifact_suffix..." >&2
		(cd "$unpack" &&
		 "/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"7za a -mx9 \"$artifactsdir/$zip\" *") &&
		echo "Created $artifactsdir/$zip" >&2 ||
		die 'Could not create %s for %s\n' "$zip" "$arch"
	done
}

render_release_notes_and_mail () { # <output-directory> <next-version> [<sha-256>...]
	test -d "$1" || mkdir "$1" || die "Could not create '%s'\n" "$1"
	case "$2" in
	*-[0-9]*)
		ver="${2#v}"
		display_version="prerelease-$2"
		;;
	v[0-9]*.windows.[0-9]|v[1-9]*.windows.[1-9][0-9])
		set_version_from_tag_name "$2"
		;;
	*)
		die "Unhandled version: %s\n" "$2"
		;;
	esac

	name="Git for Windows $display_version"
	text="$(sed -n \
		"/^## Changes since/,\${s/## //;:1;p;n;/^## Changes/q;b1}" \
		<"$sdk64"/usr/src/build-extra/ReleaseNotes.md)"
	checksums="$(printf '%s | %s\n' \
		Git-"$ver"-64-bit.exe $3 \
		Git-"$ver"-32-bit.exe $4 \
		PortableGit-"$ver"-64-bit.7z.exe $5 \
		PortableGit-"$ver"-32-bit.7z.exe $6 \
		MinGit-"$ver"-64-bit.zip $7 \
		MinGit-"$ver"-32-bit.zip $8 \
		MinGit-"$ver"-busybox-64-bit.zip $9 \
		MinGit-"$ver"-busybox-32-bit.zip ${10} \
		Git-"$ver"-64-bit.tar.bz2 ${11} \
		Git-"$ver"-32-bit.tar.bz2 ${12})"
	body="$(printf "%s\n\n%s\n%s\n%s" "$text" \
		'Filename | SHA-256' '-------- | -------' "$checksums")"
	echo "$body" >"$1/release-notes-$ver"

	# Required to render the release notes for the announcement mail
	type w3m ||
	case "$(uname -s)" in
	Linux)
		sudo apt-get -y install w3m ||
		die "Could not install w3m\n"
		;;
	MINGW*|MSYS)
		sdk="$sdk64" require w3m
		;;
	*)
		die "Could not install w3m\n"
		;;
	esac

	url=https://gitforwindows.org/
	case "$display_version" in
	prerelease-*)
		url=https://wingit.blob.core.windows.net/files/index.html
		;;
	*-rc*)
		url=https://github.com/git-for-windows/git/releases/tag/$2
		;;
	esac

	prefix="$(printf "%s\n\n%s%s\n\n    %s\n" \
		"Dear Git users," \
		"I hereby announce that Git for Windows " \
		"$display_version is available from:" \
		"$url")"
	rendered="$(echo "$text" |
		if type markdown >&2
		then
			markdown |
			LC_CTYPE=C w3m -dump -cols 72 -T text/html
		else
			"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
				'markdown |
				LC_CTYPE=C w3m -dump -cols 72 -T text/html'
		fi)"
	printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n%s\n" \
		"From $version Mon Sep 17 00:00:00 2001" \
		"From: $(git var GIT_COMMITTER_IDENT | sed -e 's/>.*/>/')" \
		"Date: $(date -R)" \
		"To: git-for-windows@googlegroups.com, git@vger.kernel.org, git-packagers@googlegroups.com" \
		"Subject: [ANNOUNCE] Git for Windows $display_version" \
		"Content-Type: text/plain; charset=UTF-8" \
		"Content-Transfer-Encoding: 8bit" \
		"MIME-Version: 1.0" \
		"Fcc: Sent" \
		"$prefix" \
		"$rendered" \
		"$checksums" \
		"Ciao," \
		"$(git var GIT_COMMITTER_IDENT | sed -e 's/ .*//')" \
		>"$1/announce-$ver"

	echo "Announcement saved as $1/announcement-$ver" >&2
}

release_sdk () { # <version>
	version="$1"
	tag=git-sdk-"$version"

	up_to_date /usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	! git rev-parse --git-dir="$sdk64"/usr/src/build-extra \
		--verify "$tag" >/dev/null 2>&1 ||
	die "Tag %s already exists\n" "$tag"

	for sdk in "$sdk32" "$sdk64"
	do
		"$sdk"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'cd /usr/src/build-extra/sdk-installer &&
			 ./release.sh '"$version" ||
		die "%s: could not build\n" "$sdk$pkgpath"
	done

	sign_files "$HOME"/git-sdk-installer-"$version"-64.7z.exe \
		"$HOME"/git-sdk-installer-"$version"-32.7z.exe

	git --git-dir="$sdk64"/usr/src/build-extra/.git \
		tag -a -m "Git for Windows SDK $version" "$tag" ||
	die "Could not tag %s\n" "$tag"
}

publish_sdk () { #
	up_to_date /usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	tag="$(git --git-dir="$sdk64"/usr/src/build-extra/.git for-each-ref \
		--format='%(refname:short)' --sort=-taggerdate \
		--count=1 'refs/tags/git-sdk-*'	)"
	version="${tag#git-sdk-}"

	url=https://api.github.com/repos/git-for-windows/build-extra/releases
	id="$(curl --netrc -s $url |
		sed -n '/^    "id":/{:1;N;/"tag_name": *"'"$tag"'"/{
			s/^ *"id": *\([0-9]*\).*/\1/p;q};b1}')"
	test -z "$id" ||
	die "Release %s exists already as ID %s\n" "$tag" "$id"

	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--repo=build-extra "$tag" \
		"$HOME"/git-sdk-installer-"$version"-64.7z.exe \
		"$HOME"/git-sdk-installer-"$version"-32.7z.exe ||
	die "Could not upload files\n"

	git --git-dir="$sdk64"/usr/src/build-extra/.git push origin "$tag"
}

create_sdk_artifact () { # [--out=<directory>] [--git-sdk=<directory>] [--architecture=(x86_64|i686|aarch64|auto)] [--bitness=(32|64)] [--force] <name>
	git_sdk_path=/
	output_path=
	force=
	architecture=auto
	bitness=
	keep_worktree=
	while case "$1" in
	--out|-o)
		shift
		output_path="$(cygpath -am "$1")" || exit
		;;
	--out=*|-o=*)
		output_path="$(cygpath -am "${1#*=}")" || exit
		;;
	-o*)
		output_path="$(cygpath -am "${1#-?}")" || exit
		;;
	--git-sdk|--sdk|-g)
		shift
		git_sdk_path="$(cygpath -am "$1")" || exit
		;;
	--git-sdk=*|--sdk=*|-g=*)
		git_sdk_path="$(cygpath -am "${1#*=}")" || exit
		;;
	-g*)
		git_sdk_path="$(cygpath -am "${1#-?}")" || exit
		;;
	--bitness|-b)
		shift
		bitness="$1"
		;;
	--bitness=*|-b=*)
		bitness="${1#*=}"
		echo "WARNING: using --bitness or -b is deprecated. Please use --architecture instead."
		;;
	-b*)
		bitness="${1#-?}"
		echo "WARNING: using --bitness or -b is deprecated. Please use --architecture instead."
		;;
	--architecture=*|-a=*)
		architecture="${1#*=}"
		;;
	-a*)
		architecture="${1#-?}"
		;;
	--force|-f)
		force=t
		;;
	--keep-worktree)
		keep_worktree=t
		;;
	--no-keep-worktree)
		keep_worktree=
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected one argument, got $#: %s\n" "$*"

	test -n "$output_path" ||
	output_path="$(cygpath -am "$1")"

	if test -n "$bitness"
	then
		case "$bitness" in
		32)
			architecture=i686
			;;
		64)
			architecture=x86_64
			;;
		*) die "Unhandled bitness: %s\n" "$bitness";;
		esac
	elif test auto = "$architecture"
	then
		if git -C "$git_sdk_path" rev-parse --quiet --verify HEAD:clangarm64 2>/dev/null
		then
			architecture=aarch64
		elif git -C "$git_sdk_path" rev-parse --quiet --verify HEAD:usr/i686-pc-msys 2>/dev/null
		then
			architecture=i686
		elif git -C "$git_sdk_path" rev-parse --quiet --verify HEAD:usr/x86_64-pc-msys 2>/dev/null
		then
			architecture=x86_64
		else
			die "'%s' is neither 32-bit nor 64-bit SDK?!?" "$git_sdk_path"
		fi
	elif test -z "$architecture"
	then
		die "Either --architecture or --bitness must be provided for this function to work."
	fi

	case "$architecture" in
	x86_64)
		MSYSTEM=MINGW64
		PREFIX="/mingw64"
		# TODO update to git-sdk-amd64 after the repo has been updated
		SDK_REPO="git-sdk-64"
		;;
	i686)
		MSYSTEM=MINGW32
		PREFIX="/mingw32"
		# TODO update to git-sdk-x86 after the repo has been updated
		SDK_REPO="git-sdk-32"
		;;
	aarch64)
		MSYSTEM=CLANGARM64
		PREFIX="/clangarm64"
		SDK_REPO="git-sdk-arm64"
		;;
	*) die "Unhandled architecture: %s\n" "$architecture";;
	esac

	mode=
	case "$1" in
	minimal|git-sdk-minimal) mode=minimal-sdk;;
	full) mode=full-sdk;;
	minimal-sdk|makepkg-git|build-installers|full-sdk) mode=$1;;
	*) die "Unhandled artifact: '%s'\n" "$1";;
	esac

	test ! -d "$output_path" ||
	if test -z "$force"
	then
		die "Directory exists already: '%s'\n" "$output_path"
	elif test -f "$output_path/.git"
	then
		git -C "$(git -C "$output_path" rev-parse --git-common-dir)" worktree remove -f "$(cygpath -am "$output_path")"
	else
		rm -rf "$output_path"
	fi ||
	die "Could not remove '%s'\n" "$output_path"

	if test -d "$git_sdk_path"
	then
		test ! -f "${git_sdk_path%/}/.git" ||
		git_sdk_path="$(git -C "${git_sdk_path%/}" rev-parse --git-dir)"
		test ! -d "${git_sdk_path%/}/.git" ||
		git_sdk_path="${git_sdk_path%/}/.git"
		test true = "$(git -C "$git_sdk_path" rev-parse --is-inside-git-dir)" ||
		die "Not a Git repository: '%s'\n" "$git_sdk_path"
	else
		test -z "$architecture" ||
		die "No SDK found at '%s'; Please use \`--architecture=<a>\` to indicate which SDK to use" "$git_sdk_path"

		test "z$git_sdk_path" != "z${git_sdk_path%.git}" ||
		git_sdk_path="$git_sdk_path.git"
		git clone --depth 1 --bare https://github.com/git-for-windows/$SDK_REPO "$git_sdk_path"
	fi

	test full-sdk != "$mode" || {
		mkdir -p "$output_path" &&
		git -C "$git_sdk_path" archive --format=tar HEAD -- ':(exclude)ssl' |
		xz -9 >"$output_path"/$SDK_REPO.tar.xz &&
		echo "$SDK_REPO.tar.xz written to '$output_path'" >&2 ||
		die "Could not write $SDK_REPO.tar.xz to '%s'\n" "$output_path"
		return 0
	}

	git -C "$git_sdk_path" config core.repositoryFormatVersion 1 &&
	git -C "$git_sdk_path" config extensions.worktreeConfig true &&
	git -C "$git_sdk_path" worktree add --detach --no-checkout "$output_path" HEAD &&
	sparse_checkout_file="$(git -C "$output_path" rev-parse --git-path info/sparse-checkout)" &&
	git -C "$output_path" config --worktree core.sparseCheckout true &&
	git -C "$output_path" config --worktree core.bare false &&
	mkdir -p "${sparse_checkout_file%/*}" &&
	case "$mode" in
	build-installers)
		cat <<-\EOF >"$sparse_checkout_file"
		# Minimal `sh`
		/git-cmd.exe
		/usr/bin/sh.exe
		/usr/bin/msys-2.0.dll
		/etc/nsswitch.conf

		# Pacman
		/usr/bin/pacman.exe
		/usr/bin/pactree.exe
		/usr/bin/msys-gpg*.dll
		/usr/bin/gpg.exe
		/usr/bin/gpgconf.exe
		/usr/bin/msys-gcrypt*.dll
		/usr/bin/msys-z.dll
		/usr/bin/msys-sqlite*.dll
		/usr/bin/msys-bz2*.dll
		/usr/bin/msys-assuan*.dll
		/etc/pacman*
		/usr/ssl/certs/ca-bundle.crt
		/usr/share/pacman/
		/var/lib/pacman/local/

		# Some other utilities required by `make-file-list.sh`
		/usr/bin/cat.exe
		/usr/bin/dirname.exe
		/usr/bin/grep.exe
		/usr/bin/ls.exe
		/usr/bin/rm.exe
		/usr/bin/sed.exe
		/usr/bin/sort.exe
		/usr/bin/uniq.exe
		/usr/bin/msys-iconv-*.dll
		/usr/bin/msys-intl-*.dll
		/usr/bin/msys-pcre*.dll
		/usr/bin/msys-gcc_s-*.dll

		# markdown, to render the release notes
		/usr/bin/markdown

		# Files to include into the installer/Portable Git/MinGit
		EOF
		git -C "$output_path" checkout -- &&
		mkdir -p "$output_path/tmp" &&
		printf 'export MSYSTEM=%s\nexport PATH=%s/bin:/usr/bin/:/usr/bin/core_perl:/c/WINDOWS/system32:/c/WINDOWS:/c/WINDOWS/System32/Wbem\n' "$MSYSTEM" "$PREFIX" >"$output_path/etc/profile" &&
		mkdir -p "${output_path}${PREFIX}/bin" &&
		case $architecture in
		i686)
			# copy git.exe, for the libssp test
			git -C "$output_path" show HEAD:mingw32/bin/git.exe \
				>"$output_path/mingw32/bin/git.exe" &&
			ARCH=i686 "$output_path/git-cmd.exe" --command=usr\\bin\\sh.exe -lx \
			"${this_script_path%/*}/make-file-list.sh" |
			# escape the `[` in `[.exe`
			sed -e 's|[][]|\\&|g' >>"$sparse_checkout_file" &&
			if git -C "$git_sdk_path" rev-parse -q --verify HEAD:.sparse/makepkg-git >/dev/null
			then
				printf '\n' >>"$sparse_checkout_file" &&
				git -C "$git_sdk_path" show HEAD:.sparse/makepkg-git >>"$sparse_checkout_file"
			else
				cat <<-EOF >>"$sparse_checkout_file"

				# For code-signing
				/mingw32/bin/osslsigncode.exe
				/mingw32/bin/libgsf-[0-9]*.dll
				/mingw32/bin/libglib-[0-9]*.dll
				/mingw32/bin/libgobject-[0-9]*.dll
				/mingw32/bin/libgio-[0-9]*.dll
				/mingw32/bin/libxml2-[0-9]*.dll
				/mingw32/bin/libgmodule-[0-9]*.dll
				/mingw32/bin/libzstd*.dll
				/mingw32/bin/libffi-[0-9]*.dll
				EOF
			fi
			;;
		*)
			git -C "$git_sdk_path" show HEAD:.sparse/minimal-sdk >"$sparse_checkout_file" &&
			printf '\n' >>"$sparse_checkout_file" &&
			git -C "$git_sdk_path" show HEAD:.sparse/makepkg-git >>"$sparse_checkout_file" &&
			if test x86_64 = $architecture
			then
				printf '\n' >>"$sparse_checkout_file" &&
				git -C "$git_sdk_path" show HEAD:.sparse/makepkg-git-i686 >>"$sparse_checkout_file"
			fi &&
			printf '\n# markdown, to render the release notes\n/usr/bin/markdown\n\n' >>"$sparse_checkout_file" &&
			ARCH=$architecture "$output_path/git-cmd.exe" --command=usr\\bin\\sh.exe -l \
			"${this_script_path%/*}/make-file-list.sh" | sed -e 's|[][]|\\&|g' -e 's|^|/|' >>"$sparse_checkout_file"
			;;
		esac &&
		rm "$output_path/etc/profile" &&
		cat <<-EOF >>"$sparse_checkout_file" &&

		# 7-Zip
		/usr/bin/7za
		/usr/lib/p7zip/7za.exe
		/usr/bin/msys-stdc++-*.dll

		# WinToast
		$PREFIX/bin/wintoast.exe

		# BusyBox
		$PREFIX/bin/busybox.exe
		EOF
		mkdir -p "$output_path/.sparse" &&
		cp "$sparse_checkout_file" "$output_path/.sparse/build-installers"
		;;
	*)
		git -C "$git_sdk_path" show HEAD:.sparse/minimal-sdk >"$sparse_checkout_file" &&
		if test makepkg-git = $mode
		then
			printf '\n' >>"$sparse_checkout_file" &&
			git -C "$git_sdk_path" show HEAD:.sparse/$mode >>"$sparse_checkout_file" &&
			if test x86_64 = $architecture
			then
				printf '\n' >>"$sparse_checkout_file" &&
				git -C "$git_sdk_path" show HEAD:.sparse/$mode-i686 >>"$sparse_checkout_file"
			fi
		fi
		;;
	esac &&
	git -C "$output_path" checkout -- &&
	if test ! -f "$output_path/etc/profile"
	then
		if test minimal-sdk = $mode
		then
			printf 'export MSYSTEM=%s\nexport PATH=%s/bin:/usr/bin/:/usr/bin/core_perl:/c/WINDOWS/system32:/c/WINDOWS:/c/WINDOWS/System32/Wbem\n' "$MSYSTEM" "$PREFIX" >"$output_path/etc/profile"
		elif test makepkg-git = $mode
		then
			cat >"$output_path/etc/profile" <<-\EOF
			case "$SYSTEMROOT" in
			[A-Za-z]:*)
					SYSTEMROOT_MSYS=/${SYSTEMROOT%%:*}${SYSTEMROOT#?:}
					SYSTEMROOT_MSYS=${SYSTEMROOT_MSYS//\\/\/}
					;;
			*)
					SYSTEMROOT_MSYS=${SYSTEMROOT//\\/\/}
					;;
			esac

			if test MSYS = "$MSYSTEM"
			then
					PATH=/usr/bin:/usr/bin/core_perl:$SYSTEMROOT_MSYS/system32:$SYSTEMROOT_MSYS
			elif test CLANGARM64 = "$MSYSTEM"
			then
					PATH=/clangarm64/bin:/usr/bin:/usr/bin/core_perl:$SYSTEMROOT_MSYS/system32:$SYSTEMROOT_MSYS
			elif test MINGW32 = "$MSYSTEM"
			then
					PATH=/mingw32/bin:/mingw64/bin:/usr/bin:/usr/bin/core_perl:$SYSTEMROOT_MSYS/system32:$SYSTEMROOT_MSYS
			else
					export MSYSTEM=MINGW64
					PATH=/mingw64/bin:/usr/bin:/usr/bin/core_perl:$SYSTEMROOT_MSYS/system32:$SYSTEMROOT_MSYS
			fi

			# These Cygwin-style pseudo symlinks are marked as system files
			# and that attribute cannot be preserved in .zip archives
			test -h /dev/fd || {
					ln -s /proc/self/fd /dev/
					test -h /dev/stdin || ln -s /proc/self/fd/0 /dev/stdin
					test -h /dev/stdout || ln -s /proc/self/fd/1 /dev/stdout
					test -h /dev/stderr || ln -s /proc/self/fd/2 /dev/stderr
			}
			EOF
		fi
	fi &&
	if test makepkg-git = $mode && test ! -x "$output_path/usr/bin/git"
	then
		printf '#!/bin/sh\n\nexec %s/bin/git.exe "$@"\n' \
			"/mingw$bitness" >"$output_path/usr/bin/git"
	fi &&
	if test makepkg-git = $mode && ! grep -q http://docbook.sourceforge.net/release/xsl-ns/current "$output_path/etc/xml/catalog"
	then
		# Slightly dirty workaround for missing docbook-xsl-ns
		(cd "$output_path/usr/share/xml/" &&
			test -d docbook-xsl-ns-1.78.1 ||
			curl -L https://sourceforge.net/projects/docbook/files/docbook-xsl-ns/1.78.1/docbook-xsl-ns-1.78.1.tar.bz2/download |
			tar xjf -) &&
		sed -i -e 's|C:/git-sdk-64-ci||g' -e '/<\/catalog>/i\
  <rewriteSystem systemIdStartString="http://docbook.sourceforge.net/release/xsl-ns/current" rewritePrefix="/usr/share/xml/docbook-xsl-ns-1.78.1"/>\
  <rewriteURI uriStartString="http://docbook.sourceforge.net/release/xsl-ns/current" rewritePrefix="/usr/share/xml/docbook-xsl-ns-1.78.1"/>' \
			"$output_path/etc/xml/catalog"
	fi &&
	if test -z "$keep_worktree"
	then
		rm -r "$(cat "$output_path/.git" | sed 's/^gitdir: //')" &&
		rm "$output_path/.git"
	fi &&
	echo "Output written to '$output_path'" >&2 ||
	die "Could not write artifact at '%s'\n" "$output_path"
}

find_mspdb_dll () { #
	for v in 140 120 110 100 80
	do
		type -p mspdb$v.dll 2>/dev/null && return 0
	done
	return 1
}

build_mingw_w64_git () { # [--only-i686] [--only-x86_64] [--only-aarch64] [--skip-test-artifacts] [--skip-doc-man] [--skip-doc-html] [--force] [<revision>]
	output_path=
	sed_makepkg_e=
	force=
	src_pkg=
	while case "$1" in
	--only-i686|--only-32-bit)
		MINGW_ARCH=mingw32
		export MINGW_ARCH
		;;
	--only-x86_64|--only-64-bit)
		MINGW_ARCH=mingw64
		export MINGW_ARCH
		;;
	--only-aarch64)
		MINGW_ARCH=clangarm64
		export MINGW_ARCH
		;;
	--skip-test-artifacts)
		sed_makepkg_e="$sed_makepkg_e"' -e s/"\${MINGW_PACKAGE_PREFIX}-\${_realname}-test-artifacts"//'
		;;
	--skip-doc-man)
		sed_makepkg_e="$sed_makepkg_e"' -e s/"\${MINGW_PACKAGE_PREFIX}-\${_realname}-doc-man"//'
		;;
	--skip-doc-html)
		sed_makepkg_e="$sed_makepkg_e"' -e s/"\${MINGW_PACKAGE_PREFIX}-\${_realname}-doc-html"//'
		;;
	--build-src-pkg)
		src_pkg=t
		;;
	--force)
		force=--force
		;;
	--out|--output|-o)
		shift
		output_path="$(cygpath -am "$1")" || exit
		;;
	--out=*|--output=*|-o=*)
		output_path="$(cygpath -am "${1#*=}")" || exit
		;;
	-o*)
		output_path="$(cygpath -am "${1#-?}")" || exit
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# -le 1 ||
	die "Expected at most one argument, got $#: %s\n" "$*"

	git_src_dir="/usr/src/MINGW-packages/mingw-w64-git/src/git"
	test -d ${git_src_dir%/src/git} ||
	git clone --depth 1 --single-branch -b main https://github.com/git-for-windows/MINGW-packages /usr/src/MINGW-packages ||
	die "Could not clone MINGW-packages\n"

	tag="$(git for-each-ref --count=1 --sort=-taggerdate --format '%(refname:short)' --points-at="${1:-HEAD}" 'refs/tags/v[0-9]*')"
	test -n "$tag" || {
		tag=$(git describe --match=v* "${1:-HEAD}" | sed 's/-.*//').$(date +%Y%m%d%H%M%S) &&
		git tag $tag "${1:-HEAD}"
	} ||
	die "Could not create tag\n"

	test -d ${git_src_dir%/src/git}/git ||
	git clone --bare https://github.com/git-for-windows/git.git ${git_src_dir%/src/git}/git ||
	die "Could not initialize %s\n" ${git_src_dir%/src/git}/git

	sed -e "s/^tag=.*/tag=${tag#v}/" $sed_makepkg_e <${git_src_dir%/src/git}/PKGBUILD >${git_src_dir%/src/git}/PKGBUILD.$tag ||
	die "Could not write %s\n" ${git_src_dir%/src/git}/PKGBUILD.$tag

	case "$tag" in
	*[-:/\ ]*)
		# This is a prerelease
		sed -i -e '/^pkgver *() {/,/^}$/s/^/# /' \
			-e 's/^\(pkgver=\).*/\1'"$(echo "${tag#v}" | tr ':/ -' .)"/ \
			${git_src_dir%/src/git}/PKGBUILD.$tag
		;;
	esac

	test -d ${git_src_dir%/src/git}/git ||
	git clone --bare https://github.com/git-for-windows/git.git ${git_src_dir%/src/git}/git ||
	die "Could not initialize %s\n" ${git_src_dir%/src/git}/git

	test -d $git_src_dir || {
		git -c core.autoCRLF=false clone --reference ${git_src_dir%/src/git}/git https://github.com/git-for-windows/git $git_src_dir &&
		git -C $git_src_dir config core.autoCRLF false
	} ||
	die "Could not initialize %s\n" $git_src_dir

	git push $git_src_dir $tag ||
	die "Could not push %s\n" $tag

	# Work around bug where the incorrect xmlcatalog.exe wrote /etc/xml/catalog
	sed -i -e 's|C:/git-sdk-64-ci||g' /etc/xml/catalog

	test true = "$GITHUB_ACTIONS" || # GitHub Actions' agents have the mspdb.dll, and cv2pdb finds it
	test -n "$SYSTEM_COLLECTIONURI$SYSTEM_TASKDEFINITIONSURI" || # Same for Azure Pipelines
	test "$MINGW_ARCH" = "clangarm64" || # We don't need cv2pdb when compiling using Clang/LLVM
	find_mspdb_dll >/dev/null || {
		WITHOUT_PDBS=1
		export WITHOUT_PDBS
	}

	(if test -n "$(git config alias.signtool)"
	 then
		d="$(git rev-parse --absolute-git-dir)"
		export SIGNTOOL="git ${d:+--git-dir="$d"} signtool"
	 fi &&
	 cd ${git_src_dir%/src/git}/ &&
	 MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} makepkg-mingw -s --noconfirm $force -p PKGBUILD.$tag &&
	 if test -n "$src_pkg"
	 then
		git -C git repack -adf &&
		MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} MINGW_ARCH=mingw64 makepkg-mingw $force --allsource -p PKGBUILD.$tag
	 fi) ||
	die "Could not build mingw-w64-git\n"

	test -z "$output_path" || {
		pkgpattern="$(sed -n '/^pkgver=/{N;s/pkgver=\(.*\).pkgrel=\(.*\)/\1-\2/p}' <${git_src_dir%/src/git}/PKGBUILD.$tag)" &&
		mkdir -p "$output_path" &&
		{ test -z "$src_pkg" || cp ${git_src_dir%/src/git}/*-"$pkgpattern".src.tar.gz "$output_path/"; } &&
		cp ${git_src_dir%/src/git}/*-"$pkgpattern"-any.pkg.tar.xz ${git_src_dir%/src/git}/PKGBUILD.$tag "$output_path/"
	} ||
	die "Could not copy artifact(s) to %s\n" "$output_path"
}

# This function does not "clean up" after installing the packages
make_installers_from_mingw_w64_git () { # [--pkg=<package>[,<package>...]] [--version=<version>] [--installer] [--portable] [--mingit] [--mingit-busybox] [--nuget] [--nuget-mingit] [--archive] [--include-arm64-artifacts=<path>]
	modes=
	install_package=
	output=
	output_path=
	version=0-test
	include_arm64_artifacts=
	include_pdbs=
	while case "$1" in
	--pkg=*)
		install_package="${install_package:+$install_package }$(echo "${1#*=}" | tr , ' ')"
		for file in ${1#*=}
		do
			candidate="$(echo $file | sed -n 's/.*git-\([0-9][.0-9a-f]*\).*/\1/p')"
			test 0-test != "$version" || test -z "$candidate" || version="$candidate"
		done
		;;
	--pkg)
		shift
		install_package="${install_package:+$install_package }$(echo "$1" | tr , ' ')"
		for file in $1
		do
			candidate="$(echo $file | sed -n 's/.*git-\([0-9][.0-9a-f]*\).*/\1/p')"
			test 0-test != "$version" || test -z "$candidate" || version="$candidate"
		done
		;;
	--version)
		shift
		version=$1
		;;
	--version=*)
		version=${1#*=}
		;;
	--installer|--portable|--mingit|--mingit-busybox|--nuget|--nuget-mingit|--archive)
		modes="${modes:+$modes }${1#--}"
		;;
	--only-installer|--only-portable|--only-mingit|--only-mingit-busybox|--only-nuget|--only-nuget-mingit|--only-archive)
		modes="${1#--only-}"
		;;
	--out|--output|-o)
		shift
		output_path="$(cygpath -am "$1")"
		output="--output=$output_path" || exit
		;;
	--out=*|--output=*|-o=*)
		output_path="$(cygpath -am "${1#*=}")"
		output="--output=$output_path" || exit
		;;
	-o*)
		output_path="$(cygpath -am "${1#-?}")"
		output="--output=$output_path" || exit
		;;
	--include-arm64-artifacts=*)
		include_arm64_artifacts="$1"
		;;
	--include-pdbs)
		include_pdbs=--include-pdbs
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# -eq 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	test -n "$modes" ||
	modes=installer

	mkdir -p "$output_path" ||
	die "Could not make '%s/'\n" "$output_path"

	test -z "$install_package" || {
		eval pacman -U --noconfirm --overwrite=\\\* $install_package &&
		(. /var/lib/pacman/local/*-git-extra-*/install && post_install)
	} ||
	die "Could not install packages: %s\n" "$install_package"

	for mode in $modes
	do
		extra=

		test mingit-busybox != $mode || {
			mode=mingit
			extra="${extra:+$extra }--busybox"
		}

		test nuget-mingit != $mode || {
			mode=nuget
			extra="${extra:+$extra }--mingit"
		}

		test installer != $mode ||
		extra="${extra:+$extra }--window-title-version=$version"

		sh -x "${this_script_path%/*}/$mode/release.sh" $output $include_pdbs $extra $include_arm64_artifacts $version
	done
}

# This function can build a given package in the current SDK and copy the result into a specified directory
build_and_copy_artifacts () { # --directory=<artifacts-directory> [--force] [--cleanbuild] <package>
	artifactsdir=
	force=
	cleanbuild=
	while case "$1" in
	--directory=*)
		artifactsdir="$(cygpath -am "${1#*=}")" || exit
		test -d "$artifactsdir" ||
		mkdir "$artifactsdir" ||
		die "Could not create artifacts directory: %s\n" "$artifactsdir"
		;;
	--directory)
		shift
		artifactsdir="$(cygpath -am "$1")" || exit
		test -d "$artifactsdir" ||
		mkdir "$artifactsdir" ||
		die "Could not create artifacts directory: %s\n" "$artifactsdir"
		;;
	-f|--force)
		force=--force
		;;
	--cleanbuild)
		cleanbuild=--cleanbuild
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	test -n "$artifactsdir" ||
	die "Need a directory to copy the artifacts to\n"

	set_package "$1" &&

	cd "$pkgpath" &&
	sdk= pkg_build $force $cleanbuild &&
	sdk= pkg_copy_artifacts ||
	die "Could not copy artifacts for '%s' to '%s'\n" "$package" "$artifactsdir"
}

this_script_path="$(cd "$(dirname "$0")" && echo "$(pwd -W)/$(basename "$0")")" ||
die "Could not determine this script's path\n"

test $# -gt 0 &&
test help != "$*" ||
die "Usage: $0 <command>\n\nCommands:\n%s" \
	"$(sed -n 's/^\([a-z_]*\) () { #\(.*\)/\t\1\2/p' <"$0")"

command="$1"
shift

test "a$command" = "a${command#*-}" ||
command="$(echo "$command" | tr - _)"

usage="$(sed -n "s/^$command () { # \?/ /p" <"$0")"
test -n "$usage" ||
die "Unknown command: %s\n" "$command"

case "$usage" in
*'['*)
	test $# -ge $(echo "$usage" | sed -e 's/\[[^]]*\]//g' | tr -dc '<' |
		wc -c)
	;;
*)
	test $# = $(echo "$usage" | tr -dc '<' | wc -c)
	;;
esac ||
die "Usage: %s %s%s\n" "$0" "$command" "$usage"

"$command" "$@"

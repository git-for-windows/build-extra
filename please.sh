#!/bin/sh

# This script is meant to help maintain Git for Windows. It automates large
# parts of the release engineering.
#
# The major trick is to be able to update and build 32-bit as well as 64-bit
# packages. This is particularly problematic when trying to update files that
# are in use, such as msys-2.0.dll or bash.exe. To that end, this script is
# intended to run from a *separate* Bash, such as Git Bash.
#
# Common workflows:
#
# 1) release a new Git version
#
#	<make sure that Git for Windows' 'master' reflects the new version>
#	./please.sh sync
#	./please.sh finalize release-notes
#	./please.sh tag_git
#	./please.sh build git
#	./please.sh install git
#	./please.sh test_git 64
#	./please.sh upload git
#	./please.sh release
#	./please.sh publish
#
# 2) release a new Pacman package, e.g. git-extra or msys2-runtime
#
#	./please.sh sync
#	<make sure that the 'master' branch reflects the new version>
#	./please.sh build git-extra
#	./please.sh install git-extra
#	<verify that everything's alright>
#	./please.sh upload git-extra

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

# In MinGit, there is no `cygpath`...
# We really only use -w, -am and -au in please.sh, so that's what we
# support here

cygpath () {
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
	result="$(git config windows.sdk"$1".path)" && test -n "$result" || {
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

info () { #
	is_independent_shell && warning= ||
	warning="WARNING: Current shell is not independent"

	printf "%s\n%s\n%s" \
		"Git for Windows 64-bit SDK: $sdk64" \
		"Git for Windows 32-bit SDK: $sdk32" \
		"$warning"
}

prepare_keep_despite_upgrade () { # <sdk-path>
	keep_despite_upgrade="$(cat "${this_script_path%/*}/keep-despite-upgrade.txt")" ||
	die 'Could not read keep-despite-upgrade.txt\n'

	case "$keep_despite_upgrade" in *' '*) die 'keep-despite-upgrade.txt contains spaces!\n';; esac

	test "$sdk64" = "$1" ||
	keep_despite_upgrade="$(echo "$keep_despite_upgrade" | sed '/^mingw64/d')"

	rm -rf "$1/.keep" &&
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
		cp -Ru "$2/.keep/"* "$2/"
		return $?
	}

	cp -Ru "$1/.keep/"* "$1/" &&
	rm -rf "$1/.keep"
}

sync () { # [--force]
	force=
	y_opt=y
	while case "$1" in
	--force)
		force='--overwrite=\*'
		y_opt=yy
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	export MSYSTEM=msys
	export MSYS2_PATH_TYPE=minimal
	for sdk in "$sdk32" "$sdk64"
	do
		mkdir -p "$sdk/var/log" ||
		die "Could not ensure %s/var/log/ exists\n" "$sdk"

		remove_obsolete_packages ||
		die "Could not remove obsolete packages\n"

		"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -lc \
			"pacman.exe -S$y_opt" ||
		die "Cannot run pacman in %s\n" "$sdk"

		prepare_keep_despite_upgrade "$sdk" ||
		die 'Could not keep files as planned\n'

		"$sdk/git-cmd.exe" --cd="$sdk" --command=usr\\bin\\bash.exe \
			-lc 'pacman.exe -Su '$force' --noconfirm' ||
		die "Could not update packages in %s\n" "$sdk"

		"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -l -c '
			pacman-key --list-keys BB3AA74136C569BB >/dev/null ||
			pacman-key --populate git-for-windows' ||
		die "Could not re-populate git-for-windows-keyring\n"

		process_keep_despite_upgrade --keep "$sdk" ||
		die 'Could not copy back files-to-keep\n'

		case "$(tail -c 16384 "$sdk/var/log/pacman.log" |
			grep '\[PACMAN\] starting .* system upgrade' |
			tail -n 1)" in
		*"full system upgrade")
			;; # okay
		*)
			# only "core" packages were updated, update again
			"$sdk/git-cmd.exe" --cd="$sdk" \
				--command=usr\\bin\\bash.exe -l \
				-c 'pacman -Su '$force' --noconfirm' ||
			die "Cannot update packages in %s\n" "$sdk"

			process_keep_despite_upgrade --keep "$sdk" ||
			die 'Could not copy back files-to-keep\n'

			"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -l -c '
				pacman-key --list-keys BB3AA74136C569BB \
					>/dev/null ||
				pacman-key --populate git-for-windows' ||
			die "Could not re-populate git-for-windows-keyring\n"
			;;
		esac

		process_keep_despite_upgrade "$sdk" ||
		die 'Could not copy back files-to-keep\n'

		# A ruby upgrade (or something else) may require a re-install
		# of the `asciidoctor` gem. We only do this for the 64-bit
		# SDK, though, as we require asciidoctor only when building
		# Git, whose 32-bit packages are cross-compiled in from 64-bit.
		test "$sdk64" != "$sdk" ||
		"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -l -c \
			'test -n "$(gem list --local | grep "^asciidoctor ")" ||
			 gem install asciidoctor || exit;
			 export PATH=/mingw32/bin:$PATH;
			 test -n "$(gem list --local | grep "^asciidoctor ")" ||
			 gem install asciidoctor' ||
		die "Could not re-install asciidoctor in %s\n" "$sdk"

		# git-extra rewrites some files owned by other packages,
		# therefore it has to be (re-)installed now
		"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -l -c \
			'pacman -S '$force' --noconfirm git-extra' ||
		die "Cannot update git-extra in %s\n" "$sdk"

		pacnew="$(sed -ne '/starting core system upgrade/{
			:1;
			s/.*/WAIT/;x
			:2;
			n;
			/warning:.*installed as .*\.pacnew$/{s/.* as //;H;b2}
			/starting full system upgrade/{x;s/WAIT//;x;b2}
			/starting core system upgrade/{x;/WAIT/{x;b2};b1}
			${x;s/WAIT//;s/^\n//;/./p}
			b2;
			}' <"$sdk"/var/log/pacman.log)" ||
		die "Could not get list of .pacnew files\n"
		if test -n "$pacnew"
		then
			# Make sure we have the git-extra package locally, as
			# one of the .pacnew files could be pacman.conf, and
			# replacing it removes the link to Git for Windows'
			# Pacman repository
			"$sdk/git-cmd.exe" --command=usr\\bin\\bash.exe -l -c \
			   'pkg=/var/cache/pacman/pkg/$(pacman -Q git-extra |
				tr \  -)*.pkg.tar.xz
			    test -f $pkg || {
				pacman -Sw --noconfirm git-extra &&
				test -f $pkg || {
					echo "Could not cache $pkg" >&2
					exit 1
				}
			    }
			    for f in '"$(echo "$pacnew" | tr '\n' ' ')"'
			    do
				test ! -f $f ||
				mv -f $f ${f%.pacnew} || {
					echo "Could not rename $f" >&2
					exit 1
				}
			    done
			    pacman -U --noconfirm '$force' $pkg || {
				echo "Could not reinstall $pkg" >&2
				exit 1
			    }' ||
			die "Could not handle .pacnew files\n"
		fi
	done
}

run () { # <bitness> <command> [<arg>...]
	test 32 = "$1" || test 64 = "$1" || die "Which bitness?\n"

	sdk="$(eval "echo \$sdk$1")"
	shift

	cmdline=eval
	for arg
	do
		cmdline="$cmdline '$(echo "$arg" | sed -e "s/'/&\\\\&&/g")'"
	done

	"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c "$cmdline"
}

killall () { # <bitness>
	sdk="$(eval "echo \$sdk$1")"

	pids="$("$sdk/git-cmd.exe" --command=usr\\bin\\ps.exe -s |
		grep -v ' /usr/bin/ps$' |
		sed -n "s/^ *\([0-9][0-9]*\).*/\1/p")"
	test -z "$pids" ||
	"$sdk/git-cmd.exe" --command=usr\\bin\\kill.exe $pids
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
	git-extra)
		type=MINGW
		pkgpath=/usr/src/build-extra/$package
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
		extra_packages="bash-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	heimdal)
		type=MSYS
		extra_packages="heimdal-libs heimdal-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	perl)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		extra_makepkg_opts=--nocheck
		;;
	perl-Net-SSLeay|perl-HTML-Parser|perl-TermReadKey|perl-Locale-Gettext|perl-XML-Parser|perl-YAML-Syck)
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
	gnupg)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	*)
		die "Unknown package: %s\n" "$package"
		;;
	esac
}

# foreach_sdk <function> [<args>]
foreach_sdk () {
	# Run function in 32-bit/64-bit SDKs (only 64-bit for MINGW packages)
	for sdk in "$sdk32" "$sdk64"
	do
		# MINGW packages are compiled in the 64-bit SDK only
		test "a$sdk64" = "a$sdk" ||
		test MINGW != "$type" ||
		continue

		(cd "$sdk/$pkgpath" ||
		 die "%s does not exist\n" "$sdk/$pkgpath"

		 "$@") ||
		die "Could not run '%s' in '%s'\n" "$*" "$sdk"
	done
}

require_clean_worktree () {
	git update-index -q --ignore-submodules --refresh &&
	git diff-files --quiet --ignore-submodules &&
	git diff-index --cached --quiet --ignore-submodules HEAD ||
	die "%s not up-to-date\n" "$sdk/$pkgpath"
}

ff_master () {
	test refs/heads/master = "$(git rev-parse --symbolic-full-name HEAD)" ||
	die "%s: Not on 'master'\n" "$sdk/$pkgpath"

	require_clean_worktree

	git pull --ff-only origin master ||
	die "%s: cannot fast-forward 'master'\n" "$sdk/$pkgpath"
}

update () { # <package>
	if test git != "$1" && test -d "$sdk64"/usr/src/"$1"
	then
		pkgpath=/usr/src/"$1"
	else
		set_package "$1"
	fi

	foreach_sdk ff_master
}

remove_obsolete_packages () {
	test "a$sdk" = "a$sdk32" &&
	arch=i686 ||
	arch=x86_64

	for p in mingw-w64-$arch-curl-winssl-bin
	do
		test ! -d "$sdk"/var/lib/pacman/local/$p-[0-9]* ||
		"$sdk"/git-cmd.exe --command=usr\\bin\\pacman.exe \
			-R --noconfirm $p ||
		die "Could not remove %s\n" "$p"
	done
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
			'MAKEFLAGS=-j5 MINGW_INSTALLS=mingw32\ mingw64 \
				'"$extra"'makepkg-mingw -s --noconfirm \
					'"$extra_makepkg_opts"' &&
			 if test mingw-w64-git = "'"$package"'"
			 then
				git -C src/git push "$PWD/git" \
					refs/tags/"'"$tag"'"
			 fi &&
			 MINGW_INSTALLS=mingw64 makepkg-mingw --allsource \
				'"$extra_makepkg_opts" ||
		die "%s: could not build\n" "$sdk/$pkgpath"

		git update-index -q --refresh &&
		git diff-files --quiet --ignore-submodules PKGBUILD ||
		git commit -s -m "$package: new version" PKGBUILD ||
		die "%s: could not commit after build\n" "$sdk/$pkgpath"
		;;
	MSYS)
		require msys2-devel binutils
		if test msys2-runtime = "$package"
		then
			require mingw-w64-cross-crt-git mingw-w64-cross-gcc
			test ! -d msys2-runtime ||
			(cd msys2-runtime && git fetch) ||
			die "Could not fetch from origin"
			test ! -d src/msys2-runtime/.git ||
			(cd src/msys2-runtime &&
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
			 export PATH=/usr/bin:/opt/bin:$PATH &&
			 unset ORIGINAL_PATH &&
			 . /etc/profile &&
			 MAKEFLAGS=-j5 makepkg -s --noconfirm \
				'"$extra_makepkg_opts"' &&
			 makepkg --allsource '"$extra_makepkg_opts" ||
		die "%s: could not build\n" "$sdk/$pkgpath"

		if test "a$sdk32" = "a$sdk"
		then
			git update-index -q --refresh &&
			git diff-files --quiet --ignore-submodules PKGBUILD ||
			git commit -s -m "$package: new version" PKGBUILD ||
			die "%s: could not commit after build\n" "$sdk/$pkgpath"
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
		git -C "$1" fetch "$2" refs/heads/master
	else
		git -C "$1" fetch "$2"/.. refs/heads/master
	fi &&
	git -C "$1" merge --ff-only "$3" &&
	test "a$3" = "a$(git -C "$1" rev-parse --verify HEAD)"
}

# up_to_date <path>
up_to_date () {
	# test that repos at <path> are up-to-date in both 64-bit and 32-bit
	pkgpath="$1"

	foreach_sdk require_clean_worktree

	commit32="$(cd "$sdk32/$pkgpath" && git rev-parse --verify HEAD)" &&
	commit64="$(cd "$sdk64/$pkgpath" && git rev-parse --verify HEAD)" ||
	die "Could not determine HEAD commit in %s\n" "$pkgpath"

	if test "a$commit32" != "a$commit64"
	then
		fast_forward "$sdk32/$pkgpath" "$sdk64/$pkgpath" "$commit64" ||
		fast_forward "$sdk64/$pkgpath" "$sdk32/$pkgpath" "$commit32" ||
		die "%s: commit %s (32-bit) != %s (64-bit)\n" \
			"$pkgpath" "$commit32" "$commit64"
	fi
}

build () { # [--force] [--cleanbuild] <package>
	force=
	cleanbuild=
	while case "$1" in
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

	set_package "$1"
	extra_makepkg_opts="$extra_makepkg_opts $force $cleanbuild"

	test MINGW = "$type" ||
	up_to_date "$pkgpath" ||
	die "%s: not up-to-date\n" "$pkgpath"

	foreach_sdk pkg_build $force $cleanbuild ||
	die "Could not build '%s'\n" "$package"
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
		case "$(git config http."$url".extraheader)" in
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

record_rerere_train () {
	conflicts="$(git ls-files --unmerged)" &&
	test -n "$conflicts" ||
	die "No merge conflicts?!?\n"

	commit="$(git rev-parse -q --verify refs/heads/rerere-train)" ||
	commit="$(git rev-parse -q --verify \
		refs/remotes/git-for-windows/rerere-train)"
	if test -z "$GIT_INDEX_FILE"
	then
		GIT_INDEX_FILE="$(git rev-parse --git-path index)"
	fi &&
	orig_index="$GIT_INDEX_FILE" &&
	(GIT_INDEX_FILE="$orig_index.tmp" &&
	 export GIT_INDEX_FILE &&

	 for stage in 1 2 3
	 do
		cp "$orig_index" "$GIT_INDEX_FILE" &&
		echo "$conflicts" |
		sed -n "s/^\\([^ ]* [^ ]* \\)$stage/\\10/p" |
		git update-index --index-info &&
		git ls-files --unmerged |
		sed -n "s/^[^ ]*/0/p" |
		git update-index --index-info &&
		eval tree$stage="$(git write-tree)" ||
		die "Could not write tree %s\n" "$stage"
	 done &&
	 cp "$orig_index" "$GIT_INDEX_FILE" &&
	 git add -u &&
	 tree4="$(git write-tree)" &&
	 if ! stopped_sha="$(git rev-parse --git-path \
			rebase-merge/stopped-sha)" ||
		! stopped_sha="$(cat "$stopped_sha")"
	 then
		stopped_sha="$(git rev-parse -q --verify MERGE_HEAD)"
	 fi &&
	 base_msg="$(printf "cherry-pick %s onto %s\n\n%s\n%s\n\n\t%s" \
		"$(git show -s --pretty=tformat:%h $stopped_sha)" \
		"$(git show -s --pretty=tformat:%h HEAD)" \
		"This commit helps to teach \`git rerere\` to resolve merge " \
		"conflicts when cherry-picking:" \
		"$(whatis $stopped_sha)")" &&
	 commit=$(git commit-tree ${commit:+-p} $commit \
		-m "base: $base_msg" $tree1) &&
	 commit2=$(git commit-tree -p $commit -m "pick: $base_msg" $tree3) &&
	 commit=$(git commit-tree -p $commit -m "upstream: $base_msg" $tree2) &&
	 commit=$(git commit-tree -p $commit -p $commit2 \
		-m "resolve: $base_msg" $tree4) &&
	 git update-ref -m "$base_msg" refs/heads/rerere-train $commit) || exit

	git add -u &&
	git rerere
}

rerere_train () {
	git rev-list --reverse --parents "$@" |
	while read commit parent1 parent2 rest
	do
		test -n "$parent2" && test -z "$rest" || continue

		printf "Learning merge conflict resolution from %s\n" \
			"$(whatis "$commit")" >&2

		(GIT_CONFIG_PARAMETERS="$GIT_CONFIG_PARAMETERS${GIT_CONFIG_PARAMETERS:+ }'rerere.enabled=true'" &&
		 export GIT_CONFIG_PARAMETERS &&
		 worktree="$(git rev-parse --git-path train)" &&
		 if test ! -d "$worktree"
		 then
			git worktree add "$worktree" "$parent1" ||
			die "Could not create worktree %s\n" "$worktree"
		 fi &&
		 cd "$worktree" &&
		 git checkout -f -q "$parent1" &&
		 git reset -q --hard &&
		 if git merge "$parent2" >/dev/null 2>&1
		 then
			echo "Nothing to be learned: no merge conflicts" >&2
		 else
			if ! test -s "$(git rev-parse --git-path MERGE_RR)"
			then
				git rerere forget -- . &&
				test -f "$(git rev-parse --git-path MERGE_RR)" ||
				die "Could not re-learn from %s\n" "$commit"
			fi

			git checkout -q "$commit" -- . &&
			git rerere ||
			die "Could not learn from %s\n" "$commit"
		 fi) || exit
	done
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
					checkout -t origin/master ||
				die "Could not check out %s\n" \
					"$mingw_packages_dir"
			fi
		fi
		(cd "${git_src_dir%/src/git}" &&
		 echo "Checking out Git (not making it)" >&2 &&
		 "$sdk64/git-cmd" --command=usr\\bin\\sh.exe -l -c \
			'makepkg-mingw --noconfirm -s -o') ||
		die "Could not initialize %s\n" "$git_src_dir"
	fi

	test ! -f "$git_src_dir/PKGBUILD" ||
	(cd "$git_src_dir/../.." &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "MINGW-packages not up-to-date\n"

	test false = "$(git -C "$git_src_dir" config core.autocrlf)" ||
	(cd "$git_src_dir" &&
	 git config core.autocrlf false &&
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

rebase () { # [--worktree=<dir>] [--test [--full-test-log] [--with-svn-tests]] ( -- jump | [--redo] [--abort-previous] [--continue | --skip] <upstream-branch-or-tag> )
	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	run_tests=
	redo=
	abort_previous=
	continue_rebase=
	skip_rebase=
	full_test_log=
	with_svn_tests=
	while case "$1" in
	--worktree=*)
		git_src_dir=${1#*=}
		test -d "$git_src_dir" ||
		die "Worktree does not exist: %s\n" "$git_src_dir"
		git rev-parse -q --verify e83c5163316f89bfbde7d ||
		die "Does not appear to be a Git checkout: %s\n" "$git_src_dir"
		;;
	--jump)
		test $# = 1 || test $# = 2 -a a"$2" = a"${2#-}" ||
		die "%s must be the last option\n" "--jump"

		cd "$git_src_dir" &&
		exec contrib/git-jump/git-jump merge ||
		die "Could not run git jump merge\n"
		;;
	--test) run_tests=t;;
	--full-test-log) full_test_log=--full-log;;
	--with-svn-tests) with_svn_tests=--with-svn-tests;;
	--redo) redo=t;;
	--abort-previous) abort_previous=t;;
	--continue) continue_rebase=t;;
	--skip) skip_rebase=t;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	test tt != "$skip_rebase$continue_rebase" ||
	die "Cannot continue *and* skip\n"

	# special-case master and maint: we will want full tests on those
	case "$1" in master|maint) with_svn_tests=--with-svn-tests;; esac

	sdk="$sdk64"

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update build-extra\n"

	require_git_src_dir

	(cd "$git_src_dir" &&
	 if is_rebasing && test -z "$continue_rebase$skip_rebase"
	 then
		if test -n "$abort_previous"
		then
			git rebase --abort ||
			die "Could not abort previous rebase\n"
		else
			die "Rebase already in progress.\n%s\n" \
				"Require --continue or --abort-previous."
		fi
	 fi &&

	 if ! is_rebasing
	 then
		test -z "$continue_rebase$skip_rebase" ||
		die "No rebase was started...\n"

		require_remote upstream https://github.com/git/git &&
		require_remote git-for-windows \
			https://github.com/git-for-windows/git &&
		require_push_url git-for-windows ||
		die "Could not update remotes\n"

		orig_rerere_train=
		if rerere_train2="$(git rev-parse -q --verify \
				refs/remotes/git-for-windows/rerere-train)" &&
			rerere_train="$(git rev-parse -q --verify \
				refs/heads/rerere-train)"
		then
			orig_rerere_train="$rerere_train.."

			test 0 -eq $(git rev-list --count \
				"$rerere_train2..$rerere_train") ||
			if test -z "$(git merge-base \
				"$rerere_train" "$rerere_train2")"
			then
				rm -r "$(git rev-parse --git-path rr-cache)" ||
				die "Could not reset rerere cache\n"
				git update-ref refs/heads/rerere-train \
					"$rerere_train2" ||
				die 'Could not reset `rerere-train` branch\n'
			else
				die 'The `%s` branch has unpushed changes\n' \
					rerere-train
			fi
		fi

		if test -n "$rerere_train2"
		then
			rerere_train "$orig_rerere_train$rerere_train2" ||
			die "Could not replay merge conflict resolutions\n"

			git push . $rerere_train2:refs/heads/rerere-train ||
			die "Could not update local 'rerere-train' branch\n"
		fi
	 fi &&
	 if ! onto=$(git rev-parse -q --verify refs/remotes/upstream/"$1" ||
		git rev-parse -q --verify refs/tags/"$1")
	 then
		die "No such upstream branch or tag: %s\n" "$1"
	 fi &&
	 if prev=$(git rev-parse -q --verify \
		refs/remotes/git-for-windows/shears/"$1") &&
		test 0 = $(git rev-list --count \
			^"$prev" git-for-windows/master $onto)
	 then
		if test -z "$redo"
		then
			echo "shears/$1 was already rebased" >&2
			exit 0
		fi
	 fi &&
	 GIT_CONFIG_PARAMETERS="$GIT_CONFIG_PARAMETERS${GIT_CONFIG_PARAMETERS:+ }'core.editor=touch' 'rerere.enabled=true' 'rerere.autoupdate=true' 'gc.auto=0'" &&
	 export GIT_CONFIG_PARAMETERS &&
	 if is_rebasing
	 then
		test 0 = $(git rev-list --count HEAD..$onto) ||
		die "Current rebase is not on top of %s\n" "$1"

		test -z "$skip_rebase" ||
		git diff HEAD | git apply -R ||
		test -z "$(git diff HEAD)" ||
		die "Could not skip current commit in rebase\n"

		# record rerere-train, update index & continue
		record_rerere_train
	 else
		git checkout git-for-windows/master &&
		if ! "$build_extra_dir"/shears.sh \
			-f --merging --onto "$onto" merging-rebase
		then
			is_rebasing ||
			die "shears aborted without starting the rebase\n"
		fi
	 fi &&
	 while is_rebasing && ! has_merge_conflicts
	 do
		test ! -f "$(git rev-parse --git-path MERGE_HEAD)" ||
		git commit ||
		die "Could not continue merge\n"

		git rebase --continue || true
	 done &&
	 if ! is_rebasing && test 0 -lt $(git rev-list --count "$onto"..)
	 then
		git push git-for-windows +HEAD:refs/heads/shears/"$1" ||
		die "Could not push shears/%s\n" "$1"
		if git rev-parse -q --verify refs/heads/rerere-train
		then
			git rev-parse -q --verify \
				refs/remotes/git-for-windows/rerere-train &&
			test 0 -eq $(git rev-list --count \
				refs/heads/rerere-train \
				^refs/remotes/git-for-windows/rerere-train) ||
			git push git-for-windows refs/heads/rerere-train ||
			die "Could not push rerere-train\n"
		fi
	 fi &&
	 if is_rebasing
	 then
		printf "There are merge conflicts:\n\n" >&2
		git diff >&2

		die "\nRebase needs manual resolution in:\n\n\t%s\n\n%s%s\n" \
			"$(pwd)" \
			"(Call \`please.sh rebase --continue $1\` to " \
			"contine, do *not* stage changes!"
	 else
		git gc &&
		git prune ||
		echo "WARNING: problems with garbage collection..." >&2

		if test -n "$run_tests"
		then
			echo "Building and testing Git" >&2 &&
			build_and_test_64 $full_test_log $with_svn_tests
		fi
	 fi) ||
	exit
}

test_remote_branch () { # [--worktree=<dir>] [--skip-tests] [--bisect-and-comment] [--full-log] [--with-svn-tests] <remote-tracking-branch> [<commit>]
	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	bisect_and_comment=
	skip_tests=
	full_log=
	with_svn_tests=
	while case "$1" in
	--worktree=*)
		git_src_dir=${1#*=}
		test -d "$git_src_dir" ||
		die "Worktree does not exist: %s\n" "$git_src_dir"
		git rev-parse -q --verify e83c5163316f89bfbde7d ||
		die "Does not appear to be a Git checkout: %s\n" "$git_src_dir"
		;;
	--skip-tests)
		skip_tests=--skip-tests
		;;
	--bisect-and-comment)
		require_commitcomment_credentials
		bisect_and_comment=t
		;;
	--full-log)
		full_log=--full-log
		;;
	--with-svn-tests)
		with_svn_tests=--with-svn-tests
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	case $# in
		1) branch=$1; commit=$branch;;
		2) branch=$1; commit=$2;;
		*) die "Expected 1 or 2 arguments, got $#: %s\n" "$*" ;;
	esac

	test -z "$bisect_and_comment" ||
	test -z "$skip_tests" ||
	die "Cannot skip tests *and* bisect\n"

	# special-case master and maint: we will want full tests on those
	case "$branch" in
	upstream/master|upstream/maint) with_svn_tests=--with-svn-tests;;
	esac

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
	 upstream/*|v[1-9]*|upstream/v[1-9]*)
		require_remote upstream https://github.com/git/git
		case "$branch" in
		upstream/refs/pull/[0-9]*)
			git fetch upstream "${branch#upstream/}:refs/remotes/$branch" ||
			die "Could not fetch %s from upstream\n" \
				"${branch#upstream/}"
			;;
		upstream/v[1-9]*)
			git fetch upstream "refs/tags/${branch#upstream/}:refs/remotes/$branch" ||
			die "Could not fetch %s from upstream\n" \
				"${branch#upstream/}"
			;;
		esac
		;;
	 esac &&
	 if test "$branch" != "$commit"
	 then
		if ! git merge-base --is-ancestor $commit $branch
		then
			case "$branch" in
			upstream/pu|upstream/next)
				echo "Commit $commit is not on branch $branch; skipping" >&2
				exit 0
				;;
			*)
				echo "Commit $commit is not on branch $branch; falling back to $branch" >&2
				commit=$branch
				;;
			esac
		fi
	 fi &&
	 git checkout -f "$commit" &&
	 git reset --hard &&
	 if build_and_test_64 $skip_tests $full_log $with_svn_tests
	 then
		: everything okay
	 elif test -z "$bisect_and_comment"
	 then
		exit 1
	 else
		printf "\nBisecting broken Git tests...\n" >&2 &&
		case "$branch" in
		upstream/pu) good=upstream/next;;
		upstream/next) good=upstream/master;;
		upstream/master) good=upstream/maint;;
		*) die "Cannot bisect from bad '%s'\n" "$branch";;
		esac
		for f in $(cat "$(git rev-parse --git-dir)/failing.txt")
		do
			"$sdk64/git-cmd" --command=usr\\bin\\sh.exe -l -c '
				sh "'"$this_script_path"'" bisect_broken_test \
					--bad="'"$commit"'" --good='$good' \
					--worktree=. --publish-comment '$f
		done
		exit 1
	 fi) ||
	exit
}

update_vs_branch () { # [--worktree=<path>] [--remote=<remote>] [--branch=<branch>]
	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	remote=git-for-windows
	branch=master
	while case "$1" in
	--worktree=*)
		git_src_dir=${1#*=}
		test -d "$git_src_dir" ||
		die "Worktree does not exist: %s\n" "$git_src_dir"
		git rev-parse -q --verify e83c5163316f89bfbde7d ||
		die "Does not appear to be a Git checkout: %s\n" "$git_src_dir"
		;;
	--remote=*)
		remote="${1#*=}"
		;;
	--branch=*)
		branch="${1#*=}"
		branch="${branch#refs/heads/}"
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected 0 argument, got $#: %s\n" "$*"

	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	sdk="$sdk64"

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update build-extra\n"

	require_git_src_dir

	(cd "$git_src_dir" &&
	 case "$remote" in
	 git-for-windows)
		require_remote git-for-windows \
			https://github.com/git-for-windows/git &&
		require_push_url git-for-windows
		;;
	 *)
		test -n "$(git config remote."$remote".url)" &&
		git fetch "$remote" \
			refs/heads/"$branch":refs/remotes/"$remote/$branch"
		;;
	 esac ||
	 die "Could not update remote\n"

	 if prev=$(git rev-parse -q --verify \
		refs/remotes/"$remote"/vs/"$branch") &&
		test 0 = $(git rev-list --count \
			"$prev"..refs/remotes/"$remote/$branch")
	 then
		echo "vs/$branch was already rebased" >&2
		exit 0
	 fi &&
	 git reset --hard &&
	 git checkout --force refs/remotes/"$remote/$branch"^0 &&
	 make vcxproj &&
	 git push "$remote" +HEAD:refs/heads/vs/"$branch" ||
	 die "Could not push vs/$branch\n") ||
	exit
}

needs_upload_permissions () {
	grep -q '^machine api\.github\.com$' "$HOME"/_netrc &&
	grep -q '^machine uploads\.github\.com$' "$HOME"/_netrc ||
	die "Missing GitHub entries in ~/_netrc\n"
}

# [--include-sha256sums] <tag> <dir-with-files>
publish_prerelease () {
	body=
	include_sha256sums=
	while case "$1" in
	--include-sha256sums)
		include_sha256sums=t
		;;
	-*)
		die "Unhandled option: '%s'\n" "$1"
		;;
	*)
		break
		;;
	esac; do shift; done
	test $# = 2 ||
	die "Unexpected arguments: '%s'\n" "$*"

	if test -n "$include_sha256sums"
	then
		checksums="Filename | SHA-256\\n-------- | -------\\n$(cd "$2" &&
			sha256sum.exe * |
			sed -n 's/\([^ ]*\) \*\(.*\)/\2 | \1\\n/p' |
			tr -d '\012')"
		body="\"body\":\"Pre-release: Git $1\\n\\n$checksums\","
	fi

	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--repo=git "$1" \
		"$2"/* ||
	die "Could not upload files from %s\n" "$2"

	url=https://api.github.com/repos/git-for-windows/git/releases
	id="$(curl --netrc -s $url |
		sed -n '/"id":/{N;N;/"tag_name": *"'"$1"'"/{
			s/.*"id": *\([0-9]*\).*/\1/p;q}}')"
	test -n "$id" ||
	die "Could not determine ID of release for %s\n" "$1"

	out="$(curl --netrc --show-error -s -XPATCH -d \
		'{"name":"'"$1"'",'"$body"'"draft":false,"prerelease":true}' \
		$url/$id)" ||
	die "Could not edit release for %s:\n%s\n" "$1" "$out"
}

prerelease () { # [--installer | --portable | --mingit | --mingit-busybox] [--only-64-bit] [--clean-output=<directory> | --output=<directory>] [--force-version=<version>] [--skip-prerelease-prefix] <revision>
	modes=
	output=
	outputdir="$HOME"
	force_tag=
	force_version=
	prerelease_prefix=prerelease-
	only_64_bit=
	upload=
	include_sha256sums=
	include_pdbs=
	while case "$1" in
	--force-tag)
		force_tag=-f
		;;
	--force-version)
		shift
		force_version="$1"
		force_tag=-f
		;;
	--force-version=*)
		force_version="${1#*=}"
		force_tag=-f
		;;
	--skip-prerelease-prefix)
		prerelease_prefix=
		;;
	--installer|--portable|--mingit|--mingit-busybox)
		modes="$modes ${1#--}"
		;;
	--only-installer|--only-portable|--only-mingit|--only-mingit-busybox)
		modes="${1#--only-}"
		;;
	--reset-mode)
		modes=
		;;
	--installer+portable)
		modes="installer portable"
		;;
	--only-64-bit)
		only_64_bit=t
		;;
	--output=*)
		outputdir="$(cygpath -am "${1#*=}")" &&
		output="--output='$outputdir'" ||
		die "Directory '%s' inaccessible\n" "${1#*=}"
		;;
	--clean-output=*)
		outputdir="$(cygpath -am "${1#*=}")" &&
		rm -rf "$outputdir" &&
		mkdir -p "$outputdir" ||
		die "Could not make directory '%s'\n" "$outputdir"
		output="--output='$outputdir'" ||
		die "Directory '%s' inaccessible\n" "$outputdir"
		;;
	--now)
		outputdir="$(cygpath -am "./prerelease-now")" &&
		rm -rf "$outputdir" &&
		mkdir "$outputdir" ||
		die "Could not make ./prerelease-now/\n"
		output="--output='$outputdir'" ||
		die "Directory "$outputdir"/ is inaccessible\n"

		modes="installer portable mingit mingit-busybox"
		force_version='%(prerelease-tag)'
		force_tag=-f
		upload=t
		;;
	--no-upload)
		upload=
		;;
	--include-pdbs)
		include_pdbs=--include-pdbs
		;;
	--include-sha256sums)
		include_sha256sums=--include-sha256sums
		;;
	--no-include-sha256sums)
		include_sha256sums=
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	test -z "$include_sha256sums" || test -n "$upload" ||
	die "%s\n" "--include-sha256sums makes only sense when uploading"

	test -n "$modes" ||
	modes=installer

	if test -z "$only_64_bit"
	then
		ensure_valid_login_shell 32
	fi &&
	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	sdk="$sdk64"

	portable_root=/usr/src/build-extra/portable/root/
	rm -rf "$sdk$portable_root"/mingw64/libexec/git-core ||
	die "Could not ensure that portable Git in '%s' is cleaned\n" "$sdk"
	test -n "$only_64_bit" ||
	rm -rf "$sdk32$portable_root"/mingw32/libexec/git-core ||
	die "Could not ensure that portable Git in '%s' is cleaned\n" "$sdk32"

	build_extra_dir="$sdk32/usr/src/build-extra"
	test -n "$only_64_bit" ||
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update 32-bit build-extra\n"

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update build-extra\n"

	if test -n "$force_version"
	then
		while case "$force_version" in
		*'%(use-existing-tag)'*)
			tag_name="$(git for-each-ref --points-at="$1" \
				--sort=-taggerdate \
				--format='%(refname:strip=2)' 'refs/tags/*' |
			    sed -ne '/\.g[0-9a-f]\{7,\}$/d' -e 'p;q')"
			if test -z "$tag_name"
			then
				force_version="$(echo "$force_version" |
					sed 's/%(use-existing-tag)//g')"
			else
				force_version="$tag_name"
				break
			fi
			;;
		*'%(infix:'*')'*)
			tag_name="${force_version#*%(infix:}"
			tag_name="${tag_name%%)*}"
			match=windows
			case "$tag_name" in
			*=*)
				match="${tag_name%%=*}"
				tag_name="${tag_name#*=}"
				;;
			esac
			desc="$(git describe --match "v[0-9]*.$match.*" \
					--abbrev=7 "$1")"
			while echo "$desc" |
			grep '\.g[0-9a-f]\{7,\}\(\(\.[0-9]\+\)\?-[0-9]\+[-.]g[0-9a-f]\{7,\}\)\?$'
			do
				git tag -d "$desc" ||
				git tag -d "${desc%-[0-9]*}" ||
				die "Could not delete tag %s\n" "$desc"
				desc="$(git describe --match \
					"v[0-9]*.$match.*" --abbrev=7 "$1")"
			done
			tag_name="$(echo "$desc" |
				sed -e "s|-\(g[0-9a-f]*\)$|.\1|g" -e \
					"s|\.$match\.|.$tag_name.|g")"
			force_version="$(echo "$force_version" |
				sed "s|%(infix:[^)]*)|$tag_name|g")"
			;;
		*'%(base-version)'*)
			tag_name="v$(git describe --match='v[0-9]*.windows.*' \
				"$1" |
			  sed -e 's/[A-Za-z]*//g' -e 's/[^.0-9]/./g' \
			    -e 's/\.\.*/./g' \
			    -e 's/^\([^.]*\.[^.]*\.[^.]*\.[^.]*\)\..*$/\1/')"
			force_version="$(echo "$force_version" |
				sed "s/%(base-version)/$tag_name/g")"
			;;
		*'%(counter)')
			force_version="${force_version%?(counter)}"
			tag_name=1
			while git rev-parse --verify -q \
				"$force_version$tag_name" >/dev/null
			do
				tag_name=$(($tag_name+1))
			done
			force_version="$force_version$tag_name"
			;;
		*'%(counter)'*)
			die "%(counter) must be last\n"
			;;
		*'%(prerelease-tag)'*)
			tag_name="$(git describe \
				--match='v[1-9]*.windows.[1-9]*' "$1" |
			sed -n 's|^\(v[.0-9]*\)\.windows\.[0-9].*|\1|p')"
			test -n "$tag_name" ||
			die "Could not describe '%s'\n" "$1"
			tag_name="${tag_name%.*}.$((${tag_name##*.}+1))"
			tag_name="$tag_name".windows-prerelease.1
			while git rev-parse -q --verify "$tag_name"
			do
				tag_name="${tag_name%.*}.$((${tag_name##*.}+1))"
			done
			force_version="$(echo "$force_version" |
				sed "s/%(prerelease-tag)/$tag_name/g")"
			;;
		*'%'*)
			die "Unknown placeholder: '%s'\n" \
				"$(echo "%${force_version#*%}" |
					sed -e 's/).*/)/')"
			;;
		*)
			break
			;;

		esac
		do
			: go on
		done
		echo "Using version $force_version" >&2
		tag_name="$force_version"
		pkgver="$(echo "${force_version#v}" | tr +- .)"

		test -n "$pkgver" &&
		test -z "$(echo "$pkgver" | tr -d 'A-Za-z0-9.')" ||
		die "Unusable version '%s'\n" "$force_version"
	else
		pkgver="$(git describe --match 'v[0-9]*' "$1" | tr - .)"
		tag_name=prerelease-$pkgver
		test -n "$tag_name" ||
		die "Could not find revision '%s'\n" "$1"

		test -z "$(echo "$pkgver" | tr -d 'A-Za-z0-9.')" ||
		die "The revision '%s' yields unusable version '%s'\n" \
			"$1" "$pkgver"
	fi

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	require_git_src_dir

	if test -n "$upload"
	then
		needs_upload_permissions &&
		(cd "$git_src_dir" &&
		 require_remote git-for-windows \
			https://github.com/git-for-windows/git &&
		 require_push_url git-for-windows) ||
		die "Need upload/push permissions\n"
	fi

	(cd "$git_src_dir/../.." &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update mingw-w64-git\n"

	skip_makepkg=
	force_makepkg=
	pkgprefix="$git_src_dir/../../mingw-w64"
	pkgsuffix="${pkgver#v}-1-any.pkg.tar.xz"
	case "$modes" in
	mingit|mingit-busybox|"mingit mingit-busybox"|"mingit-busybox mingit")
		pkglist="git"
		;;
	*)
		pkglist="git git-doc-html"
		;;
	esac
	if test -n "$only_64_bit" -o \
			-f "${pkgprefix}-i686-${pkglist##* }-${pkgsuffix}" &&
		test -f "${pkgprefix}-x86_64-${pkglist##* }-${pkgsuffix}" &&
		test "$(git rev-parse --verify "$1"^{commit})" = \
			"$(git -C "$git_src_dir" rev-parse --verify \
				"$tag_name"^{commit})"
	then
		echo "Skipping makepkg: already built packages" >&2
		skip_makepkg=t
	elif test -n "$force_tag"
	then
		test -n "$force_version" &&
		test "$(git rev-parse -q --verify "$1"^{commit})" = \
			"$(git rev-parse -q --verify \
				"refs/tags/$tag_name"^{commit})" ||
		git tag -f -a -m "Prerelease of $1" "$tag_name" "$1" ||
		die "Could not create tag '%s'\n" "$tag_name"

		git push --force "$(cygpath -au "$git_src_dir")" \
			"refs/tags/$tag_name" ||
		die "Could not push tag '%s' to '%s'\n" \
			"$tag_name" "$git_src_dir"

		force_makepkg=--force
	else
		! git rev-parse --verify -q "$tag_name" 2>/dev/null ||
		die "Tag '%s' already exists\n" "$tag_name"

		! git -C "$git_src_dir" rev-parse --verify -q "$tag_name" \
			2>/dev/null ||
		die "Tag '%s' already exists in '%s'\n" \
			"$tag_name" "$git_src_dir"

		git tag -a -m "Prerelease of $1" "$tag_name" "$1" ||
		die "Could not create tag '%s'\n" "$tag_name"

		git push "$(cygpath -au "$git_src_dir")" \
			"refs/tags/$tag_name" ||
		die "Could not push tag '%s' to '%s'\n" \
			"$tag_name" "$git_src_dir"
	fi

	sed -e "s/^tag=.*/tag=${tag_name#v}/" \
		-e "s/^\(source.*tag=\)[^\"]*/\\1$tag_name/" \
		-e "s/^pkgver=.*/pkgver=${pkgver#v}/" \
		-e "s/^pkgver *(/disabled_&/" \
		-e "s/^pkgrel=.*/pkgrel=1/" \
		<"$git_src_dir/../../PKGBUILD" |
	case "$modes" in
	mingit|mingit-busybox)
		sed -e '/^pkgname=/{N;N;s/"[^"]*-doc[^"]*"//g}'
		;;
	*)
		sed -e '/^pkgname=/{N;N;s/"[^"]*-doc-man[^"]*"//g}'
		;;
	esac >"$git_src_dir/../../prerelease-$pkgver.pkgbuild" ||
	die "Could not generate prerelase-%s.pkgbuild\n" "$pkgver"

	if test -z "$skip_makepkg"
	then
		test -n "$only_64_bit" ||
		install_git_32bit_prereqs
		test -n "$only_64_bit" ||
		require mingw-w64-i686-toolchain mingw-w64-i686-make
		require mingw-w64-x86_64-toolchain mingw-w64-x86_64-make
		if test -z "$(git --git-dir="$sdk64/usr/src/build-extra/.git" \
			config alias.signtool)"
		then
			extra=
		else
			extra="SIGNTOOL=\"git --git-dir=\\\"$sdk64/usr/src"
			extra="$extra/build-extra/.git\\\" signtool\" "
		fi
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"cd \"$git_src_dir/../..\" &&"'
			rm -f src/git/{git-wrapper.o,*.res} &&
			MAKEFLAGS=-j5 \
			MINGW_INSTALLS='"$(test -n "$only_64_bit" ||
				echo mingw32)"'\ mingw64 \
			'"$extra"' \
			makepkg-mingw -s --noconfirm '"$force_tag"' \
				'"$force_makepkg"' \
				-p prerelease-'"$pkgver"'.pkgbuild &&
			MINGW_INSTALLS=mingw64 makepkg-mingw --allsource \
				-p prerelease-'"$pkgver".pkgbuild ||
		die "%s: could not build '%s'\n" "$git_src_dir" "$pkgver"

		pkgsuffix="$(sed -n '/^pkgver=/{N;
			s/pkgver=\(.*\).pkgrel=\(.*\)/\1-\2-any.pkg.tar.xz/p}' \
			<"$git_src_dir/../../prerelease-$pkgver.pkgbuild")" ||
		die "Could not determine package suffix\n"
	fi

	for sdk in "$sdk32" "$sdk64"
	do
		test -z "$only_64_bit" ||
		test a"$sdk" = a"$sdk64" ||
		continue

		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c '
			cd "'"$git_src_dir"'/../.." &&
			mach="$(uname -m)" &&
			pkgpre=mingw-w64-$mach-git && {
			'"$(test -z "'"$outputdir"'" || {
			echo 'file=$pkgpre-pdb-"'"$pkgsuffix"'";
				test ! -f "$file" ||
				cp "$file" "'"$outputdir"'"/; } && {
				file=$pkgpre-test-artifacts-"'"$pkgsuffix"'";
				test ! -f "$file" ||
				cp "$file" "'"$outputdir"'"/; }; '
			srcsuffix="${pkgsuffix%-any.pkg.tar.xz}.src.tar.gz"
			test "a$sdk" != "a$sdk64" ||
			echo 'file=mingw-w64-git-'"$srcsuffix"';
				test ! -f "$file" ||
				cp "$file" "'"$outputdir"'"/;'
			} )"'
			precmd="pacman --overwrite=\* --noconfirm -U" &&
			postcmd="pacman --overwrite=\* --noconfirm -U" &&
			for pkg in '"$pkglist"'
			do
				pkg=mingw-w64-$mach-$pkg

				file="$(pacman -Q $pkg)" || {
					pacman -S --noconfirm $pkg &&
					file="$(pacman -Q $pkg)" || {
						echo "$pkg not installed" >&2
						exit 1
					}
				}
				file="/var/cache/pacman/pkg/$(echo $file |
					tr \  -)-any.pkg.tar.xz"
				test -f $file ||
				cp "${file##*/}" "$file" ||
				pacman -Sw --noconfirm "$(pacman -Q $pkg |
						tr " " "=")" || {
					echo "$file does not exist" >&2
					exit 1
				}
				postcmd="$postcmd $file"

				file=$pkg-'"$pkgsuffix"'
				test -f $file || {
					echo "$file was not built" >&2
					exit 1
				}
				test -z "'"$outputdir"'" ||
				cp "$file" "'"$outputdir"'/" || {
					echo "$file not copied to outputdir" >&2
					exit 1
				}
				precmd="$precmd $file"
			done || exit
			eval "$precmd" &&
			pacman -S --noconfirm git-extra &&
			sed -i -e "1s/.*/# Pre-release '"$pkgver"'/" \
				-e "2s/.*/Date: '"$(today)"'/" \
				/usr/src/build-extra/ReleaseNotes.md &&
			version='"$prerelease_prefix${pkgver#v}"' &&
			for m in '"$modes"'
			do
				extra=
				v="$version"
				test installer != $m ||
				extra=--window-title-version="$version"
				test mingit-busybox != $m || {
					extra="$extra --busybox"
					v="$v-BusyBox"
					m=mingit
				}
				/usr/src/build-extra/$m/release.sh \
					'"$include_pdbs"' \
					'"$output"' $extra "$v" || {
					postcmd="$postcmd && exit 1"
					break
				}
			done &&
			(cd /usr/src/build-extra &&
			 git diff -- ReleaseNotes.md | git apply -R) &&
			eval "$postcmd" &&
			pacman -S --noconfirm git-extra' ||
		die "Could not use package '%s' in '%s'\n" "$pkglist" "$sdk"
	done

	case " $modes " in
	*" portable "*)
		version="$prerelease_prefix${pkgver#v}" &&
		sign_files "$outputdir"/PortableGit-"$version"-64-bit.7z.exe &&
		{ test -n "$only_64_bit" || sign_files \
			"$outputdir"/PortableGit-"$version"-32-bit.7z.exe; } ||
		die "Could not code-sign portable Git(s)\n"
		;;
	esac

	test -z "$upload" || {
		git -C "$git_src_dir" push git-for-windows "$tag_name" &&
		publish_prerelease $include_sha256sums "$tag_name" "$outputdir"
	} ||
	die "Could not publish %s\n" "$tag_name"
}

require_commitcomment_credentials () {
	test -n "$(git config github.commitcomment.credentials)" ||
	die "Need credentials to publish commit comments\n"
}

add_commit_comment_on_github () { # <org/repo> <commit> <message>
	credentials="$(git config github.commitcomment.credentials)"
	test -n "$credentials" ||
	die "Need credentials to publish commit comments\n"

	quoted="$(echo "$3" |
		sed -e ':1;${s/[\\"]/\\&/g;s/\n/\\n/g;s/\t/\\t/g;s/\x1b/<ESC>/g};N;b1')"
	url="https://$credentials@api.github.com/repos/$1/commits/$2/comments"
	curl -X POST --show-error -s -XPOST -d \
		'{"body":"'"$quoted"'"}' "$url"
}

bisect_broken_test () { # [--worktree=<path>] [--bad=<revision> --good=<revision>] [--publish-comment] <test>
	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	bad=
	good=
	skip_run=
	publish_comment=
	while case "$1" in
	--worktree=*)
		git_src_dir=${1#*=}
		test -d "$git_src_dir" ||
		die "Worktree does not exist: %s\n" "$git_src_dir"
		git rev-parse -q --verify e83c5163316f89bfbde7d ||
		die "Does not appear to be a Git checkout: %s\n" "$git_src_dir"
		;;
	--bad=*)
		bad=${1#*=}
		;;
	--good=*)
		good=${1#*=}
		;;
	--skip-run)
		# mostly for debugging
		skip_run=t
		;;
	--publish-comment)
		require_commitcomment_credentials
		publish_comment=t
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	if test -z "$bad"
	then
		test -z "$good" || die "Need --bad, too\n"
	else
		test -n "$good" || die "Need --good, too\n"
	fi

	broken_test="$1"
	case "$broken_test" in
	[0-9]*)
		broken_test=t"$broken_test"
		;;
	esac

	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	sdk="$sdk64"

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update build-extra\n"

	require_git_src_dir

	(cd "$git_src_dir" ||
	 die "Could not cd to %s\n" "$git_src_dir"

	 test -n "$skip_run" ||
	 test ! -f "$(git rev-parse --git-path BISECT_START)" ||
	 git bisect reset ||
	 die "Could not reset previous bisect\n"

	 if test -n "$skip_run"
	 then
		test -f "$(git rev-parse --git-path BISECT_RUN)" ||
		die "No previous bisect run detected\n"
	 elif test -z "$bad"
	 then
		require_remote git-for-windows \
			https://github.com/git-for-windows/git &&
		require_remote upstream https://github.com/git/git ||
		die "Could not update remotes\n"

		git checkout upstream/pu ||
		die "Could not check out pu\n"
	 else
		git checkout "$bad"^{commit} ||
		die "Could not check out %s\n" "$bad"
	 fi

	 if ! test -f t/"$broken_test"
	 then
		broken_test="$(cd t && echo "$broken_test"*.sh)"
		test -f t/"$broken_test" ||
		die "Could not find test %s\n" "$broken_test"
	 fi
	 bisect_run="$(git rev-parse --git-dir)/bisect-run.sh" &&
	 printf "#!/bin/sh\n\n%s\n%s\n%s%s\n%s\n" \
		"test -f \"t/$broken_test\" || exit 0" \
		"echo \"Running make\" >&2" \
		"o=\"\$(make -j5 2>&1)\" || " \
		"{ echo \"\$o\" >&2; exit 125; }" \
		"GIT_TEST_OPTS=-i make -C t \"$broken_test\"" \
		>"$bisect_run" &&
	 chmod a+x "$bisect_run" ||
	 die "Could not write %s\n" "$bisect_run"

	 if test -z "$bad" && test -z "$skip_run"
	 then
		echo "Testing in pu..." >&2
		! sh "$bisect_run" ||
		die "%s does not fail in pu\n" "$broken_test"

		bad=upstream/pu
		for branch in next master maint
		do
			echo "Testing in $branch..." >&2
			git checkout upstream/$branch ||
			die "Could not check out %s\n" "$branch"

			if sh "$bisect_run"
			then
				good=upstream/$branch
				break
			else
				bad=upstream/$branch
			fi
		done || exit

		test -n "$good" ||
		die "%s is broken even in maint\n" "$broken_test"
		echo "Bisecting between $good and $bad" >&2
	 fi

	 if test -z "$skip_run"
	 then
		git bisect start "$bad" "$good" &&
		case "$bad $good" in
		upstream/*' 'upstream/*)
			# we know in which direction patches enter...
			for b in $(git merge-base -a "$bad" "$good")
			do
				git bisect good "$b"
			done
			;;
		esac &&
		if test -f "$(git rev-parse --git-path BISECT_LOG)"
		then
			git bisect run "$bisect_run"
		else
			test 1 = $(git rev-list --count "$good..$bad") ||
			die 'Could not start bisect between %s and %s\n' \
				"$bad" "$good"
			printf '%s is the first bad commit\n' \
				"$(git rev-parse "$bad")" \
			>"$(git rev-parse --git-path BISECT_RUN)"
			printf 'No need to bisect: %s is the bad apple\n' \
				"$(git rev-parse "$bad")"
		fi
	 fi) ||
	exit

	if test -n "$publish_comment"
	then
		# read full file name of the broken test
		broken_test="$(sed -n 's/.* make -C t "\(.*\)"$/\1/p' \
			<"$(git rev-parse --git-dir)/bisect-run.sh")"

		bisect_run="$(git rev-parse --git-path BISECT_RUN)"
		first_bad="$(sed -n \
			'1s/^\([0-9a-f]*\) is the first bad commit$/\1/p' \
			<"$bisect_run")"
		skipped=
		skipped_message=
		if test -z "$first_bad"
		then
			skipped="$(sed -e '1,/^The first bad commit could be/d' \
				-e '/^We cannot bisect more/,$d' <"$bisect_run")"
			first_bad="$(echo "$skipped" | sed -n '$p')"
			skipped="$(echo "$skipped" | sed '$d')"
			case $(echo "$skipped" | wc -l) in
			1)
				skipped_message=" (or $skipped)"
				;;
			[2-9]*)
				skipped_message=" (or any of these: $skipped)"
				;;
			esac
		fi
		git checkout "$first_bad" ||
		die "Could not check out first bad commit: %s\n" "$first_bad"
		make -j5 ||
		die "Could not build %s\n" "$first_bad"
		err="$(git rev-parse --git-path broken-test.err)"
		if GIT_TEST_OPTS="-i -v -x" \
			make -C t "$broken_test" >"$err" 2>&1
		then
			die "Test %s passes?\n" "$broken_test"
		fi
		message="$(cat <<EOF
The [administrative script of Git for Windows](https://github.com/git-for-windows/build-extra/blob/master/please.sh) identified a problem with this commit$skipped_message while running \`$broken_test\`:

\`\`\`
`cat "$err"`
\`\`\`
EOF
)"

		add_commit_comment_on_github git/git "$first_bad" "$message" ||
		die "Could not add a commit comment for %s\n" "$first_bad"
		test -z "$skipped" || for s in $skipped
		do
			message="$(printf "%s %s %s" \
				"There was a problem building Git when trying to" \
				"bisect the failing $broken_test, see $first_bad" \
				"for the output of the failed test.")"
			add_commit_comment_on_github git/git "$s" "$message" ||
			die "Could not add a commit comment for %s\n" "$first_bad"
		done

	fi
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
	 sdk= pkgpath=$PWD ff_master) ||
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
	 cov-build --dir cov-int \
		make -j15 DEVELOPER=1 CPPFLAGS=-DFLEX_ARRAY=65536 &&
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
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not update build-extra\n"

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	(cd "$git_src_dir" &&
	 require_remote upstream https://github.com/git/git &&
	 require_remote git-for-windows \
		https://github.com/git-for-windows/git &&
	 require_push_url git-for-windows) || exit

	case "$branch_to_use" in
	*@*)
		git "$dir_option" fetch --tags \
			"${branch_to_use#*@}" "${branch_to_use%%@*}" ||
		die "Could not fetch '%s' from '%s'\n" \
			"${branch_to_use%%@*}" "${branch_to_use#*@}"
		branch_to_use=FETCH_HEAD
		;;
	esac
	branch_to_use="${branch_to_use:-git-for-windows/master}"

	nextver="$(sed -ne \
		'1s/.* \(v[0-9][.0-9]*\)(\([0-9][0-9]*\)) .*/\1.windows.\2/p' \
		-e '1s/.* \(v[0-9][.0-9]*\) .*/\1.windows.1/p' \
		<"$build_extra_dir/ReleaseNotes.md")"
	! git --git-dir="$git_src_dir" rev-parse --verify \
		refs/tags/"$nextver" >/dev/null 2>&1 ||
	test -n "$force" ||
	die "Already tagged: %s\n" "$nextver"

	notes="$("$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'markdown </usr/src/build-extra/ReleaseNotes.md |
		 LC_CTYPE=C w3m -dump -cols 72 -T text/html | \
		 sed -n "/^Changes since/,\${:1;p;n;/^Changes/q;b1}"')"

	tag_message="$(printf "%s\n\n%s" \
		"$(sed -n '1s/.*\(Git for Windows v[^ ]*\).*/\1/p' \
		<"$build_extra_dir/ReleaseNotes.md")" "$notes")" &&
	(cd "$git_src_dir" &&
	 signopt= &&
	 if git config user.signingkey >/dev/null; then signopt=-s; fi &&
	 git tag -m "$tag_message" -a $signopt $force \
		"$nextver" $branch_to_use) ||
	die "Could not tag %s in %s\n" "$nextver" "$git_src_dir"

	echo "Created tag $nextver" >&2
}

test_git () { # <bitness>
	sdk="$(eval "echo \$sdk$1")"

	echo "Testing $1-bit $("$sdk/cmd/git.exe" version)"

	(cd "$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git/" &&
	 "$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"make GIT-CFLAGS && if test GIT-CFLAGS -nt git.res; then touch git.rc; fi && make -j5" &&
	 cd t &&
	 "$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l \
		-c "cd \"\$(cygpath -au .)\" && GIT_TEST_INSTALLED=/mingw$1/bin/ prove --timer --jobs 5 ./t[0-9]*.sh")
}

version_from_pkgbuild () { # <PKGBUILD>
	sed -ne \
		'/^_basever=/{N;N;s/.*=\([0-9].*\)\n.*\npkgrel=\(.*\)/\1-\2/p}' \
		-e '/^_ver=/{N;N;N;s/.*=\([.0-9]*\)\([a-z][a-z]*\)\n.*\n.*\npkgrel=\(.*\)/\1.\2-\3/p}' \
		-e '/^pkgver=/{N;N;s/.*=\([0-9].*\)\npkgrel=\([0-9]*\)\nepoch=\([0-9\*\)/\3~\1-\2/p;s/.*=\([0-9].*\)\npkgrel=\([0-9]*\).*/\1-\2/p;N;s/.*=\([0-9].*\)\n.*\npkgrel=\(.*\).*/\1-\2/p}' \
		-e '/^pkgver=/{N;N;s/[^=]*=\([0-9].*\)\npkgrel=\([0-9]*\)\nepoch=\([0-9]*\).*/\3~\1-\2/p;s/[^=]*=\([0-9].*\)\npkgrel=\([0-9]*\).*/\1-\2/p}' \
		-e '/^_basever=/{N;s/^_basever=\([0-9].*\)\n_patchlevel=\([0-9]*\) .*\n.*\npkgrel=\([0-9]*\).*/\1.\2-\3/p}' \
		<"$1"
}

pkg_files () {
	pkgver="$(version_from_pkgbuild PKGBUILD)"
	test -n "$pkgver" ||
	die "%s: could not determine pkgver\n" "$sdk/$pkgpath"

	test a--for-upload != "a$1" ||
	echo $package-$pkgver.src.tar.gz

	test "a$sdk" = "a$sdk32" &&
	arch=i686 ||
	arch=x86_64

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

install () { # <package>
	set_package "$1"

	case "$package" in
	msys2-runtime|bash)
		is_independent_shell ||
		die "Need to run from a different shell (try Git Bash)\n"
		;;
	esac

	foreach_sdk pkg_install

	test mingw-w64-git != "$package" || {
		"$sdk32/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'pacman -S --noconfirm git-extra' &&
		"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'pacman -S --noconfirm git-extra'
	}
}

# origin HEAD
really_push () {
	if ! git push "$@"
	then
		if test "origin HEAD" = "$*"
		then
			git pull origin master
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

pkg_upload () {
	require_clean_worktree

	files="$(pkg_files --for-upload)" || exit

	pacman_helper add $files
}

upload () { # <package>
	test -n "$GPGKEY" ||
	die "Need GPGKEY to upload packages\n"

	set_package "$1"

	test -s "$HOME"/.azure-blobs-token ||
	die "Missing token in ~/.azure-blobs-token\n"

	(cd "$sdk64/$pkgpath" &&
	 require_push_url origin) || exit

	PACMAN_DB_LEASE="$(pacman_helper lock)" ||
	die 'Could not obtain a lock for uploading\n'

	pacman_helper fetch &&
	foreach_sdk pkg_upload &&
	PACMAN_DB_LEASE="$PACMAN_DB_LEASE" pacman_helper push ||
	die "Could not upload %s\n" "$package"

	pacman_helper unlock "$PACMAN_DB_LEASE" ||
	die 'Could not release lock for uploading\n'
	PACMAN_DB_LEASE=

	# Here, we exploit the fact that the 64-bit SDK is either the only
	# SDK where the package was built (MinGW) or it agrees with the 32-bit
	# SDK's build product (MSYS2).
	(cd "$sdk64/$pkgpath" &&
	 test -z "$(git rev-list refs/remotes/origin/master..)" ||
	 if test refs/heads/master = \
		"$(git rev-parse --symbolic-full-name HEAD)"
	 then
		really_push origin HEAD
	 else
		printf "The local branch '%s' in '%s' has unpushed changes\n" \
			"$(git rev-parse --symbolic-full-name HEAD)" \
			"$sdk64/$pkgpath" >&2
	 fi) ||
	die "Could not push commits in %s/%s\n" "$sdk64" "$pkgpath"
}

updpkgsums () {
	MINGW_INSTALLS=mingw64 \
	"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c updpkgsums
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
			git -C "$top_dir" checkout -t origin/master ||
			die "Could not check out master in '%s'" "$top_dir"
		fi
		;;
	*)
		die "Cannot initialize '%s'\n" "$1"
		;;
	esac
}

# <key-id>
ensure_gpg_key () {
	for sdk in "$sdk32" "$sdk64"
	do
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'gpg --list-key '"$1"' >/dev/null 2>&1 || {
			 gpg --recv-keys '"$1"' &&
			 gpg --lsign-key '"$1; }" ||
		die "Could not ensure key '%s' to be installed into '%s'\n" \
			"$1" "$sdk"
	done
}

create_bundle_artifact () {
	test -n "$artifactsdir" || return
	upstream_master="$(git rev-parse --verify -q git-for-windows/master)" ||
	upstream_master="$(git rev-parse --verify -q origin/master)" ||
	return
	repo_name=$(git rev-parse --show-toplevel) &&
	repo_name=${repo_name##*/} &&
	range="$upstream_master..$(git symbolic-ref --short HEAD)" &&
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

# <pkrel>
maybe_force_pkgrel () {
	if test -n "$1"
	then
		test -z "$(echo "$1" | tr -d 0-9)" ||
		die "Invalid pkgrel: '%s'\n" "$1"

		sed -i "s/^\\(pkgrel=\\).*/\\1$1/" PKGBUILD
	fi
}

# --force overwrites existing an Git tag, or existing package files
upgrade () { # [--directory=<artifacts-directory>] [--only-mingw] [--no-upload] [--force] [--release-date=<date>] [--use-branch=<branch>[@<URL>]] [--force-pkgrel=<pkgrel>] [--cleanbuild] <package>
	artifactsdir=
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

	test -n "$GPGKEY" ||
	die "Need GPGKEY to upload packages\n"

	test -s "$HOME"/.azure-blobs-token ||
	die "Missing token in ~/.azure-blobs-token\n"

	set_package "$1"

	test -z "$only_mingw" ||
	test curl = "$package" ||
	die "The --only-mingw option is supported only for curl\n"

	test -z "$skip_mingw" ||
	test openssl = "$package" ||
	test curl = "$package" ||
	die "The --skip-mingw option is supported only for openssl/curl\n"

	test -z "$only_mingw" || test -z "$skip_mingw" ||
	die "--only-mingw and --skip-mingw are mutually exclusive\n"

	test -z "$release_date" ||
	test mingw-w64-git = "$package" ||
	die "The --release-date option is supported only for git\n"

	test -z "$use_branch" ||
	test mingw-w64-git = "$package" ||
	die "The --use-branch option is supported only for git\n"

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

	maybe_init_repository "$sdk64/$pkgpath"
	test MSYS != "$type" || maybe_init_repository "$sdk32/$pkgpath"

	(cd "$sdk64/$pkgpath" &&
	 require_push_url origin &&
	 sdk="$sdk64" ff_master) || exit

	relnotes_feature=
	case "$package" in
	mingw-w64-git-credential-manager)
		repo=Microsoft/Git-Credential-Manager-for-Windows
		url=https://api.github.com/repos/$repo/releases/latest
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"
		tag_name="$(echo "$release" |
			sed -n 's/^  "tag_name": "\(.*\)",\?$/\1/p')"
		test 1.18.5 != "$tag_name" || {
			tag_name=1.19.0
			release="$(curl --netrc -s ${url%/latest}/16090167)"
		}
		zip_name="$(echo "$release" | sed -n \
			's/.*"browser_download_url":.*\/\(gcm.*\.zip\).*/\1/p')"
		version=${tag_name#v}
		zip_prefix=${zip_name%$version.zip}
		if test "$zip_prefix" = "$zip_name"
		then
			# The version in the tag and the zip file name differ
			zip_replace='s/^\(zip_url=.*\/\)gcm[^"]*/\1'$zip_name/
		else
			zip_replace='s/^\(zip_url=.*\/\)gcm[^"]*/\1'$zip_prefix'${_realver}.zip/'
		fi
		src_zip_prefix=${tag_name%$version}
		(cd "$sdk64/$pkgpath" &&
		 sed -i -e "s/^\\(pkgver=\\).*/\1$version/" -e "$zip_replace" \
		 -e 's/^\(src_zip_url=.*\/\).*\(\$.*\)/\1'$src_zip_prefix'\2/' \
		 -e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 updpkgsums &&
		 srcdir2="$(unzip -l $zip_prefix$version.zip | sed -n \
		   's/^.\{28\} *\(.*\/\)\?git-credential-manager.exe/\1/p')" &&
		 sed -i -e 's/^\(  srcdir2=\).*/\1"${srcdir}\/'$srcdir2'"/' \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD) &&
		url=https://github.com/$repo/releases/tag/$tag_name &&
		relnotes_feature='Comes with [Git Credential Manager v'$version']('"$url"').'
		;;
	git-extra)
		(cd "$sdk64/$pkgpath" &&
		 updpkgsums &&
		 git update-index -q --refresh &&
		 if ! git diff-files --quiet -- PKGBUILD
		 then
			git commit -s -m "git-extra: adjust checksums" PKGBUILD
		 fi &&
		 if test git-extra.install.in -nt git-extra.install
		 then
			MINGW_INSTALLS=mingw64 \
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
		version="$(curl -s https://curl.haxx.se/download.html |
		sed -n 's/.*<a href="\/download\/curl-\([1-9]*[^"]*\)\.tar\.bz2".*/\1/p')"
		test -n "$version" ||
		die "Could not determine newest cURL version\n"

		ensure_gpg_key B71E12C2 || exit

		test -n "$only_mingw" ||
		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify curl-$version.tar.bz2.asc curl-$version.tar.bz2 &&
		 git commit -s -m "curl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master &&

		case "$version,$force_pkgrel" in 7.58.0,|7.62.0,)
			: skip because of partially successful upgrade
			;;
		*)
		(if test -n "$skip_mingw"
		 then
			 exit 0
		 fi &&
		 set_package mingw-w64-$1 &&
		 maybe_init_repository "$sdk64/$pkgpath" &&
		 cd "$sdk64/$pkgpath" &&
		 require_push_url origin &&
		 sdk="$sdk64" ff_master || exit

		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify curl-$version.tar.bz2.asc curl-$version.tar.bz2 &&
		 git commit -s -m "curl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&

		 build $force $cleanbuild "$package" &&
		 install "$package" &&
		 if test -z "$skip_upload"; then upload "$package"; fi &&
		 sdk="$sdk64" pkg_copy_artifacts)
			;;
		esac &&

		url=https://curl.haxx.se/changes.html &&
		url="$url$(echo "#$version" | tr . _)" &&
		v="$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature='Comes with [cURL v'$v']('"$url"').'
		;;
	mingw-w64-git)
		finalize $delete_existing_tag $release_date $use_branch \
			release-notes &&
		tag_git $force $use_branch &&
		if test -n "$artifactsdir"
		then
			echo "$nextver" >"$artifactsdir/nextver" &&
			git -C "$git_src_dir" bundle create \
				"$artifactsdir/git.bundle" \
				git-for-windows/master..$nextver &&
			git -C "$sdk64/usr/src/build-extra" bundle create \
				"$artifactsdir/build-extra.bundle" \
				-9 master
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
			grep "$needle1"'.*\\n[0-9a-z]\{64\}\(\\r\)\?\(\\n\)\?"$')"
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
		(cd "$sdk64/$pkgpath" &&
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
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD) &&
		url=https://github.com/$repo/releases/tag/v$version &&
		relnotes_feature='Comes with [Git LFS v'$version']('"$url"').'
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

		 version="$(echo "$tag" | sed -ne 'y/_/./' -e \
		    's|^refs/tags/cygwin-\([1-9][.0-9]*\)-release$|\1|p')" &&
		 test -n "$version" ||
		 die "Invalid version '%s' for '%s'\n" "$version" "$package"

		 # rebase if necessary
		 if test 0 -lt $(git rev-list --count \
			git-for-windows/master..$tag)
		 then
			require_push_url git-for-windows &&
			git reset --hard &&
			git checkout git-for-windows/master &&
			GIT_EDITOR=true \
			"$sdk64"/usr/src/build-extra/shears.sh \
				--merging --onto "$tag" merging-rebase &&
			git push git-for-windows HEAD:master ||
			die "Could not rebase '%s' to '%s'\n" "$package" "$tag"
		 fi

		 test -n "$force_pkgrel" ||
		 case "$(version_from_pkgbuild ../../PKGBUILD)" in
		 $version-[1-9]*)
			 msys2_runtime_mtime=$(git log -1 --format=%ct \
				git-for-windows/master --) &&
			 msys2_package_mtime=$(git -C ../.. log -1 \
				--format=%ct -- .) &&
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
		 else
		 	cygwin_url="$(curl -s https://cygwin.com/ |
			 sed -n '/The most recent version of the Cygwin DLL is/{
			    N;s/.*<a href="\([^"]*\)">'"$version"'<\/a>.*/\1/p
			 }')"
			test -n "$cygwin_url" ||
			cygwin_url="$(curl -Lis https://cygwin.com/ml/cygwin-announce/current |
			 sed -ne '/^Location: /{s/^Location: //;x}' \
			  -e '/<a \(name=[^ ]* \)\?href=[^>]*>cygwin '"$(echo "$version" |
				sed 's/\./\\&/g')"'/{s/.* href="\([^"]*\).*/\1/;H;x;s/\n//;p;q}')"
		 fi &&

		 test -n "$cygwin_url" ||
		 die "Could not retrieve Cygwin mail about v%s\n" "$version"

		 git reset --hard &&
		 git checkout git-for-windows/master &&
		 commit_url=https://github.com/git-for-windows/msys2-runtime &&
		 commit_url=$commit_url/commit/$(git rev-parse HEAD) &&
		 cd ../.. &&
		 if test "$version" = "$(sed -n 's/^pkgver=//p' <PKGBUILD)"
		 then
			pkgrel=$(($(sed -n 's/^pkgrel=//p' <PKGBUILD)+1)) &&
			printf 'Comes with %s%s [%s](%s).' \
			 "[patch level $pkgrel]($commit_url) of the " \
			 'MSYS2 runtime (Git for Windows flavor) based on' \
			 "Cygwin $version" "$cygwin_url" >../.git/relnotes &&
			sed -i "s/^\\(pkgrel=\\).*/\\1$pkgrel/" PKGBUILD
		 else
			pkgrel=
			printf 'Comes with %s [%s](%s).' \
			 'MSYS2 runtime (Git for Windows flavor) based on' \
			 "Cygwin $version" "$cygwin_url" >../.git/relnotes &&
			sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
				-e "s/^\\(pkgrel=\\).*/\\11/" PKGBUILD
		 fi &&
			 git commit -s -m "$package: update to v$version${pkgrel:+ ($pkgrel)}" PKGBUILD &&
		 MSYSTEM=msys PATH="$sdk64/usr/bin:$PATH" \
		 "$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			./update-patches.sh &&
		 git commit --amend -C HEAD ||
		 die "Could not update PKGBUILD of '%s' to version %s\n" \
			"$package" "$version" &&
		 git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master
		) || exit
		relnotes_feature="$(cat "$sdk64/$pkgpath/../.git/relnotes")"
		;;
	mingw-w64-busybox)
		(cd "$sdk64/$pkgpath" &&
		 if test ! -d src/busybox-w32
		 then
			MINGW_INSTALLS=mingw64 \
			"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
				'makepkg-mingw --nobuild -s --noconfirm'
		 fi &&
		 git stash &&
		 url=https://github.com/git-for-windows/busybox-w32 &&
		 (cd src/busybox-w32 &&
		  require_remote git-for-windows "$url" &&
		  require_remote rmyorston \
			https://github.com/rmyorston/busybox-w32 ||
		  die "Could not connect remotes for '%s'\n" "$package"
		  if test 0 -lt $(git rev-list --count \
			git-for-windows/master..rmyorston/master)
		  then
			require_push_url git-for-windows &&
			git reset --hard &&
			git checkout git-for-windows/master &&
			GIT_EDITOR=true \
			"$sdk64"/usr/src/build-extra/shears.sh --merging \
				--onto rmyorston/master merging-rebase &&
			git push git-for-windows HEAD:master ||
			die "Could not rebase '%s' to '%s'\n" \
				"$package" "rmyorston/master"
		  fi) ||
		 die "Could not initialize/rebase '%s'\n" "$package"

		 built_from_commit="$(sed -n \
			's/^pkgver=.*\.\([0-9a-f]*\)$/\1/p' <PKGBUILD)" &&
		 test 0 -lt $(git -C src/busybox-w32 rev-list --count \
			"$built_from_commit"..git-for-windows/master) ||
		 die "Package '%s' already up-to-date at commit '%s'\n" \
			"$package" "$built_from_commit"

		 MINGW_INSTALLS=mingw64 \
		 "$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'makepkg-mingw --nobuild -s --noconfirm' &&
		 version="$(sed -n 's/^pkgver=\(.*\)$/\1/p' <PKGBUILD)" &&
		 git commit -s -m "busybox: upgrade to $version" PKGBUILD &&
		 url=$url/commit/${version##*.} &&
		 echo "Comes with [BusyBox v$version]($url)." \
			>../.git/relnotes) || exit
		relnotes_feature="$(cat "$sdk64/$pkgpath/../.git/relnotes")"
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
		relnotes_feature='Comes with [OpenSSH v'$version']('"$url"').'
		sha256="$(echo "$notes" |
			sed -n "s/.*SHA256 (openssh-$version\\.tar\\.gz) = \([^ ]*\).*/\\1/p" |
			base64 -d | hexdump -e '1/1 "%02x"')"

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 grep "sha256sums.*$sha256" PKGBUILD &&
		 git commit -s -m "openssh: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master ||
		die "Could not update $sdk32/$pkgpath"
		;;
	openssl)
		version="$(curl -s https://www.openssl.org/source/ |
		sed -n 's/.*<a href="openssl-\(1\.1\.1[^"]*\)\.tar\.gz".*/\1/p')"
		test -n "$version" ||
		die "Could not determine newest OpenSSL version\n"

		ensure_gpg_key 0E604491 || exit

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(_ver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify openssl-$version.tar.gz.asc \
		 	openssl-$version.tar.gz &&
		 git commit -s -m "openssl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) &&
		test 0 = $? ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master &&

		(if test -n "$skip_mingw"
		 then
			 exit 0
		 fi &&
		 set_package mingw-w64-$1 &&
		 maybe_init_repository "$sdk64/$pkgpath" &&
		 cd "$sdk64/$pkgpath" &&
		 require_push_url origin &&
		 sdk="$sdk64" ff_master || exit

		 sed -i -e 's/^\(_ver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 gpg --verify openssl-$version.tar.gz.asc \
		 	openssl-$version.tar.gz &&
		 git commit -s -m "openssl: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD &&

		 build $force $cleanbuild "$package" &&
		 install "$package" &&
		 if test -z "$skip_upload"; then upload "$package"; fi &&
		 sdk="$sdk64" pkg_copy_artifacts) &&
		test 0 = $? &&

		v="$(echo "$version" | tr -dc 0-9.)" &&
		url=https://www.openssl.org/news/openssl-$v-notes.html &&
		relnotes_feature='Comes with [OpenSSL v'$version']('"$url"').'
		;;
	mingw-w64-wintoast|mingw-w64-cv2pdb)
		(cd "$sdk64/$pkgpath" &&
		 MINGW_INSTALLS=mingw64 \
		 "$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'makepkg-mingw --nobuild -s --noconfirm' &&
		 version="$(sed -n 's/^pkgver=\(.*\)$/\1/p' <PKGBUILD)" &&
		 if test "1.0.0.181.9b0663d" != "$version" &&
			test "0.44.18.g0198534" != "$version"
		 then
			git commit -s -m \
				"${package#mingw-w64-}: upgrade to $version" \
				PKGBUILD
		 fi &&
		 git update-index -q --refresh &&
		 git diff-files --quiet --)
		;;
	bash)
		url="http://git.savannah.gnu.org/cgit/bash.git/commit/?id=master" &&
		version=4.4 &&
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
		 git commit -s -m "bash: new version ($v)" PKGBUILD) ||
		exit
		v="$version patchlevel $patchlevel ${force_pkgrel:+ ($force_pkgrel)}" &&
		url=https://tiswww.case.edu/php/chet/bash/NEWS &&
		relnotes_feature='Comes with [Bash v'$v']('"$url"').'
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
		 git commit -s -m "heimdal: new version ($ver)" PKGBUILD) ||
		exit

		url=http://h5l.org/releases.html &&
		relnotes_feature='Comes with [Heimdal v'$ver']('"$url"').'
		;;
	perl)
		releases="$(curl https://dev.perl.org/perl5/)" ||
		die "Could not download release notes for Perl\n"

		ver="$(echo "$releases" | sed -n \
			's/.*Perl <[^>]*>\(5\..*\)<.* stable version.*/\1/p')"
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
		 git commit -s -m "perl: new version ($ver)" PKGBUILD) ||
		exit

		url=http://search.cpan.org/dist/perl-$ver/pod/perldelta.pod &&
		relnotes_feature='Comes with [Perl v'$ver']('"$url"').'
		;;
	perl-Net-SSLeay|perl-HTML-Parser|perl-TermReadKey|perl-Locale-Gettext|perl-XML-Parser|perl-YAML-Syck)
		metaname=${package#perl-}
		case $metaname in
		Locale-Gettext) metaname=gettext;;
		esac
		meta="$(curl -s https://metacpan.org/release/$metaname)" ||
		die "Could not download release notes for $package\n"

		ver="$(echo "$meta" | sed -n \
			's/.*<option selected value="\/release\/\([^"]*\)-\([0-9.]*\)".*/\1 \2/p')"
		test -n "$ver" ||
		die "Could not determine latest $package version\n"

		metapath=${ver% *}
		ver=${ver##* }

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$ver/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($ver)" PKGBUILD) ||
		exit

		url=https://metacpan.org/source/$metapath-$ver/Changes &&
		relnotes_feature="Comes with [$package v$ver]($url)."
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
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD) ||
		exit

		url=https://github.com/jonas/tig/releases/tag/tig-$version &&
		relnotes_feature="Comes with [$package v$version]($url)."
		;;
	subversion)
		url=https://subversion.apache.org/download.cgi
		release="$(curl --netrc -s $url)"
		test -n "$release" ||
		die "Could not determine the latest version of %s\n" "$package"

		version="$(echo "$release" | sed -n \
		 's/.*<a href="#recommended-release">\([1-9][0-9.]*\)<.*/\1/p')"
		test -n "$version" ||
		die "Could not determine version of %s\n" "$package"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD) ||
		exit

		url=https://svn.apache.org/repos/asf/subversion/tags/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature="Comes with [$package $v]($url/CHANGES)."
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
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD) ||
		exit

		url=http://git.savannah.gnu.org/cgit/gawk.git/plain &&
		url=$url/NEWS?h=gawk-$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature="Comes with [$package $v]($url)."
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

		(cd "$sdk64/$pkgpath" &&
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
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD)
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
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD) ||
		exit

		url=https://nodejs.org/en/blog/release/v$version/ &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature="Comes with [$package $v]($url)."
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

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e "s/^\\(pkgver=\\).*/\\1$version/" \
		 -e "s/^\\(pkgrel=\\).*/\\11/" \
			PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "Upgrade $package to $version${force_pkgrel:+-$force_pkgrel}" PKGBUILD)
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

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 grep "sha256sums.*$sha256" PKGBUILD &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master ||
		die "Could not update $sdk32/$pkgpath"

		url=https://github.com/$repo/releases/tag/$version &&
		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature="Comes with [$package $v]($url)."
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
		relnotes_feature='Comes with ['$package' v'$version']('"$url"').'

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master ||
		die "Could not update $sdk32/$pkgpath"
		;;
	gnupg)
		url='https://git.gnupg.org/cgi-bin/gitweb.cgi?p=gnupg.git;a=tags'
		tags="$(curl -s "$url")" ||
		die 'Could not obtain download page from %s\n' "$url"
		version="$(echo "$tags" |
			sed -n '/ href=[^>]*>gnupg-[1-9][.0-9]*</{s/.*>gnupg-\([.0-9]*\).*/\1/p;q}')"
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
		relnotes_feature='Comes with [GNU Privacy Guard '"$v"']('"$announce_url"').'

		(cd "$sdk64/$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: new version ($version${force_pkgrel:+-$force_pkgrel})" PKGBUILD) ||
		die "Could not update %s\n" "$sdk64/$pkgpath/PKGBUILD"

		git -C "$sdk32/$pkgpath" pull "$sdk64/$pkgpath/.." master ||
		die "Could not update $sdk32/$pkgpath"
		;;
	mingw-w64-pcre2)
		url=https://pcre.org/changelog.txt
		changelog="$(curl $url)" ||
		die "Could not download %s\n" "$url"

		version="$(echo "$changelog" | sed -n -e \
			'/^Version [1-9][0-9]*\.[1-9]/{s/^[^1-9]*\([^ ]*\).*/\1/p;q}' )"
		test -n "$version" ||
		die "Could not determine current PCRE2 version\n"

		(cd "$sdk64$pkgpath" &&
		 sed -i -e 's/^\(pkgver=\).*/\1'$version/ \
			-e 's/^pkgrel=.*/pkgrel=1/' PKGBUILD &&
		 maybe_force_pkgrel "$force_pkgrel" &&
		 updpkgsums &&
		 git commit -s -m "$package: upgrade to v$version" PKGBUILD) ||
		exit

		v="v$version${force_pkgrel:+ ($force_pkgrel)}" &&
		relnotes_feature="Comes with [PCRE2 $v]($url)."
		;;
	*)
		die "Unhandled package: %s\n" "$package"
		;;
	esac &&

	if test -n "$relnotes_feature"
	then
		(cd "$sdk64/usr/src/build-extra" &&
		 require_push_url origin)
	fi &&

	if test -z "$only_mingw"
	then
		build $force $cleanbuild "$package" &&
		foreach_sdk pkg_copy_artifacts &&
		install "$package" &&
		if test -z "$skip_upload"; then upload "$package"; fi
	fi &&

	if test -n "$relnotes_feature"
	then
		(cd "$sdk64/usr/src/build-extra" &&
		 git pull origin master &&
		 mention feature "$relnotes_feature"&&
		 create_bundle_artifact &&
		 if test -z "$skip_upload"; then really_push origin HEAD; fi)
	fi
}

set_version_from_sdks_git () {
	version="$("$sdk64/cmd/git.exe" version)"
	version32="$("$sdk32/cmd/git.exe" version)"
	test -n "$version" &&
	test "a$version" = "a$version32" ||
	die "Version mismatch in 32/64-bit: %s vs %s\n" "$version32" "$version"

	version="${version#git version }"
	ver="$(echo "$version" | sed -n \
	 's/^\([0-9]*\.[0-9]*\.[0-9]*\)\.windows\(\.1\|\(\.[0-9]*\)\)$/\1\3/p')"
	test -n "$ver" ||
	die "Unexpected version format: %s\n" "$version"

	displayver="$ver"
	case "$displayver" in
	*.*.*.*)
		displayver="${displayver%.*}(${displayver##*.})"
		;;
	esac
}

version_from_release_notes () {
	sed -e '1s/^# Git for Windows v\(.*\) Release Notes$/\1/' -e 1q \
		"$sdk64/usr/src/build-extra/ReleaseNotes.md"
}

previous_version_from_release_notes () {
	sed -n "/^## Changes since/{s/## .* v\([^ ]*\) (.*/\1/p;q}" \
		<"$sdk64"/usr/src/build-extra/ReleaseNotes.md
}

today () {
	LC_ALL=C date +"%B %-d %Y" |
	sed -e 's/\( [2-9]\?[4-90]\| 1[0-9]\) /\1th /' \
		-e 's/1 /1st /' -e 's/2 /2nd /' -e 's/3 /3rd /'
}

mention () { # <what, e.g. bug-fix, new-feature> <release-notes-item>
	case "$1" in
	bug|bugfix|bug-fix) what="Bug Fixes";;
	new|feature|newfeature|new-feature) what="New Features";;
	*) die "Don't know how to mention %s\n" "$1";;
	esac
	shift

	quoted="* $(echo "$*" | sed "s/[\\\/\"'&]/\\\\&/g")"

	if test ! -d "$sdk32/$pkgpath"; then
		(cd "$sdk64/$pkgpath" && require_clean_worktree)
	fi ||
	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	relnotes="$sdk64"/usr/src/build-extra/ReleaseNotes.md
	latest="$(version_from_release_notes)"
	if test "$latest" != "$(previous_version_from_release_notes)"
	then
		# insert whole "Changes since" section
		date="$(sed -n -e '2s/Latest update: //p' -e 2q \
			<"$relnotes")"
		quoted="v$latest ($date)\\n\\n### $what\\n\\n$quoted"
		quoted="## Changes since Git for Windows $quoted"
		sed -i -e "/^## Changes since/{s/^/$quoted\n\n/;:1;n;b1}" \
			"$relnotes"
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

			:7;n;b7}' "$relnotes"
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
			}' -e p "$relnotes"
		;;
	esac

	(cd "$sdk64"/usr/src/build-extra &&
	 what_singular="$(echo "$what" |
		 sed -e 's/Fixes/Fix/' -e 's/Features/Feature/')" &&
	 git commit -s -m "Mention $what_singular in release notes" \
		-m "$(echo "$*" | fmt -72)" ReleaseNotes.md) ||
	die "Could not commit release note edits\n"

	test ! -d "$sdk32"/usr/src/build-extra ||
	(cd "$sdk32"/usr/src/build-extra &&
	 git pull --ff-only "$sdk64"/usr/src/build-extra master) ||
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
	relnotes|rel-notes|release-notes) ;;
	*) die "I don't know how to finalize %s\n" "$1";;
	esac

	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	update git &&
	git_src_dir="$sdk64/$pkgpath"/src/git &&
	require_git_src_dir &&
	(cd "$git_src_dir"/.git &&
	 require_remote upstream https://github.com/git/git &&
	 require_remote git-for-windows \
		https://github.com/git-for-windows/git) &&
	dir_option="--git-dir=$sdk64/$pkgpath"/src/git/.git &&
	git "$dir_option" fetch --tags git-for-windows &&
	git "$dir_option" fetch --tags upstream ||
	die "Could not update Git\n"

	case "$branch_to_use" in
	*@*)
		git "$dir_option" fetch --tags \
			"${branch_to_use#*@}" "${branch_to_use%%@*}" ||
		die "Could not fetch '%s' from '%s'\n" \
			"${branch_to_use%%@*}" "${branch_to_use#*@}"
		branch_to_use=FETCH_HEAD
		;;
	esac
	branch_to_use="${branch_to_use:-git-for-windows/master}"

	ver="$(git "$dir_option" \
		describe --first-parent --match 'v[0-9]*[0-9]' \
		"$branch_to_use")" ||
	die "Cannot describe current revision of Git\n"
	ver=${ver%%-*}

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

		nextver=${ver%.windows.*}.windows.$((${ver##*.windows.}+1))
		displayver="${ver%.windows.*}(${nextver##*.windows.})"
		;;
	*)
		i=1
		displayver="$ver"
		while git "$dir_option" \
			rev-parse --verify $ver.windows.$i >/dev/null 2>&1
		do
			i=$(($i+1))
			displayver="$ver($i)"
		done
		nextver=$ver.windows.$i
		;;
	esac
	displayver=${displayver#v}

	test "$displayver" != "$(version_from_release_notes)" ||
	die "Version %s already in the release notes\n" "$displayver"

	case "$nextver" in
	*.windows.1)
		v=${nextver%.windows.1} &&
		if ! grep -q "^\\* Comes with \\[Git $v\\]" \
			"$sdk64"/usr/src/build-extra/ReleaseNotes.md
		then
			url=https://github.com/git/git/blob/$v &&
			url=$url/Documentation/RelNotes/${v#v}.txt &&
			mention feature 'Comes with [Git '$v']('$url').'
		fi ||
		die "Could not mention that Git was upgraded to $v\n"
		;;
	esac

	test -n "$release_date" ||
	release_date="$(today)"

	sed -i -e "1s/.*/# Git for Windows v$displayver Release Notes/" \
		-e "2s/.*/Latest update: $release_date/" \
		"$sdk64"/usr/src/build-extra/ReleaseNotes.md ||
	die "Could not edit release notes\n"

	(cd "$sdk64"/usr/src/build-extra &&
	 git commit -s -m "Prepare release notes for v$displayver" \
		ReleaseNotes.md) ||
	die "Could not commit finalized release notes\n"

	(cd "$sdk32"/usr/src/build-extra &&
	 git pull --ff-only "$sdk64"/usr/src/build-extra master) ||
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
			"sign //v //f mycert.p12 //p mypassword'" \
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
	packages="mingw-w64-git-pdb mingw-w64-curl-pdb mingw-w64-openssl-pdb
		bash-devel"

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
	architectures="i686 x86_64"

	versions="$(case $# in 0) pacman -Q;; 1) cat "$1";; esac |
		sed 's/^\(mingw-w64\)\(-[^-]*\)/\1/' | sort | uniq)"
	test -n "$versions" ||
	die 'Could not obtain package versions\n'

	git_version="$(echo "$versions" | sed -n 's/^mingw-w64-git //p')"

	dir="${this_script_path:+$(cygpath -au \
		"${this_script_path%/*}")/}"cached-source-packages
	test -n "$unpack" ||
	unpack=$dir/.unpack
	url=https://wingit.blob.core.windows.net

	mkdir -p "$dir" ||
	die "Could not create '%s'\n" "$dir"

	for arch in $architectures
	do
		test i686 = $arch &&
		bitness=32-bit ||
		bitness=64-bit

		echo "Unpacking .pdb files for $bitness..." >&2

		test x86_64 = $arch &&
		oarch=x86-64 ||
		oarch=$arch

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
				tar=mingw-w64-$arch-${package#mingw-w64-}-$version-any.pkg.tar.xz
				dir2="$sdk64/usr/src/MINGW-packages/$name"
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
			 "$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
				"tar --wildcards -xf \"$dir/$tar\" \\*.pdb") ||
			die 'Could not unpack .pdb files from %s\n' "$tar"
		done

		test -n "$artifactsdir" || continue

		zip=pdbs-for-git-$bitness-$git_version.zip &&
		echo "Bundling .pdb files for $bitness..." >&2
		(cd "$unpack" &&
		 "$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"7za a -mx9 \"$artifactsdir/$zip\" *") &&
		echo "Created $artifactsdir/$zip" >&2 ||
		die 'Could not create %s for %s\n' "$zip" "$arch"
	done
}

release () { # [--directory=<artifacts-directory>] [--release-date=*]
	artifactsdir=
	release_date=
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
	--release-date=*)
		release_date="$(echo "${1#*=}" | tr +_ ' ')"
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	set_version_from_sdks_git

	# if builtins are still original hard-links, reinstall git-extra
	cmp "$sdk32"/mingw32/bin/git-receive-pack.exe \
		"$sdk32"/mingw32/bin/git.exe 2>/dev/null &&
	"$sdk32/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'pacman -S --noconfirm git-extra'
	cmp "$sdk64"/mingw64/bin/git-receive-pack.exe \
		"$sdk64"/mingw64/bin/git.exe 2>/dev/null &&
	"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'pacman -S --noconfirm git-extra'

	echo "Releasing Git for Windows $displayver" >&2

	test "$displayver" = "$(version_from_release_notes)" ||
	die "Incorrect version in the release notes\n"

	test -n "$release_date" ||
	release_date="$(today)"

	test "Latest update: $release_date" = "$(sed -n 2p \
		<"$sdk64/usr/src/build-extra/ReleaseNotes.md")" ||
	die "Incorrect release date in the release notes\n"

	for sdk in "$sdk32" "$sdk64"
	do
		for dir in installer portable archive mingit
		do
			"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
				"/usr/src/build-extra/$dir/release.sh '$ver'" ||
			die "Could not make %s in %s\n" "$dir" "$sdk"
		done
		test "$sdk64" != "$sdk" ||
		(cd "$sdk/usr/src/build-extra" &&
		 cp installer/package-versions.txt \
		    versions/package-versions-$ver.txt &&
		 cp mingit/root/etc/package-versions.txt \
		    versions/package-versions-$ver-MinGit.txt &&
		 git add versions/package-versions-$ver.txt \
			versions/package-versions-$ver-MinGit.txt &&
		 git commit -s -m "versions: add v$ver" \
			versions/package-versions-$ver.txt \
			versions/package-versions-$ver-MinGit.txt &&
		 if test -n "$artifactsdir"
		 then
			git -C "$sdk64/usr/src/build-extra" bundle create \
				"$artifactsdir/build-extra.bundle" \
				-9 master &&
			cp versions/package-versions-$ver-MinGit.txt \
				versions/package-versions-$ver.txt \
				"$artifactsdir/"
		 fi) ||
		die "Could not add the package-versions for %s\n" "$ver"

		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"/usr/src/build-extra/mingit/release.sh \
				--busybox '$ver-busybox'" ||
		die "Could not make BusyBox-based MinGit in %s\n" "$sdk"
	done

	sign_files "$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
		"$HOME"/PortableGit-"$ver"-32-bit.7z.exe

	"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"/usr/src/build-extra/nuget/release.sh '$ver'" &&
	"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"/usr/src/build-extra/nuget/release.sh --mingit '$ver'" ||
	die "Could not make NuGet packages\n"

	if test -n "$artifactsdir"
	then
		(cd "$USERPROFILE" && cp \
			Git-"$ver"-64-bit.exe \
			Git-"$ver"-32-bit.exe \
			"$artifactsdir/") &&
		(cd "$HOME" && cp \
			PortableGit-"$ver"-64-bit.7z.exe \
			PortableGit-"$ver"-32-bit.7z.exe \
			MinGit-"$ver"-64-bit.zip \
			MinGit-"$ver"-32-bit.zip \
			MinGit-"$ver"-busybox-64-bit.zip \
			MinGit-"$ver"-busybox-32-bit.zip \
			Git-"$ver"-64-bit.tar.bz2 \
			Git-"$ver"-32-bit.tar.bz2 \
			GitForWindows.$ver.nupkg \
			Git-Windows-Minimal.$ver.nupkg \
			"$artifactsdir/") ||
		die "Could not copy artifacts to '%s'\n" "$artifactsdir"

		(cd "$sdk64/usr/src/build-extra" &&
		 bundle_pdbs --directory="$artifactsdir" \
			installer/package-versions.txt) ||
		die 'Could not generate .pdb bundles\n'
	fi
}

virus_check () { #
	set_version_from_sdks_git

	grep -q '^machine api\.virustotal\.com$' "$HOME"/_netrc ||
	die "Missing VirusTotal entries in ~/_netrc\n"

	for file in \
		"$HOME"/Git-"$ver"-64-bit.exe \
		"$HOME"/Git-"$ver"-32-bit.exe \
		"$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
		"$HOME"/PortableGit-"$ver"-32-bit.7z.exe
	do
		"$sdk64/usr/src/build-extra/send-to-virus-total.sh" \
			"$file" || exit
	done
}

require_3rdparty_directory () {
	test -d "$sdk64/usr/src/git" || {
		mkdir -p "$sdk64/usr/src/git" &&
		git init "$sdk64/usr/src/git" &&
		git -C "$sdk64/usr/src/git" remote add origin \
			https://github.com/git-for-windows/git
	} ||
	die 'Could not initialize /usr/src/git in SDK-64\n'

	test -d "$sdk64/usr/src/git/3rdparty" || {
		mkdir "$sdk64/usr/src/git/3rdparty" &&
		echo "/3rdparty/" >> "$sdk64/usr/src/git/.git/info/exclude"
	} ||
	die "Could not make /usr/src/3rdparty in SDK-64\n"
}

publish () { #
	set_version_from_sdks_git

	git_pkgver="$("$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'pacman -Q mingw-w64-x86_64-git | sed "s/.* //"')"

	needs_upload_permissions || exit

	grep -q '<apikeys>' "$HOME"/AppData/Roaming/NuGet/NuGet.Config ||
	die "Need to call \`%s setApiKey Your-API-Key\`\n" \
		"$sdk64/usr/src/build-extra/nuget/nuget.exe"

	require_3rdparty_directory

	wwwdir="$sdk64/usr/src/git/3rdparty/git-for-windows.github.io"
	if test ! -d "$wwwdir"
	then
		git clone https://github.com/git-for-windows/${wwwdir##*/} \
			"$wwwdir"
	fi &&
	(cd "$wwwdir" &&
	 sdk= pkgpath=$PWD ff_master &&
	 require_push_url &&
	 if ! type node.exe
	 then
		sdk="$sdk64" require mingw-w64-x86_64-nodejs
	 fi) ||
	die "Could not prepare website clone for update\n"

	(cd "$sdk64/usr/src/build-extra" &&
	 require_push_url &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not prepare build-extra for download-stats update\n"

	test ! -x "$sdk64/mingw64/bin/node.exe" ||
	"$sdk64/mingw64/bin/node.exe" -v || {
		if test -f "$sdk64/mingw64/bin/libcares-3.dll" &&
			test ! -f "$sdk64/mingw64/bin/libcares-2.dll"
		then
			ln "$sdk64/mingw64/bin/libcares-3.dll" \
				"$sdk64/mingw64/bin/libcares-2.dll"
		fi
		"$sdk64/mingw64/bin/node.exe" -v
	} ||
	die "Could not execute node.exe\n"

	# Required to render the release notes for the announcement mail
	sdk="$sdk64" require w3m

	echo "Preparing release message"
	name="Git for Windows $displayver"
	text="$(sed -n \
		"/^## Changes since/,\${s/## //;:1;p;n;/^## Changes/q;b1}" \
		<"$sdk64"/usr/src/build-extra/ReleaseNotes.md)"
	checksums="$(printf 'Filename | SHA-256\n-------- | -------\n'
		(cd "$HOME" && sha256sum.exe \
			Git-"$ver"-64-bit.exe \
			Git-"$ver"-32-bit.exe \
			PortableGit-"$ver"-64-bit.7z.exe \
			PortableGit-"$ver"-32-bit.7z.exe \
			MinGit-"$ver"-64-bit.zip \
			MinGit-"$ver"-32-bit.zip \
			MinGit-"$ver"-busybox-64-bit.zip \
			MinGit-"$ver"-busybox-32-bit.zip \
			Git-"$ver"-64-bit.tar.bz2 \
			Git-"$ver"-32-bit.tar.bz2 \
			pdbs-for-git-64-bit-$git_pkgver.zip \
			pdbs-for-git-32-bit-$git_pkgver.zip) |
		sed -n 's/\([^ ]*\) \*\(.*\)/\2 | \1/p')"
	body="$(printf "%s\n\n%s" "$text" "$checksums")"
	quoted="$(echo "$body" |
		sed -e ':1;${s/[\\"]/\\&/g;s/\n/\\n/g};N;b1')"

	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--gentle --repo=git "v$version" \
		"$HOME"/Git-"$ver"-64-bit.exe \
		"$HOME"/Git-"$ver"-32-bit.exe \
		"$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
		"$HOME"/PortableGit-"$ver"-32-bit.7z.exe \
		"$HOME"/MinGit-"$ver"-64-bit.zip \
		"$HOME"/MinGit-"$ver"-32-bit.zip \
		"$HOME"/MinGit-"$ver"-busybox-64-bit.zip \
		"$HOME"/MinGit-"$ver"-busybox-32-bit.zip \
		"$HOME"/Git-"$ver"-64-bit.tar.bz2 \
		"$HOME"/Git-"$ver"-32-bit.tar.bz2 \
		"$HOME"/pdbs-for-git-64-bit-$git_pkgver.zip \
		"$HOME"/pdbs-for-git-32-bit-$git_pkgver.zip ||
	die "Could not upload files\n"

	for nupkg in GitForWindows Git-Windows-Minimal
	do
		test "$nupkg $ver" != \
			"$("$sdk64/usr/src/build-extra/nuget/nuget.exe" \
				list "$nupkg")" ||
		continue

		count=0
		while test $count -lt 5
		do
			"$sdk64/usr/src/build-extra/nuget/nuget.exe" \
				push -NonInteractive -Verbosity detailed \
				-Source https://www.nuget.org/api/v2/package \
				-Timeout 3000 "$HOME"/$nupkg.$ver.nupkg && break
			count=$(($count+1))
		done
		test $count -lt 5 ||
		die "Could not upload %s\n" "$HOME"/$nupkg.$ver.nupkg
	done

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git" &&
	nextver=v"$version" &&
	git -C "$git_src_dir" push git-for-windows "$nextver" ||
	die "Could not push tag %s in %s\n" "$nextver" "$git_src_dir"

	url=https://api.github.com/repos/git-for-windows/git/releases
	id="$(curl --netrc -s $url |
		sed -n '/"id":/{N;N;/"tag_name": *"v'"$version"'"/{
			s/.*"id": *\([0-9]*\).*/\1/p;q}}')"
	test -n "$id" ||
	die "Could not determine ID of release for %s\n" "$version"

	out="$(curl --netrc --show-error -s -XPATCH -d \
		'{"name":"'"$name"'","body":"'"$quoted"'",
		 "draft":false,"prerelease":false}' \
		$url/$id)" ||
	die "Could not edit release for %s:\n%s\n" "$version" "$out"

	echo "Updating website..." >&2
	(cd "$wwwdir" &&
	 PATH="$sdk64/mingw64/bin/:$PATH" node.exe bump-version.js --auto &&
	 git commit -a -s -m "New Git for Windows version" &&
	 really_push origin HEAD) ||
	die "Could not update website\n"

	echo "Updating download-stats.sh..." >&2
	(cd "$sdk64/usr/src/build-extra" &&
	 ./download-stats.sh --update &&
	 git commit -s -m "download-stats: new Git for Windows version" \
		./download-stats.sh &&
	 really_push origin HEAD) ||
	die "Could not update download-stats.sh\n"

	prefix="$(printf "%s\n\n%s%s\n\n\t%s\n" \
		"Dear Git users," \
		"It is my pleasure to announce that Git for Windows " \
		"$displayver is available from:" \
		"https://gitforwindows.org/")"
	rendered="$(echo "$text" |
		"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'markdown |
			 LC_CTYPE=C w3m -dump -cols 72 -T text/html')"
	printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n%s\n" \
		"From $version Mon Sep 17 00:00:00 2001" \
		"From: $(git var GIT_COMMITTER_IDENT | sed -e 's/>.*/>/')" \
		"Date: $(date -R)" \
		"To: git-for-windows@googlegroups.com, git@vger.kernel.org, git-packagers@googlegroups.com" \
		"Subject: [ANNOUNCE] Git for Windows $displayver" \
		"Content-Type: text/plain; charset=UTF-8" \
		"Content-Transfer-Encoding: 8bit" \
		"MIME-Version: 1.0" \
		"Fcc: Sent" \
		"$prefix" \
		"$rendered" \
		"$checksums" \
		"Ciao," \
		"$(git var GIT_COMMITTER_IDENT | sed -e 's/ .*//')" \
		> "$HOME/announce-$ver"

	test -z "$(git config alias.sendannouncementmail)" ||
	git sendAnnouncementMail "$HOME/announce-$ver" ||
	echo "error: could not send announcement" >&2

	echo "Announcement saved as ~/announcement-$ver" >&2
}

release_sdk () { # <version>
	version="$1"
	tag=git-sdk-"$version"

	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	! git rev-parse --git-dir="$sdk64"/usr/src/build-extra \
		--verify "$tag" >/dev/null 2>&1 ||
	die "Tag %s already exists\n" "$tag"

	for sdk in "$sdk32" "$sdk64"
	do
		"$sdk"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'cd /usr/src/build-extra/sdk-installer &&
			 ./release.sh '"$version" ||
		die "%s: could not build\n" "$sdk/$pkgpath"
	done

	sign_files "$HOME"/git-sdk-installer-"$version"-64.7z.exe \
		"$HOME"/git-sdk-installer-"$version"-32.7z.exe

	git --git-dir="$sdk64"/usr/src/build-extra/.git \
		tag -a -m "Git for Windows SDK $version" "$tag" ||
	die "Could not tag %s\n" "$tag"
}

publish_sdk () { #
	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	tag="$(git --git-dir="$sdk64"/usr/src/build-extra/.git for-each-ref \
		--format='%(refname:short)' --sort=-taggerdate \
		--count=1 'refs/tags/git-sdk-*'	)"
	version="${tag#git-sdk-}"

	url=https://api.github.com/repos/git-for-windows/build-extra/releases
	id="$(curl --netrc -s $url |
		sed -n '/"id":/{N;N;/"tag_name": *"'"$tag"'"/{
			s/.*"id": *\([0-9]*\).*/\1/p;q}}')"
	test -z "$id" ||
	die "Release %s exists already as ID %s\n" "$tag" "$id"

	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--repo=build-extra "$tag" \
		"$HOME"/git-sdk-installer-"$version"-64.7z.exe \
		"$HOME"/git-sdk-installer-"$version"-32.7z.exe ||
	die "Could not upload files\n"

	git --git-dir="$sdk64"/usr/src/build-extra/.git push origin "$tag"
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

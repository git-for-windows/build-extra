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

sdk_path () { # <bitness>
	result="$(git config windows.sdk"$1".path)" && test -n "$result" ||
	result="C:/git-sdk-$1"

	test -e "$result" ||
	die "%s\n\n%s\n%s\n" \
		"Could not determine location of Git for Windows SDK $1-bit" \
		"Default location: C:/git-sdk-$1" \
		"Config variable to override: windows.sdk$1.path"

	echo "$result"
}

sdk64="$(sdk_path 64)"
sdk32="$(sdk_path 32)"

in_use () { # <sdk> <path>
	test -n "$($1/mingw??/bin/WhoUses.exe -m "$1$path" |
		grep '^[^-P]')"
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

sync () { #
	for sdk in "$sdk32" "$sdk64"
	do
		"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe -Sy ||
		die "Cannot run pacman in %s\n" "$sdk"

		for p in bash pacman "msys2-runtime msys2-runtime-devel"
		do
			"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe \
				-S --noconfirm --needed $p ||
			die "Could not update %s in %s\n" "$p" "$sdk"
		done

		PATH="$sdk/bin:$PATH" \
		"$sdk/git-cmd.exe" --cd="$sdk" --command=usr\\bin\\sh.exe -l \
			-c 'pacman -Su --noconfirm' ||
		die "Cannot update packages in %s\n" "$sdk"

		# git-extra rewrites some files owned by other packages,
		# therefore it has to be (re-)installed now
		PATH="$sdk/bin:$PATH" \
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'pacman -S --noconfirm git-extra' ||
		die "Cannot update git-extra in %s\n" "$sdk"
	done
}

killall () { # <bitness>
	sdk="$(eval "echo \$sdk$1")"

	pids="$("$sdk/git-cmd.exe" --command=usr\\bin\\ps.exe -s |
		grep -v ' /usr/bin/ps$' |
		sed -n "s/^ *\([0-9][0-9]*\).*/\1/p")"
	test -z "$pids" ||
	"$sdk/git-cmd.exe" --command=usr\\bin\\kill.exe $pids
}

# set_package <package>
set_package () {
	package="$1"
	extra_packages=
	case "$package" in
	git-extra)
		type=MINGW
		path=/usr/src/build-extra/git-extra
		;;
	git)
		package=mingw-w64-git
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
		type=MINGW
		path=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-git)
		type=MINGW
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
		path=/usr/src/MINGW-packages/$package
		;;
	msys2-runtime)
		type=MSYS
		extra_packages="msys2-runtime-devel"
		path=/usr/src/MSYS2-packages/$package
		;;
	mintty)
		type=MSYS
		path=/usr/src/MSYS2-packages/$package
		;;
	w3m)
		type=MSYS
		path=/usr/src/MSYS2-packages/$package
		;;
	*)
		die "Unknown package: %s\n" "$package"
		;;
	esac
}

# foreach_sdk <function> [<args>]
foreach_sdk () {
	# No uncommitted changes?
	for sdk in "$sdk32" "$sdk64"
	do
		# MINGW packages are compiled in the 64-bit SDK only
		test "a$sdk64" = "a$sdk" ||
		test MINGW != "$type" ||
		continue

		(cd "$sdk/$path" ||
		 die "%s does not exist\n" "$sdk/$path"

		 "$@") || exit
	done
}

require_clean_worktree () {
	git update-index -q --ignore-submodules --refresh &&
	git diff-files --quiet --ignore-submodules &&
	git diff-index --cached --quiet --ignore-submodules HEAD ||
	die "%s not up-to-date" "$sdk/$path"
}

ff_master () {
	test refs/heads/master = "$(git rev-parse --symbolic-full-name HEAD)" ||
	die "%s: Not on 'master'\n" "$sdk/$path"

	require_clean_worktree

	git pull --ff-only origin master ||
	die "%s: cannot fast-forward 'master'\n" "$sdk/$path"
}

update () { # <package>
	set_package "$1"

	foreach_sdk ff_master
}

# require <metapackage> <telltale>
require () {
	test -d "$sdk"/var/lib/pacman/local/"${2:-$1}"-[0-9]* ||
	"$sdk"/git-cmd.exe --command=usr\\bin\\pacman.exe \
		-Sy --needed --noconfirm "$1" ||
	die "Could not install %s\n" "$1"
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
	for prereq in mingw-w64-i686-asciidoctor-extensions
	do
		test ! -d "$sdk64"/var/lib/pacman/local/$prereq-[0-9]* ||
		continue

		sdk="$sdk32" require $prereq &&
		pkg="$sdk32/var/cache/pacman/pkg/$("$sdk32/git-cmd.exe" \
			--command=usr\\bin\\pacman.exe -Q "$prereq" |
			sed -e 's/ /-/' -e 's/$/-any.pkg.tar.xz/')" &&
		"$sdk64"/git-cmd.exe --command=usr\\bin\\sh.exe -l -c \
			'pacman -U --noconfirm "'"$pkg"'"' ||
		die "Could not install %s into SDK-64\n" "$prereq"
	done

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

		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'MAKEFLAGS=-j5 MINGW_INSTALLS=mingw32\ mingw64 \
				makepkg-mingw -s --noconfirm &&
			 MINGW_INSTALLS=mingw64 makepkg-mingw --allsource' ||
		die "%s: could not build\n" "$sdk/$path"

		git commit -s -m "$package: new version" PKGBUILD ||
		die "%s: could not commit after build\n" "$sdk/$path"
		;;
	MSYS)
		require msys2-devel binutils
		if test msys2-runtime = "$package"
		then
			require mingw-w64-cross-gcc mingw-w64-cross-gcc
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
			'export MSYSTEM=MSYS &&
			 export PATH=/usr/bin:/opt/bin:$PATH &&
			 MAKEFLAGS=-j5 makepkg -s --noconfirm &&
			 makepkg --allsource' ||
		die "%s: could not build\n" "$sdk/$path"

		if test "a$sdk32" = "a$sdk"
		then
			git diff-files --quiet --ignore-submodules PKGBUILD ||
			git commit -s -m "$package: new version" PKGBUILD ||
			die "%s: could not commit after build\n" "$sdk/$path"
		else
			git add PKGBUILD &&
			git pull "$sdk32/${path%/*}/.git" \
				"$(git rev-parse --symbolic-full-name HEAD)" &&
			require_clean_worktree ||
			die "%s: unexpected difference between 32/64-bit\n" \
				"$path"
		fi
		;;
	esac
}

# up_to_date <path>
up_to_date () {
	# test that repos at <path> are up-to-date in both 64-bit and 32-bit
	path="$1"

	commit32="$(cd "$sdk32/$path" && git rev-parse --verify HEAD)" &&
	commit64="$(cd "$sdk64/$path" && git rev-parse --verify HEAD)" ||
	die "Could not determine HEAD commit in %s\n" "$path"

	test "a$commit32" = "a$commit64" ||
	die "%s: commit %s (32-bit) != %s (64-bit)\n" \
		"$path" "$commit32" "$commit64"

	foreach_sdk require_clean_worktree
}

build () { # <package>
	set_package "$1"

	test MINGW = "$type" ||
	up_to_date "$path" ||
	die "%s: not up-to-date\n" "$path"

	foreach_sdk pkg_build
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
	if test -z "$(git config remote."$remote".pushurl)"
	then
		pushurl="$(git config remote."$remote".url |
			sed -n 's|^https://github.com/\(.*\)|github.com:\1|p')"
		test -n "$pushurl" ||
		die "Not a GitHub remote: %s\n" "$remote"

		git remote set-url --push "$remote" "$pushurl" ||
		die "Could not set push URL of %s to %s\n" "$remote" "$pushurl"

		grep -q '^Host github.com$' "$HOME/.ssh/config" ||
		die "No github.com entry in ~/.ssh/config\n"
	fi
}

tag_git () { #
	sdk="$sdk64" require w3m w3m

	build_extra_dir="$sdk64/usr/src/build-extra"
	(cd "$build_extra_dir" &&
	 sdk= path=$PWD ff_master) ||
	die "Could not update build-extra\n"

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git"
	(cd "$git_src_dir" &&
	 require_remote upstream https://github.com/git/git &&
	 require_remote git-for-windows \
		https://github.com/git-for-windows/git &&
	 require_push_url git-for-windows) || exit

	nextver="$(sed -ne \
		'1s/.* \(v[0-9][.0-9]*\)(\([0-9][0-9]*\)) .*/\1.windows.\2/p' \
		-e '1s/.* \(v[0-9][.0-9]*\) .*/\1.windows.1/p' \
		<"$build_extra_dir/installer/ReleaseNotes.md")"
	! git --git-dir="$git_src_dir" rev-parse --verify \
		refs/tags/"$nextver" >/dev/null 2>&1 ||
	die "Already tagged: %s\n" "$nextver"

	notes="$("$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'markdown </usr/src/build-extra/installer/ReleaseNotes.md |
		 w3m -dump -cols 72 -T text/html | \
		 sed -n "/^Changes since/,\${:1;p;n;/^Changes/q;b1}"')"

	tag_message="$(printf "%s\n\n%s" \
		"$(sed -n '1s/.*\(Git for Windows v[^ ]*\).*/\1/p' \
		<"$build_extra_dir/installer/ReleaseNotes.md")" "$notes")" &&
	(cd "$git_src_dir" &&
	 git tag -m "$tag_message" -a "$nextver" git-for-windows/master) ||
	die "Could not tag %s in %s\n" "$nextver" "$git_src_dir"

	(cd "$git_src_dir" &&
	 git push git-for-windows "$nextver") ||
	die "Could not push tag %s in %s\n" "$nextver" "$git_src_dir"
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

pkg_files () {
	pkgver="$(sed -ne \
		'/^_basever=/{N;N;s/.*=\([0-9].*\)\n.*\npkgrel=\(.*\)/\1-\2/p}' \
		-e '/^pkgver=/{N;s/.*=\([0-9].*\)\npkgrel=\(.*\)/\1-\2/p}' \
		<PKGBUILD)"
	test -n "$pkgver" ||
	die "%s: could not determine pkgver\n" "$sdk/$path"

	test a--for-upload != "a$1" ||
	echo $package-$pkgver.src.tar.gz

	test "a$sdk" = "a$sdk32" &&
	arch=i686 ||
	arch=x86_64

	for p in $package $extra_packages
	do
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

	"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"pacman -U --noconfirm $files"

	if test MINGW = "$type"
	then
		"$sdk32/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			"pacman -U --noconfirm $(pkg_files --i686)"
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
	set_package "$1"

	grep -q '^machine api\.bintray\.com$' "$HOME"/_netrc ||
	die "Missing BinTray entries in ~/_netrc\n"

	(cd "$sdk64/$path" &&
	 require_push_url origin) || exit

	pacman_helper fetch &&
	foreach_sdk pkg_upload &&
	pacman_helper push ||
	die "Could not upload %s\n" "$package"

	# Here, we exploit the fact that the 64-bit SDK is either the only
	# SDK where the package was built (MinGW) or it agrees with thw 32-bit
	# SDK's build product (MSys2).
	(cd "$sdk64/$path" &&
	 test -z "$(git rev-list @{u}..)" ||
	 if test refs/heads/master = \
		"$(git rev-parse --symbolic-full-name HEAD)"
	 then
		git -c push.default=simple push
	 else
		echo "The local branch in $sdk64/$path has unpushed changes" >&2
	 fi) ||
	die "Could not push commits in %s/%s\n" "$sdk64" "$path"
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

release () { #
	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	set_version_from_sdks_git

	echo "Releasing Git for Windows $displayver" >&2

	test "# Git for Windows v$displayver Release Notes" = "$(head -n 1 \
		"$sdk64/usr/src/build-extra/installer/ReleaseNotes.md")" ||
	die "Incorrect version in the release notes\n"

	today="$(LC_ALL=C date +"%B %-d %Y" | sed \
		-e 's/\( [2-9]\?[4-90]\| 1[0-9]\) /\1th /' \
		-e 's/1 /1st /' -e 's/2 /2nd /' -e 's/3 /3rd /')"
	test "Latest update: $today" = "$(sed -n 2p \
		<"$sdk64/usr/src/build-extra/installer/ReleaseNotes.md")" ||
	die "Incorrect release date in the release notes\n"

	for sdk in "$sdk32" "$sdk64"
	do
		for dir in installer portable archive
		do
			"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
				"/usr/src/build-extra/$dir/release.sh '$ver'" ||
			die "Could not make %s in %s\n" "$dir" "$sdk"
		done
	done

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
		for file in \
			"$HOME"/Git-"$ver"-64-bit.exe \
			"$HOME"/Git-"$ver"-32-bit.exe \
			"$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
			"$HOME"/PortableGit-"$ver"-32-bit.7z.exe
		do
			git --git-dir="$sdk64/usr/src/build-extra/.git" \
				signtool "$file"
		done
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

publish () { #
	set_version_from_sdks_git

	grep -q '^machine api\.github\.com$' "$HOME"/_netrc &&
	grep -q '^machine uploads\.github\.com$' "$HOME"/_netrc ||
	die "Missing GitHub entries in ~/_netrc\n"

	test -d "$sdk64/usr/src/git/3rdparty" || {
		mkdir "$sdk64/usr/src/git/3rdparty" &&
		echo "/3rdparty/" >> "$sdk64/usr/src/git/.git/info/exclude"
	} ||
	die "Could not make /usr/src/3rdparty in SDK-64\n"

	wwwdir="$sdk64/usr/src/git/3rdparty/git-for-windows.github.io"
	if test ! -d "$wwwdir"
	then
		git clone https://github.com/git-for-windows/${wwwdir##*/} \
			"$wwwdir"
	fi &&
	(cd "$wwwdir" &&
	 sdk= path=$PWD ff_master &&
	 require_push_url &&
	 sdk="$sdk64" require mingw-w64-x86_64-nodejs) ||
	die "Could not prepare website clone for update\n"

	(cd "$sdk64/usr/src/build-extra" &&
	 require_push_url &&
	 sdk= path=$PWD ff_master) ||
	die "Could not prepare build-extra for download-stats update\n"

	echo "Preparing release message"
	name="Git for Windows $displayver"
	text="$(sed -n \
		"/^## Changes since/,\${s/## //;:1;p;n;/^## Changes/q;b1}" \
		<"$sdk64"/usr/src/build-extra/installer/ReleaseNotes.md)"
	checksums="$(printf 'Filename | SHA-256\n-------- | -------\n'
		(cd "$HOME" && sha256sum.exe \
			Git-"$ver"-64-bit.exe \
			Git-"$ver"-32-bit.exe \
			PortableGit-"$ver"-64-bit.7z.exe \
			PortableGit-"$ver"-32-bit.7z.exe \
			Git-"$ver"-64-bit.tar.bz2 \
			Git-"$ver"-32-bit.tar.bz2) |
		sed -n 's/\([^ ]*\) \*\(.*\)/\2 | \1/p')"
	body="$(printf "%s\n\n%s" "$text" "$checksums")"
	quoted="$(echo "$body" |
		sed -e ':1;${s/[\\"]/\\&/g;s/\n/\\n/g};N;b1')"

	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--repo=git "v$version" \
		"$HOME"/Git-"$ver"-64-bit.exe \
		"$HOME"/Git-"$ver"-32-bit.exe \
		"$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
		"$HOME"/PortableGit-"$ver"-32-bit.7z.exe \
		"$HOME"/Git-"$ver"-64-bit.tar.bz2 \
		"$HOME"/Git-"$ver"-32-bit.tar.bz2 ||
	die "Could not upload files\n"

	url=https://api.github.com/repos/git-for-windows/git/releases
	id="$(curl --netrc -s $url |
		sed -n '/"id":/{N;/"tag_name": *"v'"$version"'"/{
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
	 "$sdk64/mingw64/bin/node.exe" bump-version.js --auto &&
	 git commit -a -s -m "New Git for Windows version" &&
	 git push origin HEAD) ||
	die "Could not update website\n"

	echo "Updating download-stats.sh..." >&2
	(cd "$sdk64/usr/src/build-extra" &&
	 ./download-stats.sh --update &&
	 git commit -a -s -m "download-stats: new Git for Windows version" &&
	 git push origin HEAD) ||
	die "Could not update download-stats.sh\n"

	prefix="$(printf "%s\n\n%s%s\n\n\t%s\n" \
		"Dear Git users," \
		"It is my pleasure to announce that Git for Windows " \
		"$displayver is available from:" \
		"https://git-for-windows.github.io/")"
	rendered="$(echo "$text" |
		"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'markdown | w3m -dump -cols 72 -T text/html')"
	printf "%s\n%s\n%s\n%s\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n%s\n" \
		"From $version Mon Sep 17 00:00:00 2001" \
		"From: $(git var GIT_COMMITTER_IDENT | sed -e 's/>.*/>/')" \
		"Date: $(date -R)" \
		"To: git-for-windows@googlegroups.com, git@vger.kernel.org" \
		"Subject: [ANNOUNCE] Git for Windows $displayver" \
		"$prefix" \
		"$rendered" \
		"$checksums" \
		"Ciao," \
		"$(git var GIT_COMMITTER_IDENT | sed -e 's/ .*//')" \
		> "$HOME/announce-$ver"
	echo "Announcement saved as ~/announcement-$ver" >&2
}

test $# -gt 0 &&
test help != "$*" ||
die "Usage: $0 <command>\n\nCommands:\n%s" \
	"$(sed -n 's/^\([a-z_]*\) () { #\(.*\)/\t\1\2/p' <"$0")"

command="$1"
shift

usage="$(sed -n "s/^$command () { # \?/ /p" <"$0")"
test -n "$usage" ||
die "Unknown command: %s\n" "$command"

test $# = $(echo "$usage" | tr -dc '<' | wc -c) ||
die "Usage: %s %s%s\n" "$0" "$command" "$usage"

"$command" "$@"

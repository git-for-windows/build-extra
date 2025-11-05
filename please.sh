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

mount_sdks () { #
	test -d /sdk32 || mount "$sdk32" /sdk32
	test -d /sdk64 || mount "$sdk64" /sdk64
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

	(cd "$pkgpath" && sdk= && require_clean_worktree)

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
		test -d "$coverity_tool" || mkdir $coverity_tool
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
		test -f "$git_src_dir/GIT-VERSION-GEN" ||
		die "Does not appear to contain Git's source code: %s\n" "$git_src_dir"
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
	up_to_date /usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	(cd /usr/src/build-extra && node ./add-release-note.js --commit "$@")
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

	set_package git &&
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
			adoc="$(echo "${v#v}" | sed 's/-rc[0-9]*$//').adoc" &&
			url=$url/Documentation/RelNotes/$adoc &&
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
	url=https://raw.githubusercontent.com/git-for-windows/pacman-repo/refs/heads

	mkdir -p "$dir" ||
	die "Could not create '%s'\n" "$dir"

	for arch in $architectures
	do
		echo "Unpacking .pdb files for $arch..." >&2

		case $arch in
			x86_64)
				oarch=x86_64
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
			if test -z "$version"
			then
				# Fall back to mingw-w64-curl-winssl if mingw-w64-curl is not installed
				if test mingw-w64-curl = "$name"
				then
					name=mingw-w64-curl-winssl
					package=$name-pdb
					version=$(echo "$versions" | sed -n "s/^$name //p")
				fi
				test -n "$version" ||
				die "Package $name not installed?!?"
			fi
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
			"7z a -mx9 \"$artifactsdir/$zip\" *") &&
		echo "Created $artifactsdir/$zip" >&2 ||
		die 'Could not create %s for %s\n' "$zip" "$arch"
	done
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
		elif git -C "$git_sdk_path" rev-parse --quiet --verify HEAD:usr/x86_64-pc-cygwin 2>/dev/null
		then
			architecture=x86_64
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
		/update-via-pacman.ps1

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

		# For the libuuid/libunistring check
		/usr/bin/msys-apr*.dll
		/usr/bin/msys-unistring*.dll
		/usr/bin/msys-gnutls*.dll

		# For the /etc/bash.bash_logout check
		/etc/bash.bash_logout

		# markdown, to render the release notes
		/usr/bin/markdown

		# gettext (for makepkg)
		/usr/bin/gettext.exe
		/usr/bin/xgettext.exe
		/usr/bin/msys-gettext*.dll

		# The `error_highlight` Ruby gem, needed by `asciidoctor`
		*error_highlight*

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
			# Work around an outdated i686 gnupg/gnutls build that depends on a hence-updated libunistring
			if test ! -e "$output_path/usr/bin/msys-unistring-2.dll" -a \
				-e "$output_path/usr/bin/msys-unistring-5.dll" -a \
				-e "$output_path/usr/bin/msys-gnutls-30.dll" &&
				grep msys-unistring-2 "$output_path/usr/bin/msys-gnutls-30.dll"
			then
				cp "$output_path/usr/bin/msys-unistring-5.dll" \
					"$output_path/usr/bin/msys-unistring-2.dll"
			fi &&
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
			printf '\n# For the /etc/msystem.d/ check\n/etc/msystem.d/\n\n' >>"$sparse_checkout_file" &&
			printf '\n# markdown, to render the release notes\n/usr/bin/markdown\n\n' >>"$sparse_checkout_file" &&
			ARCH=$architecture "$output_path/git-cmd.exe" --command=usr\\bin\\sh.exe -l \
			"${this_script_path%/*}/make-file-list.sh" | sed -e 's|[][]|\\&|g' -e 's|^|/|' >>"$sparse_checkout_file"
			;;
		esac &&
		rm "$output_path/etc/profile" &&
		cat <<-EOF >>"$sparse_checkout_file" &&

		# 7-Zip
		$PREFIX/bin/7z.dll
		$PREFIX/bin/7z.exe

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
			"$PREFIX" >"$output_path/usr/bin/git"
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
	maybe_sync=
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
        --reset-pkgrel)
                sed_makepkg_e="$sed_makepkg_e"' -e s/^pkgrel=[0-9][0-9]*$/pkgrel=1/'
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
	--maybe-sync|-s)
		maybe_sync="-s --noconfirm"
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
	 MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} makepkg-mingw $maybe_sync $force -p PKGBUILD.$tag &&
	 if test -n "$src_pkg"
	 then
		git --git-dir src/git/.git archive --prefix git/ -o git-$tag.tar.gz $tag &&
		oid="$(git --git-dir src/git/.git rev-parse $tag^0)" &&
		sed -e 's/^source.*git+https.*/source=("git-'$tag'.tar.gz"/' \
		    -e '/^prepare /{N;s/$/&& sed -i s\/GIT_BUILT_FROM_COMMIT\/\\\"'$oid'\\\"\/ version.c \&\&/}' \
			<PKGBUILD.$tag >PKGBUILD.src &&
		MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} MINGW_ARCH=mingw64 makepkg-mingw $force --allsource -p PKGBUILD.src
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

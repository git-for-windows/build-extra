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
	test -n "$($1/mingw??/bin/WhoUses.exe -m "$1$2" |
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

sync () { # [--force]
	force=
	y_opt=y
	while case "$1" in
	--force)
		force=--force
		y_opt=yy
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 0 ||
	die "Expected no argument, got $#: %s\n" "$*"

	for sdk in "$sdk32" "$sdk64"
	do
		mkdir -p "$sdk/var/log" ||
		die "Could not ensure %s/var/log/ exists\n" "$sdk"

		"$sdk/git-cmd.exe" --command=usr\\bin\\pacman.exe -S$y_opt ||
		die "Cannot run pacman in %s\n" "$sdk"

		PATH="$sdk/usr/bin:$PATH" \
		"$sdk/git-cmd.exe" --cd="$sdk" --command=usr\\bin\\pacman.exe \
			-Su $force --noconfirm ||
		die "Could not update packages in %s\n" "$sdk"

		case "$(tail -c 16384 "$sdk/var/log/pacman.log" |
			grep '\[PACMAN\] starting .* system upgrade' |
			tail -n 1)" in
		*"full system upgrade")
			;; # okay
		*)
			# only "core" packages were updated, update again
			PATH="$sdk/usr/bin:$PATH" \
			"$sdk/git-cmd.exe" --cd="$sdk" \
				--command=usr\\bin\\sh.exe -l \
				-c 'pacman -Su '$force' --noconfirm' ||
			die "Cannot update packages in %s\n" "$sdk"
			;;
		esac

		# A ruby upgrade (or something else) may require a re-install
		# of the `asciidoctor` gem. We only do this for the 64-bit
		# SDK, though, as we require asciidoctor only when building
		# Git, whose 32-bit packages are cross-compiled in from 64-bit.
		test "$sdk64" != "$sdk" ||
		PATH="$sdk/usr/bin:$PATH" \
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'test -n "$(gem list --local | grep "^asciidoctor ")" ||
			 gem install asciidoctor || exit;
			 export PATH=/mingw32/bin:$PATH;
			 test -n "$(gem list --local | grep "^asciidoctor ")" ||
			 gem install asciidoctor' ||
		die "Could not re-install asciidoctor in %s\n" "$sdk"

		# git-extra rewrites some files owned by other packages,
		# therefore it has to be (re-)installed now
		PATH="$sdk/bin:$PATH" \
		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
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
			PATH="$sdk/bin:$PATH" \
			"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
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
		pkgpath=/usr/src/build-extra/git-extra
		;;
	git)
		package=mingw-w64-git
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-git)
		type=MINGW
		extra_packages="mingw-w64-git-doc-html mingw-w64-git-doc-man"
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
	cv2pdb|mingw-w64-cv2pdb)
		package=mingw-w64-cv2pdb
		type=MINGW
		pkgpath=/usr/src/build-extra/mingw-w64-cv2pdb
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
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	curl)
		type=MSYS
		extra_packages="libcurl libcurl-devel"
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	mingw-w64-curl)
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/$package
		;;
	mingw-w64-curl-winssl-bin)
		type=MINGW
		pkgpath=/usr/src/MINGW-packages/mingw-w64-curl
		extra_makepkg_opts="-p PKGBUILD-winssl-bin"
		(cd "$sdk64/$pkgpath" &&
		 test -f PKGBUILD-winssl-bin &&
		 test PKGBUILD-winssl-bin -nt PKGBUILD &&
		 test PKGBUILD-winssl-bin -nt make-PKGBUILD-winssl-bin.sh ||
		 test ! -f make-PKGBUILD-winssl-bin.sh ||
		 ./make-PKGBUILD-winssl-bin.sh) ||
		die "Could not generate PKGBUILD-winssl-bin in %s\n" "$pkgpath"
		;;
	git-flow)
		type=MSYS
		pkgpath=/usr/src/MSYS2-packages/$package
		;;
	p7zip)
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
	# No uncommitted changes?
	for sdk in "$sdk32" "$sdk64"
	do
		# MINGW packages are compiled in the 64-bit SDK only
		test "a$sdk64" = "a$sdk" ||
		test MINGW != "$type" ||
		continue

		(cd "$sdk/$pkgpath" ||
		 die "%s does not exist\n" "$sdk/$pkgpath"

		 "$@") || exit
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

# require <metapackage> <telltale>
require () {
	test -d "$sdk"/var/lib/pacman/local/"${2:-$1}"-[0-9]* ||
	"$sdk"/git-cmd.exe --command=usr\\bin\\pacman.exe \
		-Sy --needed --noconfirm "$1" ||
	die "Could not install %s\n" "$1"
}

install_git_32bit_prereqs () {
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
			 MINGW_INSTALLS=mingw64 makepkg-mingw --allsource \
				'"$extra_makepkg_opts" ||
		die "%s: could not build\n" "$sdk/$pkgpath"

		git commit -s -m "$package: new version" PKGBUILD ||
		die "%s: could not commit after build\n" "$sdk/$pkgpath"
		;;
	MSYS)
		require msys2-devel binutils
		if test msys2-runtime = "$package"
		then
			require mingw-w64-cross-gcc
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
	git -C "$1" fetch "$2" refs/heads/master &&
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

build () { # <package>
	set_package "$1"

	test MINGW = "$type" ||
	up_to_date "$pkgpath" ||
	die "%s: not up-to-date\n" "$pkgpath"

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
	 git stash) ||
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

rebase () { # [--worktree=<dir>] [--test [--full-test-log] [--with-svn-tests]] [--redo] [--abort-previous] [--continue | --skip] <upstream-branch-or-tag>
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

		require_remote upstream https://github.com/git/git &&
		require_remote git-for-windows \
			https://github.com/git-for-windows/git &&
		require_push_url git-for-windows ||
		die "Could not update remotes\n"

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
	 GIT_CONFIG_PARAMETERS="$GIT_CONFIG_PARAMETERS${GIT_CONFIG_PARAMETERS:+ }'core.editor=touch' 'rerere.enabled=true' 'rerere.autoupdate=true'" &&
	 export GIT_CONFIG_PARAMETERS &&
	 if is_rebasing
	 then
		test 0 = $(git rev-list --count HEAD..$onto) ||
		die "Current rebase is not on top of %s\n" "$1"

		test -z "$skip_rebase" ||
		git diff HEAD | git apply -R ||
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
		1) branch=$1 commit=$branch ;;
		2) branch=$1 commit=$2 ;;
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
	 [ "$branch" == "$commit" ] ||
		git merge-base --is-ancestor $commit $branch ||
		die "Commit %s is not on branch %s\n" $commit $branch &&
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
	 make MSVC=1 vcxproj &&
	 git push "$remote" +HEAD:refs/heads/vs/"$branch" ||
	 die "Could not push vs/$branch\n") ||
	exit
}

needs_upload_permissions () {
	grep -q '^machine api\.github\.com$' "$HOME"/_netrc &&
	grep -q '^machine uploads\.github\.com$' "$HOME"/_netrc ||
	die "Missing GitHub entries in ~/_netrc\n"
}

# <tag> <dir-with-files>
publish_prerelease () {
	"$sdk64/usr/src/build-extra/upload-to-github.sh" \
		--repo=git "$1" \
		"$2"/* ||
	die "Could not upload files from %s\n" "$2"

	url=https://api.github.com/repos/git-for-windows/git/releases
	id="$(curl --netrc -s $url |
		sed -n '/"id":/{N;/"tag_name": *"'"$1"'"/{
			s/.*"id": *\([0-9]*\).*/\1/p;q}}')"
	test -n "$id" ||
	die "Could not determine ID of release for %s\n" "$1"

	out="$(curl --netrc --show-error -s -XPATCH -d \
		'{"name":"'"$1"'","body":"This is a prerelease.",
		 "draft":false,"prerelease":true}' \
		$url/$id)" ||
	die "Could not edit release for %s:\n%s\n" "$1" "$out"
}

prerelease () { # [--installer | --portable | --mingit] [--only-64-bit] [--clean-output=<directory> | --output=<directory>] [--force-version=<version>] [--skip-prerelease-prefix] <revision>
	modes=
	output=
	force_tag=
	force_version=
	prerelease_prefix=prerelease-
	only_64_bit=
	upload=
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
	--installer|--portable|--mingit)
		modes="$modes ${1#--}"
		;;
	--installer+portable)
		modes="installer portable"
		;;
	--only-64-bit)
		only_64_bit=t
		;;
	--output=*)
		output="--output='$(cygpath -am "${1#*=}")'" ||
		die "Directory '%s' inaccessible\n" "${1#*=}"
		;;
	--clean-output=*)
		rm -rf "${1#*=}" &&
		mkdir -p "${1#*=}" ||
		die "Could not make directory '%s'\n" "${1#*=}"
		output="--output='$(cygpath -am "${1#*=}")'" ||
		die "Directory '%s' inaccessible\n" "${1#*=}"
		;;
	--now)
		rm -rf ./prerelease-now &&
		mkdir ./prerelease-now ||
		die "Could not make ./prerelease-now/\n"
		output="--output='$(cygpath -am ./prerelease-now)'" ||
		die "Directory ./prerelease-now/ is inaccessible\n"

		modes="installer portable mingit"
		force_version='%(prerelease-tag)'
		force_tag=-f
		upload=t
		;;
	-*) die "Unknown option: %s\n" "$1";;
	*) break;;
	esac; do shift; done
	test $# = 1 ||
	die "Expected 1 argument, got $#: %s\n" "$*"

	test -n "$modes" ||
	modes=installer

	ensure_valid_login_shell 32 &&
	ensure_valid_login_shell 64 ||
	die "Could not ensure valid login shell\n"

	sdk="$sdk64"

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
	if test -n "$only_64_bit" -o \
			-f "${pkgprefix}-i686-git-doc-html-${pkgsuffix}" &&
		test -f "${pkgprefix}-x86_64-git-doc-html-${pkgsuffix}" &&
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

		git push --force "$git_src_dir" "refs/tags/$tag_name" ||
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

		git push "$git_src_dir" "refs/tags/$tag_name" ||
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
	mingit)
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
				-p prerelease-'"$pkgver".pkgbuild ||
		die "%s: could not build '%s'\n" "$git_src_dir" "$pkgver"

		pkgsuffix="$(sed -n '/^pkgver=/{N;
			s/pkgver=\(.*\).pkgrel=\(.*\)/\1-\2-any.pkg.tar.xz/p}' \
			<"$git_src_dir/../../prerelease-$pkgver.pkgbuild")" ||
		die "Could not determine package suffix\n"
	fi

	case "$modes" in
	mingit)
		pkglist="git"
		;;
	*)
		pkglist="git git-doc-html"
		;;
	esac
	for sdk in "$sdk32" "$sdk64"
	do
		test -z "$only_64_bit" ||
		test a"$sdk" = a"$sdk64" ||
		continue

		"$sdk/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c '
			cd "'"$git_src_dir"'/../.." &&
			precmd="pacman --force --noconfirm -U" &&
			postcmd="pacman --force --noconfirm -U" &&
			for pkg in '"$pkglist"'
			do
				pkg=mingw-w64-"$(uname -m)"-$pkg

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
				precmd="$precmd $file"
			done || exit
			eval "$precmd" &&
			sed -i -e "1s/.*/# Pre-release '"$pkgver"'/" \
				-e "2s/.*/Date: '"$(today)"'/" \
				/usr/src/build-extra/ReleaseNotes.md &&
			version='"$prerelease_prefix${pkgver#v}"' &&
			for m in '"$modes"'
			do
				extra=
				test installer != $m ||
				extra=--window-title-version="$version"
				/usr/src/build-extra/$m/release.sh \
					'"$output"' $extra "$version" || {
					postcmd="$postcmd && exit 1"
					break
				}
			done &&
			(cd /usr/src/build-extra &&
			 git diff -- ReleaseNotes.md | git apply -R) &&
			eval "$postcmd"' ||
		die "Could not use package '%s' in '%s'\n" "$pkglist" "$sdk"
	done

	test -z "$upload" || {
		git -C "$git_src_dir" push git-for-windows "$tag_name" &&
		publish_prerelease "$tag_name" ./prerelease-now
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

tag_git () { #
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

	nextver="$(sed -ne \
		'1s/.* \(v[0-9][.0-9]*\)(\([0-9][0-9]*\)) .*/\1.windows.\2/p' \
		-e '1s/.* \(v[0-9][.0-9]*\) .*/\1.windows.1/p' \
		<"$build_extra_dir/ReleaseNotes.md")"
	! git --git-dir="$git_src_dir" rev-parse --verify \
		refs/tags/"$nextver" >/dev/null 2>&1 ||
	die "Already tagged: %s\n" "$nextver"

	notes="$("$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		'markdown </usr/src/build-extra/ReleaseNotes.md |
		 LC_CTYPE=C w3m -dump -cols 72 -T text/html | \
		 sed -n "/^Changes since/,\${:1;p;n;/^Changes/q;b1}"')"

	tag_message="$(printf "%s\n\n%s" \
		"$(sed -n '1s/.*\(Git for Windows v[^ ]*\).*/\1/p' \
		<"$build_extra_dir/ReleaseNotes.md")" "$notes")" &&
	(cd "$git_src_dir" &&
	 git tag -m "$tag_message" -a "$nextver" git-for-windows/master) ||
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

pkg_files () {
	pkgver="$(sed -ne \
		'/^_basever=/{N;N;s/.*=\([0-9].*\)\n.*\npkgrel=\(.*\)/\1-\2/p}' \
		-e '/^_ver=/{N;N;N;s/.*=\([.0-9]*\)\([a-z][a-z]*\)\n.*\n.*\npkgrel=\(.*\)/\1.\2-\3/p}' \
		-e '/^pkgver=/{N;s/.*=\([0-9].*\)\npkgrel=\(.*\)/\1-\2/p}' \
		<PKGBUILD)"
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

	test mingw-w64-git != "$package" || {
		set_package git-extra
		foreach_sdk pkg_install
	}
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

	(cd "$sdk64/$pkgpath" &&
	 require_push_url origin) || exit

	pacman_helper fetch &&
	foreach_sdk pkg_upload &&
	pacman_helper push ||
	die "Could not upload %s\n" "$package"

	# Here, we exploit the fact that the 64-bit SDK is either the only
	# SDK where the package was built (MinGW) or it agrees with thw 32-bit
	# SDK's build product (MSYS2).
	(cd "$sdk64/$pkgpath" &&
	 test -z "$(git rev-list @{u}..)" ||
	 if test refs/heads/master = \
		"$(git rev-parse --symbolic-full-name HEAD)"
	 then
		git -c push.default=simple push
	 else
		echo "The local branch in $sdk64/$pkgpath has unpushed changes" >&2
	 fi) ||
	die "Could not push commits in %s/%s\n" "$sdk64" "$pkgpath"
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
		sed -i -e '/^## Changes since/{
			:1;n;
			/^### '"$what"'/b3;
			/^### Bug Fixes/b2;
			/^## Changes since/b2;
			b1;

			:2;s/^/### '"$what"'\n\n'"$quoted"'\n\n/;b5;

			:3;/^\*/b4;n;b3;:4;n;/^\*/b4;
			s/^/'"$quoted"'\n/;b5;

			:5;n;b5}' "$relnotes"
	fi ||
	die "Could not edit release notes\n"

	(cd "$sdk64"/usr/src/build-extra &&
	 what_singular="$(echo "$what" |
		 sed -e 's/Fixes/Fix/' -e 's/Features/Feature/')" &&
	 git commit -s -m "Mention $what_singular in release notes" \
		-m "$(echo "$*" | fmt -72)" ReleaseNotes.md) ||
	die "Could not commit release note edits\n"

	(cd "$sdk32"/usr/src/build-extra &&
	 git pull --ff-only "$sdk64"/usr/src/build-extra master) ||
	die "Could not synchronize release note edits to 32-bit SDK\n"
}

finalize () { # <what, e.g. release-notes>
	case "$1" in
	relnotes|rel-notes|release-notes) ;;
	*) die "I don't know how to finalize %s\n" "$1";;
	esac

	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	update git &&
	dir_option="--git-dir=$sdk64/$pkgpath"/src/git/.git &&
	git "$dir_option" fetch --tags git-for-windows &&
	git "$dir_option" fetch --tags junio ||
	die "Could not update Git\n"

	ver="$(git "$dir_option" \
		describe --first-parent --match 'v[0-9]*[0-9]' \
		git-for-windows/master)" ||
	die "Cannot describe current revision of Git\n"
	ver=${ver%%-*}
	case "$ver" in
	*.windows.*)
		test 0 -lt $(git "$dir_option" rev-list --count \
			"$ver"..git-for-windows/master) ||
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

	sed -i -e "1s/.*/# Git for Windows v$displayver Release Notes/" \
		-e "2s/.*/Latest update: $(today)/" \
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

release () { #
	up_to_date usr/src/build-extra ||
	die "build-extra is not up-to-date\n"

	set_version_from_sdks_git

	echo "Releasing Git for Windows $displayver" >&2

	test "$displayver" = "$(version_from_release_notes)" ||
	die "Incorrect version in the release notes\n"

	test "Latest update: $(today)" = "$(sed -n 2p \
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
	done

	sign_files "$HOME"/PortableGit-"$ver"-64-bit.7z.exe \
		"$HOME"/PortableGit-"$ver"-32-bit.7z.exe

	"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"/usr/src/build-extra/nuget/release.sh '$ver'" &&
	"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
		"/usr/src/build-extra/nuget/release.sh --mingit '$ver'" ||
	die "Could not make NuGet packages\n"
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

	needs_upload_permissions || exit

	grep -q '<apikeys>' "$HOME"/AppData/Roaming/NuGet/NuGet.Config ||
	die "Need to call \`%s setApiKey Your-API-Key\`\n" \
		"$sdk64/usr/src/build-extra/nuget/nuget.exe"

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
	 sdk= pkgpath=$PWD ff_master &&
	 require_push_url &&
	 sdk="$sdk64" require mingw-w64-x86_64-nodejs) ||
	die "Could not prepare website clone for update\n"

	(cd "$sdk64/usr/src/build-extra" &&
	 require_push_url &&
	 sdk= pkgpath=$PWD ff_master) ||
	die "Could not prepare build-extra for download-stats update\n"

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
		"$HOME"/MinGit-"$ver"-64-bit.zip \
		"$HOME"/MinGit-"$ver"-32-bit.zip \
		"$HOME"/Git-"$ver"-64-bit.tar.bz2 \
		"$HOME"/Git-"$ver"-32-bit.tar.bz2 ||
	die "Could not upload files\n"

	for nupkg in GitForWindows Git-Windows-Minimal
	do
		count=0
		while test $count -lt 5
		do
			"$sdk64/usr/src/build-extra/nuget/nuget.exe" \
				push -NonInteractive -Verbosity detailed \
				-Timeout 3000 "$HOME"/$nupkg.$ver.nupkg && break
			count=$(($count+1))
		done
		test $count -lt 5 ||
		die "Could not upload %s\n" "$HOME"/$nupkg.$ver.nupkg
	done

	git_src_dir="$sdk64/usr/src/MINGW-packages/mingw-w64-git/src/git" &&
	nextver=v"$version" &&
	(cd "$git_src_dir" &&
	 git push git-for-windows "$nextver" &&
	 mirrors="$( git config --get-regexp 'remote\..*\.releasemirror' |
		sed -n 's/^remote.\(.*\).releasemirror true$/\1/p')" &&
	 if test -n "$mirrors"
	 then
		for remote in $mirrors
		do
			git push $remote "$nextver^{commit}:master" "$nextver"
		done
	 fi) ||
	die "Could not push tag %s in %s\n" "$nextver" "$git_src_dir"

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
	 git commit -s -m "download-stats: new Git for Windows version" \
		./download-stats.sh &&
	 git push origin HEAD) ||
	die "Could not update download-stats.sh\n"

	prefix="$(printf "%s\n\n%s%s\n\n\t%s\n" \
		"Dear Git users," \
		"It is my pleasure to announce that Git for Windows " \
		"$displayver is available from:" \
		"https://git-for-windows.github.io/")"
	rendered="$(echo "$text" |
		"$sdk64/git-cmd.exe" --command=usr\\bin\\sh.exe -l -c \
			'markdown |
			 LC_CTYPE=C w3m -dump -cols 72 -T text/html')"
	printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n%s\n" \
		"From $version Mon Sep 17 00:00:00 2001" \
		"From: $(git var GIT_COMMITTER_IDENT | sed -e 's/>.*/>/')" \
		"Date: $(date -R)" \
		"To: git-for-windows@googlegroups.com, git@vger.kernel.org" \
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

	git  --git-dir="$sdk64"/usr/src/build-extra/.git \
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
		sed -n '/"id":/{N;/"tag_name": *"'"$tag"'"/{
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

this_script_path="$(cygpath -am "$0")"
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

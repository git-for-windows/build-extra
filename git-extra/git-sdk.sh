# This profile.d script configures a few things for the Git SDK (but is
# excluded from the end user-facing Git for Windows).

# If both 32-bit and 64-bit Git for Windows SDK is installed next to each other,
# using the default directory names, mount them as /sdk32 and /sdk64,
# respectively, to make it easier to interact between the two.

rootdir="$(cygpath -w /)" &&
rootdir="${rootdir%\\}" &&
case "$rootdir" in
*\\git-sdk-32|*\\git-sdk-64)
	otherarch=$((96-${rootdir##*-})) &&
	if test ! -d /sdk$otherarch
	then
		othersdk="${rootdir%??}$otherarch"
		test ! -d "$othersdk" ||
		mount -o noacl "$othersdk" /sdk$otherarch 2>/dev/null
	fi
	;;
esac

sdk () {
	case "$1" in
	help|--help|-h)
		cat >&2 <<-EOF
		The 'sdk' shell function helps you to get up and running
		with the Git for Windows SDK. The available subcommands are:

		create-desktop-icon: install a desktop icon that starts the Git for
		    Windows SDK Bash.

		cd <project>: initialize/update a worktree and cd into it. Known projects:
		$(sdk valid_projects | sdk fmt_list)

		init <project>: initialize and/or update a worktree. Known projects
		    are the same as for the 'cd' command.

		build <project>: builds one of the following:
		$(sdk valid_build_targets | sdk fmt_list)

		edit <file>: edit a well-known file. Well-known files are:
		$(sdk valid_edit_targets | sdk fmt_list)

		reload: reload the 'sdk' function.
		EOF
		;;
	welcome)
		test -z "$MSYS_NO_PATHCONV" || cat >&2 <<-EOF
		WARNING: You have the MSYS_NO_PATHCONV env var defined
		Please consult the documentation, e.g. at
		https://github.com/git-for-windows/build-extra/blob/HEAD/ReleaseNotes.md#known-issues

		EOF

		test -z "$GIT_SDK_WELCOME_SHOWN" || {
			echo 'Reloaded the `sdk` function' >&2
			return 0
		}
		cat >&2 <<-EOF
		Welcome to the Git for Windows SDK!

		The common tasks are automated via the \`sdk\` function;
		See \`sdk help\` for details.
		EOF
		GIT_SDK_WELCOME_SHOWN=t
		return 0
		;;
	create-desktop-icon)
		force=t &&
		while case "$1" in
		--gentle) force=;;
		'') break;;
		-*) sdk die "Unknown option: %s\n" "$1"; return 1;;
		esac; do shift; done &&
		case "$(uname -m)" in
		i686) bitness=" 32-bit";;
		x86_64) bitness=" 64-bit";;
		*) bitness=;;
		esac &&
		desktop_icon_path="Git SDK$bitness.lnk" &&
		desktop_icon_path="$(create-shortcut.exe -n --desktop-shortcut /git-bash.exe "$desktop_icon_path" |
			sed -n 's/^destination: //p')" &&
		if test -n "$force" || test ! -f "$desktop_icon_path"
		then
			create-shortcut.exe --icon-file /msys2.ico --work-dir \
				/ /git-bash.exe "$desktop_icon_path"
		fi
		;;
	die)
		shift
		echo "$*" >&2
		return 1
		;;
	fmt_list)
		fmt -w 64 | sed 's/^/\t/'
		;;
	# for completion
	valid_commands)
		echo "build cd create-desktop-icon init edit reload"
		;;
	valid_projects)
		printf "%s " git git-extra msys2-runtime installer \
			build-extra MINGW-packages MSYS2-packages \
			mingw-w64-busybox \
			mingw-w64-curl \
			mingw-w64-cv2pdb \
			mingw-w64-git \
			mingw-w64-git-credential-manager \
			mingw-w64-git-lfs \
			mingw-w64-git-sizer \
			mingw-w64-wintoast \
			bash \
			curl \
			gawk \
			git-flow \
			gnupg \
			heimdal \
			mintty \
			nodejs \
			openssh \
			openssl \
			perl \
			perl-HTML-Parser \
			perl-Locale-Gettext \
			perl-Net-SSLeay \
			perl-TermReadKey \
			perl-XML-Parser \
			perl-YAML-Syck \
			subversion \
			tig
		;;
	valid_build_targets)
		printf "%s " git-and-installer $(sdk valid_projects | tr ' ' '\n' |
			grep -v '^\(build-extra\|\(MINGW\|MSYS2\)-packages\)')
		;;
	valid_edit_targets)
		printf "%s " git-sdk.sh sdk.completion ReleaseNotes.md \
			install.iss
		;;
	# for building
	makepkg|makepkg-mingw)
		cmd=$1; shift
		WITHOUT_PDBS="$(! grep -q WITHOUT_PDBS PKGBUILD || sdk find_mspdb_dll || echo true)" \
		MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} PKGEXT='.pkg.tar.xz' $cmd --syncdeps --noconfirm --skipchecksums --skippgpcheck "$@"
		;;
	find_mspdb_dll)
		for v in 140 120 110 100 80
		do
			type -p mspdb$v.dll 2>/dev/null && return 0
		done
		return 1
		;;
	# here start the commands
	init-lazy)
		case "$2" in
		build-extra|git|MINGW-packages|MSYS2-packages)
			src_dir=/usr/src/"$2"
			src_cdup_dir="$src_dir"
			test -d "$src_dir"/.git && return
			mkdir -p "$src_dir" &&
			git -C "$src_dir" init &&
			git -C "$src_dir" config core.autocrlf false &&
			git -C "$src_dir" remote add origin \
				https://github.com/git-for-windows/"$2" ||
			sdk die "Could not initialize $src_dir"
			;;
		msys2-runtime)
			sdk init MSYS2-packages &&
			(cd "$src_dir/$2" &&
			 test -d src/msys2-runtime ||
			 sdk makepkg --nobuild) &&
			src_cdup_dir="$src_dir/$2" &&
			src_dir="$src_cdup_dir/src/msys2-runtime" ||
			return 1
			;;
		git-extra|git-for-windows-keyring|mingw-w64-cv2pdb|\
		mingw-w64-git-lfs|\
		mingw-w64-git-credential-manager|\
		mingw-w64-git-sizer|mingw-w64-wintoast|installer)
			sdk init-lazy build-extra &&
			src_dir="$src_dir/$2" ||
			return 1
			;;
		mingw-w64-*)
			sdk init MINGW-packages &&
			src_dir="$src_cdup_dir/$2" &&
			test -d "$src_dir" ||
			return 1
			;;
		*)
			sdk init MSYS2-packages &&
			src_dir="$src_cdup_dir/$2" &&
			test -d "$src_dir" ||
			return 1
			;;
		esac
		;;
	cd)
		sdk init "$2" &&
		cd "$src_dir" ||
		sdk die "Could not change directory to '$2'"

		case "$(uname -m)" in
		i686)
			MSYSTEM=MINGW32
			MINGW_MOUNT_POINT=/mingw32
			;;
		x86_64)
			MSYSTEM=MINGW64
			MINGW_MOUNT_POINT=/mingw64
			;;
		*)
			sdk die "Could not determine bitness"
			return 1
			;;
		esac
		PKG_CONFIG_PATH="${MINGW_MOUNT_POINT}/lib/pkgconfig:${MINGW_MOUNT_POINT}/share/pkgconfig"
		ACLOCAL_PATH="${MINGW_MOUNT_POINT}/share/aclocal:/usr/share/aclocal"
		MANPATH="${MINGW_MOUNT_POINT}/local/man:${MINGW_MOUNT_POINT}/share/man:${MANPATH}"
		first_path=$MINGW_MOUNT_POINT/bin
		second_path=/usr/bin

		case "$PWD" in
		*/MSYS2-packages|*/MSYS2-packages/*)
			MSYSTEM=MSYS
			unset MINGW_MOUNT_POINT
			PKG_CONFIG_PATH="/usr/lib/pkgconfig:/usr/share/pkgconfig:/lib/pkgconfig"
			second_path=$first_path
			first_path=/usr/bin:/opt/bin
			;;
		esac
		. /etc/msystem

		PATH="$first_path:$second_path:$(echo "$PATH" |
			sed -e "s|:\($first_path\|$second_path\)/\?:|:|g")"
		return $?
		;;
	init)
		sdk init-lazy "$2" &&
		case "$(git -C "$src_cdup_dir" symbolic-ref HEAD 2>/dev/null)" in
		'')
			test -n "$(git -C "$src_cdup_dir" rev-parse HEAD 2>/dev/null)" ||
			# Not checked out yet
			git -C "$src_cdup_dir" pull origin HEAD
			;;
		refs/heads/master)
			if git -C "$src_cdup_dir" rev-parse --verify HEAD >/dev/null 2>&1
			then
				git -C "$src_cdup_dir" branch -m main &&
				sdk "$@"
				return $?
			fi
			# Not checked out yet
			git -C "$src_cdup_dir" symbolic-ref HEAD refs/heads/main &&
			git -C "$src_cdup_dir" pull origin HEAD
			;;
		refs/heads/main)
			case "$(git -C "$src_cdup_dir" rev-parse --symbolic-full-name main@{upstream} 2>/dev/null)" in
			refs/remotes/origin/master)
				git -C "$src_cdup_dir" fetch origin &&
				git -C "$src_cdup_dir" branch --set-upstream-to=origin/main main;;
			esac &&

			case "$(git -C "$src_cdup_dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)" in
			''|refs/heads/master)
				git -C "$src_cdup_dir" fetch origin &&
				git -C "$src_cdup_dir" remote set-head -a origin;;
			esac &&

			if { git -C "$src_cdup_dir" diff-files --quiet &&
				git -C "$src_cdup_dir" diff-index --quiet HEAD ||
				test ! -s "$src_cdup_dir"/.git/index; }
			then
				git -C "$src_cdup_dir" pull origin HEAD
			fi
			;;
		esac &&
		if test git = "$2" && test ! -f "$src_dir/config.mak"
		then
			cat >"$src_dir/config.mak" <<-\EOF
			DEVELOPER=1
			SKIP_DASHED_BUILT_INS=YesPlease
			ifndef NDEBUG
			CFLAGS := $(filter-out -O2,$(CFLAGS))
			ASLR_OPTION := -Wl,--dynamicbase
			BASIC_LDFLAGS := $(filter-out $(ASLR_OPTION),$(BASIC_LDFLAGS))
			endif
			EOF
		elif test msys2-runtime = "$2"
		then
			remotes="$(git -C "$src_dir"  remote -v)"
			case "$remotes" in *"cygwin	"*) ;;
			*) git -C "$src_dir" remote add -f cygwin \
				https://github.com/Cygwin/cygwin;; esac
			case "$remotes" in *"msys2	"*) ;;
			*) git -C "$src_dir" remote add -f msys2 \
				https://github.com/Alexpux/Cygwin;; esac
			case "$remotes" in *"git-for-windows	"*) ;;
			*) git -C "$src_dir" remote add -f \
				git-for-windows \
				https://github.com/git-for-windows/$2;; esac
		fi
		;;
	build)
		if test -z "$2"
		then
			set -- "$1" "$(basename "$PWD")" &&
			sdk init-lazy "$2" &&
			test "a$PWD" = "a$src_dir" ||
			test "a$PWD" = "a$src_cdup_dir" || {
				sdk die "$PWD seems not to be a known project"
				return $?
			}
		fi

		case "$2" in
		git)
			sdk init git &&
			make -C "$src_dir" -j$(nproc) DEVELOPER=1
			;;
		installer)
			sdk init "$2" &&
			"$src_dir"/release.sh "${3:-0-test}"
			;;
		git-and-installer)
			sdk build git &&
			make -C "$src_dir" strip install &&
			pacman -Syyu git-extra &&
			sdk init build-extra &&
			"$src_dir"/installer/release.sh "${3:-0-test}"
			;;
		msys2-runtime)
			sdk cd "$2" ||
			return $?

			if test refs/heads/makepkg = \
				"$(git symbolic-ref HEAD 2>/dev/null)" &&
				{ git diff-files --quiet &&
				  git diff-index --quiet HEAD ||
				  test ! -s .git/index ||
				  (uname_m="$(uname -m)" &&
				    test ! -d "../build-$uname_m-pc-msys/$uname_m-pc-msys/winsup/cygwin"); }
			then
				# no local changes
				cd "$src_cdup_dir" &&
				sdk makepkg -f
				return $?
			fi

			# Build the current branch
			(uname_m="$(uname -m)" &&
			 cd "../build-$uname_m-pc-msys/$uname_m-pc-msys/winsup/cygwin" &&
			 make -j$(nproc))
			return $?
			;;
		*)
			sdk cd "$2" ||
			return $?
			if test -f PKGBUILD
			then
				case "$MSYSTEM" in
				MSYS) sdk makepkg -f;;
				MINGW*) MINGW_ARCH=${MSYSTEM,,} sdk makepkg-mingw -f;;
				esac
				return $?
			fi

			cat >&2 <<EOF
sdk build <project>

Supported projects:
	git
	installer [<version>]
	git-and-installer [<version>]
	msys2-runtime
EOF
			return 1
			;;
		esac
		;;
	git-editor)
		# Cannot use `git config -e -f "$2", as that would cd up to the
		# top-level if the file is in a subdirectory of a Git worktree
		eval "$(git var GIT_EDITOR)" "$2"
		;;
	edit)
		cmd=init-lazy
		test --cd != "$2" || {
			cmd=cd
			shift
		}

		case "$2" in
		git-sdk.sh|sdk.completion)
			sdk $cmd git-extra &&
			sdk git-editor "$src_dir/$2" &&
			. "$src_dir/$2"
			;;
		ReleaseNotes.md|please.sh)
			sdk $cmd build-extra &&
			sdk git-editor "$src_dir/$2"
			;;
		install.iss)
			sdk $cmd installer &&
			sdk git-editor "$src_dir/$2"
			;;
		*)
			sdk die "Not a valid edit target: $2"
			;;
		esac || return $?
		;;
	reload)
		shift
		case "$*" in
		--experimental)
			sdk init git-extra &&
			. "$src_dir"/sdk.completion &&
			. "$src_dir"/git-sdk.sh
			;;
		--system)
			. /usr/share/bash-completion/completions/sdk &&
			. /etc/profile.d/git-sdk.sh
			;;
		'')
			. "$GIT_SDK_SH_PATH"
			;;
		*)
			sdk die "Unhandled option: '$*'"
			;;
		esac
		return $?
		;;
	*)
		printf "Usage: sdk <command> [<argument>...]\n\n" >&2 &&
		sdk help
		;;
	esac
}

if [ -n "$ZSH_VERSION" ]; then
	GIT_SDK_SH_PATH="$(realpath "${(%):-%x}")"
else
	GIT_SDK_SH_PATH="$(realpath "$BASH_SOURCE")"
fi

case $- in
*i*)
	# in any interactive session, initialize (but do not fetch) worktrees
	# in /usr/src, and also create the Git SDK shortcut on the Desktop
	# (unless it already exists).
	test -n "$JENKINS_URL" || {
		for project in git build-extra MINGW-packages MSYS2-packages
		do
			sdk init-lazy $project
		done

		sdk create-desktop-icon --gentle
	}

	sdk welcome
	;;
esac

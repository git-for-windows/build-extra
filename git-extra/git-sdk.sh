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
		mount "$othersdk" /sdk$otherarch 2>/dev/null
	fi
	;;
esac

sdk () {
	case "$1" in
	help|--help|-h)
		cat >&2 <<-EOF
		The 'sdk' shell function helps you to get up and running
		with the Git for Windows SDK. The available subcommands are:

		create-desktop-icon: install a desktop icon that starts the GfW SDK shell.

		init <repo>: initialize and/or update a development repo. Known repos
		    are: build-extra, git, MINGW-packages, MSYS2-packages.

		build: builds one of the following: git, git-and-installer.
		EOF
		;;
	welcome)
		cat >&2 <<-EOF
		Welcome to the Git for Windows SDK!

		The common tasks are automated via the \`sdk\` function;
		See \`sdk help\` for details.
		EOF
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
		desktop_icon_path="$HOME/Desktop/Git SDK$bitness.lnk" &&
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
	init-lazy)
		case "$2" in
		build-extra|git|MINGW-packages|MSYS2-packages)
			test -d /usr/src/"$2"/.git && return
			mkdir -p /usr/src/"$2" &&
			git -C /usr/src/"$2" init &&
			git -C /usr/src/"$2" config core.autocrlf false &&
			git -C /usr/src/"$2" remote add origin \
				https://github.com/git-for-windows/"$2" ||
			sdk die "Could not initialize /usr/src/$2"
			;;
		*)
			sdk die "Unhandled repository: $2" >&2
			;;
		esac
		;;
	init)
		sdk init-lazy "$2" &&
		git -C "/usr/src/$2" pull origin master
		;;
	build)
		case "$2" in
		git)
			sdk init git &&
			make -C /usr/src/git -j$(nproc) DEVELOPER=1
			;;
		installer)
			sdk init build-extra &&
			/usr/src/build-extra/installer/release.sh "${3:-0-test}"
			;;
		git-and-installer)
			sdk build git &&
			make -C /usr/src/git strip install &&
			pacman -Syyu git-extra &&
			sdk init build-extra &&
			/usr/src/build-extra/installer/release.sh "${3:-0-test}"
			;;
		*)
			cat >&2 <<EOF
sdk build <project>

Supported projects:
	git
	installer [<version>]
	git-and-installer [<version>]
EOF
			return 1
			;;
		esac
		;;
	*)
		sdk die "Usage: sdk ( build-git | init <repo> | create-desktop-icon | help )"
		;;
	esac
}

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

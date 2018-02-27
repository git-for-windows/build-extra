#!/bin/sh

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

		build-git:   initializes the Git repo and builds Git.
		EOF
		;;
	create-desktop-icon)
		create-shortcut.exe --icon-file /msys2.ico --work-dir / /git-bash.exe \
		"$HOME/Desktop/Git SDK$(case "$(uname -m)" in i686) echo " 32-bit";; x86_64) echo " 64-bit";; esac).lnk"
		;;
	die)
		shift
		echo "$*" >&2
		return 1
		;;
	init)
		case "$2" in
		build-extra|git|MINGW-packages|MSYS2-packages)
			dest="/usr/src/$2"
			if test ! -d "$dest"/.git
			then
				mkdir -p "$dest" &&
				git init "$dest" &&
				git -C "$dest" remote add origin https://github.com/git-for-windows/$2
			fi &&
			git -C "$dest" pull origin master
			;;
		*)
			sdk die "Unhandled repository: $2" >&2
			;;
		esac
		;;
	build-git)
		sdk init git &&
		make -C /usr/src/git -j$(nproc) DEVELOPER=1
		;;
	*)
		sdk die "Usage: sdk ( build-git | init <repo> | create-desktop-icon | help )"
		;;
	esac
}

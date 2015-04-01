#!/bin/bash

die () {
	echo "$*" >&2
	exit 1
}

force=
while test $# -gt 0
do
	case "$1" in
	-f|--force)
		force=t
		shift
		;;
	*)
		break
	esac
done

test $# -gt 0 ||
die "Usage: $0 [-f] <version>"

version=$1

# change directory to the script's directory
cd "$(dirname "$0")" ||
die "Could not switch directory"

# Export paths to inno setup file
SCRIPTDIR="$(pwd -W)"
ROOTDIR="$(cd / && pwd -W)"
export SCRIPTDIR ROOTDIR

# Evaluate architecture
ARCH="$(uname -m)"

case "$ARCH" in
i686)
	BITNESS=32
	;;
x86_64)
	BITNESS=64
	;;
*)
	die "Unhandled architecture: $ARCH"
	;;
esac

# Generate list of files to include
pacman_list () {
	pacman -Ql $(for arg
		do
			pactree -u "$arg"
		done |
		sort |
		uniq) |
	grep -v '/$' |
	sed 's/^[^ ]* //'
}

LIST="$(pacman_list mingw-w64-$ARCH-git git-extra ncurses mintty vim \
	sed awk less grep gnupg findutils coreutils \
	dos2unix which subversion |
	grep -v -e '\.[acho]$' -e '/aclocal/' \
		-e '/man/' \
		-e '^/usr/include/' -e '^/mingw32/include/' \
		-e '^/usr/share/doc/' -e '^/mingw32/share/doc/' \
		-e '^/usr/share/info/' -e '^/mingw32/share/info/' |
	sed 's/^\///')"

LIST="$LIST etc/profile etc/bash.bash_logout etc/bash.bashrc etc/fstab"
LIST="$LIST mingw$BITNESS/etc/gitconfig"

rm -rf file-list.iss
for f in $LIST
do
	printf 'Source: %s; DestDir: {app}\%s; Flags: %s; AfterInstall: %s\n' \
                $f $(dirname $f) replacesameversion DeleteFromVirtualStore \
        >> file-list.iss
done

sed -e "s|%APPVERSION%|$version|" -e "s|%MINGW_BITNESS%|mingw$BITNESS|" < install.iss.in > install.iss ||
exit

echo "Launching Inno Setup compiler ..." &&
./InnoSetup/ISCC.exe install.iss > install.out ||
die "Could not make installer"
git tag -a -m "Git for Windows $1" Git-$1 &&
echo "Installer is available as $(tail -n 1 install.out)"

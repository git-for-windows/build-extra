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
case "$version" in
[0-9]*) ;; # okay
*) die "InnoSetup requires a version that begins with a digit";;
esac

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

echo "Generating file list to be included in the installer ..."
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

LIST="$(pacman_list mingw-w64-$ARCH-git mingw-w64-$ARCH-git-doc-html \
	git-extra ncurses mintty vim \
	sed awk less grep gnupg findutils coreutils \
	dos2unix which subversion mingw-w64-$ARCH-tk |
	grep -v -e '\.[acho]$' -e '/aclocal/' \
		-e '/man/' \
		-e '/mingw32/share/doc/git-doc/.*\.txt$' \
		-e '^/usr/include/' -e '^/mingw32/include/' \
		-e '^/usr/share/doc/' -e '^/mingw32/share/doc/' \
		-e '^/usr/share/info/' -e '^/mingw32/share/info/' |
	sed 's/^\///')"

LIST="$(printf "%s\n%s\n%s\n%s\n%s\n%s\n" \
	"$LIST" \
	etc/profile \
	etc/bash.bash_logout \
	etc/bash.bashrc \
	etc/fstab \
	mingw$BITNESS/etc/gitconfig)"

echo "; List of files" > file-list.iss ||
die "Could not write to file-list.iss"

echo "$LIST" |
sed -e 's|/|\\|g' \
	-e 's|^\([^\\]*\)$|Source: \1; DestDir: {app}; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore|' \
	-e 's|^\(.*\)\\\([^\\]*\)$|Source: \1\\\2; DestDir: {app}\\\1; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore|' \
	>> file-list.iss

echo "Generating bindimage.txt"
pacman -Ql mingw-w64-$ARCH-git |
sed -n -e 's|^[^ ]* /\(.*\.exe\)$|\1|p' \
	-e 's|^[^ ]* /\(.*\.dll\)$|\1|p' > bindimage.txt
echo "Source: \"$SCRIPTDIR\\bindimage.txt\"; DestDir: {app}\\mingw$BITNESS\\share\git\bindimage.txt; Flags: replacesameversion; AfterInstall: DeleteFromVirtualStore" >> file-list.iss

sed -e "s|%APPVERSION%|$version|g" \
	-e "s|%MINGW_BITNESS%|mingw$BITNESS|g" -e "s|%BITNESS%|$BITNESS|g" \
<install.iss.in >install.iss ||
exit

echo "Launching Inno Setup compiler ..." &&
./InnoSetup/ISCC.exe install.iss > install.out ||
die "Could not make installer"

echo "Tagging Git for Windows installer release ..."
if git rev-parse Git-$version >/dev/null 2>&1; then
	echo "-> installer release 'Git-$version' was already tagged."
else
	git tag -a -m "Git for Windows $version" Git-$version
fi

echo "Installer is available as $(tail -n 1 install.out)"

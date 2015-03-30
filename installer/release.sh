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

SCRIPTDIR="$(pwd -W)"
ROOTDIR="$(cd / && pwd -W)"

# Generate list of files to include
printf > file-list.iss
for f in gpl-2.0.rtf git.bmp gitsmall.bmp
do
	printf 'Source: %s; DestDir: {app}; Flags: %s; AfterInstall: %s\n' \
		$f replacesameversion DeleteFromVirtualStore \
	>> file-list.iss
done

sed -e "s/%APPVERSION%/$version/" < install.iss.in > install.iss ||
exit

echo "Launching Inno Setup compiler ..." &&
./InnoSetup/ISCC.exe > install.out ||
die "Could not make installer"
git tag -a -m "Git for Windows $1" Git-$1 &&
echo "Installer is available as $(tail -n 1 install.out)"

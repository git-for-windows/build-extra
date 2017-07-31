#!/bin/sh

# Download the most recent Inno Setup version.
installer="is-unicode.exe"
url="http://www.jrsoftware.org/download.php/$installer"

die () {
	echo "$*" >&2
	exit 1
}

cd "$(dirname "$0")" ||
die "Could not switch directory"

curl -# -L -O -R -z $installer "$url" ||
die "Could not download $url"

# Remove any previous installation.
test ! -d InnoSetup ||
rm -r InnoSetup/ ||
die "Could not remove previous installation"

# Silently install Inno Setup below the mingw root.
if type wine > /dev/null 2>&1
then
	wine $installer /verysilent /dir=InnoSetup /noicons /tasks= /portable=1
else
	# See http://www.mingw.org/wiki/Posix_path_conversion.
	./$installer //verysilent //dir=InnoSetup \
		//noicons //tasks= //portable=1
fi ||
die "Could not install InnoSetup"

# Remove unneeded files from the installation.
rm -r InnoSetup/Examples/ InnoSetup/Compil32.exe InnoSetup/isscint.dll

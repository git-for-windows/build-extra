#!/bin/sh

# Download the most recent WiX 4.x version.
feed=http://wixtoolset.org/releases/feeds/wix4-0.feed
zip=wix40-binaries.zip

die () {
	echo "$*" >&2
	exit 1
}

cd "$(dirname "$0")" ||
die "Could not switch directory"

url="$(curl -s $feed |
	sed -n '/<id>.*\/v4-[0-9]/{s/.*>\(.*\)<.*/\1/p;q}')"
test -n "$url" ||
die "Could not determine the newest version"
url=$url$zip

curl -#LORz $(test -f $zip && echo $zip || echo 19700101) "$url" ||
die "Could not download $url"

# Remove any previous installation.
test ! -d wix ||
rm -r wix/ ||
die "Could not remove previous installation"

unzip -d wix/ -q $zip ||
die "Could not install WiX toolset"

# Convert DOS line endings
dos2unix wix/*.config

# Remove unneeded files
rm wix/{LuxTasks.dll,ThmViewer.exe,Wix{[CFGHILMPSV],Di,Tas,Toolset.B}*.dll}
rm wix/{dark,difx,lux,melt,nit,pyro,retina,shine,smoke,swc,torch}*
rm wix/*.targets
rm -r wix/{doc,sdk}

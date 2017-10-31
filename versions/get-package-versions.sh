#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test $# = 1 ||
die "Usage: $0 <version>"

version="$1"

cd "$(dirname "$0")" ||
die "Could not switch current directory to versions/"

tagname="$(echo "$version" |
	sed -ne 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\)$/v&.windows.1/p' \
	  -e 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\)\(\.[0-9]\+\)$/v\1.windows\2/p' \
	  -e 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\)(\([0-9]\+\))$/v\1.windows.\2/p')"
test -n "$tagname" ||
die "Could not guess tag name for $version"

base_url=https://github.com/git-for-windows/git/releases/download/"$tagname"

download () {
	test -f cached-files/"$1" || {
		mkdir -p cached-files &&
		curl -Lfo cached-files/"$1" "$base_url/$1"
	} ||
	die "Could not download $1"
}

file=package-versions-"$version".txt
test -f "$file" || {
	if ! type innoextract >/dev/null 2>&1
	then
		pacman -Sy mingw-w64-x86_64-innoextract ||
		die "Could not install innoextract"
	fi &&
	installer=Git-"$version"-64-bit.exe &&
	download "$installer" &&
	extracted=app/etc/package-versions.txt &&
	if test -f $extracted
	then
		rm $extracted
	fi &&
	# For some stupid reason, innoextract segfaults after extracting the
	# file successfully... Work-around.
	({ innoextract -e -I "$(echo $extracted | tr / \\\\)" \
		cached-files/"$installer"; } 2>/dev/null ||
	 test 139 = $?) &&
	mv $extracted "$file"
} ||
die "Could not extract $file"

file=package-versions-"$version"-MinGit.txt
test -f "$file" || {
	zip=MinGit-"$version"-64-bit.zip &&
	download "$zip" &&
	unzip -p cached-files/"$zip" etc/package-versions.txt >"$file"
} ||
die "Could not extract $file"

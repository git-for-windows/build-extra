#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

tag="$1"
tag="${tag#refs/tags/}"
test -n "$tag" ||
die "Need a tag!"

cd /usr/src/MINGW-packages/mingw-w64-git &&
{
	git diff-index --cached --quiet --ignore-submodules HEAD -- ':(exclude)PKGBUILD' &&
	git diff-files --quiet --ignore-submodules -- ':(exclude)PKGBUILD' ||
	die "Not up to date: $(pwd)"
} &&
git checkout HEAD -- PKGBUILD &&
versionprefix="$(echo "${tag#v}" | sed -n 's/^\([0-9]\+\.[0-9]\+\)\..*/\1/p')" &&
if test -n "$versionprefix"
then
	git checkout mingit-$versionprefix.x-releases
fi &&
sed -i \
	-e 's/^pkgver *(/disabled_&/' \
	-e 's/^pkgrel=.*/pkgrel=1/' \
	-e 's/^pkgver=.*/pkgver='"$(echo "${tag#v}" | tr +- .)"/ \
	-e 's/^tag=.*/tag='"${tag#v}"/ \
	PKGBUILD &&
MINGW_INSTALLS=mingw64 makepkg-mingw --allsource ||
die "Failed to recreate source package for $tag"

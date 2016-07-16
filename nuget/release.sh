#!/bin/sh

BUILDEXTRA="$(cd "$(dirname "$0")"/.. && pwd)"

die () {
	echo "$*" >&2
	exit 1
}

AUTHOR=$USERNAME
ID=GitForWindows
while test $# -gt 1
do
	case "$1" in
	--author=*) AUTHOR=${1#--*=};;
	--id=*) ID=${1#--*=};;
	-*) die "Unknown option: $1";;
	*) break;;
	esac
	shift
done

test $# -ge 1 ||
die "Usage: $0 [--author=<name>] [--id=<name>] <version> [<extra-package>...]"

VERSION=$1
shift

if test -x "$BUILDEXTRA"/nuget/nuget.exe
then
	PATH=$BUILDEXTRA/nuget:$PATH
elif ! type -p nuget.exe
then
	(cd "$BUILDEXTRA"/nuget &&
	 curl -O https://dist.nuget.org/win-x86-commandline/latest/nuget.exe) ||
	die "Could not download nuget.exe"
fi

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

# Generate release notes for NuGet
"$BUILDEXTRA"/render-release-notes.sh --css "$BUILDEXTRA"/nuget/content/ ||
die "Could not generate ReleaseNotes.html."

SPECIN="$BUILDEXTRA"/nuget/GitForWindows.nuspec.in
SPEC="$BUILDEXTRA/nuget/$ID".nuspec
sed -e "s/@@VERSION@@/$VERSION/g" -e "s/@@AUTHOR@@/$AUTHOR/g" \
	-e "s/@@ID@@/$ID/g" -e '/@@FILELIST@@/,$d' <"$SPECIN" >"$SPEC"

# Make a list of files to include
LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
	PACKAGE_VERSIONS_FILE="$BUILDEXTRA"/nuget/package-versions.txt \
	sh "$BUILDEXTRA"/make-file-list.sh "$@")" ||
die "Could not generate file list"

echo "$LIST" |
sed -e 'y/\//\\/' -e 's/.*/    <file src="&" target="tools\\&" \/>/' >>"$SPEC"

sed '1,/@@FILELIST@@/d' <"$SPECIN" >>"$SPEC"

nuget pack -BasePath / -Properties buildextra="$(cd "$BUILDEXTRA" && pwd -W)" \
	-OutputDirectory "$HOME" -Verbosity detailed "$SPEC"

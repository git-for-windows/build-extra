#!/bin/sh

BUILDEXTRA="$(cd "$(dirname "$0")"/.. && pwd)"

die () {
	echo "$*" >&2
	exit 1
}

AUTHOR=
OWNERS=
ID=GitForWindows
TITLE="Git for Windows"
DESCRIPTION='Git for Windows focuses on offering a lightweight, native set of tools that bring the full feature set of the Git to Windows while providing appropriate user interfaces for experienced users.'
SUMMARY='The power of Git on Windows.'
EXTRATAGS=
while test $# -gt 1
do
	case "$1" in
	--author=*) AUTHOR=${1#--*=};;
	--owners=*) OWNERS="${1#--*=}";;
	--id=*) ID=${1#--*=};;
	--mingit)
		ID=Git-Windows-Minimal
		TITLE="Minimal Git for Windows (MinGit)"
		DESCRIPTION="$DESCRIPTION\\n\\nMinimal Git for Windows is a reduced sized package designed to support application integration (like integrated development environments, graph visualizers, etc.) where full console support (colorization, pagniation, etc.) is not needed. Additionally, non-critical packages such as Git-Bash, Git-Gui, PERL, Python, and Tcl are excluded from Minimal Git for Windows to reduce the package size."
		SUMMARY="$SUMMARY Offering a lightweight, native set of tools that bring the core feature set of Git to Windows."
		EXTRATAGS=" mingit$EXTRATAGS"
		export MINIMAL_GIT=1
		;;
	-*) die "Unknown option: $1";;
	*) break;;
	esac
	shift
done

test $# -ge 1 ||
die "Usage: $0 [--author=<name>] [--id=<name>] <version> [<extra-package>...]"

VERSION=$1
shift

if test -z "$AUTHOR"
then
	AUTHOR="$(git config nuget.author)"
	test -n "$AUTHOR" || AUTHOR="$USERNAME"
fi
if test -z "$OWNERS"
then
	OWNERS="$(git config nuget.owners)"
	test -n "$OWNERS" || OWNERS="$AUTHOR"
fi

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

VERSIONTAG="$(echo "$VERSION" | sed -e 's/^[1-9]/v&/' \
	-e 's/^\(v[0-9]*\.[0-9]*\.[0-9]*\)\(\.[0-9]*\)$/\1.windows\2/' \
	-e 's/^v[0-9]*\.[0-9]*\.[0-9]*$/&.windows.1/')"
SPECIN="$BUILDEXTRA"/nuget/GitForWindows.nuspec.in
SPEC="$BUILDEXTRA/nuget/$ID".nuspec
sed -e "s/@@VERSION@@/$VERSION/g" -e "s/@@AUTHOR@@/$AUTHOR/g" \
	-e "s/@@OWNERS@@/$OWNERS/g" \
	-e "s/@@TITLE@@/$TITLE/g" -e "s/@@EXTRATAGS@@/$EXTRATAGS/g" \
	-e "s/@@DESCRIPTION@@/$DESCRIPTION/g" -e "s/@@SUMMARY@@/$SUMMARY/g" \
	-e "s/@@VERSIONTAG@@/$VERSIONTAG/g" \
	-e "s/@@ID@@/$ID/g" -e '/@@FILELIST@@/,$d' <"$SPECIN" >"$SPEC"

# Make a list of files to include
LIST="$(ARCH=$ARCH BITNESS=$BITNESS \
	PACKAGE_VERSIONS_FILE="$BUILDEXTRA"/nuget/package-versions.txt \
	sh "$BUILDEXTRA"/make-file-list.sh "$@")" ||
die "Could not generate file list"

echo "$LIST" |
sed -e 'y/\//\\/' -e 's/.*/    <file src="&" target="tools\\&" \/>/' >>"$SPEC"

test -z "$MINIMAL_GIT" || {
	printf '    <file src="$buildextra$\\%s" target="tools\\etc" />\n' \
		nuget\\libexec-moved.txt >>"$SPEC" &&
	mv "$SPEC" "$SPEC".unmoved &&
	sed -e '/tools\\mingw..\\libexec\\git-core\\git\(\|-upload-pack\).exe/d' \
	    -e 's%\( target="tools\\mingw[36][24]\\\)libexec\\git-core\\\('"$(\
	        pacman -Ql mingw-w64-$ARCH-git |
	        sed -n 's|^[^ ]* /mingw../libexec/git-core/\(.*\.exe\)$|\1\\|p' |
	        tr '\n' '|')"'\)"%\1bin\\\2"%' <"$SPEC".unmoved >"$SPEC" &&
	git diff --no-index "$SPEC.unmoved" "$SPEC" |
	sed -n 's/^-.* src="\([^"]*\).*/\1/p' \
		>"$BUILDEXTRA"/nuget/libexec-moved.txt
} ||
die "Could not move the core Git .exe files out of libexec/git-core"

sed '1,/@@FILELIST@@/d' <"$SPECIN" >>"$SPEC"

nuget pack -BasePath / -Properties buildextra="$(cd "$BUILDEXTRA" && pwd -W)" \
	-OutputDirectory "$HOME" -Verbosity detailed "$SPEC"

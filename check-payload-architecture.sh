#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

usage () {
	cat <<-\EOF
	usage: check-payload-architecture.sh [options]

	  --manifest=<file>      write the deterministic TSV manifest here
	  --baseline=<file>      allow the x64 paths listed in this file
	  --strict               fail if the payload contains any x64 PE file
	  --root=<directory>     read payload files below this directory
	  --file-list=<file>     use this installer file list instead of generating one
	  --package-list=<file>  use this "pacman -Ql" output instead of querying pacman
	EOF
}

thisdir="$(cd "$(dirname "$0")" && pwd)" ||
die "Could not determine script directory"

manifest=arm64-payload-architecture.tsv
baseline="$thisdir/arm64-x64-payload-baseline.txt"
root=/
file_list=
package_list=
strict=

while test $# -gt 0
do
	case "$1" in
	--manifest=*) manifest=${1#*=};;
	--baseline=*) baseline=${1#*=};;
	--root=*) root=${1#*=};;
	--file-list=*) file_list=${1#*=};;
	--package-list=*) package_list=${1#*=};;
	--strict) strict=t;;
	-h|--help) usage; exit 0;;
	*) die "Unknown option: $1";;
	esac
	shift
done

test -n "$manifest" || die "Manifest path cannot be empty"
test -d "$root" || die "Payload root does not exist: $root"
root=${root%/}
test -n "$root" || root=/

tmp=${TMPDIR:-/tmp}/payload-architecture.$$
trap 'rm -f "$tmp".*' EXIT

if test -z "$file_list"
then
	file_list=$tmp.files
	ARCH=aarch64 INCLUDE_GIT_UPDATE=1 \
		"$thisdir/make-file-list.sh" >"$file_list" ||
	die "Could not generate the installer file list"
fi
test -f "$file_list" || die "File list does not exist: $file_list"

sed -e 's/\r$//' -e 's|^\./||' "$file_list" |
LC_ALL=C sort -u |
grep -Ei '\.(dll|exe)$' >"$tmp.pe-paths" ||
die "The installer file list contains no PE files"

while IFS= read -r path
do
	case "$path" in
	""|/*|../*|*/../*) die "Invalid payload path: $path";;
	esac
	if test / = "$root"
	then
		full_path=/$path
	else
		full_path=$root/$path
	fi
	test -f "$full_path" || die "Payload file does not exist: $path"
	printf '%s\n' "$full_path"
done <"$tmp.pe-paths" >"$tmp.full-paths"

powershell=${POWERSHELL:-powershell.exe}
xargs -d '\n' -n 100 "$powershell" -NoProfile -ExecutionPolicy Bypass \
	-File "$thisdir/pe-imports.ps1" -ArchitectureOnly \
	<"$tmp.full-paths" >"$tmp.architectures" ||
die "Could not inspect payload PE architectures"
tr -d '\r' <"$tmp.architectures" >"$tmp.architectures.normalized" &&
mv "$tmp.architectures.normalized" "$tmp.architectures"

path_count=$(wc -l <"$tmp.pe-paths" | tr -d ' ')
architecture_count=$(wc -l <"$tmp.architectures" | tr -d ' ')
test "$path_count" = "$architecture_count" ||
die "Parsed $architecture_count of $path_count payload PE files"

paste "$tmp.pe-paths" "$tmp.architectures" >"$tmp.path-architectures"

if test -z "$package_list"
then
	package_list=$tmp.packages
	pacman -Ql >"$package_list" ||
	die "Could not query installed package file ownership"
fi
test -f "$package_list" || die "Package list does not exist: $package_list"

sed -n 's/^\([^ ]*\) \/\(.*\)$/\2	\1/p' "$package_list" |
LC_ALL=C sort -t '	' -k1,1 >"$tmp.path-packages"

printf 'path\tarchitecture\tpackage\tarea\n' >"$tmp.manifest"
awk -F '	' '
	FILENAME == ARGV[1] {
		package[$1] = $2
		next
	}
	{
		path = $1
		split(path, component, "/")
		if (component[1] == "usr")
			area = "msys"
		else if (component[1] ~ /^(clangarm64|mingw32|mingw64|ucrt64)$/)
			area = "mingw"
		else if (index(path, "/") == 0)
			area = "root"
		else
			area = component[1]
		printf "%s\t%s\t%s\t%s\n", path, $2, package[path], area
	}
' "$tmp.path-packages" "$tmp.path-architectures" >>"$tmp.manifest" ||
die "Could not build payload architecture manifest"
mv "$tmp.manifest" "$manifest" ||
die "Could not write payload architecture manifest: $manifest"

tail -n +2 "$manifest" |
cut -f2 |
LC_ALL=C sort |
uniq -c |
awk '{ printf "%s\t%d\n", $2, $1 }' >"$tmp.summary"

echo "Payload PE architecture summary:"
awk -F '	' '{ printf "  %-12s %d\n", $1, $2 }' "$tmp.summary"
echo "Manifest: $manifest"

if test -n "$GITHUB_STEP_SUMMARY"
then
	{
		echo "### ARM64 installer payload architectures"
		echo
		echo "| Architecture | Files |"
		echo "| --- | ---: |"
		awk -F '	' '{ printf "| %s | %d |\n", $1, $2 }' "$tmp.summary"
		echo
		echo "Manifest: \`$manifest\`"
	} >>"$GITHUB_STEP_SUMMARY"
fi

tail -n +2 "$manifest" |
awk -F '	' '$2 == "x64" { print $1 }' |
LC_ALL=C sort >"$tmp.x64"

if test -n "$strict"
then
	if test -s "$tmp.x64"
	then
		echo "Strict mode rejects these x64 payload files:" >&2
		cat "$tmp.x64" >&2
		exit 1
	fi
	exit 0
fi

test -f "$baseline" || die "x64 payload baseline does not exist: $baseline"
sed 's/\r$//' "$baseline" >"$tmp.baseline-input"
LC_ALL=C sort -u "$tmp.baseline-input" >"$tmp.baseline"
cmp -s "$tmp.baseline-input" "$tmp.baseline" ||
die "x64 payload baseline must be sorted and contain no duplicates: $baseline"

comm -13 "$tmp.baseline" "$tmp.x64" >"$tmp.new-x64"
if test -s "$tmp.new-x64"
then
	echo "New x64 payload files are not in the checked-in baseline:" >&2
	cat "$tmp.new-x64" >&2
	exit 1
fi

baseline_count=$(wc -l <"$tmp.baseline" | tr -d ' ')
x64_count=$(wc -l <"$tmp.x64" | tr -d ' ')
echo "x64 regression gate: $x64_count present, $baseline_count allowed by baseline"

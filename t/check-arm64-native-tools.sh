#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

thisdir="$(cd "$(dirname "$0")" && pwd)" ||
die "Could not determine the test directory"
selection_only=
case "$1" in
--selection-only) selection_only=t;;
"") ;;
*) die "Unknown option: $1";;
esac
tmp=${TMPDIR:-/tmp}/arm64-native-tools.$$
trap 'rm -f "$tmp"' EXIT

ARCH=aarch64 INCLUDE_GIT_UPDATE=1 \
	"$thisdir/../make-file-list.sh" >"$tmp" ||
die "Could not generate the ARM64 file list"

for tool in bunzip2 bzcat bzip2 bzip2recover \
	nettle-hash nettle-lfib-stream nettle-pbkdf2 pkcs1-conv sexp-conv \
	p11-kit trust
do
	grep -qx "usr/bin/$tool.exe" "$tmp" &&
	die "The ARM64 file list still contains usr/bin/$tool.exe"
	grep -qx "clangarm64/bin/$tool.exe" "$tmp" ||
	die "The ARM64 file list does not contain clangarm64/bin/$tool.exe"
done

for pattern in \
	'^usr/bin/msys-bz2-[0-9].*\.dll$' \
	'^usr/lib/perl5/.*/auto/Compress/Raw/Bzip2/Bzip2\.dll$' \
	'^usr/bin/msys-hogweed-[0-9].*\.dll$' \
	'^usr/bin/msys-nettle-[0-9].*\.dll$' \
	'^usr/bin/msys-p11-kit-[0-9].*\.dll$' \
	'^usr/lib/pkcs11/p11-kit-trust\.dll$' \
	'^usr/libexec/p11-kit/p11-kit-remote\.exe$' \
	'^usr/libexec/p11-kit/p11-kit-server\.exe$'
do
	grep -Eq "$pattern" "$tmp" ||
	die "The ARM64 file list no longer contains required x64 payload matching $pattern"
done

test -z "$selection_only" || exit 0

PATH=/clangarm64/bin:/usr/bin
export PATH
check_tool () {
	tool=$1
	expected=$2
	shift 2

	path=$(command -v "$tool") ||
	die "Could not resolve $tool from Git Bash"
	test "/clangarm64/bin/$tool" = "$path" ||
	die "$tool resolves to $path instead of /clangarm64/bin/$tool"

	"$tool" "$@" >"$tmp" 2>&1
	actual=$?
	test "$expected" = "$actual" ||
	die "$tool returned $actual instead of $expected"
}

check_tool bunzip2 0 --help
check_tool bzcat 0 --help
check_tool bzip2 0 --help
check_tool bzip2recover 1
check_tool nettle-hash 0 --help
check_tool nettle-lfib-stream 1 --help
check_tool nettle-pbkdf2 0 --help
check_tool pkcs1-conv 0 --help
check_tool sexp-conv 0 --help
check_tool p11-kit 0 --help
check_tool trust 0 --help

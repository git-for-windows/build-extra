#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

thisdir="$(cd "$(dirname "$0")" && pwd)" ||
die "Could not determine test directory"
root="$(cd "$thisdir/.." && pwd)" ||
die "Could not determine repository root"

trash=${TMPDIR:-/tmp}/check-payload-architecture-test.$$
trap 'rm -rf "$trash"' EXIT
mkdir -p "$trash/root/usr/bin" "$trash/root/clangarm64/bin" \
	"$trash/root/cmd" "$trash/root/etc" ||
die "Could not create test directories"

make_pe () {
	{
		printf 'MZ'
		dd if=/dev/zero bs=1 count=58 2>/dev/null
		printf '\100\000\000\000PE\000\000%b' "$2"
		dd if=/dev/zero bs=1 count=58 2>/dev/null
	} >"$1"
}

make_anycpu_pe () {
	dd if=/dev/zero of="$1" bs=1 count=544 2>/dev/null &&
	printf 'MZ' | dd of="$1" bs=1 seek=0 conv=notrunc 2>/dev/null &&
	printf '\100\000\000\000' | dd of="$1" bs=1 seek=60 conv=notrunc 2>/dev/null &&
	printf 'PE\000\000\114\001\001\000' | dd of="$1" bs=1 seek=64 conv=notrunc 2>/dev/null &&
	printf '\340\000' | dd of="$1" bs=1 seek=84 conv=notrunc 2>/dev/null &&
	printf '\013\001' | dd of="$1" bs=1 seek=88 conv=notrunc 2>/dev/null &&
	printf '\000\020\000\000\110\000\000\000' |
		dd of="$1" bs=1 seek=296 conv=notrunc 2>/dev/null &&
	printf '\000\001\000\000\000\020\000\000\000\001\000\000\000\002\000\000' |
		dd of="$1" bs=1 seek=320 conv=notrunc 2>/dev/null &&
	printf '\001\000\000\000' |
		dd of="$1" bs=1 seek=528 conv=notrunc 2>/dev/null
}

make_pe "$trash/root/usr/bin/legacy.exe" '\144\206'
make_pe "$trash/root/clangarm64/bin/git.exe" '\144\252'
make_pe "$trash/root/cmd/helper" '\114\001'
make_anycpu_pe "$trash/root/cmd/managed"

cat >"$trash/files" <<-\EOF
	usr/bin/legacy.exe
	etc/not-a-pe
	cmd/managed
	cmd/helper
	clangarm64/bin/git.exe
	EOF
echo text >"$trash/root/etc/not-a-pe"
cat >"$trash/packages" <<-\EOF
	msys2-runtime /usr/bin/legacy.exe
	mingw-w64-clang-aarch64-git /clangarm64/bin/git.exe
	EOF
echo usr/bin/legacy.exe >"$trash/baseline"

"$root/check-payload-architecture.sh" \
	--root="$trash/root" \
	--file-list="$trash/files" \
	--package-list="$trash/packages" \
	--baseline="$trash/baseline" \
	--manifest="$trash/manifest" >"$trash/output" ||
die "Baseline check unexpectedly failed"

cat >"$trash/expected" <<-\EOF
	path	architecture	machine	package	area
	clangarm64/bin/git.exe	arm64	0xAA64	mingw-w64-clang-aarch64-git	mingw
	cmd/helper	x86	0x014C		cmd
	cmd/managed	anycpu	0x014C		cmd
	usr/bin/legacy.exe	x64	0x8664	msys2-runtime	msys
	EOF
diff -u "$trash/expected" "$trash/manifest" ||
die "Manifest differs from expected output"
grep -q '^  arm64  *1$' "$trash/output" ||
die "ARM64 count is missing from summary"
grep -q '^  anycpu  *1$' "$trash/output" ||
die "AnyCPU count is missing from summary"
grep -q '^  x64  *1$' "$trash/output" ||
die "x64 count is missing from summary"
grep -q '^  x86  *1$' "$trash/output" ||
die "x86 count is missing from summary"

make_pe "$trash/root/usr/bin/new.exe" '\144\206'
echo usr/bin/new.exe >>"$trash/files"
if "$root/check-payload-architecture.sh" \
	--root="$trash/root" \
	--file-list="$trash/files" \
	--package-list="$trash/packages" \
	--baseline="$trash/baseline" \
	--manifest="$trash/regression-manifest" >"$trash/regression-output" 2>"$trash/regression-error"
then
	die "New x64 payload unexpectedly passed the baseline gate"
fi
grep -q '^usr/bin/new.exe$' "$trash/regression-error" ||
die "New x64 payload was not reported"

if "$root/check-payload-architecture.sh" \
	--root="$trash/root" \
	--file-list="$trash/files" \
	--package-list="$trash/packages" \
	--strict \
	--manifest="$trash/strict-manifest" >"$trash/strict-output" 2>"$trash/strict-error"
then
	die "x64 payload unexpectedly passed strict mode"
fi
grep -q '^usr/bin/legacy.exe$' "$trash/strict-error" ||
die "Strict mode did not report existing x64 payload"

grep -v '^usr/bin/' "$trash/files" >"$trash/native-files"
"$root/check-payload-architecture.sh" \
	--root="$trash/root" \
	--file-list="$trash/native-files" \
	--package-list="$trash/packages" \
	--strict \
	--manifest="$trash/native-manifest" >/dev/null ||
die "Zero-x64 payload failed strict mode"

echo "check-payload-architecture tests passed"

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
mkdir -p "$trash/root/usr/bin" "$trash/root/clangarm64/bin" "$trash/root/cmd" ||
die "Could not create test directories"

make_pe () {
	{
		printf 'MZ'
		dd if=/dev/zero bs=1 count=58 2>/dev/null
		printf '\100\000\000\000PE\000\000%b' "$2"
		dd if=/dev/zero bs=1 count=58 2>/dev/null
	} >"$1"
}

make_pe "$trash/root/usr/bin/legacy.exe" '\144\206'
make_pe "$trash/root/clangarm64/bin/git.exe" '\144\252'
make_pe "$trash/root/cmd/helper.exe" '\114\001'

cat >"$trash/files" <<-\EOF
	usr/bin/legacy.exe
	cmd/helper.exe
	clangarm64/bin/git.exe
	EOF
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
	path	architecture	package	area
	clangarm64/bin/git.exe	arm64	mingw-w64-clang-aarch64-git	mingw
	cmd/helper.exe	x86		cmd
	usr/bin/legacy.exe	x64	msys2-runtime	msys
	EOF
diff -u "$trash/expected" "$trash/manifest" ||
die "Manifest differs from expected output"
grep -q '^  arm64  *1$' "$trash/output" ||
die "ARM64 count is missing from summary"
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

#!/bin/sh
#
# pin-mtimes.sh - pin file mtimes for reproducible builds
#
# Usage: pin-mtimes.sh [--root=<dir>] <file>...
#
# Pin the mtime of every given file, and of every parent directory up to the
# filesystem root, to $SOURCE_DATE_EPOCH. When --root=<dir> is given, every
# file and directory under that overlay directory is pinned as well.
#
# The files must be given as paths relative to the filesystem root (e.g.
# "usr/bin/git.exe", as produced by make-file-list.sh). Archives (tar/zip/7z)
# and the installer embed file and directory timestamps, so pinning mtimes
# makes repeated builds of the same version byte-identical on the same SDK
# snapshot. This is a no-op (and exits 0) when SOURCE_DATE_EPOCH is unset.

test -n "$SOURCE_DATE_EPOCH" || exit 0

root=
case "$1" in
--root=*)
	root="${1#--root=}"
	shift
	;;
esac

echo "==> pinning file mtimes (SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH)"

tmp="$(mktemp)" || exit 1

# Pin the files themselves; remember those that could not be pinned.
for f in "$@"
do
	test -n "$f" || continue
	touch -h -d "@$SOURCE_DATE_EPOCH" "/$f" 2>/dev/null || echo "$f" >>"$tmp"
done

# make-file-list.sh only lists files, so pin the parent chain of every file
# (deduplicated) as well.
{
	for f in "$@"
	do
		test -n "$f" || continue
		d="/${f%/*}"
		while test -n "$d" && test "$d" != "/"
		do
			printf '%s\n' "$d"
			d="${d%/*}"
		done
	done
} | sort -u |
while IFS= read -r d
do
	test -d "$d" &&
	touch -h -d "@$SOURCE_DATE_EPOCH" "$d" 2>/dev/null
done
touch -h -d "@$SOURCE_DATE_EPOCH" "/" 2>/dev/null || true

# Pin every file and directory in the root overlay, if any.
test -z "$root" ||
find "$root" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} + 2>/dev/null || true
test -z "$root" ||
find "$root" -type d -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} + 2>/dev/null || true

if test -s "$tmp"
then
	echo "==> WARNING: could not pin mtime of $(wc -l <"$tmp") file(s):" >&2
	sed -n '1,20p' "$tmp" >&2
fi
rm -f "$tmp"

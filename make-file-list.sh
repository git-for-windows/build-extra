#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test $# -gt 0 ||
die "Usage: $0 <package-name>..."

pacman -Ql $(for arg
	do
		pactree -u "$arg"
	done |
	sort |
	uniq) |
grep -v '/$' |
sed 's/^[^ ]* //'

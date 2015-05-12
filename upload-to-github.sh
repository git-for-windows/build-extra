#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test $# -ge 2 ||
die "Usage: $0 [--repo=<repo>] <tag-name> <path>..."

repo=git-for-windows/build-extra
case "$1" in
--repo=*)
	repo=${1#--repo=}
	test "a${repo}" != "a${repo#*/}" ||
	repo=git-for-windows/$repo
	shift
	;;
esac

tagname="$1"
shift

url=https://api.github.com/repos/$repo/releases
id="$(curl --netrc -s $url |
	grep -B1 "\"tag_name\": \"$tagname\"" |
	sed -n 's/.*"id": *\([0-9]*\).*/\1/p')"
test -n "$id" || {
	out="$(curl --netrc -s -XPOST -d '{"tag_name":"'"$tagname"'"}' $url)" ||
	die "Error creating release: $out"
	id="$(echo "$out" |
		sed -n 's/^  "id": *\([0-9]*\).*/\1/p')"
	test -n "$id" ||
	die "Could not create release for tag $tagname"
}

url=https://uploads.${url#https://api.}

for path
do
	case "$path" in
	*.exe)
		contenttype=application/executable
		;;
	*.7z)
		contenttype=application/zip
		;;
	*)
		die "Unknown file type: $path"
		;;
	esac
	basename="$(basename "$path")"
	curl -i --netrc -XPOST -H "Content-Type: $contenttype" \
		--data-binary @"$path" "$url/$id/assets?name=$basename"
done

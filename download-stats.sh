#!/bin/sh

# This script shows the download stats on GitHub. Update the ids by calling
# this script with the `--update` option

test "--update" != "$1" || {
	curl -s \
	 https://api.github.com/repos/git-for-windows/git/releases |
	tac |
	sed -n '/^    "tag_name":/{
    N;
    s/.*"tag_name": "\([^"]*\)"[^"]*"id": \([0-9]*\).*/# \1\n#id=${1:-\2}/p
}' | sed '$s/^#//' >"${0%.sh}".ids &&
	echo "$ids" |
	sed -i -e '/^#\( v\?2.*windows\|id=\)/d' -e '/^id=/d' \
		-e "/^# IDs/r${0%.sh}.ids" "$0"
	exit
}

# IDs
# v2.3.5.windows.8
#id=${1:-1148462}
# v2.3.6.windows.2
#id=${1:-1215956}
# v2.3.7.windows.1
#id=${1:-1235013}
# v2.4.0.windows.1
#id=${1:-1257687}
# v2.4.0.windows.2
#id=${1:-1272221}
# v2.4.1.windows.1
#id=${1:-1296332}
# v2.4.2.windows.1
#id=${1:-1345088}
# v2.4.3.windows.1
#id=${1:-1409345}
# v2.4.4.windows.2
#id=${1:-1441039}
# v2.4.5.windows.1
#id=${1:-1471836}
# v2.4.6.windows.1
#id=${1:-1554860}
# v2.5.0.windows.1
#id=${1:-1683962}
# v2.5.1.windows.1
#id=${1:-1744098}
# v2.5.2.windows.1
#id=${1:-1796452}
# v2.5.2.windows.2
#id=${1:-1804946}
# v2.5.3.windows.1
#id=${1:-1835755}
# v2.6.0.windows.1
#id=${1:-1886219}
# v2.6.1.windows.1
#id=${1:-1914287}
# v2.6.2.windows.1
#id=${1:-1984920}
# v2.6.3.windows.1
#id=${1:-2104213}
# v2.6.4.windows.1
#id=${1:-2285622}
# v2.7.0.windows.1
#id=${1:-2375145}
# v2.7.0.windows.2
#id=${1:-2538484}
# v2.7.1.windows.1
#id=${1:-2566181}
# v2.7.1.windows.2
#id=${1:-2602217}
# v2.7.2.windows.1
#id=${1:-2671180}
# v2.7.3.windows.1
#id=${1:-2818116}
# v2.7.4.windows.1
#id=${1:-2838068}
# v2.8.0.windows.1
#id=${1:-2906101}
# v2.8.1.windows.1
id=${1:-2944817}

case "$id" in
*.*)
	case "$id" in
	v*.windows.*) id="$(echo "$id" | sed 's/\./\\./g')";;
	*\(*\)) id="$(echo "$id" |
		sed -e 's/(\(.*\))$/.windows.\1/' -e 's/\./\\./g')";;
	*)
		id="$(echo "$id" | sed 's/\./\\./g').windows.1";;
	esac
	id="$(sed -n "/$id/{N;s/.*:-\([0-9]*\).*/\1/p}" <"$0")"
	test -n "$id" || {
		echo "Version $1 not found" >&2
		exit 1
	}
	;;
esac

curl -s https://api.github.com/repos/git-for-windows/git/releases/$id/assets |
grep -e '"name":' -e '"download_count":'

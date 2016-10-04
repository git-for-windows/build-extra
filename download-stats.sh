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
#id=${1:-2944817}
# v2.8.2.windows.1
#id=${1:-3150188}
# v2.8.3.windows.1
#id=${1:-3271192}
# v2.8.4.windows.1
#id=${1:-3388498}
# v2.9.0.windows.1
#id=${1:-3439291}
# v2.9.2.windows.1
#id=${1:-3672442}
# v2.9.2.windows.2
#id=${1:-3848233}
# v2.9.2.windows.3
#id=${1:-3876868}
# v2.9.3.windows.1
#id=${1:-3880739}
# v2.9.3.windows.2
#id=${1:-3972357}
# v2.9.3.windows.3
#id=${1:-4022347}
# v2.10.0.windows.1
#id=${1:-4044191}
# prerelease-v2.10.0.windows.1.11.geda474c
#id=${1:-4092034}
# v2.10.1.windows.1
id=${1:-4300678}

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

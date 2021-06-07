#!/bin/sh

# This script shows the download stats on GitHub. Update the ids by calling
# this script with the `--update` option

test "--update" != "$1" || {
	curl -s \
	 https://api.github.com/repos/git-for-windows/git/releases |
	tac |
	sed -n '/^  }/{
    :1;N;/\n  {/b2;b1
    :2;
    y/\n/\r/
    s/.*"tag_name": "\([^"]*\)".*"id": \([0-9]*\).*/# \1\n#id=${1:-\2}/p
}' | sed '$s/^#//' >"${0%.sh}".ids &&
	echo "$ids" |
	sed -i -e '/^#\( v\?2.*windows\|id=\)/d' -e '/^id=/d' \
		-e "/^# IDs/r${0%.sh}.ids" "$0"
	exit
}

# IDs
# v2.28.0-rc0.windows.1
#id=${1:-28443037}
# v2.28.0-rc1.windows.1
#id=${1:-28694895}
# v2.28.0-rc2.windows.1
#id=${1:-28844078}
# v2.28.0.windows.1
#id=${1:-29022776}
# v2.29.0-rc0.windows.1
#id=${1:-32206602}
# v2.29.0-rc1.windows.1
#id=${1:-32382861}
# v2.29.0-rc2.windows.1
#id=${1:-32646100}
# v2.29.0.windows.1
#id=${1:-32779796}
# v2.29.1.windows.1
#id=${1:-33001134}
# v2.29.2.windows.1
#id=${1:-33276732}
# v2.29.2.windows.2
#id=${1:-33478840}
# v2.29.2.windows.3
#id=${1:-34991264}
# v2.30.0-rc0.windows.1
#id=${1:-35261934}
# v2.30.0-rc1.windows.1
#id=${1:-35525593}
# v2.30.0-rc2.windows.1
#id=${1:-35692134}
# v2.30.0.windows.1
#id=${1:-35782740}
# v2.30.0.windows.2
#id=${1:-36382794}
# v2.30.1.windows.1
#id=${1:-37800609}
# v2.31.0-rc0.windows.1
#id=${1:-38795836}
# v2.31.0-rc1.windows.1
#id=${1:-39205162}
# v2.30.2.windows.1
#id=${1:-39534296}
# v2.29.2.windows.4
#id=${1:-39539472}
# v2.31.0-rc2.windows.1
#id=${1:-39614982}
# v2.31.0.windows.1
#id=${1:-39845515}
# v2.31.1.windows.1
#id=${1:-40576275}
# v2.32.0-rc0.windows.1
#id=${1:-43059649}
# v2.32.0-rc1.windows.1
#id=${1:-43411438}
# v2.32.0-rc2.windows.1
#id=${1:-43764147}
# v2.32.0-rc3.windows.1
#id=${1:-43963002}
# v2.32.0.windows.1
id=${1:-44204800}
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.6
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.4
# v2.11.1.mingit-prerelease.5
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.3
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# v2.11.1.mingit-prerelease.2
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.11.0.windows.1.1
# v2.11.1.mingit-prerelease.1
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.10.0.windows.1.11.geda474c
# prerelease-v2.10.0.windows.1.11.geda474c

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

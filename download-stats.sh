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
# v2.40.0-rc2.windows.1
#id=${1:-94847502}
# v2.40.0.windows.1
#id=${1:-95506050}
# v2.39.3.windows.1
#id=${1:-100842599}
# v2.40.1.windows.1
#id=${1:-100843039}
# v2.41.0-rc0.windows.1
#id=${1:-103323513}
# v2.41.0-rc1.windows.1
#id=${1:-103666003}
# v2.41.0-rc2.windows.1
#id=${1:-104189428}
# v2.41.0.windows.1
#id=${1:-105721665}
# v2.41.0.windows.2
#id=${1:-111394395}
# v2.41.0.windows.3
#id=${1:-112183312}
# v2.42.0-rc0.windows.1
#id=${1:-115601947}
# v2.42.0-rc1.windows.1
#id=${1:-116023665}
# v2.42.0-rc2.windows.1
#id=${1:-117405398}
# v2.42.0.windows.1
#id=${1:-118070747}
# v2.42.0.windows.2
#id=${1:-119230678}
# v2.43.0-rc0.windows.1
#id=${1:-127821750}
# v2.43.0-rc1.windows.1
#id=${1:-128598566}
# v2.43.0-rc2.windows.1
#id=${1:-129447716}
# v2.43.0.windows.1
#id=${1:-130475909}
# v2.44.0-rc0.windows.1
#id=${1:-141203075}
# v2.44.0-rc1.windows.1
#id=${1:-142065209}
# v2.44.0-rc2.windows.1
#id=${1:-142840047}
# v2.44.0.windows.1
#id=${1:-143416764}
# v2.45.0-rc0.windows.1
#id=${1:-152015410}
# v2.39.4.windows.1
#id=${1:-155742750}
# v2.43.4.windows.1
#id=${1:-155740960}
# v2.44.1.windows.1
#id=${1:-155741902}
# v2.45.0-rc1.windows.1
#id=${1:-152688473}
# v2.45.0.windows.1
#id=${1:-153357134}
# v2.45.1.windows.1
id=${1:-155738226}
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

#!/bin/sh

# This script shows the download stats on GitHub. Update the ids by calling
# this script with the `--update` option

test "--update" != "$1" || {
	curl -s \
	 https://api.github.com/repos/git-for-windows/git/releases |
	tac |
	sed -n '/^    "\(tag_name\|id\)":/{
    N;N;
    y/\n/ /;
    s/.*"tag_name": "\([^"]*\)".*"id": \([0-9]*\).*/# \1\n#id=${1:-\2}/p
}' | sed '$s/^#//' >"${0%.sh}".ids &&
	echo "$ids" |
	sed -i -e '/^#\( v\?2.*windows\|id=\)/d' -e '/^id=/d' \
		-e "/^# IDs/r${0%.sh}.ids" "$0"
	exit
}

# IDs
# v2.16.1.windows.2
#id=${1:-9514737}
# v2.16.1.windows.3
#id=${1:-9555514}
# v2.16.1.windows.4
#id=${1:-9579600}
# v2.16.2.windows.1
#id=${1:-9749756}
# v2.17.0-rc0.windows.1
#id=${1:-10134423}
# v2.17.0-rc1.windows.1
#id=${1:-10235214}
# v2.16.3.windows.1
#id=${1:-10235771}
# v2.17.0-rc2.windows.1
#id=${1:-10322089}
# v2.17.0.windows.1
#id=${1:-10369295}
# v2.17.1.windows.1
#id=${1:-11224533}
# v2.17.1.windows.2
#id=${1:-11227511}
# v2.14.4.windows.1
#id=${1:-11238015}
# v2.11.1.mingit-prerelease.3
#id=${1:-11238166}
# v2.18.0-rc1.windows.1
#id=${1:-11395085}
# v2.18.0-rc1.windows.2
#id=${1:-11427247}
# v2.18.0-rc1.windows.3
#id=${1:-11448041}
# v2.18.0-rc2.windows.1
#id=${1:-11480848}
# v2.14.4.windows.2
#id=${1:-11589766}
# v2.18.0.windows.1
#id=${1:-11604912}
# v2.19.0-rc0.windows.1
#id=${1:-12509211}
# v2.19.0-rc0.windows.2
#id=${1:-12552758}
# v2.19.0-rc1.windows.1
#id=${1:-12624020}
# v2.19.0-rc2.windows.1
#id=${1:-12746845}
# v2.19.0.windows.1
#id=${1:-12872702}
# v2.19.1.windows.1
#id=${1:-13272534}
# v2.20.0-rc0.windows.1
#id=${1:-14103000}
# v2.19.2.windows.1
#id=${1:-14129204}
# v2.20.0-rc1.windows.1
#id=${1:-14165638}
# v2.20.0-rc2.windows.1
#id=${1:-14304457}
# v2.20.0.windows.1
id=${1:-14440825}
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

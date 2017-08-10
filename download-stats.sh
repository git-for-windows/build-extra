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
# v2.10.1.windows.2
#id=${1:-4382260}
# v2.10.2.windows.1
#id=${1:-4547425}
# v2.11.0-rc0.windows.1
#id=${1:-4574263}
# v2.11.0-rc0.windows.2
#id=${1:-4637903}
# v2.11.0-rc1.windows.1
#id=${1:-4665420}
# v2.11.0-rc2.windows.1
#id=${1:-4705463}
# v2.11.0-rc3.windows.1
#id=${1:-4755145}
# v2.11.0.windows.1
#id=${1:-4805052}
# prerelease-v2.11.0.windows.1.1
#id=${1:-4880739}
# v2.11.1.windows-prerelease.1
#id=${1:-5001367}
# v2.11.1.mingit-prerelease.1
#id=${1:-5068926}
# v2.11.0.windows.2
#id=${1:-5153384}
# v2.11.0.windows.3
#id=${1:-5159523}
# v2.11.1.windows-prerelease.2
#id=${1:-5220049}
# v2.11.1.windows.1
#id=${1:-5349389}
# v2.12.0.windows.1
#id=${1:-5571947}
# v2.12.0.windows.2
#id=${1:-5757342}
# v2.12.1.windows.1
#id=${1:-5819520}
# v2.12.2.windows.1
#id=${1:-5885060}
# v2.12.2.windows.2
#id=${1:-5987210}
# v2.13.0.windows.1
#id=${1:-6335523}
# v2.13.1.windows.1
#id=${1:-6694419}
# v2.13.1.windows.2
#id=${1:-6727667}
# v2.13.2.windows.1
#id=${1:-6835647}
# v2.13.3.windows.1
#id=${1:-7027502}
# v2.14.0.windows.1
#id=${1:-7295280}
# v2.14.0.windows.2
#id=${1:-7302996}
# v2.12.2.windows.3
#id=${1:-7350784}
# v2.13.1.windows.3
#id=${1:-7350859}
# v2.14.1.windows.1
id=${1:-7352987}
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

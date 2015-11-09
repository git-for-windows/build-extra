#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

case "$1" in
*/.git/*) ;; # needs LF line endings
*) exec notepad.exe "$1" || die "Could not launch notepad.exe";;
esac

test $# = 1 ||
die "Usage: $0 <file>"

if test -f "$1"
then
	unix2dos.exe "$1"
fi &&
notepad.exe "$1" &&
dos2unix.exe "$1" &&
case "$1" in
*/COMMIT_EDITMSG|*\\COMMIT_EDITMSG)
	! columns="$(git config format.commitmessagecolumns)" || {
		msg="$(fmt.exe -s -w "$columns" "$1")" &&
		printf "%s" "$msg" >"$1"
	}
	;;
esac

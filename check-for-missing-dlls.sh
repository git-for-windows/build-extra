#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

thisdir="$(cd "$(dirname "$0")" && pwd)" ||
die "Could not determine script directory"

sys_dlls="$(ls "$SYSTEMROOT/system32"/*.dll "$SYSTEMROOT/system32"/*.DLL "$SYSTEMROOT/system32"/*.drv | tr A-Z a-z)" ||
die "Could not enumerate system .dll files"

LF='
'

ARCH="$(uname -m)" ||
die "Could not determine architecture"

case "$ARCH" in
i686) BITNESS=32;;
x86_64) BITNESS=64;;
*) die "Unhandled architecture: $ARCH";;
esac

if test -t 2
then
	next_line='\033[K\r'
else
	next_line='\n'
fi

all_files="$(export ARCH BITNESS && "$thisdir"/make-file-list.sh | tr A-Z a-z)" &&
usr_bin_dlls="$(echo "$all_files" | grep '^usr/bin/[^/]*\.dll$')" &&
mingw_bin_dlls="$(echo "$all_files" | grep '^mingw'$BITNESS'/bin/[^/]*\.dll$')" &&
dirs="$(echo "$all_files" | sed -n 's/[^/]*\.\(dll\|exe\)$//p' | sort | uniq)" &&
for dir in $dirs
do
	printf "dir: $dir$next_line\\r" >&2

	case "$dir" in
	usr/*) dlls="$dlls$LF$usr_bin_dlls$LF";;
	mingw$BITNESS/*) dlls="$dlls$LF$mingw_bin_dlls$LF";;
	*) dlls="$sys_dlls$LF";;
	esac

	/usr/bin/objdump -p $(echo "$all_files" | sed -ne 's,[][],\\&,g' -e "s,^$dir[^/]*\.\(dll\|exe\)$,/&,p") |
	tr A-Z\\r a-z\  |
	grep -e '^.dll name:' -e '^[^ ]*\.\(dll\|exe\):' |
	while read a b c d
	do
		case "$a,$b" in
		*.exe:,*|*.dll:,*) current="${a%:}";;
		*.dll,"=>") # `ldd` output
			case "$dlls" in
			*"/$a$LF"*) ;; # okay, it's included
			*) echo "$current is missing $a" >&2;;
			esac
			;;
		dll,name:) # `objdump -p` output
			case "$dlls" in
			*"/$c$LF"*) ;; # okay, it's included
			*) echo "$current is missing $c" >&2;;
			esac
			;;
		esac
	done
done
printf "$next_line" >&2

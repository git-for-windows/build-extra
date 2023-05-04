#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

while case "$1" in
--mingit) MINIMAL_GIT=1; export MINIMAL_GIT;;
-*) die "Unknown option: $1";;
*) break;;
esac; do shift; done

test $# = 0 || die "$0 does not take arguments"

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
	print_dir=t
else
	print_dir=
fi

used_dlls_file=/tmp/used-dlls.$$.txt
>"$used_dlls_file"
missing_dlls_file=/tmp/missing-dlls.$$.txt
>"$missing_dlls_file"
unused_dlls_file=/tmp/unused-dlls.$$.txt
tmp_file=/tmp/tmp.$$.txt
trap "rm \"$used_dlls_file\" \"$missing_dlls_file\" \"$unused_dlls_file\" \"$tmp_file\"" EXIT

all_files="$(export ARCH BITNESS && "$thisdir"/make-file-list.sh | tr A-Z a-z | grep -v '/getprocaddr64.exe$')" &&
usr_bin_dlls="$(echo "$all_files" | grep '^usr/bin/[^/]*\.dll$')" &&
mingw_bin_dlls="$(echo "$all_files" | grep '^mingw'$BITNESS'/bin/[^/]*\.dll$')" &&
dirs="$(echo "$all_files" | sed -n 's/[^/]*\.\(dll\|exe\)$//p' | sort | uniq)" &&
for dir in $dirs
do
	test -z "$print_dir" ||
	printf "dir: $dir\\033[K\\r" >&2

	case "$dir" in
	usr/*) dlls="$sys_dlls$LF$usr_bin_dlls$LF";;
	mingw$BITNESS/*) dlls="$sys_dlls$LF$mingw_bin_dlls$LF";;
	*) dlls="$sys_dlls$LF";;
	esac

	paths=$(echo "$all_files" |
		sed -ne 's,[][],\\&,g' -e "s,^$dir[^/]*\.\(dll\|exe\)$,/&,p")
	out="$(/usr/bin/objdump -p $paths 2>"$tmp_file")"
	paths="$(sed -n 's|^/usr/bin/objdump: \([^ :]*\): file format not recognized|\1|p' <"$tmp_file")"
	test -z "$paths" ||
	out="$out$LF$(ldd $paths)"

	echo "$out" |
	tr A-Z\\r a-z\  |
	grep -e '^.dll name:' -e '^[^ ]*\.\(dll\|exe\):' -e '\.dll =>' |
	while read a b c d
	do
		case "$a,$b" in
		*.exe:,*|*.dll:,*) current="${a%:}";;
		*.dll,"=>") # `ldd` output
			echo "$a" >>"$used_dlls_file"
			case "$dlls" in
			*"/$a$LF"*) ;; # okay, it's included
			*)
				echo "$current is missing $a" >&2
				echo "$a" >>"$missing_dlls_file"
				;;
			esac
			;;
		dll,name:) # `objdump -p` output
			echo "$c" >>"$used_dlls_file"
			case "$dlls" in
			*"/$c$LF"*) ;; # okay, it's included
			*)
				echo "$current is missing $c" >&2
				echo "$c" >>"$missing_dlls_file"
				;;
			esac
			;;
		esac
	done
done
printf "$next_line" >&2

used_dlls_regex="/\\($(test -n "$MINIMAL_GIT" || printf 'p11-kit-trust\\|';
	sort <"$used_dlls_file" |
	uniq |
	sed -e 's/+x/\\+/g' -e 's/\.dll$/\\|/' -e '$s/\\|//' |
	tr -d '\n')\\)\\.dll\$"
echo "$all_files" |
	grep '\.dll$' |
	grep -v \
		-e "$used_dlls_regex" \
		-e '^usr/lib/perl5/' \
		-e '^usr/lib/gawk/' \
		-e '^usr/lib/openssl/engines' \
		-e '^usr/lib/sasl2/' \
		-e '^usr/lib/coreutils/libstdbuf.dll' \
		-e '^mingw../bin/\(atlassian\|azuredevops\|bitbucket\|gcmcore.*\|github\|gitlab\|microsoft\|newtonsoft\|system\..*\|webview2loader\|avalonia\|.*harfbuzzsharp\|microcom\|.*skiasharp\|av_libglesv2\|msalruntime_x86\)\.' \
		-e '^mingw../lib/\(engines\|reg\|thread\)' |
	sed 's/^/unused dll: /' |
	tee "$unused_dlls_file" >&2

test ! -s "$missing_dlls_file" && test ! -s "$unused_dlls_file"

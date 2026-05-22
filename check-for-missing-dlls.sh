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

case "$MSYSTEM" in
MINGW64) MINGW_PREFIX=mingw64;;
CLANGARM64)
	MINGW_PREFIX=clangarm64
	ARCH=aarch64
	;;
MINGW32) MINGW_PREFIX=mingw32;;
*)
	case "$ARCH" in
	i686) MINGW_PREFIX=mingw32;;
	x86_64)
		case $(uname -s) in
			*-ARM64)
				MINGW_PREFIX=clangarm64
				ARCH=aarch64
				;;
			*) MINGW_PREFIX=mingw64;;
		esac
		;;
	*) die "Unhandled architecture: $ARCH";;
	esac
	;;
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

ARCH=$ARCH "$thisdir"/make-file-list.sh | tr A-Z a-z | grep -v '/getprocaddr64.exe$' >"$tmp_file.all" &&
usr_bin_dlls="$(grep '^usr/bin/[^/]*\.dll$' "$tmp_file.all")" &&
mingw_bin_dlls="$(grep '^'$MINGW_PREFIX'/bin/[^/]*\.dll$' "$tmp_file.all")" &&
dirs="$(sed -n 's/[^/]*\.\(dll\|exe\)$//p' "$tmp_file.all" | sort | uniq)" &&
for dir in $dirs
do
	test -z "$print_dir" ||
	printf "dir: $dir\\033[K\\r" >&2

	case "$dir" in
	usr/*) dlls="$usr_bin_dlls$LF";;
	$MINGW_PREFIX/*) dlls="$mingw_bin_dlls$LF";;
	*) dlls="";;
	esac

	paths=$(sed -ne 's,[][],\\&,g' -e "s,^$dir[^/]*\.\(dll\|exe\)$,/&,p" "$tmp_file.all")
	/usr/bin/objdump -p $paths 2>"$tmp_file" >"$tmp_file.ldd"
	paths="$(sed -n 's|^/usr/bin/objdump: \([^ :]*\): file format not recognized|\1|p' <"$tmp_file")"
	if test -n "$paths"
	then
		powershell.exe -NoProfile -ExecutionPolicy Bypass \
			-File "$thisdir/pe-imports.ps1" $paths >>"$tmp_file.ldd" ||
		die "pe-imports.ps1 failed to parse PE imports"
	fi

	tr A-Z\\r a-z\ <"$tmp_file.ldd" |
	grep -e '^.dll name:' -e '^[^ ]*\.\(dll\|exe\):' |
	while read a b c d
	do
		case "$a,$b" in
		*.exe:,*|*.dll:,*) current="${a%:}";;
		dll,name:) # `objdump -p` / pe-imports.ps1 output
			echo "$c" >>"$used_dlls_file"
			case "$sys_dlls$LF$dlls" in
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
grep '\.dll$' "$tmp_file.all" |
	grep -v \
		-e "$used_dlls_regex" \
		-e '^usr/lib/perl5/' \
		-e '^usr/lib/gawk/' \
		-e '^usr/lib/openssl/engines' \
		-e '^usr/lib/sasl2/' \
		-e '^usr/lib/coreutils/libstdbuf.dll' \
		-e "^$MINGW_PREFIX/bin/libcurl\(\|-openssl\)-4.dll" \
		-e "^$MINGW_PREFIX/bin/\(atlassian\|azuredevops\|bitbucket\|gcmcore.*\|github\|gitlab\|microsoft\|newtonsoft\|system\..*\|webview2loader\|avalonia\|.*harfbuzzsharp\|microcom\|.*skiasharp\|av_libglesv2\|msalruntime\(\|_x86\|_arm64\)\)\." \
		-e "^$MINGW_PREFIX/lib/ossl-modules/" \
		-e "^$MINGW_PREFIX/lib/\(engines\|reg\|thread\)" |
	sed 's/^/unused dll: /' |
	tee "$unused_dlls_file" >&2

test ! -s "$missing_dlls_file" && test ! -s "$unused_dlls_file"

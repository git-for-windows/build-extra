#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test $# -ge 4 ||
die "usage: ${0##*/} <storage-account-name> <container-name> <access-key> ( list | upload <file>... | upload-with-lease <lease-id> <file> | remove <file>[,<filesize>]... | lock <file> | unlock <lease-id> <file> | add-snapshot <version>)"

storage_account="$1"; shift
container_name="$1"; shift
access_key="$1"; shift

blob_store_url="blob.core.windows.net"

script_dir="$(cd "$(dirname "$0")" && pwd)"

get_remote_file_length () {
	curl --silent --head -i \
		"https://$storage_account.$blob_store_url/$container_name/$1" |
	tr -d '\r' |
	sed -n 's/^Content-Length: *//ip'
}

req () {
	uploading=
	file=
	x_ms_blob_type=
	x_ms_lease_action=
	x_ms_lease_duration=
	x_ms_lease_id=
	content_length=
	content_length_header=
	content_type=
	resource_extra=
	resource_trailer=
	get_parameters=
	string_to_sign_extra=
	extract_lease=
	case "$1" in
	upload)
		uploading=t
		while case "$2" in
		--lease-id=*) x_ms_lease_id="x-ms-lease-id:${2#*=}";;
		--filename=*) resource_extra=/"${2#*=}";;
		-*) die "Unknown option: '$2'";;
		*) break;;
		esac; do shift; done
		file="$2"
		test -f "$file" || {
			echo "File does not exist: '$file'" >&2
			return 1
		}

		test -n "$resource_extra" ||
		resource_extra=/"${file##*/}"

		request_method="PUT"
		x_ms_blob_type="x-ms-blob-type:BlockBlob"
		content_length="$(stat -c %s "$file")"
		content_length_header="Content-Length: $content_length"
		case "$file" in
		*.html) content_type="text/html";;
		*.css) content_type="text/css";;
		*.txt|*.md) content_type="text/plain";;
		*.exe) content_type="application/x-executable";;
		*) content_type="application/octet-stream";;
		esac
		;;
	remove)
		file="$2"
		content_length="$(get_remote_file_length "$file")"
		resource_extra=/"${file##*/}"

		request_method="DELETE"
		content_length_header="Content-Length: $content_length"
		;;
	lock)
		extract_lease=t
		lease_duration=60
		while case "$2" in
		--verbose|-v) extract_lease=;;
		--duration=*) lease_duration=${2#*=};;
		-*) die "Unknown option: '$2'";;
		*) break;;
		esac; do shift; done

		file="$2"
		content_length=0
		resource_extra=/"${file##*/}"

		request_method="PUT"
		get_parameters="?comp=lease"
		string_to_sign_extra="\ncomp:lease"
		x_ms_lease_action="x-ms-lease-action:acquire"
		x_ms_lease_duration="x-ms-lease-duration:$lease_duration"
		content_length_header="Content-Length: $content_length"
		;;
	unlock)
		lease_id="$2"
		file="$3"
		content_length=0
		resource_extra=/"${file##*/}"

		request_method="PUT"
		get_parameters="?comp=lease"
		string_to_sign_extra="\ncomp:lease"
		x_ms_lease_id="x-ms-lease-id:$lease_id"
		x_ms_lease_action="x-ms-lease-action:release"
		content_length_header="Content-Length: $content_length"
		;;
	list)
		request_method="GET"
		get_parameters="?restype=container&comp=list"
		string_to_sign_extra="\ncomp:list\nrestype:container"
		;;
	*)
		die "req called with unknown command: $1"
		;;
	esac

	authorization="SharedKey"

	request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
	storage_service_version="2016-05-31"

	# HTTP Request headers
	x_ms_date_h="x-ms-date:$request_date"
	x_ms_version_h="x-ms-version:$storage_service_version"

	# Build the signature string
	canonicalized_headers="${x_ms_blob_type:+$x_ms_blob_type\n}$x_ms_date_h\n${x_ms_lease_action:+$x_ms_lease_action\n}${x_ms_lease_duration:+$x_ms_lease_duration\n}${x_ms_lease_id:+$x_ms_lease_id\n}$x_ms_version_h"
	canonicalized_resource="/$storage_account/$container_name$resource_extra"

	string_to_sign="$request_method\n\n\n${content_length#0}\n\n$content_type\n\n\n\n\n\n\n$canonicalized_headers\n$canonicalized_resource$string_to_sign_extra"

	# Decode the Base64 encoded access key, convert to Hex.
	decoded_hex_key="$(printf %s "$access_key" | base64 -d -w0 | xxd -p -c256)"

	# Create the HMAC signature for the Authorization header
	signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary |  base64 -w0)
	authorization_header="Authorization: $authorization $storage_account:$signature"

	out="$({
		test -z "$content_type" ||
		echo "-H \"Content-Type: $content_type\""
		test -z "$x_ms_blob_type" || echo "-H \"$x_ms_blob_type\""
		test -z "$x_ms_lease_action" || echo "-H \"$x_ms_lease_action\""
		test -z "$x_ms_lease_duration" ||
		echo "-H \"$x_ms_lease_duration\""
		test -z "$x_ms_lease_id" || echo "-H \"$x_ms_lease_id\""
		echo "-H \"$x_ms_date_h\""
		echo "-H \"$x_ms_version_h\""
		test -z "$content_length_header" ||
		echo "-H \"$content_length_header\""
		echo "-H \"$authorization_header\""
		echo "-X$request_method"
		test -z "$uploading" || test -z "$file" ||
		echo "--data-binary \"@$file\""
	} |
	curl -i -f -K - \
	"https://$storage_account.$blob_store_url/$container_name$resource_extra$get_parameters")" ||
	die "Failed: $out"

	if test -z "$extract_lease"
	then
		echo "$out"
	else
		echo "$out" |
		tr -d '\r' |
		sed -n 's/x-ms-lease-id: *//p'
	fi
}

html_preamble='<!DOCTYPE html>
<html>
<head>
<title>Git for Windows snapshots</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<link rel="stylesheet" href="GitForWindows.css">
<link rel="shortcut icon" href="https://gitforwindows.org/favicon.ico">
</head>
<body class="details">
<div class="links">
<ul>
<li><a href="https://gitforwindows.org/">homepage</a></li>
<li><a href="https://github.com/git-for-windows/git/wiki/FAQ">faq</a></li>
<li><a href="https://gitforwindows.org/#contribute">contribute</a></li>
<li><a href="https://gitforwindows.org/#contribute">bugs</a></li>
<li><a href="mailto:git@vger.kernel.org">questions</a></li>
</ul>
</div>
<img src="https://gitforwindows.org/img/gwindows_logo.png" alt="Git Logo" style="float: right; width: 170px;"/><div class="content">
<h1><center>Git for Windows Snapshots</center></h1>

'
html_footer='

</div>
</body>
</html>
'

print_html_item () {
	mingit=
	mingit_busybox=
	while case "$1" in
	--mingit) mingit=t;;
	--mingit-busybox) mingit_busybox=t;;
	-*) die "Unhandled option: '$1'";;
	*) break;;
	esac; do shift; done
	version="$1"
	date="$2"
	h2_id="$3"
	commit="$4"
	cat <<EOF
<h2 id="$h2_id">$date<br />(commit <a href="https://github.com/git-for-windows/git/commit/$commit">$commit</a>)</h2>

<ul>
<li>Git for Windows installer: <a href="Git-$version-64-bit.exe">64-bit</a> and <a href="Git-$version-32-bit.exe">32-bit</a>.</li>
<li>Portable Git (self-extracting <tt>.7z</tt> archive): <a href="PortableGit-$version-64-bit.7z.exe">64-bit</a> and <a href="PortableGit-$version-32-bit.7z.exe">32-bit</a>.</li>
$(test -z "$mingit" ||
printf '<li>MinGit: <a href="%s">64-bit</a> and <a href="%s">32-bit</a>.</li>\n' "MinGit-$version-64-bit.zip" "MinGit-$version-32-bit.zip"
test -z "$mingit_busybox" ||
printf '<li>MinGit (BusyBox): <a href="%s">64-bit</a> and <a href="%s">32-bit</a>.</li>\n' "MinGit-$version-BusyBox-64-bit.zip" "MinGit-$version-BusyBox-32-bit.zip")</ul>
EOF
}

add_snapshot () {
	extra=
	files="Git-$1-32-bit.exe Git-$1-64-bit.exe"
	files="$files PortableGit-$1-32-bit.7z.exe PortableGit-$1-64-bit.7z.exe"

	test -f "MinGit-$1-32-bit.zip" &&
	test -f "MinGit-$1-64-bit.zip" &&
	files="$files MinGit-$1-32-bit.zip MinGit-$1-64-bit.zip" &&
	extra="${extra:+$extra }--mingit"

	test -f "MinGit-$1-BusyBox-32-bit.zip" &&
	test -f "MinGit-$1-BusyBox-64-bit.zip" &&
	files="$files MinGit-$1-BusyBox-32-bit.zip" &&
	files="$files MinGit-$1-BusyBox-64-bit.zip" &&
	extra="${extra:+$extra }--mingit-busybox"

	html_item="$(print_html_item $extra "$@")"
	for f in $files
	do
		test -f "$f" || die "File not found: '$f'"
		eval req upload "$f" || die "Could not upload '$f'"
	done

	lease_id="$(req lock index.html)" || die "Could not lock 'index.html'"
	test -n "$lease_id" || die "Could not find lease ID in $response"

	url_base="https://$storage_account.$blob_store_url/$container_name"

	curl --fail --head "$url_base/GitForWindows.css" 2>/dev/null ||
	req upload --filename=GitForWindows.css \
		"$script_dir/ReleaseNotes.css" ||
	die "Could not upload GitForWindows.css"

	if html="$(curl --silent --fail "$url_base/index.html")"
	then
		html="${html%%<h2*}$html_item${html#*</h1>}"
	else
		html="$html_preamble$html_item$html_footer"
	fi
	tmpfile=.wingit-index.$$.html
	echo "$html" >$tmpfile
	req upload --lease-id="$lease_id" --filename=index.html $tmpfile ||
	die "Could not upload 'index.html'"
	rm $tmpfile
	req unlock "$lease_id" index.html || die "Could not unlock 'index.html'"
}

action="$1"; shift
case "$action" in
list)
	test $# = 0 || die "'list' does not accept arguments"
	req "$action"
	;;
upload)
	test $# -gt 0 || die "'upload' requires arguments"
	ret=0
	for file
	do
		req "$action" "$file" || ret=1
	done
	exit $ret
	;;
upload-with-lease)
	test $# = 2 || die "'upload-with-lease' requires <lease-id> <file>"
	req "upload" --lease-id="$1" "$2"
	;;
remove)
	test $# -gt 0 || die "'remove' requires arguments"
	ret=0
	for file
	do
		req "$action" "$file" || ret=1
	done
	exit $ret
	;;
lock)
	req "$action" "$@"
	;;
unlock)
	test $# = 2 || die "'unlock' requires two parameters: <leaseID> <file>"
	req "$action" "$@"
	;;
add-snapshot)
	commit=
	case "$1" in
	--commit=*) commit="${1#*=}"; shift;;
	esac
	test $# = 1 || die "add_snapshot requires one parameter: <version>"
	version="$1"
	case "$commit,$version" in
	*" "*|*"	"*)
		die "There cannot be any whitespace in the version parameter"
		;;
	,*.g[a-f0-9]*)
		commit="${version##*.g}"
		;;
	,*)
		commit="$(git rev-parse --verify refs/tags/"$version")" ||
		die "Could not determine commit from version '$version'"
		;;
	esac

	if git rev-parse --verify -q 10ca1f73c11475e222 2>/dev/null
	then
		git_checkout=.
	else
		git_checkout=/usr/src/git
	fi
	test -d "$git_checkout" || git_checkout="$HOME/git"
	test -d "$git_checkout" || die "Could not find Git repository"
	git -C "$git_checkout" rev-parse --verify -q "$commit" ||
	die "No commit '$commit' in '$git_checkout'"
	date="$(git -C "$git_checkout" show -s --format=%cD "$commit")"
	h2_id="$(TZ=GMT date --date="$date" +%Y-%m-%d-%H:%M:%S)"

	add_snapshot "$version" "$date" "$h2_id" "$commit"
	;;
*)
	die "Unhandled action: '$action'"
	;;
esac

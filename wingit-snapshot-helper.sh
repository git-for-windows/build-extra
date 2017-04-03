#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

test $# -ge 4 ||
die "usage: ${0##*/} <storage-account-name> <container-name> <access-key> ( list | upload <file>...)"

storage_account="$1"; shift
container_name="$1"; shift
access_key="$1"; shift

req () {
	file=
	x_ms_blob_type=
	content_length=
	content_length_header=
	content_type=
	resource_trailer=
	get_parameters=
	string_to_sign_extra=
	case "$1" in
	upload)
		file="$2"
		test -f "$file" || {
			echo "File does not exist: '$file'" >&2
			return 1
		}

		resource_extra=/"${file##*/}"

		request_method="PUT"
		x_ms_blob_type="x-ms-blob-type:BlockBlob"
		content_length="$(stat -c %s "$file")"
		content_length_header="Content-Length: $content_length"
		content_type="application/x-www-form-urlencoded"
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

	blob_store_url="blob.core.windows.net"
	authorization="SharedKey"

	request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
	storage_service_version="2016-05-31"

	# HTTP Request headers
	x_ms_date_h="x-ms-date:$request_date"
	x_ms_version_h="x-ms-version:$storage_service_version"

	# Build the signature string
	canonicalized_headers="${x_ms_blob_type:+$x_ms_blob_type\n}$x_ms_date_h\n$x_ms_version_h"
	canonicalized_resource="/$storage_account/$container_name$resource_extra"

	string_to_sign="$request_method\n\n\n$content_length\n\n$content_type\n\n\n\n\n\n\n$canonicalized_headers\n$canonicalized_resource$string_to_sign_extra"

	# Decode the Base64 encoded access key, convert to Hex.
	decoded_hex_key="$(printf %s "$access_key" | base64 -d -w0 | xxd -p -c256)"

	# Create the HMAC signature for the Authorization header
	signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary |  base64 -w0)
	authorization_header="Authorization: $authorization $storage_account:$signature"

	{
		test -z "$x_ms_blob_type" || echo "-H \"$x_ms_blob_type\""
		echo "-H \"$x_ms_date_h\""
		echo "-H \"$x_ms_version_h\""
		test -z "$content_length_header" ||
		echo "-H \"$content_length_header\""
		echo "-H \"$authorization_header\""
		echo "-X$request_method"
		test -z "$file" || echo "--data-binary \"@$file\""
	} |
	curl -i -K - \
	  "https://$storage_account.$blob_store_url/$container_name$resource_extra$get_parameters"
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
*)
	die "Unhandled action: '$action'"
	;;
esac

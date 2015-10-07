#!/bin/sh

die () {
	echo "$*" >&2
	exit 1
}

form_param=
type=
case "$#,$1" in
1,http://*|1,https://*)
	form_param=url="$1"
	type=url
	;;
1,*)
	test -f "$1" ||
	die "No such file: $1"
	form_param=file="@$1"
	type=file
	;;
*)
	die "Usage: $0 <file> | <url>"
	;;
esac

apikey=$(sed -n '/^machine api.virustotal.com$/,/^password/s/^password //p' \
	<$HOME/_netrc)
test -n "$apikey" ||
die "No API key found for api.virustotal.com in $HOME/_netrc"

response="$(curl --form apikey="$apikey" --form "$form_param" -i -L -X POST -0 \
	https://www.virustotal.com/vtapi/v2/$type/scan)" ||
die "Error: $response"

test -z "$SHOW_HEADER" ||
printf "Header:\n%s\n" "$(echo "$response" | sed '/^$/q')"

extract_json () {
	echo "$1" | sed -n 's/.*"'"$2"'": *"\([^"]*\).*/\1/p'
}

extract_json "$response" verbose_msg >&2

start "$(extract_json "$response" permalink)"

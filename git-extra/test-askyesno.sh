#!/bin/sh

test $# = 2 || {
	echo "Usage: $0 <git-askyesno.exe> <test-askyesno.exe>" >&2
	exit 1
}
prompt=$1
helper=$2
directory=$(mktemp -d "${TMPDIR:-/tmp}/test-askyesno.XXXXXX") || exit 1
sequence=0

die () {
	echo "$*" >&2
	exit 1
}

cleanup () {
	result=$?
	trap - 0
	for file in "$directory"/*.pid
	do
		if test -s "$file"
		then
			read -r pid job <"$file" &&
			"$helper" kill "$job" || result=1
		fi
		rm -f "$file" || result=1
	done
	wait
	rmdir "$directory" || result=1
	exit "$result"
}
trap cleanup 0
trap 'exit 1' 1 2 3 15

start_prompt () {
	sequence=$((sequence + 1))
	file=$directory/$sequence.pid
	"$helper" run "$prompt" "$@" >"$file" &
	runner=$!
	attempt=0
	while ! test -s "$file"
	do
		attempt=$((attempt + 1))
		test "$attempt" -lt 100 || die "Could not read test prompt PID"
		sleep 0.05
	done
	read -r pid job <"$file" || die "Could not read test prompt PID"
}

finish () {
	wait "$1"
	status=$?
	rm -f "$2" || die "Could not remove test PID file"
	test "$status" = "$3" || die "Expected exit $3, got $status"
}

title="git askyesno ${directory##*/}"
mutex="Local\\GitAskYesNo.${directory##*/}"

start_prompt --title "$title" "Test prompt"
first_pid=$pid first_runner=$runner first_file=$file
"$helper" wait "$first_pid" || die "First legacy dialog did not open"
start_prompt --title "$title" "Test prompt"
"$helper" wait "$pid" &&
"$helper" close "$pid" &&
"$helper" close "$first_pid" || die "Legacy dialogs did not remain independent"
finish "$runner" "$file" 1
finish "$first_runner" "$first_file" 1
echo "PASS: legacy callers can show independent dialogs"

start_prompt --title "$title" --title "literal title" "literal question"
text=$("$helper" text "$pid") || die "Could not read legacy dialog"
test "$text" = "$title
--title literal title literal question" || die "Repeated --title changed the legacy question"
"$helper" close "$pid" || die "Could not close legacy dialog"
finish "$runner" "$file" 1
echo "PASS: a repeated --title remains part of the legacy question"

start_prompt --title "$title" --mutex "$mutex" "Test prompt"
first_pid=$pid first_runner=$runner first_file=$file
"$helper" wait "$first_pid" || die "Original guarded dialog did not open"
start_prompt --mutex "$mutex" --title "$title" "Test prompt"
finish "$runner" "$file" 2
"$helper" wait "$first_pid" || die "Duplicate closed the original dialog"
echo "PASS: a duplicate returns 2 and leaves the original dialog open"

start_prompt --title "$title" --mutex "$mutex.Other" "Test prompt"
"$helper" close "$pid" || die "A distinct mutex suppressed the dialog"
finish "$runner" "$file" 1
"$helper" close "$first_pid" || die "Could not close original dialog"
finish "$first_runner" "$first_file" 1
echo "PASS: different mutex names do not suppress each other"

start_prompt --title "$title" --mutex "$mutex" "Test prompt"
"$helper" close "$pid" || die "A closed dialog left a stale mutex"
finish "$runner" "$file" 1
echo "PASS: the mutex disappears after the original prompt closes"

start_prompt --title "$title" --mutex "$mutex" "Test prompt"
"$helper" wait "$pid" &&
"$helper" kill "$job" || die "Could not terminate test prompt"
finish "$runner" "$file" 99
start_prompt --title "$title" --mutex "$mutex" "Test prompt"
"$helper" yes "$pid" || die "A terminated dialog left a stale mutex"
finish "$runner" "$file" 0
echo "PASS: process termination leaves no stale mutex and Yes returns 0"

start_prompt --title "$title" --mutex "$mutex\\invalid" "Test prompt"
text=$("$helper" text "$pid") || die "Could not read mutex error"
printf '%s\n' "$text" |
grep -x 'Could not create prompt mutex (error [1-9][0-9]*)' ||
die "The mutex error dialog did not report a Windows error code"
"$helper" close "$pid" || die "Could not dismiss mutex error"
finish "$runner" "$file" 3
echo "PASS: a mutex error reports its Windows error code and returns 3"

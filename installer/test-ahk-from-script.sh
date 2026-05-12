#!/bin/sh
# Minimal reproduction of how run-checklist.sh invokes AHK
set -ex

ahk_exe="$(command -v AutoHotkey64.exe)"
test -n "$ahk_exe" || { echo "AutoHotkey64.exe not found" >&2; exit 1; }

script_dir="$(cd "$(dirname "$0")/ui-tests" && pwd)"
ahk_script="$(cygpath -aw "$script_dir/test-hello.ahk")"

echo "ahk_exe=$ahk_exe"
echo "ahk_script=$ahk_script"

exit_code_file="$(mktemp)"
{
	MSYS2_ARG_CONV_EXCL='*' \
	"$ahk_exe" /ErrorStdOut /force "$ahk_script"
	echo $? >"$exit_code_file"
} | tee "$script_dir/test-hello.log"
ahk_exit="$(cat "$exit_code_file")"
rm -f "$exit_code_file"
echo "ahk_exit=$ahk_exit"
echo "log contents: $(cat "$script_dir/test-hello.log")"
test 0 = "$ahk_exit"

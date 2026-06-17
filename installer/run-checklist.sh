#!/bin/sh

set -ex

curl --version | grep IPv6

! x="$(git -c http.sslbackend=123 ls-remote https://github.com/dscho/images 2>&1)" &&
case "$x" in
*openssl*schannel*|*schannel*openssl*) ;;
*) type libcurl-openssl-4.dll || exit 1;;
esac

git -c http.sslbackend=schannel ls-remote https://github.com/dscho/images
git -c http.sslbackend=openssl ls-remote https://github.com/dscho/images ||
# support for http.sslBackend was introduced in v2.13.1, but it requires
# mingw-w64-curl, whereas Git for Windows v2.41.0 switched to the combination
# of mingw-w64-curl-winssl and mingw-w64-curl-openssl-alternate (which earlier
# `git.exe` versions cannot handle)
case "$(git version)" in *2.40.*|*2.[123][0-9].*) true;; *) exit 123;; esac

git ls-remote git@ssh.dev.azure.com:v3/git-for-windows/git/git main

die () {
	echo "$*" >&2
	exit 1
}

pcon_choice="$(sed -n 's/^Enable Pseudo Console Support: //p' /etc/install-options.txt)" ||
die 'Could not read /etc/install-options.txt'

if test -n "$pcon_choice"
then
	pcon_config="$(cat /etc/git-bash.config)" ||
	die 'Could not read /etc/git-bash.config'

	case "$pcon_choice" in
	Enabled)
		test "MSYS=enable_pcon" = "$pcon_config" ||
		die "Expected enable_pcon in git-bash.config, but got '$pcon_config'"
		;;
	Disabled)
		test "MSYS=disable_pcon" = "$pcon_config" ||
		die "Expected disable_pcon in git-bash.config, but got '$pcon_config'"
		;;
	*)
		die "Unexpected Pseudo Console choice: $pcon_choice"
		;;
	esac
fi

# Check HTML docs for raw linkgit: macros that should have been
# converted to hyperlinks during the AsciiDoc build.
doc_dir="$(git --exec-path)/../../share/doc/git-doc"
# These matches are known to have linkgit: inside literal blocks
# (<pre> in the HTML) where AsciiDoc/Asciidoctor does not expand
# macros. The source text is either indented (which AsciiDoc treats
# as a literal paragraph) or inside an explicit .... block. See
# commits b3ac6e737db8 and 399694384bf9 in git/git for similar fixes.
unexpected="$(find "$doc_dir" -name '*.html' -print0 |
	xargs -0r grep -n 'linkgit:' |
	grep -v \
		-e 'gitformat-commit-graph\.html:561:' \
		-e 'gitformat-index\.html:718:' \
		-e 'gitformat-pack\.html:1058:' \
		-e 'MyFirstContribution\.html:1113:')" || true
test -z "$unexpected" ||
die "Unexpected linkgit: macros:
$unexpected"

# Verify that git help git opens the correct page by using a fake
# browser command that writes the URL to a file.
url_file="/tmp/git-help-url-$$"
rm -f "$url_file"
git -c "browser.fake.cmd=echo >$url_file" \
    -c help.browser=fake \
    help git
test -s "$url_file" ||
die 'git help git did not invoke the fake browser'
url="$(cat "$url_file")"
rm -f "$url_file"
case "$url" in
*git.html) ;;
*) die "git help git opened wrong page: $url";;
esac

# If the prerequisites for the UI tests are met (AutoHotkey in PATH
# and ~/.minttyrc has the required settings), run them. Otherwise
# just print an informational message.
ahk_exe=
for name in AutoHotkey64.exe AutoHotkey32.exe AutoHotkey.exe
do
	ahk_exe="$(command -v "$name" 2>/dev/null)" && break
done
if test -z "$ahk_exe"
then
	echo "NOTE: AutoHotkey not found in PATH; skipping UI tests." >&2
	echo "See installer/checklist.txt for manual verification steps." >&2
elif ! grep -q '^KeyFunctions=.*export-html' ~/.minttyrc 2>/dev/null ||
     ! grep -q '^SaveFilename=' ~/.minttyrc 2>/dev/null
then
	echo "NOTE: ~/.minttyrc is missing KeyFunctions or SaveFilename;" >&2
	echo "skipping UI tests. To enable them, add these lines:" >&2
	echo "  KeyFunctions=C+F5:export-html" >&2
	echo "  SaveFilename=/tmp/mintty-export" >&2
	echo "See installer/checklist.txt for manual verification steps." >&2
else
	echo "Running UI tests via AutoHotkey ($ahk_exe)..." >&2
	ui_tests_dir="$(cd "$(dirname "$0")/ui-tests" && pwd)"

	# Smoke-test: verify AHK can produce stdout output in this context.
	hello_script="$(cygpath -aw "$ui_tests_dir/test-hello.ahk")"
	echo "Smoke-testing AHK stdout..." >&2
	{
		MSYS2_ARG_CONV_EXCL='*' \
		"$ahk_exe" /ErrorStdOut /force "$hello_script"
	} | cat
	echo "Smoke test done (exit $?)" >&2

	# MSYS2_ARG_CONV_EXCL prevents MSYS2 from converting /ErrorStdOut
	# to a Unix path. The pipe to tee gives AHK a valid stdout handle
	# (without a pipe, MSYS2 bash does not provide one to native
	# Windows processes, causing FileAppend to stdout to fail silently).
	ahk_script="$(cygpath -aw "$ui_tests_dir/git-bash-checklist.ahk")"
	exit_code_file="$(mktemp)"
	{
		MSYS2_ARG_CONV_EXCL='*' \
		"$ahk_exe" /ErrorStdOut /force "$ahk_script"
		echo $? >"$exit_code_file"
	} | tee "$ui_tests_dir/git-bash-checklist-stdout.log"
	ahk_exit="$(cat "$exit_code_file")"
	rm -f "$exit_code_file"
	test 0 = "$ahk_exit" ||
	die "UI tests failed (exit code $ahk_exit)"
fi

echo "All checks passed!" >&2

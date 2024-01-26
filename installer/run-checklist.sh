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

echo "All checks passed!" >&2

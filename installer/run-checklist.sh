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

echo "All checks passed!" >&2

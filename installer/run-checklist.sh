#!/bin/sh

set -ex

curl --version | grep IPv6

! x="$(git -c http.sslbackend=schannel2 ls-remote https://github.com/dscho/images 2>&1)" &&
case "$x" in *openssl*schannel*|*schannel*openssl*) ;; *) exit 1;; esac

git -c http.sslbackend=schannel ls-remote https://github.com/dscho/images
git -c http.sslbackend=openssl ls-remote https://github.com/dscho/images

git ls-remote git@ssh.dev.azure.com:v3/git-for-windows/git/git main

#!/bin/sh

# This helper is intended to be used in the Azure Pipelines that build
# Pacman packages containing code-signed executables.
#
# It expects the private key in PKCS12 format in ~/.sig/codesign.p12 and
# the corresponding password in ~/.sig/codesign.pass.

type osslsigncode >/dev/null 2>&1 || {
	echo "Could not find osslsigncode.exe in the PATH" >&2
	exit 1
}

s () {
	osslsigncode.exe sign \
		-pkcs12 "$HOME/.sig/codesign.p12" \
		-readpass "$HOME/.sig/codesign.pass" \
		-ts http://timestamp.comodoca.com?td=sha256 \
		-n "Git for Windows" \
		-h sha256 "$1" "$1.signed.exe" &&
	mv -f "$1.signed.exe" "$1"
}

for f in "$@"
do
	s "$f" || {
		echo "Giving timestamp host some time..." >&2
		sleep 5 && s "$f"
	} || exit
done

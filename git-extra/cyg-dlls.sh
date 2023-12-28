#!/usr/bin/bash
#
#   cyg-dlls.sh - Disallow `cyg*.dll` files
#
# These files are produced when MSYS packages are built incorrectly as Cygwin
# packages.

[[ -n "$LIBMAKEPKG_LINT_PACKAGE_CYG_DLLS_SH" ]] && return
LIBMAKEPKG_LINT_PACKAGE_CYG_DLLS_SH=1

lint_package_functions+=('cyg_dlls')

cyg_dlls() {
	local cyg_dlls="$(find "${pkgdir}" -type f -name cyg\*.dll)"
	test -n "$cyg_dlls" || return 0
	printf "%s\n" >&2 "Unexpected cyg*.dll detected:" "$cyg_dlls"
	return 1
}

#!/bin/sh

# This helper supports the Azure Pipelines that build and GPG-sign commits
# and files. The idea is to configure `gpg.program` to point to the absolute
# path of this script.
#
# To do so, it expects the relevant information starting with the GPG key's
# fingerprint in the environment variable `GPGKEY` (this should be configured
# using secret variables, of course).

case "$1" in
--status-fd=*)
	status_fd="$1"
	arg1="$2"
	;;
*)
	status_fd=
	arg1="$1"
	;;
esac

case "$arg1" in
-bsau)
	eval gpg --batch --yes --no-tty --pinentry-mode loopback $status_fd -bsau $GPGKEY
	;;
--detach-sign)
	case "$*" in
	*"$GPGKEY"*)
		eval gpg --batch --yes --no-tty --pinentry-mode loopback "$@"
		;;
	*)
		eval gpg --batch --yes --no-tty --pinentry-mode loopback -u $GPGKEY "$@"
		;;
	esac
	;;
*)
	gpg --batch --yes --no-tty --pinentry-mode loopback -bsau "$@"
	;;
esac

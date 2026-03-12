# Common helpers for release scripts.
# Source this file; it consumes the shared command-line flags and
# leaves the remaining positional parameters (optional components) in "$@".
#
# After sourcing, the following variables are set:
#   output_directory, include_pdbs, VERSION,
#   BITNESS, ARCH, MD_ARG, MINGW_PREFIX, MSYSTEM_LOWER, SCRIPT_PATH
#
# The following functions are available:
#   die, prepare_root, init_etc_gitconfig,
#   generate_file_list, copy_dlls_to_libexec, unpack_pdbs

die () {
	echo "$*" >&1
	exit 1
}

output_directory="$HOME"
include_pdbs=
while test $# -gt 0
do
	case "$1" in
	--output)
		shift
		output_directory="$1"
		;;
	--output=*)
		output_directory="${1#*=}"
		;;
	--include-pdbs)
		include_pdbs=t
		;;
	-*)
		die "Unknown option: $1"
		;;
	*)
		break
	esac
	shift
done

test $# -gt 0 ||
die "Usage: $0 [--output=<directory>] <version> [optional components]"

test -d "$output_directory" ||
die "Directory inaccessible: '$output_directory'"

case "$MSYSTEM" in
MINGW32)
	BITNESS=32
	ARCH=i686
	MD_ARG=128M
	MINGW_PREFIX=mingw-w64-i686-
	;;
MINGW64)
	BITNESS=64
	ARCH=x86_64
	MD_ARG=256M
	MINGW_PREFIX=mingw-w64-x86_64-
	;;
CLANGARM64)
	BITNESS=64
	ARCH=aarch64
	MD_ARG=256M
	MINGW_PREFIX=mingw-w64-clang-aarch64-
	;;
*)
	die "Unhandled MSYSTEM: $MSYSTEM"
	;;
esac
MSYSTEM_LOWER=${MSYSTEM,,}
VERSION=$1
shift

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

case "$SCRIPT_PATH" in
*" "*)
	die "This script cannot handle spaces in $SCRIPT_PATH"
	;;
esac

# Set up the root directory with common files and redirectors.
prepare_root () {
	mkdir -p "$SCRIPT_PATH/root/" ||
	die "Could not make root"

	cp "$SCRIPT_PATH/../LICENSE.txt" "$SCRIPT_PATH/root/" ||
	die "Could not copy license file"

	mkdir -p "$SCRIPT_PATH/root/dev/mqueue" ||
	die "Could not make /dev/mqueue directory"

	mkdir -p "$SCRIPT_PATH/root/dev/shm" ||
	die "Could not make /dev/shm/ directory"

	mkdir -p "$SCRIPT_PATH/root/etc" ||
	die "Could not make etc/ directory"

	mkdir -p "$SCRIPT_PATH/root/tmp" ||
	die "Could not make tmp/ directory"

	mkdir -p "$SCRIPT_PATH/root/bin" ||
	die "Could not make bin/ directory"

	cp /cmd/git.exe "$SCRIPT_PATH/root/bin/git.exe" &&
	cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/bash.exe" &&
	cp /$MSYSTEM_LOWER/share/git/compat-bash.exe "$SCRIPT_PATH/root/bin/sh.exe" ||
	die "Could not install bin/ redirectors"
}

# Detect the system gitconfig path.
# Sets: etc_gitconfig
init_etc_gitconfig () {
	etc_gitconfig="$(git -c core.editor=echo config --system -e 2>/dev/null)" &&
	etc_gitconfig="$(cygpath -au "$etc_gitconfig")" &&
	etc_gitconfig="${etc_gitconfig#/}" ||
	die "Could not determine the path of the system config"
}

# Generate the file list and configure the system gitconfig.
# Pass any optional components as arguments.
# Sets: LIST
generate_file_list () {
	LIST="$(ARCH=$ARCH ETC_GITCONFIG="$etc_gitconfig" \
		PACKAGE_VERSIONS_FILE="$SCRIPT_PATH"/root/etc/package-versions.txt \
		sh "$SCRIPT_PATH"/../make-file-list.sh "$@" |
		grep -v "^$etc_gitconfig$")" ||
	die "Could not generate file list"

	mkdir -p "$SCRIPT_PATH/root/${etc_gitconfig%/*}" &&
	cp /"$etc_gitconfig" "$SCRIPT_PATH/root/$etc_gitconfig" &&
	git config -f "$SCRIPT_PATH/root/$etc_gitconfig" \
		credential.helper manager ||
	die "Could not configure Git-Credential-Manager as default"
	test 64 != $BITNESS ||
	git config -f "$SCRIPT_PATH/root/$etc_gitconfig" --unset pack.packSizeLimit
	git config -f "$SCRIPT_PATH/root/$etc_gitconfig" core.fscache true

	case "$LIST" in
	*/git-credential-helper-selector.exe*)
		git config -f "$SCRIPT_PATH/root/$etc_gitconfig" \
			credential.helper helper-selector
		;;
	esac
}

# Copy DLL files into libexec/git-core for runtime.
copy_dlls_to_libexec () {
	git_core="$SCRIPT_PATH/root/$MSYSTEM_LOWER/libexec/git-core" &&
	rm -rf "$git_core" &&
	mkdir -p "$git_core" &&
	if test "$(stat -c %D /$MSYSTEM_LOWER/bin)" = "$(stat -c %D "$git_core")"
	then
		ln_or_cp=ln
	else
		ln_or_cp=cp
	fi &&
	$ln_or_cp $(echo "$LIST" | sed -n "s|^$MSYSTEM_LOWER/bin/[^/]*\.dll$|/&|p") "$git_core" ||
	die "Could not copy .dll files into libexec/git-core/"
}

# Unpack PDB files if --include-pdbs was given.
unpack_pdbs () {
	test -z "$include_pdbs" || {
		find "$SCRIPT_PATH/root" -name \*.pdb -exec rm {} \; &&
		"$SCRIPT_PATH"/../please.sh bundle-pdbs \
			--arch=$ARCH --unpack="$SCRIPT_PATH"/root
	} ||
	die "Could not unpack .pdb files"
}

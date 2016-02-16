#!/bin/sh

# The purpose of this script is to gather all of the source code for a
# specific Git for Windows release, fulfilling the obligation under the
# GPL to provide it when distributing binaries.

die () {
	echo "$*" >&2
	exit 1
}

test $# = 1 ||
die "Usage: $0 <package-versions>"

msys_source_url=http://repo.msys2.org/msys/sources
mingw_source_url=http://repo.msys2.org/mingw/sources
sf_repos_url=http://sourceforge.net/projects/msys2/files/REPOS
msys_sf_source_url=$sf_repos_url/MSYS2/Sources
mingw_sf_source_url=$sf_repos_url/MINGW/Sources
bintray_source_url=https://dl.bintray.com/git-for-windows/pacman/sources

cd "$(dirname "$0")" ||
die "Could not change directory to build-extra/"

dir=cached-source-packages
mkdir -p "$dir" ||
die "Could not make the cache directory"

ref=refs/heads/all-sources
commit="$(git rev-parse --verify $ref 2>/dev/null)"
GIT_INDEX_FILE=.git/tmp-index
export GIT_INDEX_FILE
rm -f $GIT_INDEX_FILE

cat "$1" |
while read name version
do
	case "$name" in
	gcc-libs|heimdal-libs|mingw-w64-*-gcc-libs)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=${name%-libs}
		;;
	libcrypt|libdb|libpcre|libreadline|libserf|libsqlite)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=${name#lib}
		;;
	libintl)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=gettext
		;;
	libsasl)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=cyrus-sasl
		;;
	mingw-w64-*-libwinpthread-git)
		# built as secondary package (see MINGW-packages/*/PKGBUILD)
		name=$(echo $name | sed 's/libwinpthread/winpthreads/')
		;;
	mingw-w64-*-git-doc-html)
		# built as secondary package (see MINGW-packages/*/PKGBUILD)
		name=${name%-doc-html}
		;;
	esac

	# Work around mismatched version uploaded in MSYS2
	case $name-$version in
	dash-0.5.8-1) version=0.5.8-2;;
	mingw-w64-*-antiword-0.37-2) version=0.37-1;;
	esac

	# Already merged?
	test -z "$(git ls-files $name/.SRCINFO)" ||
	continue

	w64=${name#mingw-w64-x86_64-}
	w64=${w64#mingw-w64-i686-}

	if test "$name" != "$w64"
	then
		filename=mingw-w64-$w64-$version.src.tar.gz
	else
		filename=$name-$version.src.tar.gz
	fi

	if test ! -f "$dir/$filename"
	then

		case "$name" in
		git-extra|mingw-w64-x86_64-git|mingw-w64-i686-git|mintty|msys2-runtime)
			url="$bintray_source_url/$filename"
			sf1_url=
			sf2_url=
			;;
		mingw-w64-*)
			url=$mingw_source_url/$filename
			sf1_url=$mingw_sf_source_url/$filename/download
			sf2_url=$mingw_sf_source_url/$name-$version.src.tar.gz/download
			;;
		*)
			if test ! -d /usr/src/MSYS2-packages/$name
			then
				name2="$(cd /usr/src/MSYS2-packages/ &&
					grep -l "^pkgname=.*[ '\")]$name[ '\")]" \
						*/PKGBUILD |
					sed 's|/PKGBUILD$||')"
				case "$name2" in
				'')
					die "Unknown origin: $name"
					;;
				*' '*)
					die "Multiple origins of $name: $name2"
					;;
				esac
				grep "^$name2 $version$" <"$1" >/dev/null ||
				die "Package $name2 (origin of $name) not in $1!"
				continue
			fi

			url="$msys_source_url/$filename"
			sf1_url="$msys_sf_source_url/$filename/download"
			sf2_url=
			;;
		esac

		echo "Downloading $url"
		curl -sfLo "$dir/$filename" "$url" ||
		curl -sfLo "$dir/$filename" "$sf1_url" ||
		curl -sfLo "$dir/$filename" "$sf2_url" ||
		die "Could not download $filename from $url ($sf1_url $sf2_url)" >&2

		test -s "$dir/$filename" ||
		die "Empty file: $dir/$filename"
	fi

	/usr/src/git/contrib/fast-import/import-tars.perl "$dir/$filename" ||
	die "Could not import $dir/$filename"

	echo "Merging sources for $name $version"
	git read-tree --prefix=$name/ refs/heads/import-tars &&
	tree="$(git write-tree)" &&
	commit2="$(git commit-tree -m "Import sources for $name $version" \
		${commit:+-p} $commit "$tree")" &&
	git update-ref -m "Import $name $version" $ref $commit2 $commit &&
	commit=$commit2 &&
	git update-ref -m "Clean up" -d refs/heads/import-tars ||
	die "Could not merge sources for $name $version"
done


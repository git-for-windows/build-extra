#!/bin/sh

# The purpose of this script is to gather all of the source code for a
# specific Git for Windows release, fulfilling the obligation under the
# GPL to provide it when distributing binaries.

die () {
	echo "$*" >&2
	exit 1
}

mingit=
case "$1" in
--mingit)
	shift
	mingit=t
	;;
esac

test $# = 1 ||
die "Usage: $0 [--mingit] <package-versions>"

test -d /usr/src/MSYS2-packages/git ||
die "Need to run this in an SDK"

msys_source_url=http://repo.msys2.org/msys/sources
mingw_source_url=http://repo.msys2.org/mingw/sources
sf_repos_url=http://sourceforge.net/projects/msys2/files/REPOS
msys_sf_source_url=$sf_repos_url/MSYS2/Sources
mingw_sf_source_url=$sf_repos_url/MINGW/Sources
azure_blobs_source_url=https://wingit.blob.core.windows.net/sources

cd "$(dirname "$0")" ||
die "Could not change directory to build-extra/"

test -f "$1" ||
die "File not found (use absolute path?): $1"

dir=cached-source-packages
mkdir -p "$dir" ||
die "Could not make the cache directory"

if test -n "$mingit"
then
	zipdir=source-zips-mingit
	rm -rf $zipdir &&
	mkdir $zipdir ||
	die "Could not make $zipdir"
	zipprev=source-zips
else
	zipdir=source-zips
	zipprev=$zipdir.previous
	rm -rf $zipprev
	test ! -d $zipdir ||
	mv $zipdir $zipprev
	mkdir $zipdir
fi

tar2zip () {
	unpackdir=$dir/.unpack &&
	rm -rf $unpackdir &&
	mkdir $unpackdir &&
	(cd $unpackdir && tar xzf -) <"$1" &&
	(cd $unpackdir/* &&
	 CARCH=x86_64 MSBUILD_DIR=. \
	 bash -c 'source PKGBUILD &&
		repo= &&
		case "${source[0]}" in
		*::git*)
			repo="${source[0]%%::*}" &&
			trailer="${source[0]##*#}" &&
			case "$trailer" in
			tag=*) rev=refs/tags/${trailer#tag=};;
			branch=*) rev=refs/heads/${trailer#branch=};;
			commit=*) rev=${trailer#commit=};;
			"${source[0]}") rev=HEAD;;
			*) echo "Unhandled trailer: $trailer" >&2; exit 1;;
			esac &&
			if test HEAD = $rev
			then
				zip=$repo.zip
			else
				zip=$repo-${rev##*/}.zip
			fi &&
			sed -i -e "s/^source=[^)]*/source=(\"$zip\"/" \
			    -e "s/^\( *\)git am \(--[^ ]* \)\?/\1patch -p1 </" \
			    PKGBUILD
			;;
		http:*|https:*)
			sed -i "s/^\(source=(.\).*\/\([^)]*\)/\1\2/" PKGBUILD
			;;
		esac &&
		case "${source[1]}" in
		git+https:*.git)
			test -z "$repo" || {
				echo "Cannot handle *two* Git repos" >&2
				exit 1
			} &&
			repo="${source[1]##*/}" &&
			repo="${repo%.git}" &&
			rev=HEAD &&
			zip=$repo.zip &&
			sed -i -e "s/git+https:.*$repo.git/$repo.zip/" \
			    -e "s/^\( *\)git am \(--[^ ]* \)\?/\1patch -p1 </" \
			    PKGBUILD

			;;
		esac &&
		if test -n "$repo"
		then
			echo "Converting $repo to $zip" &&
			if test git = $repo &&
				! git -C $repo rev-parse -q --verify $rev
			then
				git -C "$repo" fetch origin $rev:$rev
			fi &&
			git -C "$repo" archive --prefix="$repo/" --format=zip \
				"$rev" >"$zip" &&
			rm -rf "$repo"
		fi') &&
	(cd $unpackdir && zip -9qr - .) >"$2" ||
	die "Could not transmogrify $1 to $2"
}

cat "$1" |
while read name version
do
	case "$name" in
	gcc-libs|heimdal-libs|mingw-w64-*-gcc-libs)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=${name%-libs}
		;;
	mingw-w64-*-gcc-libgfortran)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=${name%-*}
		;;
	libdb|libpcre|libreadline|libserf|libsqlite)
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
	libpcre2_8)
		# built as a secondary package (see MSYS2-packages/*/PKGBUILD)
		name=pcre2
		;;
	mingw-w64-*-libwinpthread-git)
		# built as secondary package (see MINGW-packages/*/PKGBUILD)
		name=$(echo $name | sed 's/libwinpthread/winpthreads/')
		;;
	mingw-w64-*-git-doc-html)
		# built as secondary package (see MINGW-packages/*/PKGBUILD)
		name=${name%-doc-html}
		;;
	libcrypt)
		# before https://github.com/msys2/MSYS2-packages/commit/a58271b3957
		# the package was called crypt
		test "$version" != 2.1-1 ||
		name=crypt
		;;
	libnghttp2)
		# built as secondary package (see MSYS2-packages/*/PKGBUILD)
		name=nghttp2
		;;
	esac

	# Work around mismatched version uploaded in MSYS2/Git for Windows
	case $name-$version in
	dash-0.5.8-1) version=0.5.8-2;;
	mingw-w64-*-antiword-0.37-2) version=0.37-1;;
	mingw-w64-*-curl-7.55.0-2) version=7.55.0-1;;
	esac

	zipname=$name-$version.zip

	# Already copied?
	test ! -f $zipdir/$zipname ||
	continue

	# Already transformed?
	test ! -f $zipprev/$zipname ||
	if test -n "$mingit"
	then
		echo "Copying $zipname..." >&2
		cp $zipprev/$zipname $zipdir/ ||
		die "Could not copy zip: $zipprev/$zipname"
		continue
	else
		mv $zipprev/$zipname $zipdir/ ||
		die "Could not move previous zip: $zipprev/$zipname"
		continue
	fi

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
		git-extra|mingw-w64-x86_64-git|mingw-w64-i686-git|msys2-runtime|mingw-w64-x86_64-git-credential-manager|mingw-w64-i686-git-credential-manager|mingw-w64-x86_64-git-credential-manager-core|mingw-w64-i686-git-credential-manager-core|mingw-w64-i686-git-lfs|mingw-w64-x86_64-git-lfs|curl|mingw-w64-i686-curl|mingw-w64-x86_64-curl|mingw-w64-i686-wintoast|mingw-w64-x86_64-wintoast|bash|heimdal|perl|openssh)
			url="$azure_blobs_source_url/$filename"
			sf1_url=
			sf2_url=
			sf3_url=
			;;
		mingw-w64-*)
			url=$mingw_source_url/$filename
			sf1_url=$mingw_sf_source_url/$filename/download
			sf2_url=$mingw_sf_source_url/$name-$version.src.tar.gz/download
			sf3_url="$azure_blobs_source_url/$filename"
			;;
		*)
			if test crypt != $name && test perl-Clone != $name &&
				test ! -d /usr/src/MSYS2-packages/$name
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

				# "real" package already in packages-versions?
				! grep "^$name2 $version$" <"$1" >/dev/null ||
				continue

				filename=$name2-$version.src.tar.gz
				zipname=$name2-$version.zip

				# Already transformed?
				test ! -f $zipprev/$zipname ||
				if test -n "$mingit"
				then
					echo "Copying $zipname..." >&2
					cp $zipprev/$zipname $zipdir/ ||
					die "Could not copy zip: $zipprev/$zipname"
					continue
				else
					mv $zipprev/$zipname $zipdir/ ||
					die "Could not move previous zip: $zipprev/$zipname"
					continue
				fi
			fi

			url="$msys_source_url/$filename"
			sf1_url="$msys_sf_source_url/$filename/download"
			sf2_url="$azure_blobs_source_url/$filename"
			sf3_url=
			;;
		esac

		echo "Downloading $url"
		test -s "$dir/$filename" ||
		curl -sfLo "$dir/$filename" "$url" ||
		curl -sfLo "$dir/$filename" "$sf1_url" ||
		curl -sfLo "$dir/$filename" "$sf2_url" ||
		curl -sfLo "$dir/$filename" "$sf3_url" ||
		die "Could not download $filename from $url ($sf1_url $sf2_url $sf3_url)" >&2

		test -s "$dir/$filename" ||
		die "Empty file: $dir/$filename"
	fi

	echo "Converting $filename to $zipname"
	tar2zip "$dir/$filename" "$zipdir/$zipname" ||
	die "Could not transform $dir/$filename"
done

echo "Sources are in $zipdir/"

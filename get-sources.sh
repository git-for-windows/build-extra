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
bintray_source_url=https://dl.bintray.com/git-for-windows/pacman/sources

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
		git-extra|mingw-w64-x86_64-git|mingw-w64-i686-git|msys2-runtime|mingw-w64-x86_64-git-credential-manager|mingw-w64-i686-git-credential-manager|mingw-w64-i686-git-lfs|mingw-w64-x86_64-git-lfs|mingw-w64-i686-curl-winssl-bin|mingw-w64-x86_64-curl-winssl-bin)
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
			sf2_url="$bintray_source_url/$filename"
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

	echo "Converting $filename to $zipname"
	tar2zip "$dir/$filename" "$zipdir/$zipname" ||
	die "Could not transform $dir/$filename"
done

echo "Sources are in $zipdir/"

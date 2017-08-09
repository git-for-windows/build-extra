#!/bin/sh

# This script helps Git for Windows developers to manage their Pacman
# repository and their local pacman package-database.
#
# A Pacman repository is like a Git repository, but for binary packages.
#
# This script supports seven commands:
#
# - 'fetch' to initialize (or update) a local mirror of the Pacman repository
#
# - 'add' to add packages to the local mirror
#
# - 'remove' to make the next 'push' skip the given package(s)
#
# - 'push' to synchronize local changes (after calling `repo-add`) to the
#   remote Pacman repository
#
# - 'files' shows files that are not owned by any package.
#
# - 'dirs' shows directories that are not owned by any package.
#
# - 'orphans' removes any package that became an orphan.

die () {
	printf "$*" >&2
	exit 1
}

# temporary fifo files
fifo_find="/var/tmp/disowned.find"
fifo_pacman="/var/tmp/disowned.pacman"

# MSYS2's mingw-w64-$arch-ca-certificates seem to lag behind ca-certificates
CURL_CA_BUNDLE=/usr/ssl/certs/ca-bundle.crt
export CURL_CA_BUNDLE

mode=
case "$1" in
fetch|add|remove|push|files|dirs|orphans|push_missing_signatures)
	mode="$1"
	shift
	;;
upload|publish|delete_version)
	test -n "$IKNOWWHATIMDOING" ||
	die "You need to switch to expert mode to do that"

	mode="$1"
	shift
	;;
*)
	die "Usage:\n" \
		" $0 ( fetch | push | ( add | remove ) <package>... )\n" \
		" $0 ( files | dirs | orphans )"
	;;
esac

base_url=https://dl.bintray.com/git-for-windows/pacman
api_url=https://api.bintray.com
content_url=$api_url/content/git-for-windows/pacman
packages_url=$api_url/packages/git-for-windows/pacman
mirror=/var/local/pacman-mirror

architectures="i686 x86_64"

arch_dir () { # <architecture>
	echo "$mirror/$1"
}

fetch () {
	for arch in $architectures
	do
		arch_url=$base_url/$arch
		dir="$(arch_dir $arch)"
		mkdir -p "$dir"
		(cd "$dir" &&
		 curl -sfO $arch_url/git-for-windows.db.tar.xz ||
		 continue
		 for name in $(package_list git-for-windows.db.tar.xz)
		 do
			case "$name" in
			mingw-w64-*)
				filename=$name-any.pkg.tar.xz
				;;
			*)
				filename=$name-$arch.pkg.tar.xz
				;;
			esac
			test -f $filename ||
			curl --cacert /usr/ssl/certs/ca-bundle.crt \
				-sfLO $base_url/$arch/$filename ||
			exit
		 done
		)
	done
}

upload () { # <package> <version> <arch> <filename>
	test -z "$PACMANDRYRUN" || {
		echo "upload: curl --netrc -fT $4 $content_url/$1/$2/$3/$4"
		return
	}
	echo "Uploading $1..." >&2
	curl --netrc -m 300 --connect-timeout 300 --retry 5 \
		-fT "$4" "$content_url/$1/$2/$3/$4" ||
	die "Could not upload $4 to $1/$2/$3"
}

publish () { # <package> <version>
	test -z "$PACMANDRYRUN" || {
		echo "publish: curl --netrc -fX POST $content_url/$1/$2/publish"
		return
	}
	curl --netrc --connect-timeout 300 --max-time 300 \
		--expect100-timeout 300 --speed-time 300 --retry 5 \
		-fX POST "$content_url/$1/$2/publish" ||
	while test $? = 7
	do
		echo "Timed out connecting to host, retrying in 5" >&2
		sleep 5
		curl --netrc --connect-timeout 300 --max-time 300 \
			--expect100-timeout 300 --speed-time 300 --retry 5 \
			-fX POST "$content_url/$1/$2/publish"
	done ||
	die "Could not publish $2 in $1 (exit code $?)"
}


delete_version () { # <package> <version>
	test -z "$PACMANDRYRUN" || {
		echo "delete: curl --netrc -fX DELETE $packages_url/$1/versions/$2"
		return
	}
	curl --netrc --retry 5 -fX DELETE "$packages_url/$1/versions/$2" ||
	die "Could not delete version $2 of $1"
}

package_list () { # db.tar.xz
	tar tf "$1" |
	sed -n 's/\/$//p'
}

package_exists () { # package-name
	case "$(curl --netrc --retry 5 -s "$packages_url/$1")" in
	*\"name\":\""$1"\"*)
		return 0
		;;
	*)
		echo "Package $1 does not yet exist" >&2
		return 1
		;;
	esac
}

db_version () {
	json="$(curl --netrc --retry 5 -s \
		"$packages_url/package-database/versions/_latest")"
	latest="$(expr "$json" : '.*"name":"\([^"]*\)".*')"
	test -n "$latest" ||
	die "Could not determine latest version"

	echo "$latest"
}

next_db_version () { # old version
	today="$(date -u +%Y-%m-%d)"
	case "$1" in
	$today-*)
		echo $today-$((${1##*-}+1))
		;;
	*)
		echo $today-1
		;;
	esac
}

add () { # <file>
	test $# -gt 0 ||
	die "What packages do you want to add?"

	for path
	do
		case "${path##*/}" in
		mingw-w64-*.pkg.tar.xz)
			arch=${path##*/}
			arch=${arch##mingw-w64-}
			arch=${arch%%-*}
			;;
		*-*.pkg.tar.xz)
			arch=${path##*-}
			arch=${arch%.pkg.tar.xz}
			;;
		*.src.tar.gz)
			arch=sources
			;;
		*)
			die "Invalid package name: $path"
			;;
		esac
		case " $architectures sources " in
		*" $arch "*)
			# okay
			;;
		*)
			die "Unknown architecture: $arch"
			;;
		esac

		echo "Adding ${path##*/} to $arch/" >&2

		dir="$(arch_dir $arch)"
		if test -d "$dir"
		then
			prefix="${path##*/}"
			prefix="${prefix%%-[0-9][0-9.]*}"
			(cd "$dir" &&
			 for file in "$prefix"-[0-9][0-9.]*
			 do
				test ! -f "$file" ||
				rm -v "$file"
			 done)
		else
			mkdir -p "$dir"
		fi &&
		cp "$path" "$dir/" ||
		die "Could not copy $path to $dir"

		if test -n "$GPGKEY"
		then
			gpg --detach-sign --use-agent --no-armor \
				-u $GPGKEY "$dir/$path"
		fi
	done
}

remove () { # <package>...
	test $# -gt 0 ||
	die "What packages do you want to add?"

	for package
	do
		for arch in $architectures
		do
			(cd "$(arch_dir $arch)" &&
			 rm $package-*.pkg.tar.xz &&
			 repo-remove git-for-windows.db.tar.xz $package)
		done
	done
}


update_local_package_databases () {
	signopt=
	test -z "$GPGKEY" || signopt=--sign
	for arch in $architectures
	do
		(cd "$(arch_dir $arch)" &&
		 repo-add $signopt --new git-for-windows.db.tar.xz \
			*.pkg.tar.xz &&
		 case "$arch" in
		 i686)
			repo-add $signopt --new \
				git-for-windows-mingw32.db.tar.xz \
				mingw-w64-$arch-*.pkg.tar.xz;;
		 x86_64)
			repo-add $signopt --new \
				git-for-windows-mingw64.db.tar.xz \
				mingw-w64-$arch-*.pkg.tar.xz;;
		 esac)
	done
}

push () {
	db_version="$(db_version)"
	if test -z "$db_version"
	then
		to_upload=
	else
		update_local_package_databases
		for arch in $architectures
		do
			arch_url=$base_url/$arch
			dir="$(arch_dir $arch)"
			mkdir -p "$dir"
			(cd "$dir" &&
			 echo "Getting $arch_url/git-for-windows.db.tar.xz" &&
			 curl -Lfo .remote $arch_url/git-for-windows.db.tar.xz
			) ||
			die "Could not get remote index for $arch"
		done

		old_list="$((for arch in $architectures
			do
				dir="$(arch_dir $arch)"
				test -s "$dir/.remote" &&
				package_list "$dir/.remote"
			done) |
			sort | uniq)"
		new_list="$((for arch in $architectures
			do
				dir="$(arch_dir $arch)"
				package_list "$dir/git-for-windows.db.tar.xz"
			done) |
			sort | uniq)"

		to_upload="$(printf "%s\n%s\n%s\n" \
				"$old_list" "$old_list" "$new_list" |
			sort | uniq -u)"

		test -n "$to_upload" || test "x$old_list" != "x$new_list" || {
			echo "Nothing to be done" >&2
			return
		}
	fi

	next_db_version="$(next_db_version "$db_version")"

	test -z "$to_upload" || {
		to_upload_basenames="$(echo "$to_upload" |
			sed 's/-[0-9].*//' |
			sort | uniq)"

		# Verify that the packages exist already
		for basename in $to_upload_basenames
		do
			case " $(echo "$old_list" | tr '\n' ' ')" in
			*" $basename"-[0-9]*)
				;;
			*)
				package_exists $basename ||
				die "The package $basename does not yet exist... Add it at https://bintray.com/git-for-windows/pacman/new/package?pkgPath="
				;;
			esac
		done

		for name in $to_upload
		do
			basename=${name%%-[0-9]*}
			version=${name#$basename-}
			for arch in $architectures sources
			do
				case "$name,$arch" in
				mingw-w64-i686,x86_64|mingw-w64-x86_64,i686)
					# wrong architecture
					continue
					;;
				mingw-w64-i686-*,sources)
					# sources are "included" in x86_64
					continue
					;;
				mingw-w64-x86_64-*,sources)
					# sources are "included" in x86_64
					filename=mingw-w64${name#*_64}.src.tar.gz
					;;
				*,sources)
					filename=$name.src.tar.gz
					;;
				mingw-w64-*)
					filename=$name-any.pkg.tar.xz
					;;
				*)
					filename=$name-$arch.pkg.tar.xz
					;;
				esac
				(cd "$(arch_dir $arch)" &&
				 if test -f $filename
				 then
					upload $basename $version $arch $filename
				 fi &&
				 if test -f $filename.sig
				 then
					upload $basename $version $arch \
						$filename.sig
				fi) || exit
			done
			publish $basename $version
		done
	}

	test -z "$db_version" ||
	delete_version package-database "$db_version"

	for arch in $architectures
	do
		(cd "$(arch_dir $arch)" &&
		 files= &&
		 for suffix in db db.tar.xz files files.tar.xz
		 do
			filename=git-for-windows.$suffix
			test ! -f $filename || files="$files $filename"
			test ! -f $filename.sig || files="$files $filename.sig"

			case "$arch" in
			i686) filename=git-for-windows-mingw32.$suffix;;
			x86_64) filename=git-for-windows-mingw64.$suffix;;
			*) continue;;
			esac

			test ! -f $filename || files="$files $filename"
			test ! -f $filename.sig || files="$files $filename.sig"
		 done
		 for filename in $files
		 do
			upload package-database $next_db_version $arch $filename
		 done
		) || exit
	done
	publish package-database $next_db_version
}

file_exists () { # arch filename
	curl -sfI "$base_url/$1/$2" >/dev/null
}

push_missing_signatures () {
	list="$((for arch in $architectures
		do
			dir="$(arch_dir $arch)"
			package_list "$dir/git-for-windows.db.tar.xz"
		done) |
		sort | uniq)"

	db_version="$(db_version)"

	for name in $list
	do
		count=0
		basename=${name%%-[0-9]*}
		version=${name#$basename-}
		for arch in $architectures sources
		do
			case "$name,$arch" in
			mingw-w64-i686,x86_64|mingw-w64-x86_64,i686)
				# wrong architecture
				continue
				;;
			mingw-w64-i686-*,sources)
				# sources are "included" in x86_64
				continue
				;;
			mingw-w64-x86_64-*,sources)
				# sources are "included" in x86_64
				filename=mingw-w64${name#*_64}.src.tar.gz
				;;
			*,sources)
				filename=$name.src.tar.gz
				;;
			mingw-w64-*)
				filename=$name-any.pkg.tar.xz
				;;
			*)
				filename=$name-$arch.pkg.tar.xz
				;;
			esac
			dir="$(arch_dir $arch)" &&
			if test ! -f "$dir"/$filename.sig ||
				file_exists $arch $filename.sig
			then
				continue
			fi &&
			(cd "$dir" &&
			 echo "Uploading missing $arch/$filename.sig" &&
			 upload $basename $version $arch $filename.sig) || exit
			count=$(($count+1))
		done
		test $count = 0 || {
			echo "Re-publishing $basename $version" &&
			publish $basename $version
		} ||
		die "Could not re-publish $basename $version"
	done

	count=0
	for arch in $architectures
	do
		for suffix in db db.tar.xz files files.tar.xz
		do
			filename=git-for-windows.$suffix
			dir="$(arch_dir $arch)"
			if test ! -f "$dir"/$filename.sig ||
				file_exists $arch $filename.sig
			then
				continue
			fi
			(cd "$dir" &&
			 echo "Uploading missing $arch/$filename.sig" &&
			 upload package-database $db_version $arch \
				$filename.sig) || exit
			count=$(($count+1))
		done || exit
	done
	test $count = 0 || {
		echo "Re-publishing db $db_version" &&
		publish package-database $db_version
	} ||
	die "Could not re-publish db $db_version"
}

reset_fifo_files () {
	rm -f "$fifo_find"
	rm -f "$fifo_pacman"
}

dirs () {
	reset_fifo_files

	find / \( -path '/dev' -o -path '/bin' -o -path '/usr/src' \
		-o -path '/tmp' -o -path '/proc' -o -path '/home' \
		-o -path '/var/lib/pacman' -o -path '/var/cache/pacman' \) \
		-prune -o -type d -print | sed 's/\([^/]\)$/\1\//' | \
		sort -u > "$fifo_find"

	pacman -Qlq | sort -u > "$fifo_pacman"

	comm -23 "$fifo_find" "$fifo_pacman"

	reset_fifo_files
}

files () {
	reset_fifo_files

	find / \( -path '/dev' -o -path '/bin' -o -path '/usr/src' \
		-o -path '/tmp' -o -path '/proc' -o -path "$fifo_find" \
		-o -path '/home' -o -path '/var/lib/pacman' \
		-o -path '/var/cache/pacman' \) -prune -o -type f -print | \
		sort -u > "$fifo_find"

	pacman -Qlq | sort -u > "$fifo_pacman"

	comm -23 "$fifo_find" "$fifo_pacman"

	reset_fifo_files
}

orphans () {
	pacman -Rns $(pacman -Qtdq) 2> /dev/null || echo 'no orphans found..'
}

eval "$mode" "$@"

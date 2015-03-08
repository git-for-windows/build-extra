#!/bin/sh

# This script helps Git for Windows developers to manage their Pacman
# repository.
#
# A Pacman repository is like a Git repository, but for binary packages.
#
# This script supports three commands:
#
# - 'fetch' to initialize (or update) a local mirror of the Pacman repository
#
# - 'add' to add packages to the local mirror
#
# - 'push' to synchronize local changes (after calling `repo-add`) to the
#   remote Pacman repository

die () {
	echo "$*" >&2
	exit 1
}

mode=
case "$1" in
fetch|add|push)
	mode="$1"
	shift
	;;
*)
	die "Usage: $0 ( fetch | push | add <package>... )"
	;;
esac

base_url=https://dl.bintray.com/git-for-windows/pacman
api_url=https://api.bintray.com
content_url=$api_url/content/git-for-windows/pacman
packages_url=$api_url/packages/git-for-windows/pacman
mirror=/var/local/pacman-mirror

msystems="msys2 mingw"
architectures="i686 x86_64"

arch_dir () { # <msystem> <architecture>
	echo "$mirror/$1/$2"
}

fetch () {
	for msystem in $msystems
	do
		for arch in $architectures
		do
			arch_url=$base_url/$msystem/$arch
			dir="$(arch_dir $msystem $arch)"
			mkdir -p "$dir"
			(cd "$dir" &&
			 curl -sO $arch_url/git-for-windows.db.tar.xz &&
			 for name in $(package_list git-for-windows.db.tar.xz)
			 do
				filename=$name-$arch.pkg.tar.xz
				test -f $filename ||
				curl --cacert /usr/ssl/certs/ca-bundle.crt \
					-sLO $base_url/$arch/$filename ||
				exit
			 done ||
			 exit
			)
		done
	done
}

upload () { # <package> <version> <msystem> <arch> <filename>
	curl --netrc -T "$5" "$content_url/$1/$2/$3/$4/$5"
}

publish () { # <package> <version>
	curl --netrc -X POST "$content_url/$1/$2/publish"
}


delete_version () { # <package> <version>
	curl --netrc -X DELETE "$packages_url/$1/versions/$2"
}

package_list () { # db.tar.xz
	tar tf "$1" |
	sed -n 's/\/$//p'
}

package_exists () { # package-name
	case "$(curl --netrc -s "$packages_url/$1")" in
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
	json="$(curl --netrc -s \
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
		mingw-w64-*)
			msystem=mingw
			;;
		*)
			msystem=msys2
			;;
		esac

		case "$path" in
		*-*.pkg.tar.xz)
			# okay
			;;
		*)
			die "Invalid package name: $path"
			;;
		esac
		arch=${path##*-}
		arch=${arch%.pkg.tar.xz}
		case " $architectures " in
		*" $arch "*)
			# okay
			;;
		*)
			die "Unknown architecture: $arch"
			;;
		esac
		dir="$(arch_dir $msystem $arch)"
		mkdir -p "$dir"
		cp "$path" "$dir/"
	done
}

update_local_package_databases () {
	for msystem in $msystems
	do
		for arch in $architectures
		do
			(cd "$(arch_dir $msystem $arch)" &&
			 repo-add git-for-windows.db.tar.xz \
				*-$arch.pkg.tar.xz &&
			 repo-add -f git-for-windows.files.tar.xz \
				*-$arch.pkg.tar.xz
			)
		done
	done
}

push () {
	update_local_package_databases
	for msystem in $msystems
	do
		for arch in $architectures
		do
			arch_url=$base_url/$msystem/$arch
			dir="$(arch_dir $msystem $arch)"
			mkdir -p "$dir"
			(cd "$dir" &&
			 curl -s $arch_url/git-for-windows.db.tar.xz > .remote
			) || exit
		done
	done

	old_list="$((for msystem in $msystems
		do
			for arch in $architectures
			do
				dir="$(arch_dir $msystem $arch)"
				package_list "$dir/.remote"
			done
		done) |
		sort | uniq)"
	new_list="$((for msystem in $msystems
		do
			for arch in $architectures
			do
				dir="$(arch_dir $msystem $arch)"
				package_list "$dir/git-for-windows.db.tar.xz"
			done
		done) |
		sort | uniq)"

	to_upload="$(printf "%s\n%s\n%s\n" "$old_list" "$old_list" "$new_list" |
		sort | uniq -u)"

	test -n "$to_upload" || {
		echo "Nothing to be done" >&2
		return
	}

	to_upload_basenames="$(echo "$to_upload" |
		sed 's/-[0-9].*//' |
		sort | uniq)"

	db_version="$(db_version)"
	next_db_version="$(next_db_version "$db_version")"

	# Verify that the packages exist already
	for basename in $to_upload_basenames
	do
		case " $(echo "$old_list" | tr '\n' ' ')" in
		*" $basename"-[0-9]*)
			;;
		*)
			package_exists $basename ||
			die "The package $basename does not yet exist..."
			;;
		esac
	done

	for name in $to_upload
	do
		basename=${name%%-[0-9]*}
		version=${name#$basename-}
		for msystem in $msystems
		do
			for arch in $architectures
			do
				filename=$name-$arch.pkg.tar.xz
				(cd "$(arch_dir $msystem $arch)" &&
				 if test -f $filename
				 then
					upload $basename $version \
						$msystem $arch $filename
				 fi) || exit
			done
		done
		publish $basename $version
	done

	delete_version package-database "$db_version"

	for msystem in $msystems
	do
		for arch in $architectures
		do
			(cd "$(arch_dir $msystem $arch)" &&
			 for suffix in db db.tar.xz files files.tar.xz
			 do
				filename=git-for-windows.$suffix
				test ! -f $filename ||
				upload package-database $next_db_version \
					$msystem $arch $filename
			 done
			) || exit
		done
	done
	publish package-database $next_db_version
}

eval "$mode" "$@"

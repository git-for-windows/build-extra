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
	format="$1\\n"; shift
	printf "$format" "$@" >&2
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
fetch|add|remove|push|files|dirs|orphans|push_missing_signatures|file_exists)
	mode="$1"
	shift
	;;
upload)
	test -n "$IKNOWWHATIMDOING" ||
	die "You need to switch to expert mode to do that"

	mode="$1"
	shift
	;;
*)
	die "Usage:\n%s\n%s\n" \
		" $0 ( fetch | push | ( add | remove ) <package>... )" \
		" $0 ( files | dirs | orphans )"
	;;
esac

this_script_dir="$(cygpath -am "${0%/*}")"
base_url=https://wingit.blob.core.windows.net
mirror=/var/local/pacman-mirror
azure_blobs_token=

architectures="i686 x86_64"

arch_dir () { # <architecture>
	echo "$mirror/$1"
}

map_arch () { # <architecture>
	# Azure Blobs does not allow underlines, but dashes in container names
	case "$1" in
	x86_64) echo "x86-64";;
	*) echo "$1";;
	esac
}

arch_url () { # <architecture>
	echo "$base_url/$(map_arch $1)"
}

arch_to_mingw () { # <arch>
	if test i686 = "$arch"
	then
		echo mingw32
	else
		echo mingw64
	fi
}

fetch () {
	for arch in $architectures
	do
		arch_url=$(arch_url $arch)
		dir="$(arch_dir $arch)"
		mkdir -p "$dir"
		(cd "$dir" &&
		 curl -sfO $arch_url/git-for-windows.db.tar.xz ||
		 continue
		 curl -sfO $arch_url/git-for-windows.db.tar.xz.sig ||
		 die "Could not fetch git-for-windows.sig in $arch"

		 curl -sfO $arch_url/git-for-windows.files.tar.xz ||
		 die "Could not fetch git-for-windows.files in $arch"
		 curl -sfO $arch_url/git-for-windows.files.tar.xz.sig ||
		 die "Could not fetch git-for-windows.files.sig in $arch"

		 s=$(arch_to_mingw "$arch")
		 curl -sfO $arch_url/git-for-windows-$s.db.tar.xz ||
		 die "Could not download $s db"
		 curl -sfO $arch_url/git-for-windows-$s.db.tar.xz.sig ||
		 die "Could not download $s db.sig"

		 curl -sfO $arch_url/git-for-windows-$s.files.tar.xz ||
		 die "Could not download $s files"
		 curl -sfO $arch_url/git-for-windows-$s.files.tar.xz.sig ||
		 die "Could not download $s files.sig"

		 list=$(package_list git-for-windows.db.tar.xz) ||
		 die "Cannot extract package list in $arch"
		 list="$(echo "$list" | tr '\n' ' ')"

		 # first, remove stale files
		 for file in *.pkg.tar.xz
		 do
			test '*.pkg.tar.xz' !=  "$file" ||
			break # no .pkg.tar.xz files...

			case " $list " in
			*" ${file%-*.pkg.tar.xz} "*)
				;; # okay, included
			*)
				echo "Removing stale $file in $arch" >&2
				rm $file ||
				die "Could not remove $file in $arch"
				test ! -f $file.sig ||
				rm $file.sig ||
				die "Could not remove $file.sig in $arch"
				;;
			esac
		 done

		 # now make sure all of the current packages are cached locally
		 for name in $list
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
				-sfLO $(arch_url $arch)/$filename ||
			die "Could not get $filename"
			test -f $filename.sig ||
			curl --cacert /usr/ssl/certs/ca-bundle.crt \
				-sfLO $(arch_url $arch)/$filename.sig ||
			die "Could not get $filename.sig"
			test x86_64 = "$arch" || continue

			mkdir -p "$(arch_dir sources)" ||
			die "Could not create $(arch_dir sources)"

			(cd "$(arch_dir sources)" ||
			 die "Could not cd to sources/"
			 case "$name" in
			 libcurl-[1-9]*|libcurl-devel-[1-9]*|mingw-w64-x86_64-git-doc-html-[1-9]*|mingw-w64-x86_64-git-doc-man-[1-9]*|msys2-runtime-devel-[1-9]*|libopenssl-[1-9]*|openssl-devel-[1-9]*|mingw-w64-x86_64-git-test-artifacts-[1-9]*|bash-devel-[1-9]*|heimdal-devel-[1-9]*|heimdal-libs-[1-9]*|mingw-w64-x86_64-curl-pdb-[1-9]*|mingw-w64-x86_64-git-pdb-[1-9]*|mingw-w64-x86_64-openssl-pdb-[1-9]*)
				# extra package's source included elsewhere
				continue
				;;
			 mingw-w64-x86_64-*)
				filename=mingw-w64${name#*_64}.src.tar.gz
				;;
			 *)
				filename=$name.src.tar.gz
				;;
			 esac
			 test -f $filename ||
			 curl --cacert /usr/ssl/certs/ca-bundle.crt \
				-sfLO $base_url/sources/$filename ||
			 die "Could not get $filename"
			 test -f $filename.sig ||
			 curl --cacert /usr/ssl/certs/ca-bundle.crt \
				-sfLO $base_url/sources/$filename.sig ||
			 die "Could not get $filename.sig")
		 done
		) || exit
	done
}

upload () { # <package> <version> <arch> <filename>
	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	test -z "$PACMANDRYRUN" || {
		echo "upload: wingit-snapshot-helper.sh wingit $(map_arch $3) <token> upload $4"
		return
	}

	case "$1" in
	disabled-for-now-package-database) action=upload-with-lease;;
	*) action=upload;;
	esac

	echo "Uploading $1..." >&2
	"$this_script_dir"/wingit-snapshot-helper.sh wingit $(map_arch $3) "$azure_blobs_token" $action $4 ||
	die "Could not upload $4 to $(map_arch $3)"
}

package_list () { # db.tar.xz
	tar tf "$1" |
	sed -n 's/\/$//p'
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
			 repo-remove git-for-windows.db.tar.xz $package &&
			 case "$package" in
			 mingw-w64-$arch-*)
				s=$(arch_to_mingw "$arch")
				repo-remove git-for-windows-$s.db.tar.xz \
					$package
				;;
			 esac)
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
		 repo-add $signopt --new \
		 git-for-windows-$(arch_to_mingw "$arch").db.tar.xz \
		 mingw-w64-$arch-*.pkg.tar.xz)
	done
}

push_next_db_version () {
	for arch in $architectures
	do
		(cd "$(arch_dir $arch)" &&
		 files= &&
		 for suffix in db db.tar.xz files files.tar.xz
		 do
			filename=git-for-windows.$suffix
			test ! -f $filename || files="$files $filename"
			test ! -f $filename.sig || files="$files $filename.sig"

			filename=git-for-windows-$(arch_to_mingw $arch).$suffix
			test ! -f $filename || files="$files $filename"
			test ! -f $filename.sig || files="$files $filename.sig"
		 done
		 for filename in $files
		 do
			upload package-database - $arch $filename
		 done
		) || exit
	done
}

push () {
	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	update_local_package_databases
	for arch in $architectures
	do
		arch_url=$(arch_url $arch)
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

	test -z "$to_upload" || {
		to_upload_basenames="$(echo "$to_upload" |
			sed 's/-[0-9].*//' |
			sort | uniq)"

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
		done
	}

	push_next_db_version
}

file_exists () { # arch filename
	curl -sfI "$(arch_url $1)/$2" >/dev/null
}

push_missing_signatures () {
	list="$((for arch in $architectures
		do
			dir="$(arch_dir $arch)"
			package_list "$dir/git-for-windows.db.tar.xz"
		done) |
		sort | uniq)"

	signopt=
	test -z "$GPGKEY" || signopt=--sign

	for name in $list
	do
		count=0
		basename=${name%%-[0-9]*}
		version=${name#$basename-}
		for arch in $architectures sources
		do
			case "$name,$arch" in
			mingw-w64-i686-*,x86_64|mingw-w64-x86_64-*,i686)
				# wrong architecture
				continue
				;;
			mingw-w64-i686-*,sources)
				# sources are "included" in x86_64
				continue
				;;
			libcurl*,sources|mingw-w64-*-git-doc*,sources|msys2-runtime-devel*,sources)
				# extra package's source included elsewhere
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
			test -f "$dir"/$filename.sig ||
			if test -n "$GPGKEY"
			then
				gpg --detach-sign --use-agent --no-armor \
					-u $GPGKEY "$dir/$filename"
			else
				die "Missing: $dir/$filename.sig"
			fi
			if file_exists $arch $filename.sig
			then
				continue
			fi &&
			(cd "$dir" &&
			 echo "Uploading missing $arch/$filename.sig" &&
			 upload $basename $version $arch $filename.sig) || exit
			count=$(($count+1))
		done
	done

	count=0
	for arch in $architectures
	do
		cd "$(arch_dir "$arch")" ||
		die "Could not cd to $arch/"

		list2=" $(echo "$list" | tr '\n' ' ') "
		mingw_dbname=git-for-windows-$(arch_to_mingw $arch).db.tar.xz
		for name in $(package_list $mingw_dbname)
		do
			case "$list2" in
			*" $name "*) ;; # okay, it's also in the full db
			*)
				repo-remove $signopt $mingw_dbname \
					${name%%-[0-9]*} ||
				die "Could not remove $name from $mingw_dbname"
				count=$(($count+1))
				;;
			esac
		done

		for name in $list
		do
			case "$name,$arch" in
			mingw-w64-i686*,x86_64|mingw-w64-x86_64*,i686)
				# wrong architecture; skip
				continue
				;;
			mingw-w64-$arch-*)
				filename=$name-any.pkg.tar.xz
				s=$(arch_to_mingw $arch)
				dbname=git-for-windows-$s.db.tar.xz
				out="$(tar Oxf $dbname $name/desc)" ||
				die "Could not look for $name in $arch/mingw"

				test "a" = "a${out##*PGPSIG*}" || {
					count=$(($count+1))
					repo-add $signopt $dbname $filename ||
					die "Could not add $name in $arch/mingw"
				}
				;;
			*)
				filename=$name-$arch.pkg.tar.xz
				;;
			esac

			out="$(tar Oxf git-for-windows.db.tar.xz $name/desc)" ||
			die "Could not look for $name in $arch"

			test "a" = "a${out##*PGPSIG*}" || {
				count=$(($count+1))
				repo-add $signopt git-for-windows.db.tar.xz \
					$filename ||
				die "Could not add $name in $arch"
				echo "$name is missing sig in $arch"
			}
		done
	done

	for arch in $architectures
	do
		s=-$(arch_to_mingw "$arch")
		for suffix in .db .db.tar.xz .files .files.tar.xz \
			$s.db $s.db.tar.xz $s.files $s.files.tar.xz
		do
			filename=git-for-windows$suffix
			dir="$(arch_dir $arch)"
			test -f "$dir"/$filename.sig ||
			if test -n "$GPGKEY"
			then
				gpg --detach-sign --use-agent --no-armor \
					-u $GPGKEY "$dir/$filename"
			else
				die "Missing: $dir/$filename.sig"
			fi
			if file_exists $arch $filename.sig
			then
				continue
			fi
			(cd "$dir" &&
			 echo "Uploading missing $arch/$filename.sig" &&
			 upload package-database - $arch $filename.sig) || exit
			count=$(($count+1))
		done || exit
	done

	test 0 = $count ||
	push_next_db_version ||
	die "Could not push next db_version"
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

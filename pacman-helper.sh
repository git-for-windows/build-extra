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

mode=
case "$1" in
fetch|add|remove|push|files|dirs|orphans|push_missing_signatures|file_exists|lock|unlock|break_lock|quick_add|sanitize_db)
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
	die "Usage:\n%s\n%s\n%s\n" \
		" $0 ( fetch | push | ( add | remove ) <package>... )" \
		" $0 ( lock | unlock <id> | break_lock )" \
		" $0 ( files | dirs | orphans )"
	;;
esac

case "$(uname -s)" in
MSYS|MINGW*)
	# MSYS2's mingw-w64-$arch-ca-certificates seem to lag behind ca-certificates
	CURL_CA_BUNDLE=/usr/ssl/certs/ca-bundle.crt
	export CURL_CA_BUNDLE

	this_script_dir="$(cygpath -am "${0%/*}")"
	;;
*)
	this_script_dir="$(cd "$(dirname "$0")" && pwd -P)"
	;;
esac
base_url=https://wingit.blob.core.windows.net
mirror=/var/local/pacman-mirror

architectures="i686 x86_64 aarch64"

arch_dir () { # <architecture>
	echo "$mirror/$1"
}

map_arch () { # <architecture>
	# Azure Blobs does not allow underlines, but dashes in container names
	case "$1" in
	x86_64) echo "x86-64";;
	clang-aarch64) echo "aarch64";;
	*) echo "$1";;
	esac
}

arch_url () { # <architecture>
	echo "$base_url/$(map_arch $1)"
}

arch_to_mingw () { # <arch>
	case "$arch" in
	i686) echo mingw32;;
	aarch64) echo aarch64;;
	*) echo mingw64;;
	esac
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
			curl -sfLO $(arch_url $arch)/$filename ||
			if test $? = 56
			then
				curl -sfLO $(arch_url $arch)/$filename
			fi ||
			die "Could not get $filename ($?)"
			test -f $filename.sig ||
			curl -sfLO $(arch_url $arch)/$filename.sig ||
			if test $? = 56
			then
				curl -sfLO $(arch_url $arch)/$filename.sig
			fi ||
			die "Could not get $filename.sig ($?)"
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
			 curl -sfLO $base_url/sources/$filename ||
			 if test $? = 56
			 then
				curl -sfLO $base_url/sources/$filename
			 fi ||
			 die "Could not get $filename ($?)"
			 test -f $filename.sig ||
			 curl -sfLO $base_url/sources/$filename.sig ||
			 if test $? = 56
			 then
				curl -sfLO $base_url/sources/$filename.sig
			 fi ||
			 die "Could not get $filename.sig ($?)")
		 done
		) || exit
	done
}

upload () { # <package> <version> <arch> <filename>
	test -z "$PACMANDRYRUN" || {
		echo "upload: wingit-snapshot-helper.sh wingit $(map_arch $3) <token> upload $4"
		return
	}

	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	echo "Uploading $1..." >&2
	case "$3/$4,$PACMAN_DB_LEASE" in
	x86_64/git-for-windows.db,?*)
		"$this_script_dir"/wingit-snapshot-helper.sh \
			wingit $(map_arch $3) "$azure_blobs_token" \
			upload-with-lease "$PACMAN_DB_LEASE" $4
		;;
	*)
		"$this_script_dir"/wingit-snapshot-helper.sh \
			wingit $(map_arch $3) "$azure_blobs_token" upload $4
		;;
	esac ||
	die "Could not upload $4 to $(map_arch $3)"
}

package_list () { # db.tar.xz
	tar tf "$1" |
	sed -ne '/ /d' -e 's/\/$//p'
}

call_gpg () {
	if test -z "$CALL_GPG"
	then
		GIT_GPG_PROGRAM="$(git config gpg.program)"
		CALL_GPG="${GIT_GPG_PROGRAM:-gpg}"
	fi

	"$CALL_GPG" "$@"
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
			prefix="${prefix%-*-*}"
			(cd "$dir" &&
			 for file in "$prefix"-[0-9][0-9.]*
			 do
				# Be careful: package names might contain `-<digit>`!
				if test sources = "$arch"
				then
					test "$prefix" != "${file%-*-*}" || continue
				else
					test "$prefix" != "${file%-*-*-*}" || continue
				fi

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
			call_gpg --detach-sign --no-armor \
				-u $GPGKEY "$dir/${path##*/}"
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

repo_add () {
	if test ! -s "$this_script_dir/repo-add"
	then
		# Make sure that GPGKEY is used unquoted
		 sed 's/"\(\${\?GPGKEY}\?\)"/\1/g' </usr/bin/repo-add >"$this_script_dir/repo-add"
	fi &&
	"$this_script_dir/repo-add" "$@"
}

update_local_package_databases () {
	sign_option=
	test -z "$GPGKEY" || sign_option=--sign
	for arch in $architectures
	do
		(cd "$(arch_dir $arch)" &&
		 repo_add $sign_option --new git-for-windows.db.tar.xz \
			*.pkg.tar.xz &&
		 repo_add $sign_option --new \
		 git-for-windows-$(arch_to_mingw "$arch").db.tar.xz \
		 mingw-w64-$arch-*.pkg.tar.xz) ||
		 die "Could not update $arch package database"
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

	old_list="$( (for arch in $architectures
		do
			dir="$(arch_dir $arch)"
			test -s "$dir/.remote" &&
			package_list "$dir/.remote"
		done) |
		sort | uniq)"
	new_list="$( (for arch in $architectures
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
		to_upload_base_names="$(echo "$to_upload" |
			sed 's/-[0-9][^-]*-[0-9][0-9]*$//' |
			sort | uniq)"

		for name in $to_upload
		do
			basename=${name%-*-*}
			version=${name#$basename-}
			for arch in $architectures sources
			do
				case "$name,$arch" in
				mingw-w64-x86_64-*,sources)
					# sources are "included" in x86_64
					filename=mingw-w64${name#*_64}.src.tar.gz
					;;
				*,sources)
					filename=$name.src.tar.gz
					;;
				mingw-w64-$arch,$arch)
					filename=$name-any.pkg.tar.xz
					;;
				mingw-w64-*)
					# wrong architecture
					continue
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

sanitize_db () { # <file>...
	perl -e '
		foreach my $path (@ARGV) {
			my @to_delete = ();
			my %base_to_date = ();
			my %base_to_full_name = ();

			open($fh, "-|", "tar", "tvf", $path) or die;
			while (<$fh>) {
				# parse lines like this:
				# drwxr-xr-x root/root         0 2019-02-17 21:45 bash -4.4.023-1 /
				if (/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)(-\d[^-]*-\d+)\/$/) {
					my $date = $4 . " " . $5;
					my $prefix = $6;
					my $full_name = $6 . $7;
					if ($prefix =~ / /) {
						push @to_delete, $full_name;
					} elsif (exists($base_to_date{$prefix})) {
						print $prefix . ": " . $base_to_date{$prefix} . " vs " . $date . "\n";
						if (($base_to_date{$prefix} cmp $date) < 0) {
							print $base_to_date{$prefix} . " older than " . $date . ": delete " . $base_to_date{$prefix} . "\n";
							push @to_delete, $base_to_full_name{$prefix};
							# replace
							$base_to_full_name{$prefix} = $full_name;
							$base_to_date{$prefix} = $date;
						} else {
							print $base_to_date{$prefix} . " younger than " . $date . ": delete " . $date . "\n";
							push @to_delete, $full_name;
						}
					} else {
						$base_to_date{$prefix} = $date;
						$base_to_full_name{$prefix} = $full_name;
					}
				}
			}
			close($fh);

			if ($#to_delete > 0) {
				@bsdtar = ("bsdtar", "-cJf", $path . ".bup");
				foreach my $item (@to_delete) {
					push @bsdtar, "--exclude";
					push @bsdtar, $item . "*";
				}
				push @bsdtar, "@" . $path;
				print "Sanitizing: " . join(" ", @bsdtar) . "\n";
				if (system(@bsdtar) == 0) {
					rename $path . ".bup", $path or die "Could not rename $path.bup to $path";
				} else {
					die "Could not run " . join(" ", @bsdtar);
				}
			}
		}
	' "$@" &&
	if test -n "$GPGKEY"
	then
		for path in "$@"
		do
			call_gpg --detach-sign --no-armor -u $GPGKEY "$path" ||
			die "Could not sign $path"
		done
	fi
}

quick_add () { # <file>...
	test $# -gt 0 ||
	die "Need at least one file"

	# Create a temporary directory to work with
	dir="$(mktemp -d)" &&
	mkdir "$dir/x86_64" "$dir/aarch64" "$dir/i686" "$dir/sources" ||
	die "Could not create temporary directory"

	i686_mingw=
	i686_msys=
	aarch64_mingw=
	aarch64_msys=
	x86_64_mingw=
	x86_64_msys=
	all_files=

	# Copy the file(s) to the temporary directory, and schedule their addition to the appropriate index(es)
	for path in "$@"
	do
		file="${path##*/}"
		mingw=
		case "${path##*/}" in
		mingw-w64-*.pkg.tar.xz|mingw-w64-*.pkg.tar.zst)
			arch=${file##mingw-w64-}
			arch=${arch#clang-}
			arch=${arch%%-*}
			key=${arch}_mingw
			;;
		git-extra-*.pkg.tar.xz|git-extra-*.pkg.tar.zst)
			arch=${file%.pkg.tar.*}
			arch=${arch##*-}
			key=${arch}_mingw
			;;
		*-*.pkg.tar.xz|*-*.pkg.tar.zst)
			arch=${file%.pkg.tar.*}
			arch=${arch##*-}
			test any != "$arch" || {
				arch="$(tar Oxf "$path" .BUILDINFO |
					sed -n 's/^installed = msys2-runtime-[0-9].*-\(.*\)/\1/p')"
				test -n "$arch" ||
				die "Could not determine architecture of '$path'"
			}
			key=${arch}_msys
			;;
		*.src.tar.gz|*.src.tar.xz|*.src.tar.zst)
			arch=sources
			key=
			;;
		*.sig)
			# skip explicit signatures; we copy them automatically
			continue
			;;
		*)
			echo "Skipping unknown file: $file" >&2
			continue
			;;
		esac
		test -n "$arch" || die "Could not determine architecture for $path"
		case " $architectures sources " in
		*" $arch "*) ;;  # okay
		*) echo "Skipping file with unknown arch: $file" >&2; continue;;
		esac

		echo "Copying $file to $arch/..." >&2
		test -z "$key" || eval "$key=\$$key\\ $file"
		all_files="$all_files $arch/$file"

		cp "$path" "$dir/$arch" ||
		die "Could not copy $path to $dir/$arch"

		if test -f "$path".sig
		then
			cp "$path".sig "$dir/$arch/" ||
			die "Could not copy $path.sig to $dir/$arch"
                        all_files="$all_files $arch/$file.sig"
		elif test -n "$GPGKEY"
		then
			echo "Signing $arch/$file..." >&2
			call_gpg --detach-sign --no-armor -u $GPGKEY "$dir/$arch/$file"
			all_files="$all_files $arch/$file.sig"
		fi
	done

	# Acquire lease
	PACMAN_DB_LEASE="$(lock)" ||
	die 'Could not obtain a lock for uploading'

	# Download indexes into the temporary directory and add files
	sign_option=
	test -z "$GPGKEY" || sign_option=--sign
	dbs=
	for arch in $architectures
	do
		eval "msys=\$${arch}_msys"
		eval "mingw=\$${arch}_mingw"
		test -n "$msys$mingw" || continue

		case "$(test aarch64 = $arch && curl -sI "$(arch_url $arch)/git-for-windows.db")" in
		*404*) initialize_fresh_pacman_repository=t;; # this one is new
		*) initialize_fresh_pacman_repository=;;
		esac

		case "$arch,$mingw" in
		*,) db2=;;
		i686,*) db2=mingw32;;
		*aarch64*) db2=aarch64;;
		*) db2=mingw64;;
		esac
		for db in git-for-windows ${db2:+git-for-windows-$db2}
		do
			for infix in db files
			do
				file=$db.$infix.tar.xz
				if test -n "$initialize_fresh_pacman_repository"
				then
					echo "Will initialize new $arch/$file..." >&2
				else
					echo "Downloading current $arch/$file..." >&2
					curl -sfo "$dir/$arch/$file" "$(arch_url $arch)/$file" || return 1
				fi
				dbs="$dbs $arch/$file $arch/${file%.tar.xz}"
				if test -n "$sign_option"
				then
					if test -z "$initialize_fresh_pacman_repository"
					then
						curl -sfo "$dir/$arch/$file.sig" "$(arch_url $arch)/$file.sig" ||
						return 1
						gpg --verify "$dir/$arch/$file.sig" ||
						die "Could not verify GPG signature: $dir/$arch/$file"
					fi
					dbs="$dbs $arch/$file.sig $arch/${file%.tar.xz}.sig"
				fi
				if test -z "$initialize_fresh_pacman_repository"
				then
					sanitize_db "$dir/$arch/$file" || return 1
					test ! -f "$dir/$arch/${file%.tar.xz}" ||
					sanitize_db "$dir/$arch/${file%.tar.xz}" || return 1
				fi
			done
		done
		(cd "$dir/$arch" &&
		 repo_add $sign_option git-for-windows.db.tar.xz $msys $mingw &&
		 { test ! -h git-for-windows.db || rm git-for-windows.db; } &&
		 cp git-for-windows.db.tar.xz git-for-windows.db && {
			test -z "$sign_option" || {
				{ test ! -h git-for-windows.db.sig || rm git-for-windows.db.sig; } &&
				cp git-for-windows.db.tar.xz.sig git-for-windows.db.sig
			}
		 } &&
		 if test -n "$db2"
		 then
			repo_add $sign_option git-for-windows-$db2.db.tar.xz $mingw &&
			{ test ! -h git-for-windows-$db2.db || rm git-for-windows-$db2.db; } &&
			cp git-for-windows-$db2.db.tar.xz git-for-windows-$db2.db && {
				test -z "$sign_option" || {
					{ test ! -h git-for-windows-$db2.db.sig || rm git-for-windows-$db2.db.sig; } &&
					cp git-for-windows-$db2.db.tar.xz.sig git-for-windows-$db2.db.sig
				}
			}
		 fi) ||
		die "Could not add $msys $mingw to db in $arch"
	done

	# Upload the file(s) and the appropriate index(es)
	(cd "$dir" &&
	 if test -z "$PACMANDRYRUN$azure_blobs_token"
	 then
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	 fi &&
	 for path in $all_files $dbs
	 do
		# Upload the 64-bit database with the lease
		action=upload
		test x86_64/git-for-windows.db != $path || action="upload-with-lease ${PACMAN_DB_LEASE:-<lease>}"

		if test -n "$PACMANDRYRUN"
		then
			echo "upload: wingit-snapshot-helper.sh wingit $(map_arch ${path%%/*}) <token> $action $dir/$path" >&2
		else
			"$this_script_dir"/wingit-snapshot-helper.sh wingit $(map_arch ${path%%/*}) "$azure_blobs_token" $action "$path"
		fi ||
		die "Could not upload $path"
	 done) ||
	die "Could not upload $all_files $dbs"

	# Release the lease, i.e. finalize the transaction
	unlock "$PACMAN_DB_LEASE" ||
	die 'Could not release lock for uploading\n'
	PACMAN_DB_LEASE=

	# Remove the temporary directory
	rm -r "$dir" ||
	die "Could not remove $dir/"
}

lock () { #
	test -z "$PACMANDRYRUN" || {
		echo "upload: wingit-snapshot-helper.sh wingit x86-64 <token> lock git-for-windows.db" >&2
		return
	}

	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	echo "Trying to lock for upload..." >&2
	counter=0
	while test $counter -lt 7200
	do
		"$this_script_dir"/wingit-snapshot-helper.sh wingit x86-64 \
			"$azure_blobs_token" \
			lock --duration=-1 git-for-windows.db &&
		break

		echo "Waiting 60 seconds ($counter in total so far)..." >&2
		sleep 60
		counter=$(($counter+60))
	done
}

unlock () { # <lease-ID>
	test -z "$PACMANDRYRUN" || {
		echo "upload: wingit-snapshot-helper.sh wingit x86-64 <token> unlock ${1:-<lease>} git-for-windows.db" >&2
		return
	}

	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	"$this_script_dir"/wingit-snapshot-helper.sh wingit x86-64 \
		"$azure_blobs_token" unlock "$1" git-for-windows.db
}

break_lock () { #
	test -z "$PACMANDRYRUN" || {
		echo "upload: wingit-snapshot-helper.sh wingit x86-64 <token> break-lock git-for-windows.db" >&2
		return
	}

	test -n "$azure_blobs_token" || {
		azure_blobs_token="$(cat "$HOME"/.azure-blobs-token)" &&
		test -n "$azure_blobs_token" ||
		die "Could not read token from ~/.azure-blobs-token"
	}

	"$this_script_dir"/wingit-snapshot-helper.sh wingit x86-64 \
		"$azure_blobs_token" break-lock git-for-windows.db
}

file_exists () { # arch filename
	curl -sfI "$(arch_url $1)/$2" >/dev/null
}

push_missing_signatures () {
	list="$( (for arch in $architectures
		do
			dir="$(arch_dir $arch)"
			package_list "$dir/git-for-windows.db.tar.xz"
		done) |
		sort | uniq)"

	sign_option=
	test -z "$GPGKEY" || sign_option=--sign

	for name in $list
	do
		count=0
		basename=${name%-*-*}
		version=${name#$basename-}
		for arch in $architectures sources
		do
			case "$name,$arch" in
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
			mingw-w64-$arch,$arch)
				filename=$name-any.pkg.tar.xz
				;;
			mingw-w64-*)
				# wrong architecture
				continue
				;;
			*)
				filename=$name-$arch.pkg.tar.xz
				;;
			esac
			dir="$(arch_dir $arch)" &&
			test -f "$dir"/$filename.sig ||
			if test -n "$GPGKEY"
			then
				call_gpg --detach-sign --no-armor \
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
		mingw_db_name=git-for-windows-$(arch_to_mingw $arch).db.tar.xz
		for name in $(package_list $mingw_db_name)
		do
			case "$list2" in
			*" $name "*) ;; # okay, it's also in the full db
			*)
				repo-remove $sign_option $mingw_db_name \
					${name%-*-*} ||
				die "Could not remove $name from $mingw_db_name"
				count=$(($count+1))
				;;
			esac
		done

		for name in $list
		do
			case "$name" in
			mingw-w64-$arch-*)
				filename=$name-any.pkg.tar.xz
				s=$(arch_to_mingw $arch)
				db_name=git-for-windows-$s.db.tar.xz
				out="$(tar Oxf $db_name $name/desc)" ||
				die "Could not look for $name in $arch/mingw"

				test "a" = "a${out##*PGPSIG*}" || {
					count=$(($count+1))
					repo_add $sign_option $db_name $filename ||
					die "Could not add $name in $arch/mingw"
				}
				;;
			mingw-w64-*)
				# wrong architecture; skip
				continue
				;;
			*)
				filename=$name-$arch.pkg.tar.xz
				;;
			esac

			out="$(tar Oxf git-for-windows.db.tar.xz $name/desc)" ||
			die "Could not look for $name in $arch"

			test "a" = "a${out##*PGPSIG*}" || {
				count=$(($count+1))
				repo_add $sign_option git-for-windows.db.tar.xz \
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
				call_gpg --detach-sign --no-armor \
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

"$mode" "$@"

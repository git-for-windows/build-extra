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

mode=
case "$1" in
quick_add|quick_remove)
	mode="$1"
	shift
	;;
*)
	die "Usage:\n%s\n%s\n" \
		" $0 quick_add <package>..." \
		" $0 quick_remove <package>..."
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
mirror=/var/local/pacman-mirror

architectures="i686 x86_64 aarch64"

arch_dir () { # <architecture>
	echo "$mirror/$1"
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

repo_add () {
	if test ! -s "$this_script_dir/repo-add"
	then
		# The `build-installers` SDK that is used by the
		# `pacman-packages` action of
		# `git-for-windows/git-for-windows-automation` does not ship
		# `vercmp.exe`. Inject a small Bash function of the same name
		# (`repo-add` is a Bash script, so it picks it up at the call
		# site without any PATH manipulation), and make sure that
		# `GPGKEY` is used unquoted.
		{
			sed '1q' </usr/bin/repo-add &&
			cat <<\VERCMP_EOF &&
vercmp () {
    [[ "$1" = "$2" ]] && { echo 0; return; }
    local -a sa=( ${1//[^0-9A-Za-z]/ } )
    local -a sb=( ${2//[^0-9A-Za-z]/ } )
    local n=${#sa[@]}
    (( ${#sb[@]} < n )) && n=${#sb[@]}
    local i
    for (( i = 0; i < n; i++ )); do
        [[ "${sa[i]}" = "${sb[i]}" ]] && continue
        if [[ "${sa[i]}" =~ ^[0-9]+$ && "${sb[i]}" =~ ^[0-9]+$ ]]; then
            (( 10#${sa[i]} > 10#${sb[i]} )) && echo 1 || echo -1
            return
        fi
        [[ "${sa[i]}" =~ ^[0-9]+$ ]] && { echo  1; return; }
        [[ "${sb[i]}" =~ ^[0-9]+$ ]] && { echo -1; return; }
        [[ "${sa[i]}" > "${sb[i]}" ]] && echo 1 || echo -1
        return
    done
    (( ${#sa[@]} == ${#sb[@]} )) && { echo 0; return; }
    local extra sign
    if (( ${#sa[@]} > ${#sb[@]} )); then
        extra=${sa[n]}
        sign=1
    else
        extra=${sb[n]}
        sign=-1
    fi
    [[ "$extra" =~ ^[A-Za-z] ]] && echo $(( -sign )) || echo $sign
}
VERCMP_EOF
			sed '1d; s/"\(\${\?GPGKEY}\?\)"/\1/g' </usr/bin/repo-add
		} >"$this_script_dir/repo-add"
	fi &&
	"$this_script_dir/repo-add" "$@"
}

repo_remove () {
	if test ! -s "$this_script_dir/repo-remove"
	then
		# Make sure that GPGKEY is used unquoted
		 sed 's/"\(\${\?GPGKEY}\?\)"/\1/g' </usr/bin/repo-remove >"$this_script_dir/repo-remove"
	fi &&
	"$this_script_dir/repo-remove" $(for arg
	do
		# repo-remove only accepts package _names_, but we are potentially given _files_.
		# Handle this by distilling the package names from filenames.
		case "$arg" in
		*.pkg.tar.xz|*.pkg.tar.zst) echo "${arg%-*-*-*}";;
		*) echo "$arg";;
		esac
	done)
}

update_versions_json () { # <file> <version> <tagname>
	{
		test ! -f "$1" ||
		sed -n 's/^ *\("[^"]*": *"[^"]*"\).*/ \1/p' "$1"
		printf ' "%s": "%s"\n' "$2" "$3"
	} | sort -u | sed '$!s/$/,/' |
	{ printf '{\n'; cat; printf '}\n'; } >"$1.tmp" && mv "$1.tmp" "$1"
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
			if test -f "$path.sig" && gpg --verify "$path.sig"
			then
				continue
			fi
			call_gpg --detach-sign --no-armor -u $GPGKEY "$path" ||
			die "Could not sign $path"
		done
	fi
}

quick_action () { # <action> <file>...
	test $# -gt 1 ||
	die "Need at least one file"

	label="$1"
	shift
	case "$label" in
	add|remove) action=repo_$label;;
	*) die "Unknown action '$action'";;
	esac

	if test -z "$PACMANDRYRUN$GITHUB_TOKEN"
	then
		die 'Need `GITHUB_TOKEN` to upload the files to `git-for-windows/pacman-repo`'
	fi

	# Create a shallow, sparse & partial clone of
	# git-for-windows/pacman-repo to work with
	dir="$(mktemp -d)" &&
	git -C "$dir" init &&
	git -C "$dir" remote add origin https://github.com/git-for-windows/pacman-repo &&
	git -C "$dir" config set remote.origin.promisor true &&
	git -C "$dir" config set remote.origin.partialCloneFilter blob:none &&
	git -C "$dir" config set core.sparseCheckout true &&
	git -C "$dir" config set core.sparseCheckoutCone false &&
	mkdir -p "$dir"/.git/info &&
	printf '%s\n' '/git-*.db*' '/git-*.files*' '/*.versions.json' >"$dir"/.git/info/sparse-checkout &&
	printf '%s\n' '/git-for-windows.db*' '/git-for-windows.files*' >"$dir"/.git/info/exclude &&
	mkdir "$dir/sources" ||
	die "Could not create temporary directory"

	i686_mingw=
	i686_msys=
	aarch64_mingw=
	aarch64_msys=
	x86_64_mingw=
	x86_64_msys=
	all_files=

	# Copy the file(s) to the temporary directory, and schedule their addition to the appropriate index(es),
	# or for `remove`: schedule their removal from the appropriate index(es).
	for path in "$@"
	do
		file="${path##*/}"
		mingw=
		case "${path##*/}" in
		mingw-w64-*.pkg.tar.xz|mingw-w64-*.pkg.tar.zst)
			arch=${file##mingw-w64-}
			arch=${arch#clang-}
			arch=${arch#ucrt-}
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
		*-i686|*-x86_64|*-aarch64)
			test remove = "$label" || die "Cannot add $path"
			arch=${file##*-}
			file=${file%-$arch}
			file=${file%-[0-9]*-[0-9]*}
			key=${arch}_msys
			;;
		mingw-w64-i686-*|mingw-w64-x86_64-*|mingw-w64-ucrt-x86_64-*|mingw-w64-clang-aarch64-*)
			test remove = "$label" || die "Cannot add $path"
			arch=${file#mingw-w64-}
			arch=${arch#clang-}
			arch=${arch#ucrt-}
			arch=${arch%%-*}
			file=${file%-any}
			file=${file%-[0-9]*-[0-9]*}
			key=${arch}_mingw
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

		test -z "$key" || eval "$key=\$$key\\ $file"
		all_files="$all_files $arch/$file"

		if test ! -d "$dir/$arch"
		then
			echo "Initializing $dir/$arch..." >&2
			git -C "$dir" rev-parse --quiet --verify refs/remotes/origin/$arch >/dev/null ||
			git -C "$dir" fetch --depth=1 origin x86_64 aarch64 i686 ||
			die "$dir: could not fetch from pacman-repo"

			git -C "$dir" worktree add -b $arch $arch origin/$arch ||
			die "Could not initialize $dir/$arch"
		fi

		case "$label" in
		remove)
			test -z "$GPGKEY" ||
			all_files="$all_files $arch/$file.sig"
			continue
			;;
		esac

		echo "Copying $file to $arch/..." >&2
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

	# Add or remove files
	sign_option=
	test -z "$GPGKEY" || sign_option=--sign
	dbs=
	to_push=
	>"$dir/release_notes.txt"
	tagname="$(TZ=UTC date +%Y-%m-%dT%H-%M-%S.%NZ)"
	for arch in $architectures
	do
		eval "msys=\$${arch}_msys"
		eval "mingw=\$${arch}_mingw"
		test -n "$msys$mingw" || continue
		to_push="${to_push:+$to_push }$arch"

		git -C "$dir/$arch" pull --ff-only origin $arch ||
		die "Could not update $dir/$arch"

		case "$arch,$mingw" in
		*,) db2=; db3=;;
		i686,*) db2=mingw32; db3=;;
		*aarch64*) db2=clangarm64; db3=;;
		*)
			db2=mingw64
			db3=ucrt64
			;;
		esac
		for db in git-for-windows-$arch ${db2:+git-for-windows-$db2} ${db3:+git-for-windows-$db3}
		do
			for infix in db files
			do
				file=$db.$infix.tar.xz
				dbs="$dbs $arch/$file $arch/${file%.tar.xz}"
				test -z "$sign_option" ||
				dbs="$dbs $arch/$file.sig $arch/${file%.tar.xz}.sig"

				# Guard against duplicate package versions sneaking
				# into the database (a problem that has bitten us in
				# the past, unrelated to which backend hosts the repo).
				sanitize_db "$dir/$arch/$file" || return 1
			done
		done

		(cd "$dir/$arch" &&
		 # Now add or remove the files to the Pacman database
		 $action $sign_option git-for-windows-$arch.db.tar.xz $msys $mingw &&
		 { test ! -h git-for-windows-$arch.db || rm git-for-windows-$arch.db; } &&
		 cp git-for-windows-$arch.db.tar.xz git-for-windows-$arch.db && {
			test -z "$sign_option" || {
				{ test ! -h git-for-windows-$arch.db.sig || rm git-for-windows-$arch.db.sig; } &&
				cp git-for-windows-$arch.db.tar.xz.sig git-for-windows-$arch.db.sig
			}
		 } &&
		 for db in $db2 $db3
		 do
		 	if test -n "$db"
		 	then
				$action $sign_option git-for-windows-$db.db.tar.xz $mingw &&
				{ test ! -h git-for-windows-$db.db || rm git-for-windows-$db.db; } &&
				cp git-for-windows-$db.db.tar.xz git-for-windows-$db.db && {
					test -z "$sign_option" || {
						{ test ! -h git-for-windows-$db.db.sig || rm git-for-windows-$db.db.sig; } &&
						cp git-for-windows-$db.db.tar.xz.sig git-for-windows-$db.db.sig
					}
				}
			fi
		 done &&

		 # Remove the existing versions from the Git branch
		 printf '%s\n' $msys $mingw |
		 sed '/\.pkg\.tar/{
			s/-[^-]*-[^-]*-[^-]*\.pkg\.tar\.\(xz\|zst\)$/-[0-9]*/
			b1
		 }
		 s/$/-[0-9]*/
		 :1
		 p
		 # Prevent false positives (e.g. deleting `msys2-runtime-3.3` when
		 # updating `msys2-runtime`) by requiring the suffix to be of the form
		 # `-<pkgver>-<pkgrel>-<arch><pkgext>`. Sadly, there are no non-greedy
		 # wildcards, therefore do this via an "exclude pattern" instead:
		 # `:(exclude)<pkgname>-[0-9]*-*-*-*`
		 s/$/-*-*-*/
		 s/^/:(exclude)/' |
		 xargs git rm --sparse --cached --ignore-unmatch -- ||
		 die "Could not remove the existing versions from the Git branch in $arch"

		 # Now add the files to the Git branch
		 case "$label" in
		 add)
			git add --sparse $msys $mingw \*.sig ':(exclude)*.old.sig' &&
			for file in $msys $mingw
			do
				pkgname="${file%-*-*-*.pkg.tar.*}" &&
				remainder="${file#"$pkgname"-}" &&
				verrel="${remainder%-*.pkg.tar.*}" &&
				update_versions_json "$pkgname.versions.json" \
					"$verrel" "$tagname" ||
				die "Could not update %s\n" "$pkgname.versions.json"
			done &&
			git add --sparse '*.versions.json' &&
			msg="$(printf 'Update %s package(s)\n\n%s\n' \
				$(printf '%s\n' $msys $mingw | wc -l) \
				"$(printf '%s\n' $msys $mingw |
					sed 's/^\(.*\)-\([^-]*-[^-]*\)-[^-]*\.pkg\.tar\.\(xz\|zst\)$/\1 -> \2/')")"
			printf '%s\n' $msys $mingw |
			sed 's/^\(.*\)-\([^-]*-[^-]*\)-[^-]*\.pkg\.tar\.\(xz\|zst\)$/* \1 -> \2/' >>"$dir/release_notes.txt"
			;;
		 remove)
			 msg="$(printf 'Remove %s package(s)\n\n%s\n' \
				$(printf '%s\n' $msys $mingw | wc -l) \
				"$(printf '%s\n' $msys $mingw)")"
			printf '%s\n' $msys $mingw |
			sed 's/^/* dropped /' >>"$dir/release_notes.txt"
			;;
		 esac &&
		 git commit -asm "$msg") ||
		die "Could not ${label} $msys $mingw to/from db in $arch"
	done

	test -n "$to_push" || die "No packages to push?!"

	if test -n "$PACMANDRYRUN"
	then
		echo "Would push $to_push to git-for-windows/pacman-repo" >&2
	else
		auth="$(printf 'PAT:%s' "$GITHUB_TOKEN" | base64)" &&
		if test true = "$GITHUB_ACTIONS"
		then
			echo "::add-mask::$auth"
		fi &&
		extra_header="http.extraHeader=Authorization: Basic $auth" ||
		die "Could not configure auth header for git-for-windows/pacman-repo"
		if ! git -C "$dir" -c "$extra_header" push origin $to_push
		then
			# We must assume that another deployment happened concurrently.
			# No matter, we can easily adjust to that by reverting the
			# changes to the database and then trying again
			echo "There was a problem with the push; Assuming it was a concurrent update..." >&2
			for backoff in 5 10 15 20 -1
			do
				git -C "$dir" fetch origin $architectures || die "Could not update $dir"
				for arch in $to_push
				do
					# Avoid updating the branch if it is not necessary
					test 0 -lt $(git -C "$dir" rev-list --count $arch..origin/$arch) || continue

					echo "Rebasing $arch" >&2
					(cd "$dir/$arch" &&
					 git -C "$dir/$arch" checkout HEAD^ -- 'git-for-windows*.db*' 'git-for-windows*.files*' &&
					 # Revert .versions.json to parent state; re-inserted after rebase
					 git diff-tree --no-commit-id -r --name-only HEAD -- '*.versions.json' |
					 while IFS= read -r vjson
					 do
						if git cat-file -e "HEAD^:$vjson" 2>/dev/null
						then
							git checkout HEAD^ -- "$vjson"
						else
							git rm --cached -- "$vjson"
						fi || exit 1
					 done &&
					 git -C "$dir/$arch" commit --amend --no-edit &&
					 git -C "$dir/$arch" rebase origin/$arch &&

					 eval "msys=\$${arch}_msys" &&
					 eval "mingw=\$${arch}_mingw" &&
					 case "$label" in
					 add)
						printf '%s\n' $msys $mingw |
						sed 's/-[^-]*-[^-]*-[^-]*\.pkg\.tar\.\(xz\|zst\)$/-[0-9]*/' |
						xargs -r git restore --ignore-skip-worktree-bits --
						;;
					 esac &&
					 $action $sign_option git-for-windows-$arch.db.tar.xz $msys $mingw &&
					 { test ! -h git-for-windows-$arch.db || rm git-for-windows-$arch.db; } &&
					 cp git-for-windows-$arch.db.tar.xz git-for-windows-$arch.db && {
						test -z "$sign_option" || {
							{ test ! -h git-for-windows-$arch.db.sig || rm git-for-windows-$arch.db.sig; } &&
							cp git-for-windows-$arch.db.tar.xz.sig git-for-windows-$arch.db.sig
						}
					 } &&
					 if test -n "$db2"
					 then
						$action $sign_option git-for-windows-$db2.db.tar.xz $mingw &&
						{ test ! -h git-for-windows-$db2.db || rm git-for-windows-$db2.db; } &&
						cp git-for-windows-$db2.db.tar.xz git-for-windows-$db2.db && {
							test -z "$sign_option" || {
								{ test ! -h git-for-windows-$db2.db.sig || rm git-for-windows-$db2.db.sig; } &&
								cp git-for-windows-$db2.db.tar.xz.sig git-for-windows-$db2.db.sig
							}
						}
					 fi &&
					 # Re-insert .versions.json entries after rebase
					 case "$label" in
					 add)
						for file in $msys $mingw
						do
							pkgname="${file%-*-*-*.pkg.tar.*}" &&
							remainder="${file#"$pkgname"-}" &&
							verrel="${remainder%-*.pkg.tar.*}" &&
							update_versions_json "$pkgname.versions.json" \
								"$verrel" "$tagname" ||
							die "Could not update %s\n" "$pkgname.versions.json"
						done &&
						git add --sparse '*.versions.json'
						;;
					 esac &&
					 git -C "$dir/$arch" commit --amend --no-edit -- 'git-for-windows*.db*' 'git-for-windows*.files*' '*.versions.json') ||
					die "Could not update $dir/$arch"
				done
				git -C "$dir" -c "$extra_header" push origin $to_push && break

				test -1 != $backoff &&
				echo "Waiting $backoff seconds before retrying..." >&2 &&
				sleep $backoff ||
				die "Could not push to git-for-windows/pacman-repo"
			done
		fi
	fi

	# Mirror the deployment to a new GitHub Release
	# at `git-for-windows/pacman-repo`
	if test -n "$PACMANDRYRUN"
	then
		echo "Would create a GitHub Release '$tagname' at git-for-windows/pacman-repo" >&2
	else
		body="$(sed -z 's/[\"]/\\&/g;s/\n/\\n/g' "$dir/release_notes.txt")"
		id="$(curl -H "Authorization: Bearer $GITHUB_TOKEN" -sfL --show-error -XPOST -d \
			'{"tag_name":"'"$tagname"'","name":"'"$tagname"'","body":"'"$body"'","draft":true,"prerelease":true}' \
			"https://api.github.com/repos/git-for-windows/pacman-repo/releases" |
		sed -n 's/^  "id": *\([0-9]*\).*/\1/p')"
	fi ||
	die "Could not create a draft release for tag $tagname"
	for path in $(test remove = "$label" || echo $all_files) $dbs
	do
		if test -n "$PACMANDRYRUN"
		then
			echo "Would upload $path to release" >&2
			continue
		fi
		echo "Uploading $path to release $id" >&2
		case "$path" in
		*.sig) content_type=application/pgp-signature;;
		*) content_type=application/x-xz;;
		esac
		json="$(curl -H "Authorization: Bearer $GITHUB_TOKEN" -sfL --show-error -XPOST \
			-H "Content-Type: $content_type" \
			--data-binary "@$dir/$path" \
			"https://uploads.github.com/repos/git-for-windows/pacman-repo/releases/$id/assets?name=${path##*/}")" ||
		die "Could not upload $path to GitHub ($json)"
	done
	if test -n "$PACMANDRYRUN"
	then
		echo "Would mark GitHub Release at git-for-windows/pacman-repo as latest release" >&2
	else
		json="$(curl -H "Authorization: Bearer $GITHUB_TOKEN" -sfL --show-error -XPATCH \
			-d '{"draft":false,"prerelease":false,"make_latest":"true"}' \
			"https://api.github.com/repos/git-for-windows/pacman-repo/releases/$id")" &&
		echo "Uploaded $all_files $dbs to $(echo "$json" |
			sed -n 's/^  "html_url": "\(.*\)",$/\1/p')" ||
		die "Could not publish release $id ($json)"
	fi

	if test -n "$PACMANDRYRUN"
	then
		echo "Leaving temporary directory $dir/ for inspection" >&2
		return
	fi

	# Remove the temporary directory
	chmod -R +w "$dir/.git/objects" &&
	rm -r "$dir" ||
	die "Could not remove $dir/"
}

quick_add () {
	quick_action add "$@"
}

quick_remove () {
	quick_action remove "$@"
}

"$mode" "$@"

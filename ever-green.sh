#!/bin/sh

# Update an "ever-green branch", i.e. given a previously rebased branch
# thicket, update it both to include new changes in the original branch as well
# as rebasing the result to the new upstream branch.
#
# Most prominent example: shears/seen, which reflects Git for Windows' patches as
# rebased on top of the now-current "seen" branch.
#
# There are a couple of scenarios to keep in mind:
#
# - The branch could be maintained via merging-rebases, i.e. started with a
#   fake merge that merges in previous iterations (without taking any of the
#   changes, though).
#
# - The current branch might have advanced since the previous ever-green
#   update.
#
# - The upstream branch might have advanced since the previous ever-green
#   update.
#
# - The upstream branch might have been force-pushed since the previous
#   ever-green update.
#
# If there are new patches to rebase (i.e. if there are changes to the current
# branch that have not made it to the ever-green branch yet), and if the
# upstream branch has changed, we actually need *two* rebase runs. But we will
# pretend that to be a single rebase by appending the second rebase's todo
# script to the first one's.

die () {
	echo "$*" >&2
	exit 1
}
THIS_SCRIPT="$(realpath "$0")"

make_script () { # <tip-commit-to-rebase> <rebase-i-options>...
	# Create throw-away worktree in order to generate todo list
	worktree="$(git rev-parse --absolute-git-dir)/temp-rebase.$$"
	git worktree add --no-checkout "$worktree" "$1"^0 >&2
	shift

	cur_git_dir="$(git rev-parse --absolute-git-dir)"
	tmp_todo_list="$worktree.todo"
	rm -f "$tmp_todo_list" || die "Could not remove $tmp_todo_list"

	fake_editor="$(git -C "$worktree" rev-parse --absolute-git-dir)/fake-editor.sh" &&
	cat >"$fake_editor" <<-EOF &&
	#!/bin/sh

	cat "\$1" >"$tmp_todo_list" &&
	exit 1
	EOF
	chmod a+x "$fake_editor" &&

	if out="$(unset GIT_DIR; GIT_SEQUENCE_EDITOR="$fake_editor" git -C "$worktree" rebase -i "$@" 2>&1)" ||
		test ! -f "$tmp_todo_list"
	then
		die "Failed to generate todo list for 'rebase $*' in $PWD: $out"
	fi

	git worktree remove --force "$worktree" &&
	result="$(cat "$tmp_todo_list")" &&
	rm "$tmp_todo_list" &&
	echo "$result"
}

extract_todo_help () {
	help_starts_at="$(grep -n '^# Rebase .* ([0-9]* commands)' <"$1")"
	help_starts_at="${help_starts_at%%:*}"
	case "$help_starts_at" in
	'') help=;;
	*[^0-9]*) die "BUG: could not get start of help in $1";;
	*)
		mv -f "$1" "$1.raw" ||
		die "Could not rename $1"

		help="$(sed "1,$(($help_starts_at-2))d" <"$1.raw")"
		sed "$(($help_starts_at-1))q" >"$1" <"$1.raw"
		;;
	esac
	echo "$help"
}

# When stopped with conflicts during a rebase, this function determines whether
# there is an upstream commit (i.e. a commit reachable from HEAD but not from
# the original commit to be picked), and whether it is identical (except for
# Junio's Signed-off-by: line).
#
# Returns 0 if it is essentially identical, 1 if it is not (or if no upstream
# commit could be found).

compare_stopped_to_upstream_commit () {
	tip="$(cat "$(git rev-parse --git-path rebase-merge/stopped-sha)")" &&
	git rev-parse -q --verify "$tip" || {
		echo "Could not get stopped-sha; Not in a rebase?\n" >&2
		return 1
	}
	upstream=HEAD
	count=1

	upstream_commit="$(git range-diff -s $tip^..$tip $tip.."$upstream" |
		sed -n 's/^[^:]*:[^:]*[=!][^:]*: *\([^ ]*\).*/\1/p')"
	test -n "$upstream_commit" ||
		upstream_commit="$(git range-diff --creation-factor=95 -s $tip^..$tip $tip.."$upstream" |
			sed -n 's/^[^:]*:[^:]*[=!][^:]*: *\([^ ]*\).*/\1/p')"
	test -n "$upstream_commit" || {
		echo "Could not find upstream commit for '$tip'" >&2
		return 1
	}

	if git range-diff -s $tip^..$tip $upstream_commit^..$upstream_commit |
		grep -q '^1:  [^ ]* *= '
	then
		echo "$tip is identical to $upstream_commit; skipping" >&2
		return 0
	fi

	! git grep -q '^Signed-off-by: Junio.* <gitster@pobox\.com>$' "$upstream_commit" || {
		edited_upstream_commit="$(git cat-file commit "$upstream_commit" |
			sed '/^Signed-off-by: Junio.* <gitster@pobox\.com>$/d' |
			git hash-object -t commit -w --stdin)"
		if git range-diff -s $tip^..$tip $edited_upstream_commit^..$edited_upstream_commit |
			grep -q '^1:  [^ ]* *= '
		then
			echo "$tip is essentially identical to $upstream_commit; skipping" >&2
			return 0
		fi
	}

	printf "Found upstream commit %s for %s, but they are different:\n\n" "$upstream_commit" "$tip" >&2
	git range-diff --creation-factor=95 "$tip~$count..$tip" "$upstream_commit~$count..$upstream_commit"
	return 1
}

continue_rebase () {
	test -n "$ORIGINAL_GIT_EDITOR" ||
	ORIGINAL_GIT_EDITOR="$(git var GIT_EDITOR 2>/dev/null || echo false)"
	test -n "$ORIGINAL_GIT_EDITOR" ||
	die "Could not determine editor"
	export ORIGINAL_GIT_EDITOR

	export GIT_EDITOR="\"$THIS_SCRIPT\" fixup-quietly" ||
	die "Could not override editor"

	while true
	do
		msgnum="$(cat "$(git rev-parse --git-dir)/rebase-merge/msgnum")" ||
		die "Could not determine msgnum"

		git rev-parse --verify HEAD >"$(git rev-parse --git-dir)/cur-head" ||
		die "Could not record current HEAD"

		git diff-files --quiet || {
			compare_stopped_to_upstream_commit &&
			git add -u &&
			git reset --hard
		} ||
		die "There are unstaged changes; Cannot continue"

		git rebase --continue && break

		test "exec exit 123 # force re-reading of replacement objects" != \
			"$(tail -n 1 "$(git rev-parse --git-path rebase-merge/done)")" ||
		continue

		test "$msgnum" != "$(cat "$(git rev-parse --git-dir)/rebase-merge/msgnum")" ||
		exit 1

		test -f "$(git rev-parse --git-dir)/rebase-merge/stopped-sha" ||
		exit 1
	done
}

case "$1" in
replace-todo-script)
	shift
	cp -f "$(git rev-parse --git-dir)/replace-todo" "$1" ||
	die "Could not replace todo list"

	eval "$ORIGINAL_GIT_SEQUENCE_EDITOR \"$1\"" && exit
	die "Failed to call '$ORIGINAL_GIT_SEQUENCE_EDITOR'"
	;;
nested-rebase)
	shift

	case "$1" in
	--merging=*) merging="${1#*=}"; shift;;
	*) merging=;;
	esac

	todo="$(git rev-parse --git-path rebase-merge/git-rebase-todo)" &&
	help="$(extract_todo_help "$todo")" &&
	mv -f "$todo" "$todo.save" ||
	die "Could not save $todo"

	onto="$*"; onto="${onto#*--onto }"
	test "a$onto" != "a$*" ||
	die "Could not determine --onto from '$*'"
	onto="$(git rev-parse "${onto%% *}")" ||
	die "Invalid onto: '$*'"

	echo "# Now let's rebase the ever-green branch onto $onto" >"$todo" &&
	echo "reset $onto" >>"$todo" &&
	if test -n "$merging"
	then
		cat >>"$todo" <<-EOF
		exec git merge -s ours -m "\$(cat "\$GIT_DIR/merging-rebase-message")" "$merging"
		exec git replace --graft HEAD HEAD^
		exec exit 123 # force re-reading of replacement objects
		EOF
	fi &&
	make_script HEAD "$@" >>"$todo" ||
	die "Could not retrieve new todo list"

	help="$(extract_todo_help "$todo")" &&
	cat "$todo.save" >>"$todo" &&
	if test -n "$merging"
	then
		sed -e '/^exec.*fixup.*squash/{
			i\
exec git replace --delete "HEAD^{/^Start the merging-rebase}"
:1;N;b1
		}' -e '$a\
exec git replace --delete "HEAD^{/^Start the merging-rebase}"' "$todo" >"$todo.new" &&
		mv -f "$todo.new" "$todo" ||
		die "Could not append exec line to reset the replace ref"
	fi &&
	echo "$help" >>"$todo" ||
	die "Could not append saved todo commands"

	if test -z "$ORIGINAL_GIT_SEQUENCE_EDITOR"
	then
		# If ORIGINAL_GIT_SEQUENCE_EDITOR is no longer set, that means
		# that the rebase was interrupted and restarted, i.e. the
		# GIT_SEQUENCE_EDITOR is no longer overridden by ever-green.sh.
		ORIGINAL_GIT_SEQUENCE_EDITOR="$GIT_SEQUENCE_EDITOR"
		test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
		ORIGINAL_GIT_SEQUENCE_EDITOR="$(git config sequence.editor)"
		test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
			ORIGINAL_GIT_SEQUENCE_EDITOR="$(git var GIT_EDITOR 2>/dev/null || echo false)"
		test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
		die "Could not determine editor"
	fi
	eval "$ORIGINAL_GIT_SEQUENCE_EDITOR \"$todo\"" ||
	die "Could not launch $ORIGINAL_GIT_SEQUENCE_EDITOR"

	test -s "$todo" ||
	die "Aborted phase 2 of the ever-green rebase"

	exit 0
	;;
fixup-quietly)
	test "$(git rev-parse HEAD)" != "$(cat "$(git rev-parse --git-dir)/cur-head")" ||
	exit 0

	shift
	eval "$ORIGINAL_GIT_EDITOR" "$1" ||
	die "Could not execute $ORIGINAL_GIT_EDITOR!"

	exit 0
	;;
continue-rebase)
	shift
	test --skip != "$*" || {
		shift
		git add -u &&
		git reset --hard ||
		die "Could not --skip"
	}
	test -z "$*" ||
	die "Unhandled arguments: $*"
	continue_rebase
	exit 0
	;;
self-test)
	exec </dev/null
	tmp_worktree=/tmp/ever-green.self-test
	test ! -e "$tmp_worktree" || rm -rf "$tmp_worktree" || die "Could not remove $tmp_worktree"

	git init "$tmp_worktree" &&
	cd "$tmp_worktree" &&
	git config core.autocrlf false ||
	die "Could not init $tmp_worktree"

	git config user.name "Ever Green" &&
	git config user.email "eve@rgre.en" ||
	die "Could not configure committer"

	# Let's assume that we have a local branch and a remote branch, and we
	# want to keep developing the local branch, all the while the remote
	# branch is also advancing.
	#
	# The idea of an ever-green branch is to be a continuously-updated
	# branch that reflects what the local branch would look like, after
	# rebasing it to the remote branch.
	#
	# So what does this look like? Assume that we have this local branch:
	#
	# A - B - M - fixup D - E
	#   \   /
	#     D
	#
	# where A is the revision from the remote branch on which the local
	# branch was based. Then, let's assume that the remote branch added a
	# new commit, F. The ever-green branch would now look like this:
	#
	# A - F - B' - M' - E'
	#       \    /
	#         D'
	#
	# Obviously, the fixup for D would have been squashed into D while
	# updating the ever-green branch.
	#
	# To make things realistic, we slip in a change into E' that was not
	# there in E. This reflects scenarios where changes are necessary
	# during the rebase to make things work again, e.g. when a function
	# signature changes in F and E introduces a caller to said function.
	#
	# Now, let's make things *even* more realistic by adding *quite* a bit
	# of local work:
	#
	#             --------- C         R - S
	#           /             \             \
	# A - B - M - fixup D - E - N --- P - Q - T
	#   \   /   \                   /   /
	#     D       --------- fixup B - K
	#
	# And let's also throw in another remote commit: the remote branch now
	# looks like this:
	#
	# A - F - G
	#
	# At this stage, the tip of the local branch is S, the tip of the
	# remote branch is G, and the (outdated) ever-green branch's tip is E'.
	#
	# Now we want to use ever-green.sh to update the ever-green branch, so
	# that it looks like this:
	#
	#                       C"     R - S
	#                     /    \         \
	# A - F - G - B" - M" - E" - N" - Q" - T"
	#           \    /    \         /
	#             D"        K" ----
	#
	# where B" contains the fixup and E" is actually a rebased E' (instead
	# of a rebased E that would not have that extra change).
	#
	# Note that we do *not* want the cousins R and S to be rewritten; they
	# should stay the exact same. This reflects the situation where we want
	# to merge a branch from git.git's "seen" branch thicket into Git for
	# Windows' main branch, and then use the ever-green.sh script to rebase
	# on top of a newer "seen" branch thicket.

	test_commit () { # <mark> <parent(s)> <commit-message> [<file-name> [<contents>]]
		test -n "$2" || echo "reset refs/heads/main"
		printf '%s\n' \
			'commit refs/heads/main' \
			"mark :$1" \
			"committer Ever Green <eve@rgre.en> $((1234567890+$1)) +0000" \
			'data <<EOM' \
			"$3" \
			'EOM'
		test -z "$2" || {
			first=${2% *}
			echo "from :$first"
			for parent in ${2#$first}
			do
				echo "merge :$parent"
			done
		}
		test "a$4" = "a-" ||
		printf '%s\n' \
			"M 100644 inline ${4:-$3}" \
			'data <<EOD' \
			"${5:-${4:-$3}}" \
			'EOD'
		printf '%s\n' \
			"reset refs/tags/$(echo "$3" |
				sed 's/[^a-zA-Z0-9][^a-zA-Z0-9]*/-/g')" \
			"from :$1"
	}

	git fast-import <<-EOF || die "Could not import initial history"
	$(test_commit 1 '' A)
	$(test_commit 2 1 B)
	$(test_commit 3 1 D)
	$(test_commit 4 '2 3' M D)
	$(test_commit 5 4 C)
	$(test_commit 6 4 'fixup! D' D changed)
	$(test_commit 7 6 E)
	$(test_commit 8 '5 7' N E)
	$(test_commit 9 4 'fixup! B' B fixed-up)
	$(test_commit 10 '8 9' P B fixed-up)
	$(test_commit 11 9 K)
	$(test_commit 12 '10 11' Q K)
	$(test_commit 20 1 F)
	$(test_commit 21 20 G)
	$(test_commit 22 '' R)
	$(test_commit 23 22 S)
	$(test_commit 24 '12 23' T)
	EOF

	# Start ever-green branch
	git checkout -b ever-green E &&
	"$THIS_SCRIPT" --initial --onto=F &&
	echo "E1" >E &&
	git commit --amend -m E1 E ||
	die "Could not create previous ever-green"
	git tag pre-rebase

	git log --graph --format=%s --boundary A..ever-green >actual &&
	cat >expect <<-\EOF
	* E1
	* M
	|\
	| * D
	* | B
	|/
	* F
	o A
	EOF
	git -P diff --no-index -w expect actual ||
	die "Unexpected graph"

	"$THIS_SCRIPT" --current-tip=T --previous-tip=E --ever-green-base=F --onto=G ||
	die "Could not update ever-green branch"

	git log --graph --format=%s --boundary A..ever-green >actual &&
	cat >expect <<-\EOF
	* T
	|\
	| * S
	| * R
	* Q
	|\
	| * K
	*  | N
	|\  \
	| * | E1
	| |/
	* / C
	|/
	* M
	|\
	| * D
	* | B
	|/
	* G
	* F
	o A
	EOF
	git -P diff --no-index -w expect actual ||
	die "Unexpected graph"

	test changed = "$(git show ever-green:D)" ||
	die "Lost amendment to D"
	test fixed-up = "$(git show ever-green:B)" ||
	die "Lost amendment to B"
	test E1 = "$(git show ever-green:E)" ||
	die "Lost amendment to E"
	test 0 = $(git rev-list --count ever-green^2...S --) ||
	die "S was rewritten"

	# Now, let's do the same for merging-rebases
	git checkout -b merging-ever-green E &&
	"$THIS_SCRIPT" --initial --merging --onto=F &&
	echo "E1" >E &&
	git commit --amend -m E1 E ||
	die "Could not create previous ever-green"
	git tag merging-pre-rebase

	git log --graph --format=%s --boundary A..merging-ever-green ^E -- >actual &&
	cat >expect <<-\EOF
	* E1
	* M
	|\
	| * D
	* | B
	|/
	*   Start the merging-rebase to F
	|\
	* | F
	o | A
	 /
	o E
	EOF
	git -P diff --no-index -w expect actual ||
	die "Unexpected graph"

	"$THIS_SCRIPT" --current-tip=T --merging --onto=G ||
	die "Could not update ever-green branch"

	git log --graph --format=%s --boundary A..merging-ever-green ^T -- >actual &&
	cat >expect <<-\EOF
	*   T
	|\
	* \   Q
	|\ \
	| * | K
	* | |   N
	|\ \ \
	| * | | E1
	| |/ /
	* / / C
	|/ /
	* |   M
	|\ \
	| * | D
	* | | B
	|/ /
	* |   Start the merging-rebase to G
	|\ \
	* | | G
	* | | F
	o | | A
	 / /
	o / T
	|/
	o S
	EOF
	git -P diff --no-index -w expect actual ||
	die "Unexpected graph"

	git -P diff --exit-code ever-green -- ||
	die "Incorrect tree"

	test 0 = $(git rev-list --count merging-ever-green^2...S --) ||
	die "S was rewritten"

	exit 0
	;;
esac

# We need the following information:
#
# - the tip of the ever-green branch (HEAD)
#
# - the base commit of the ever-green branch
#
# - tip current tip commit of the original branch
#
# - the latest commit of the original branch that made it into the ever-green branch
#
# - the commit onto which we want to rebase the ever-green branch

usage="$0: <options>

This script expects the ever-green branch to be checked out.

Options:
--ever-green-base=<commit>
	Specify the base of the patch thicket of the ever-green branch (i.e. the
	target (\"onto\") of the most recent rebase of the ever-green branch)

--current-tip=<commit>
	Specify the tip commit of the original branch (possibly containing new
	commits to rebase)

--previous-tip=<commit>
	Specify the previous tip commit of the original branch, i.e. the commit
	on which the current version of the ever-green branch is based

--onto=<commit>
	Specify the tip of the upstream branch on which the ever-green branch
	is based

--merging-rebase
	Perform a merging-rebase; The ever-green branch must already be a
	merging rebase

--initial
	Start rebasing the ever-green branch, right after creating it from the
	tip commit of the original branch
"

ever_green_base=
current_tip=
previous_tip=
onto=
merging=
initial=
while case "$1" in
--ever-green-base=*) ever_green_base="${1#*=}";;
--current=*|--current-tip=*) current_tip="${1#*=}";;
--previous=*|--previous-tip=*) previous_tip="${1#*=}";;
--onto=*) onto="${1#*=}";;
--merging|--merging-rebase) merging=t;;
--merging=*|--merging-rebase=*) merging=t; current_tip="${1#*=}";;
--no-merging-rebase) merging=;;
--initial) initial=t;;
'') break;;
*) die "Unhandled parameter: $1
$usage";;
esac; do shift; done

test -n "$onto" || die "Need onto"

if test -n "$initial"
then
	test -z "$current_tip" || die "--initial and --current-tip=<commit> are incompatible"
	current_tip="$(git rev-parse --verify HEAD)" ||
	die "Could not parse HEAD"

	if test -n "$merging" && test -z "$previous_tip"
	then
		previous_tip="$(git rev-list -1 --grep='^Start the merging-rebase' "$current_tip" --)" ||
		die "Failed to look for a new merging-rebase"
	fi

	test -n "$previous_tip" ||
	previous_tip="$(git merge-base -a HEAD "$onto")" ||
	die "Could not find merge base between HEAD and $onto"
	case "$previous_tip" in
	''|*' '*) die "Could not determine unique merge base between HEAD and $onto, please use --previous-tip=<commit> to provide one";;
	esac

	git reset --hard "$previous_tip" ||
	die "Could not rewind to $previous_tip"

	test -z "$ever_green_base" || die "--initial and --ever-green-base=<commit> are incompatible"
	test -n "$merging" ||
	ever_green_base="$previous_tip"
fi

test -n "$current_tip" || die "Need current tip commit of the original branch"

if test -z "$merging"
then
	test -n "$ever_green_base" || die "Need base commit of the ever-green branch"
	test -n "$previous_tip" || die "Need previous tip commit of the original branch"

	current_base=
else
	test -z "$ever_green_base" || die "--merging and --ever-green-base=<commit> are incompatible"

	if test -z "$initial" && test -n "$previous_tip"
	then
		die "--merging and --previous-tip=<commit> are incompatible"
	fi

	# automagically determine previous tip, ever-green base from merging-rebase's start commit
	if test -z "$previous_tip"
	then
		previous_tip="$(git rev-list -1 --grep='^Start the merging-rebase' "..$current_tip" --)" ||
		die "Failed to look for a new merging-rebase"
	fi

	if test -n "$previous_tip"
	then
		# The original branch was merging-rebased in the meantime, so we ignore any existing ever-green state
		current_base="$previous_tip"
		git reset --hard "$current_base" ||
		die "Cannot roll back to $current_base"

		ever_green_base="$(git rev-parse --verify HEAD)" ||
		die "Could not determine HEAD"
	else
		ever_green_base="$(git rev-list -1 --grep='^Start the merging-rebase' "$current_tip.." --)" ||
		die "Failed to look for previous merging-rebase"

		if test -z "$ever_green_base"
		then
			die "Ever-green branch was not merging-rebased"
		else
			previous_tip="$(git rev-parse --verify "$ever_green_base"^2)" ||
			die "Could not determine previous tip from $ever_green_base"

			current_base="$(git cat-file commit "$ever_green_base" |
				sed -n 's/^This commit starts the rebase of \([^ ]*\) to .*/\1/p')"
			test -n "$current_base" ||
			die "Could not determine the base commit of the original branch thicket from $ever_green_base"
		fi
	fi
	cat >"$(git rev-parse --git-dir)/merging-rebase-message" <<-EOF
	Start the merging-rebase to $onto

	This commit starts the rebase of $(git rev-parse --short "$current_base") to $(git rev-parse --short "$onto")
	EOF
fi

# We do not expect fixup!/squash! commits in the ever-green branch
test -z "$(git log "$ever_green_base.." | sed -n '/^ *$/{N;/\n    \(fixup\|squash\)!/p}')" ||
die "Ever-green branches cannot have fixup!/squash! commits"

current_has_new_commits=
test 0 = $(git rev-list --count "$previous_tip..$current_tip" ^HEAD --) ||
current_has_new_commits=t

# Let's fall through if we have to create a merging-rebase
if test -z "$merging" && test -z "$current_has_new_commits"
then
	exec git rebase -kir --autosquash --onto "$onto" "$ever_green_base"
	die '`git rebase` failed to exec'
fi

not_in_ever_green="|$(git rev-list "${current_base:-HEAD}..$current_tip" -- | tr '\n' '|')"
contained_in_ever_green () {
	case "$not_in_ever_green" in
	*"|$1"*) return 1;; # no
	*) return 0;; # yes
	esac
}

is_merge () {
	case "$(git show -s --format=%p "$1")" in
	*" "*) return 0;; # yes
	*) return 1;; # no
	esac
}

is_fixup () {
	case "$(git show -s --format=%s "$1")" in
	"fixup!"*|"squash!"*) return 0;; # yes
	*) return 1;; # no
	esac
}

string2regex () {
	echo "$1" | sed 's/[]\\\/[*?]/\\&/g'
}

find_commit_by_oneline () {
	oneline="$(git show -s --format=%s "$1")"
	regex="$(string2regex "$oneline")"
	result="$(git rev-list --grep="^$regex" "$current_tip..HEAD" -- | tr '\n' ' ' | sed 's/ $//')"
	case "$result" in
	*' '*|'') return 1;; # multiple results found, or none
	*) echo "$result"; return 0;; # found exactly one
	esac
}

# range-diff does not include merge commits
if test 0 = "$(git rev-list --count "$ever_green_base.." --)"
then
	commit_map=
else
	commit_map="$(git range-diff -s "${current_base:-$onto}..$current_tip" "$ever_green_base.." |
		  sed -n 's/^[^:]*: *\([^ ]*\) [!=][^:]*: *\([^ ]*\).*/|\1=\2:/p')"
fi
map_base_commit () {
	while true
	do
		test -n "$1" || return 0 # dummy
		result="${commit_map#*|$1=}"
		if test "$commit_map" != "$result"
		then
			echo "${result%%:*}"
			return 0
		fi

		if contained_in_ever_green "$1"
		then
			echo "$1"
			return 0
		elif is_merge "$1"
		then
			# Try to find the merge commit by name
			find_commit_by_oneline "$1" && return 0 ||
			set -- "$(git rev-parse "$1"^)"
		elif is_fixup "$1"
		then
			# try parent
			set -- "$(git rev-parse "$1"^)"
		else
			# Fall back to 'onto'
			echo 'onto'
			return 0
		fi
	done
}

# This function rebases the new changes on top of the ever-green branch
pick_new_changes_onto_ever_green () {
	ever_green_tip="$(git rev-parse --verify HEAD)" ||
	die "Could not determine the tip of the ever-green (checked-out) branch"

	echo "reset $ever_green_tip"
	todo="$(make_script "$current_tip" -ki --autosquash --rebase-merges=no-rebase-cousins --onto "$ever_green_tip" "$previous_tip")" &&
	to_map="$(echo "$todo" |
		sed -n 's/^reset \([0-9a-f][0-9a-f]*\)\($\| .*\)/\1/p' |
		sort | uniq)"
	sed_args=
	for commit in $to_map
	do
		mapped=$(map_base_commit $commit)
		test -n "$mapped" ||
		die "Could not map $(git show --oneline -s $commit) to anything in <ever-green>"
		test -z "$mapped" ||
		sed_args="$sed_args -e 's/^reset $commit/reset $mapped/'"
	done

	test -z "$sed_args" ||
	todo="$(echo "$todo" |
		eval sed "$sed_args")" ||
	die "Could not edit todo via sed $sed_args"

	echo "$todo"
}

replace_todo="$(git rev-parse --absolute-git-dir)/replace-todo"
if test -z "$current_has_new_commits"
then
	if test 0 = $(git rev-list --count "$ever_green_tip".."$onto" --)
	then
		test -z "$initial" ||
		git reset --hard "$current_tip" ||
		die "Could not reset to $current_tip"

		echo "Nothing needs to be done" >&2
		exit 0
	fi

	# No new changes: let's rebase onto upstream right away!
	echo "# Rebase the ever-green branch onto $onto" >"$replace_todo" &&
	echo "reset $onto" >>"$replace_todo" &&
	if test -n "$merging"
	then
		cat >>"$replace_todo" <<-EOF
		exec git merge -s ours -m "\$(cat "\$GIT_DIR/merging-rebase-message")" "$current_tip"
		exec git replace --graft HEAD HEAD^
		exec exit 123 # force re-reading of replacement objects
		EOF
	fi &&
	make_script HEAD -ir --autosquash --onto "$onto" "$ever_green_base" >>"$replace_todo" ||
	die "Could not generate new todo list"

	help="$(extract_todo_help "$replace_todo")" ||
	die "Could not extract help text from $replace_todo"

	if test -n "$merging"
	then
		echo "exec git replace --delete 'HEAD^{/^Start the merging-rebase}'" >>"$replace_todo" ||
		die "Could not append exec line to reset the replace ref"
	fi
else
	pick_new_changes_onto_ever_green >"$replace_todo" ||
	die "Could not generate todo list for $previous_tip..$current_tip"

	help="$(extract_todo_help "$replace_todo")" ||
	die "Could not extract todo help from $replace_todo"

	if test -n "$merging" || test 0 -lt $(git rev-list --count "$ever_green_tip".."$onto" --)
	then
		# The second rebase's todo list can only be generated after the first one is done

		cat >>"$replace_todo" <<-EOF

		# Now perform the rebase onto $onto
		exec "$THIS_SCRIPT" nested-rebase ${merging:+--merging="$current_tip"} -kir --autosquash --onto "$onto" "$ever_green_base"
		EOF
	fi
fi

cat >>"$replace_todo" <<EOF

# error on fixup!/squash! commits in the ever-green branch
exec test -z "\$(git log "$onto.." $(test -z "$merging" || echo ^HEAD^{/^Start.the.merging-rebase}) | sed -n '/^ *$/{N;/\n    \(fixup\|squash\)!/p}')" || { echo "Ever-green branches cannot contain fixup!/squash! commits" >&2; exit 1; }
EOF

test -z "$help" ||
echo "$help" >>"$replace_todo" ||
die "Could not append rebase help text to $replace_todo"

# In non-interactive mode, skip editor
test -t 0 ||
export GIT_SEQUENCE_EDITOR=true

export ORIGINAL_GIT_SEQUENCE_EDITOR="$GIT_SEQUENCE_EDITOR"
test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" || {
	ORIGINAL_GIT_SEQUENCE_EDITOR="$(git config sequence.editor)"
	test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
	ORIGINAL_GIT_SEQUENCE_EDITOR="$(git var GIT_EDITOR 2>/dev/null || echo false)"
	test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
	die "Could not determine editor"
}
export GIT_SEQUENCE_EDITOR="\"$THIS_SCRIPT\" replace-todo-script"
git rebase -kir HEAD ||
continue_rebase

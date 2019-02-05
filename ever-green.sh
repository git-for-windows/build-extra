#!/bin/sh

# Update an "ever-green branch", i.e. given a previously rebased branch
# thicket, update it both to include new changes in the original branch as well
# as rebasing the result to the new upstream branch.
#
# Most prominent example: shears/pu, which reflects Git for Windows' patches as
# rebased on top of the now-current pu branch.
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

case "$1" in
replace-todo-script)
	shift
	cp -f "$(git rev-parse --git-dir)/replace-todo" "$1" ||
	die "Could not replace todo list"

	eval "\"$ORIGINAL_GIT_SEQUENCE_EDITOR\" \"$1\"" && exit
	die "Failed to call '$ORIGINAL_GIT_SEQUENCE_EDITOR'"
	;;
nested-rebase)
	shift
	todo="$(git rev-parse --git-path rebase-merge/git-rebase-todo)" &&
	help="$(extract_todo_help "$todo")" &&
	mv -f "$todo" "$todo.save" ||
	die "Could not save $todo"

	onto="$*"; onto="${onto#*--onto }"
	test "a$onto" != "a$*" ||
	die "Could not determine --onto from '$*'"
	onto="$(git rev-parse "${onto%% *}")" ||
	die "Invalid onto: '$*'"

	echo "# Now let's rebase the ever-green branch onto the upstream branch" >"$todo" &&
	echo "reset $onto" >>"$todo" &&
	make_script HEAD "$@" >>"$todo" ||
	die "Could not retrieve new todo list"

	help="$(extract_todo_help "$todo")" &&
	cat "$todo.save" >>"$todo" &&
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
			ORIGINAL_GIT_SEQUENCE_EDITOR="$(git var GIT_EDITOR)"
		test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
		die "Could not determine editor"
	fi
	eval "\"$ORIGINAL_GIT_SEQUENCE_EDITOR\" \"$todo\"" ||
	die "Could not launch $ORIGINAL_GIT_SEQUENCE_EDITOR"

	test -s "$todo" ||
	die "Aborted phase 2 of the ever-green rebase"

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
"

ever_green_base=
current_tip=
previous_tip=
onto=
while case "$1" in
--ever-green-base=*) ever_green_base="${1#*=}";;
--current=*|--current-tip=*) current_tip="${1#*=}";;
--previous=*|--previous-tip=*) previous_tip="${1#*=}";;
--onto=*) onto="${1#*=}";;
'') break;;
*) die "Unhandled parameter: $1
$usage";;
esac; do shift; done

test -n "$ever_green_base" || die "Need base commit of the ever-green branch"
test -n "$current_tip" || die "Need current tip commit of the original branch"
test -n "$previous_tip" || die "Need previous tip commit of the original branch"
test -n "$onto" || die "Need onto"

if test 0 = $(git rev-list --count "$previous_tip..$current_tip" -- )
then
	exec git rebase -kir --autosquash --onto "$onto" "$ever_green_base"
	die '`git rebase` failed to exec'
fi

# This function rebases the new changes on top of the ever-green branch
pick_new_changes_onto_ever_green () {
	ever_green_tip="$(git rev-parse --verify HEAD)" ||
	die "Could not determine the tip of the ever-green (checked-out) branch"

	echo "reset $ever_green_tip"
	make_script "$current_tip" -ki --autosquash --rebase-merges=rebase-cousins --onto "$ever_green_tip" "$previous_tip"
}

replace_todo="$(git rev-parse --absolute-git-dir)/replace-todo"
pick_new_changes_onto_ever_green >"$replace_todo" ||
die "Could not generate todo list for $previous_tip..$current_tip"

help="$(extract_todo_help "$replace_todo")" ||
die "Could not extract todo help from $replace_todo"

THIS_SCRIPT="$(realpath "$0")"
test 0 = $(git rev-list --count "$ever_green_tip".."$onto") || {
	cat >>"$replace_todo" <<-EOF

	# Now perform the rebase onto upstream
	exec "$THIS_SCRIPT" nested-rebase -kir --autosquash --onto "$onto" "$ever_green_base"
	EOF
}

test -z "$help" ||
echo "$help" >>"$replace_todo" ||
die "Could not append rebase help text to $replace_todo"

export ORIGINAL_GIT_SEQUENCE_EDITOR="$GIT_SEQUENCE_EDITOR"
test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" || {
	ORIGINAL_GIT_SEQUENCE_EDITOR="$(git config sequence.editor)"
	test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
	ORIGINAL_GIT_SEQUENCE_EDITOR="$(git var GIT_EDITOR)"
	test -n "$ORIGINAL_GIT_SEQUENCE_EDITOR" ||
	die "Could not determine editor"
}
export GIT_SEQUENCE_EDITOR="\"$THIS_SCRIPT\" replace-todo-script"
exec git rebase -kir HEAD ||
die "Could not start the 2-phase rebase"

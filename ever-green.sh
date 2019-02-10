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

die "TODO"

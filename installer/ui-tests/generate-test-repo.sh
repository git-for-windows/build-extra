#!/bin/sh
#
# Creates the repository the UI tests run against: a 'main' branch with
# enough history to keep `git log` in the pager, and a merged side
# branch so that gitk draws a graph.

test $# = 1 || { echo "usage: $0 <directory>" >&2; exit 1; }

# Ignore the user's configuration (identity, signing, hooks) and fix the
# dates, so that the result is the same everywhere.
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME='Test User' GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME='Test User' GIT_COMMITTER_EMAIL=test@example.com
export GIT_AUTHOR_DATE='1700000000 +0000' GIT_COMMITTER_DATE='1700000000 +0000'
# When run via a Git alias from a linked worktree, GIT_DIR points to
# the caller's repository.
unset GIT_DIR

git init -q --initial-branch=main "$1" &&
cd "$1" &&
for i in 1 2 3 4 5 6 7 8 9 10
do
	git commit -q --allow-empty -m "Commit $i on main" || exit
done &&
git checkout -q -b feature HEAD~5 &&
for i in 1 2 3
do
	git commit -q --allow-empty -m "Commit $i on feature" || exit
done &&
git checkout -q main &&
git merge -q --no-ff -m "Merge branch 'feature'" feature

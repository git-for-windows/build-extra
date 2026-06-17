#!/bin/sh
#
# Generates a git fast-import stream for a small test repository.
# The resulting history has ~20 commits across two branches with a merge,
# giving gitk a non-trivial graph to display and git log colorful output.
#
# Usage:
#   ./generate-test-repo.sh                          # stream to stdout
#   ./generate-test-repo.sh --create-test-repo=<dir> # init + import
#
# The repository will have:
#   - A 'main' branch with linear commits plus a merge from 'feature'
#   - A 'feature' branch that diverges and merges back
#   - Varied commit messages and file content for realistic log output

# Fixed committer so the repository is reproducible.
committer='Test User <test@example.com>'

mark=0
next_mark () {
	mark=$((mark + 1))
	echo "mark :$mark"
}

blob () {
	printf 'blob\n'
	next_mark
	printf 'data %d\n%s\n' ${#1} "$1"
}

commit () {
	printf 'commit refs/heads/%s\n' "$1"
	next_mark
	printf 'committer %s %s +0000\n' "$committer" "$3"
	printf 'data %d\n%s\n' "${#2}" "$2"
	if test -n "${4-}"
	then
		printf 'merge :%d\n' "$4"
	fi
}

file_modify () {
	printf 'M 100644 :%d %s\n' "$2" "$1"
}

generate_stream () {

	# --- main branch: initial commits ---

	blob "# Test Project

A small project used for UI test verification."
	readme_v1=$mark

	commit main "Initial commit" 1700000000
	file_modify README.md $readme_v1

	blob "function greet(name) {
  console.log('Hello, ' + name);
}

module.exports = { greet };
"
	greet_v1=$mark
	commit main "Add greeting module" 1700000100
	file_modify src/greet.js $greet_v1

	blob '{ "name": "test-project", "version": "1.0.0" }
'
	pkg_v1=$mark
	commit main "Add package.json" 1700000200
	file_modify package.json $pkg_v1

	blob "const { greet } = require('./greet');

greet('World');
"
	index_v1=$mark
	commit main "Add main entry point" 1700000300
	file_modify src/index.js $index_v1

	blob "node_modules/
*.log
"
	gitignore=$mark
	commit main "Add .gitignore" 1700000400
	file_modify .gitignore $gitignore

	# Remember the commit mark for the branch point so 'feature' starts here.
	branch_point=$mark

	blob "const { greet } = require('./greet');
const assert = require('assert');

assert.doesNotThrow(() => greet('Test'));
console.log('All tests passed');
"
	test_v1=$mark
	commit main "Add basic test" 1700000500
	file_modify test/test.js $test_v1

	blob "MIT License

Copyright (c) 2024 Test User
"
	license=$mark
	commit main "Add license file" 1700000600
	file_modify LICENSE $license

	# --- feature branch: diverges from the branch point ---

	blob "function greet(name) {
  console.log('Hello, ' + name);
}

function farewell(name) {
  console.log('Goodbye, ' + name);
}

module.exports = { greet, farewell };
"
	greet_farewell=$mark
	commit feature "Add farewell function" 1700000350
	printf 'from :%d\n' "$branch_point"
	file_modify src/greet.js $greet_farewell

	blob "const { greet, farewell } = require('./greet');

greet('World');
farewell('World');
"
	index_farewell=$mark
	commit feature "Use farewell in main" 1700000450
	file_modify src/index.js $index_farewell

	blob "function greet(name) {
  const message = 'Hello, ' + name;
  console.log(message);
  return message;
}

function farewell(name) {
  const message = 'Goodbye, ' + name;
  console.log(message);
  return message;
}

module.exports = { greet, farewell };
"
	greet_testable=$mark
	commit feature "Return messages for testability" 1700000550
	file_modify src/greet.js $greet_testable
	feature_tip=$mark

	# --- back to main: more commits before the merge ---

	blob "# Test Project

A small project used for UI test verification.

## Usage

    node src/index.js
"
	readme_usage=$mark
	commit main "Update README with usage instructions" 1700000700
	file_modify README.md $readme_usage

	blob '{ "name": "test-project", "version": "1.1.0" }
'
	pkg_v1_1=$mark
	commit main "Bump version to 1.1.0" 1700000800
	file_modify package.json $pkg_v1_1

	# --- merge feature into main ---

	blob "const { greet, farewell } = require('./greet');
const assert = require('assert');

assert.doesNotThrow(() => greet('Test'));
assert.doesNotThrow(() => farewell('Test'));
console.log('All tests passed');
"
	test_farewell=$mark
	commit main "Merge branch 'feature' into main" 1700000900 "$feature_tip"
	file_modify test/test.js $test_farewell
	file_modify src/greet.js $greet_testable

	# --- more commits on main after the merge ---

	blob "# Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
"
	contributing=$mark
	commit main "Add contributing guidelines" 1700001000
	file_modify CONTRIBUTING.md $contributing

	blob '{ "name": "test-project", "version": "1.2.0" }
'
	pkg_v1_2=$mark
	commit main "Bump version to 1.2.0" 1700001100
	file_modify package.json $pkg_v1_2

	blob "function greet(name) {
  const message = 'Hello, ' + name + '!';
  console.log(message);
  return message;
}

function farewell(name) {
  const message = 'Goodbye, ' + name + '!';
  console.log(message);
  return message;
}

module.exports = { greet, farewell };
"
	greet_excl=$mark
	commit main "Add exclamation marks to messages" 1700001200
	file_modify src/greet.js $greet_excl

	blob "# Changelog

## 1.2.0
- Add farewell function
- Add exclamation marks to messages
- Add contributing guidelines

## 1.1.0
- Add usage instructions to README

## 1.0.0
- Initial release
"
	changelog=$mark
	commit main "Add changelog" 1700001300
	file_modify CHANGELOG.md $changelog

	blob '{ "name": "test-project", "version": "1.2.1" }
'
	pkg_v1_2_1=$mark
	commit main "Bump version to 1.2.1" 1700001400
	file_modify package.json $pkg_v1_2_1

	printf 'done\n'
}

case "${1-}" in
--create-test-repo=*)
	dir="${1#--create-test-repo=}"
	git init --initial-branch=main "$dir" &&
	generate_stream | git -C "$dir" fast-import
	;;
*)
	generate_stream
	;;
esac

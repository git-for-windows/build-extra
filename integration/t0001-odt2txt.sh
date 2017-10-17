#!/bin/bash

test_description="Comparing Open doucument files as text"

. ./setup.sh

test_expect_success "Compare odt files as text" "
    git init
    git config diff.mnemonicprefix true
    cp $DIR_TEST/.gitattributes .
    cp $DIR_TEST/a.odt .
    git add .
    git commit -m 'file a'
    cp $DIR_TEST/b.odt a.odt
    git diff --ext-diff > diff_result
    diff $DIR_TEST/result diff_result
"

test_done

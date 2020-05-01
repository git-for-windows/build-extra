#!/bin/bash

# Check if git is running
# -x flag only match processes whose name (or command line if -f is specified) exactly match the pattern. 
if pgrep -x "git-bash.exe" > /dev/null
then
    echo "An update has been detected, unfortunately we cannot update while git is running."
else
    exec git update-git-for-windows
fi

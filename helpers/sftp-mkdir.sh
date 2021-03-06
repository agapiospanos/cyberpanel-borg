#!/bin/bash

# This script will recursively create a dir if not exists

CURRENT_DIR="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
PARENT_DIR="$(dirname "${CURRENT_DIR}")"

source "$PARENT_DIR"/config.sh

# Removing the leading / if exists since keeping it would add an empty string as the first element to our DIR_ACCUMULATOR array
DIR="${1#/}"

if [[ -z $DIR ]]; then
    echo "-- Please set a directory to be created"
    echo "-- Usage: sftp-create-dir-recursively.sh the/directory/to/be/created"
    exit 1
fi

# IFS stands for "internal field separator". It is used by the shell to determine how to do word splitting, i. e. how to recognize word boundaries. More here https://unix.stackexchange.com/a/184867
IFS=/ read -r -a DIRS <<<"$DIR"

# This is usefull to add the next child dir to be created as a string (e.g. dir1, then dir1/dir2 and then dir1/dir2/dir3)
DIR_ACCUMULATOR=()

for DIR in "${DIRS[@]}"; do
    DIR_ACCUMULATOR+=("$DIR")
    DIR_TO_CREATE=$(
        IFS=/
        echo "${DIR_ACCUMULATOR[*]}"
    )
    # We have to check if the dir already exists. Otherwise mkdir fails
    if ! echo "chdir '$DIR_TO_CREATE'" | sftp $SFTP_PIPE_OPTIONS >/dev/null 2>&1; then
        echo "mkdir '$DIR_TO_CREATE'" | sftp $SFTP_PIPE_OPTIONS >/dev/null 2>&1
    fi
done

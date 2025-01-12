#!/bin/bash

if [ "$GITHUB_ACTIONS" != "true" ]; then
    echo "This script should only be run as part of a GitHub Action"
    exit 1
fi

set -x

if [ "$1" == "-v" ]; then
    COUNT=$(jq length annotations.json)
    if [ "${COUNT}" != "0" ]; then
        JSON=$(cat annotations.json)
        for row in $(echo "${JSON}" | jq -r '.[] | @base64') ; do
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }
            FILE=$(_jq '.file')
            LINE=$(_jq '.line')
            TITLE=$(_jq '.title')
            MSG=$(_jq '.message')
            echo "::error file=${FILE},line=${LINE},title=${TITLE}::${MSG}" >>/dev/stderr
        done
        exit 1
    fi

    exit 0
fi

set -eu

# Find the Spoons that have been modified
SPOONS=$(cat "${HOME}/files.json" | jq -r -c '.[] | select(contains(".lua"))' | sed -e 's#^Source/\(.*\).spoon/.*#\1#' | sort | uniq)

if [ "${SPOONS}" == "" ]; then
    echo "No Spoons modified, skipping doc linting"
    exit 0
fi

mkdir -p annotations

while IFS= read -r SPOON ; do
    /usr/bin/python3 ./hammerspoon/scripts/docs/bin/build_docs.py -l -o annotations/ -n Source/${SPOON}.spoon
    mv annotations/annotations.json "annotations/${SPOON}-annotations.json"
done <<< "${SPOONS}"

jq -s '[.[][]]' annotations/*.json >annotations.json
rm -rf annotations/


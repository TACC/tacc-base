#!/bin/bash

set -euo pipefail

CONTAINER_RUNTIME="apptainer"
DELAY=3
ORG=""
REPO=""
TAGS=""


main() {
    check_args
    check_deps
    local url="https://hub.docker.com/v2/repositories/${ORG}/${REPO}/tags/"
    get_tags $url
    for f in $TAGS
    do
        image_url="docker://$ORG/$REPO/$f"
        image_file="$REPO_$f.sif"
        if [[ ! -s $image_file ]]; then
            echo "Pulling $image_url"
            $CONTAINER_RUNTIME pull $image_url 
            sleep $DELAY
        else
            echo "Image file '$image_file' exists, not pulling."
        fi
    done
}

check_args() {
    if [[ $# -ne 2 ]]; then
        echo '''Usage: download_images.sh ORG REPO

  ORG - the docker hub user/organization name
  REPO - the docker hub repository name

  Example:
  $ download_images.sh eriksf tacc-base
'''
        exit 1
    else
        ORG=$1
        REPO=$2
    fi
}

check_deps() {
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is not installed! Download from https://stedolan.github.io/jq/ and install."
        exit 1
    fi

    if ! command -v $CONTAINER_RUNTIME &>/dev/null; then
        echo "ERROR: $CONTAINER_RUNTIME is not loaded! Run 'module load tacc-$CONTAINER_RUNTIME'."
        exit 1
    fi
}

get_tags() {
    local page=$1
    local response=$(curl --silent --show-error "$page")
    local next=$(echo $response | jq -r '.next')
    local tags=$(echo $response | jq -r '.results[].name')
    TAGS+="$tags"
    if [[ "$next" != "null" ]]; then
        get_tags $next
    fi
}

main

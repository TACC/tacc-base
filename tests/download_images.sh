#!/bin/bash

set -euo pipefail

ORG=$1
REPO=$2
URL="https://hub.docker.com/v2/repositories/${ORG}/${REPO}/tags/"
CONTAINER_RUNTIME="apptainer"
DELAY=0
TAGS=""


main() {
    check_deps
    get_tags $URL
    for f in $TAGS
    do
        image_url="docker://$ORG/$REPO/$f"
        echo "Pulling $image_url"
        #$CONTAINER_RUNTIME pull $image_url 
        sleep $DELAY
    done
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

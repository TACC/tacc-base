#!/bin/bash

set -euo pipefail

CONTAINER_RUNTIME="apptainer"
DELAY=3

if [[ $# -ne 2 ]]; then
    echo '''Usage: download_images.sh ORG REPO

  ORG - the docker hub user/organization name
  REPO - the docker hub repository name

  Example:
  $ download_images.sh eriksf tacc-base
'''
    exit 1
fi

ORG=$1
REPO=$2
URL="https://hub.docker.com/v2/repositories/${ORG}/${REPO}/tags/"
BASE_PATH=$(dirname $(realpath $0))
TAGS=""

main() {
    check_deps
    get_tags $URL

    # make image directories
    for d in base ml mpi mpi-psm2 ml-mpi
    do
        if [[ ! -d "${BASE_PATH}/${d}" ]]; then
            mkdir -p "$BASE_PATH}/${d}"
        fi
    done

    for f in $TAGS
    do
        image_url="docker://${ORG}/${REPO}:${f}"
        image_dir="${BASE_PATH}/$(checktag $f)"
        image_file="${REPO}_${f}.sif"
        if [[ ! -s "${image_dir}/${image_file}" ]]; then
            echo "Pulling $image_url"
            $CONTAINER_RUNTIME pull $image_url --dir ${image_dir} 
            sleep $DELAY
        else
            echo "Image file '$image_dir/$image_file' exists, not pulling."
        fi
    done
}

function checktag() {
    local tag=$1
    local has_ml=0
    local has_mpi=0
    local has_mpi_psm2=0

    [[ $tag == *"-pt"* ]] && has_ml=1
    [[ $tag == *"-impi"* ]] && has_mpi=1
    [[ $tag == *"-mvapich"* ]] && has_mpi=1
    [[ $tag == *"-psm2"* ]] && has_mpi_psm2=1

    if [[ $has_mpi_psm2 -eq 1 ]]; then
        echo "mpi-psm2"
    elif [[ $has_ml -eq 1 && $has_mpi -eq 1 ]]; then
        echo "ml-mpi"
    elif [[ $has_mpi -eq 1 ]]; then
        echo "mpi"
    elif [[ $has_ml -eq 1 ]]; then
        echo "ml"
    else
        echo "base"
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
        TAGS+=$'\n'
        get_tags $next
    fi
}

main

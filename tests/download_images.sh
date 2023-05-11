#!/bin/bash

set -euo pipefail

CONTAINER_RUNTIME="apptainer"
DELAY=3

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo '''Usage: download_images.sh ORG REPO [IMGTYPE]

  ORG - the docker hub user/organization name
  REPO - the docker hub repository name
  IMGTYPE - type of images (all, base, ml, ml-mpi, mpi-ib, mpi-psm2) - default all

  Example:
  $ download_images.sh eriksf tacc-base ml
'''
    exit 1
fi

ORG=$1
REPO=$2
IMGTYPE=${3:-"all"}
IMGTYPE="${IMGTYPE,,}"
URL="https://hub.docker.com/v2/repositories/${ORG}/${REPO}/tags/"
BASE_PATH=$(dirname $(realpath $0))
TAGS=""
IMAGES=""

if [[ "$IMGTYPE" == "all" ]]; then
    IMAGES="base ml mpi-ib mpi-psm2 ml-mpi"
elif [[ "$IMGTYPE" == "base" || "$IMGTYPE" == "ml" || "$IMGTYPE" == "ml-mpi" || "$IMGTYPE" == "mpi-ib" || "$IMGTYPE" == "mpi-psm2" ]]; then
    IMAGES=$IMGTYPE
else
    echo "Optional IMGTYPE must be one of (all, base, ml, ml-mpi, mpi-ib, mpi-psm2)"
    exit 1
fi

main() {
    check_deps
    get_tags $URL

    # make image directories and setup symlinks
    for d in $IMAGES
    do
        if [[ ! -d "${BASE_PATH}/${d}" ]]; then
            echo "Creating path ${BASE_PATH}/${d}"
            mkdir -p "${BASE_PATH}/${d}"
        fi
        for l in tf_test.py torch_test.py pi-mpi.py
        do
            if [[ ! -L "${BASE_PATH}/${d}/${l}" ]]; then
                echo "Creating symlink ${BASE_PATH}/${l} to ${BASE_PATH}/${d}/${l}"
                ln -s -r "${BASE_PATH}/${l}" "${BASE_PATH}/${d}/${l}"
            fi
        done
    done

    for f in $TAGS
    do
        image_url="docker://${ORG}/${REPO}:${f}"
        image_dir="${BASE_PATH}/$(checktag $f)"
        image_file="${REPO}_${f}.sif"
        if [[ "$IMGTYPE" == "all" || "$(checktag $f)" == "$IMGTYPE" ]]; then
            if [[ ! -s "${image_dir}/${image_file}" ]]; then
                echo "Pulling $image_url"
                $CONTAINER_RUNTIME pull $image_url --dir ${image_dir} 
                sleep $DELAY
            else
                echo "Image file '$image_dir/$image_file' exists, not pulling."
            fi
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
        echo "mpi-ib"
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

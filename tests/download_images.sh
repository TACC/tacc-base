#!/bin/bash

set -euo pipefail

CONTAINER_RUNTIME="apptainer"
DELAY=3

if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo '''Usage: download_images.sh ORG REPO [IMGTYPE]

  ORG - the docker hub user/organization name
  REPO - the docker hub repository name
  IMGTYPE - type of images (all, frontera, ls6, stampede2, base, ml, ml-mpi-mvapich, ml-mpi-impi, mpi-mvapich-ib, mpi-mvapich-psm2, mpi-impi) - default all

  Example:
  $ download_images.sh eriksf tacc-base ls6
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
declare -A IMAGES=()

if [[ "$IMGTYPE" == "all" ]]; then
    IMAGES=([base]=1 [ml]=1 [mpi-mvapich-ib]=1 [mpi-mvapich-psm2]=1 [mpi-impi]=1 [ml-mpi-mvapich]=1 [ml-mpi-impi]=1)
elif [[ "$IMGTYPE" == "frontera" || "$IMGTYPE" == "ls6" ]]; then
    IMAGES=([base]=1 [ml]=1 [mpi-mvapich-ib]=1 [mpi-impi]=1 [ml-mpi-mvapich]=1 [ml-mpi-impi]=1)
elif [[ "$IMGTYPE" == "stampede2" ]]; then
    IMAGES=([base]=1 [mpi-mvapich-psm2]=1 [mpi-impi]=1)
elif [[ "$IMGTYPE" == "base" || \
        "$IMGTYPE" == "ml" || \
        "$IMGTYPE" == "ml-mpi-mvapich"|| \
        "$IMGTYPE" == "ml-mpi-impi" || \
        "$IMGTYPE" == "mpi-mvapich-ib" || \
        "$IMGTYPE" == "mpi-mvapich-psm2" || \
        "$IMGTYPE" == "mpi-impi" ]]; then
    IMAGES=([$IMGTYPE]=1)
else
    echo "Optional IMGTYPE must be one of (all, frontera, ls6, stampede2, base, ml, ml-mpi-mvapich, ml-mpi-impi, mpi-mvapich-ib, mpi-mvapich-psm2, mpi-impi)"
    exit 1
fi

main() {
    check_deps
    get_tags $URL

    # make image directories and setup symlinks
    for d in "${!IMAGES[@]}"
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
        if [[ -n "${IMAGES[$(checktag $f)]+_}" ]]; then
            if [[ ! -s "${image_dir}/${image_file}" ]]; then
                echo "Pulling $image_url"
                $CONTAINER_RUNTIME pull --dir ${image_dir} $image_url
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
    local mpi_type=""

    [[ $tag == *"-pt"* ]] && has_ml=1
    [[ $tag == *"-impi"* ]] && has_mpi=1 && mpi_type="impi"
    [[ $tag == *"-mvapich"* ]] && has_mpi=1 && mpi_type="mvapich"
    [[ $tag == *"-psm2"* ]] && has_mpi_psm2=1 && mpi_type="mvapich"

    if [[ $has_mpi_psm2 -eq 1 ]]; then
        echo "mpi-mvapich-psm2"
    elif [[ $has_ml -eq 1 && $has_mpi -eq 1 && $mpi_type == "mvapich" ]]; then
        echo "ml-mpi-mvapich"
    elif [[ $has_ml -eq 1 && $has_mpi -eq 1 && $mpi_type == "impi" ]]; then
        echo "ml-mpi-impi"
    elif [[ $has_mpi -eq 1 && $mpi_type == "mvapich" ]]; then
        echo "mpi-mvapich-ib"
    elif [[ $has_mpi -eq 1 && $mpi_type == "impi" ]]; then
        echo "mpi-impi"
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

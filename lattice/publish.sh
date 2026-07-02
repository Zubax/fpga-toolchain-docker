#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
TAG_LATEST="${TAG_LATEST:-1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-lattice"

REGISTRY="${REGISTRY}" TAG="${TAG}" TAG_LATEST="${TAG_LATEST}" ./build.sh

docker push "${REPO}:${TAG}"
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    docker push "${REPO}:latest"
fi

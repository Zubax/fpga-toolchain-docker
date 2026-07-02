#!/usr/bin/env bash
# Build the Lattice Diamond Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
DIAMOND_CONTEXT="${DIAMOND_CONTEXT:-/usr/local/diamond/3.14}"
REPO="${REGISTRY}/zubax-fpga-toolchain-lattice"
OSS_IMAGE="${OSS_IMAGE:-ghcr.io/zubax/zubax-fpga-toolchain-oss:${TAG}}"

[[ -f "${DIAMOND_CONTEXT}/license/license.dat" ]] || {
    echo "ERROR: Diamond license not found: ${DIAMOND_CONTEXT}/license/license.dat" >&2
    exit 1
}

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building Lattice image ${REPO}:${TAG} from ${DIAMOND_CONTEXT}"
docker buildx build \
    --platform "${PLATFORM}" \
    --load \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-context "diamond-src=${DIAMOND_CONTEXT}" \
    .

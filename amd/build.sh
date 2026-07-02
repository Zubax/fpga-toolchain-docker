#!/usr/bin/env bash
# Build the AMD Vivado Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-ghcr.io/zubax}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
VIVADO_CONTEXT="${VIVADO_CONTEXT:-/mnt/storage/xilinx/2025.2.1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-amd"
OSS_IMAGE="${OSS_IMAGE:-${REGISTRY}/zubax-fpga-toolchain-oss:${TAG}}"

[[ -d "${VIVADO_CONTEXT}/Vivado" ]] || {
    echo "ERROR: Vivado context does not look like an AMD release root: ${VIVADO_CONTEXT}" >&2
    exit 1
}

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building AMD image ${REPO}:${TAG} from ${VIVADO_CONTEXT}"
docker buildx build \
    --platform "${PLATFORM}" \
    --load \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-context "vivado-src=${VIVADO_CONTEXT}" \
    .

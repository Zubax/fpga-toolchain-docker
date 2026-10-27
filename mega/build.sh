#!/usr/bin/env bash
# Build the mega Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-mega"
OSS_IMAGE="${OSS_IMAGE:-ghcr.io/zubax/zubax-fpga-toolchain-oss:latest}"
AMD_IMAGE="${AMD_IMAGE:-${REGISTRY}/zubax-fpga-toolchain-amd:latest}"
LATTICE_IMAGE="${LATTICE_IMAGE:-${REGISTRY}/zubax-fpga-toolchain-lattice:latest}"
INTEL_IMAGE="${INTEL_IMAGE:-${REGISTRY}/zubax-fpga-toolchain-intel:latest}"

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building Mega image ${REPO}:${TAG}"
echo "Mega uses OSS_IMAGE=${OSS_IMAGE}, AMD_IMAGE=${AMD_IMAGE}, LATTICE_IMAGE=${LATTICE_IMAGE}, and INTEL_IMAGE=${INTEL_IMAGE}."
docker buildx build \
    --platform "${PLATFORM}" \
    --load \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-arg "AMD_IMAGE=${AMD_IMAGE}" \
    --build-arg "LATTICE_IMAGE=${LATTICE_IMAGE}" \
    --build-arg "INTEL_IMAGE=${INTEL_IMAGE}" \
    .

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
# PUSH=1 pushes straight from BuildKit instead of loading into the local image store,
# which avoids keeping a second unpacked copy of this very large image on disk.
PUSH="${PUSH:-0}"

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

output=(--load)
if [[ "${PUSH}" == "1" ]]; then
    output=(--push)
fi

echo "Building Mega image ${REPO}:${TAG}"
echo "Mega uses OSS_IMAGE=${OSS_IMAGE}, AMD_IMAGE=${AMD_IMAGE}, LATTICE_IMAGE=${LATTICE_IMAGE}, and INTEL_IMAGE=${INTEL_IMAGE}."
docker buildx build \
    --platform "${PLATFORM}" \
    "${output[@]}" \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-arg "AMD_IMAGE=${AMD_IMAGE}" \
    --build-arg "LATTICE_IMAGE=${LATTICE_IMAGE}" \
    --build-arg "INTEL_IMAGE=${INTEL_IMAGE}" \
    .

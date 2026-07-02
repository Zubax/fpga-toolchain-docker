#!/usr/bin/env bash
# Build the open-source Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-ghcr.io/zubax}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-oss"

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building OSS image ${REPO}:${TAG}"
docker buildx build --platform "${PLATFORM}" --load --file Dockerfile "${tags[@]}" .

#!/usr/bin/env bash
# Build the Altera/Intel Quartus Prime Lite Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-intel"
OSS_IMAGE="${OSS_IMAGE:-ghcr.io/zubax/zubax-fpga-toolchain-oss:latest}"

quartus_version() {
    "${1}/quartus/bin/quartus_sh" --version 2>/dev/null \
        | sed -n 's/^Version \([^[:space:]]*\).*/\1/p' | head -n 1
}

discover_quartus_context() {
    local executable context version
    local -a candidates=()

    while IFS= read -r -d '' executable; do
        context="${executable%/quartus/bin/quartus_sh}"
        version="$(quartus_version "${context}")" || continue
        [[ -n "${version}" ]] || continue
        candidates+=("${version}"$'\t'"${context}")
    done < <(find "${HOME}" /opt -type f -path '*/quartus/bin/quartus_sh' -executable -print0 2>/dev/null)

    ((${#candidates[@]} > 0)) || return 1
    printf '%s\n' "${candidates[@]}" | LC_ALL=C sort -V | tail -n 1 | cut -f 2-
}

if [[ -z "${QUARTUS_CONTEXT:-}" ]]; then
    QUARTUS_CONTEXT="$(discover_quartus_context)" || {
        echo "ERROR: Could not find a Quartus release root under ${HOME} or /opt." >&2
        echo "Set QUARTUS_CONTEXT explicitly to the release root containing quartus/bin/quartus_sh." >&2
        exit 1
    }
fi
[[ -x "${QUARTUS_CONTEXT}/quartus/bin/quartus_sh" ]] || {
    echo "ERROR: Quartus context does not look like a Quartus release root: ${QUARTUS_CONTEXT}" >&2
    exit 1
}
QUARTUS_CONTEXT="$(realpath "${QUARTUS_CONTEXT}")"
QUARTUS_VERSION="$(quartus_version "${QUARTUS_CONTEXT}")"
[[ -n "${QUARTUS_VERSION}" ]] || {
    echo "ERROR: Could not determine the Quartus version in ${QUARTUS_CONTEXT}" >&2
    exit 1
}

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building Intel image ${REPO}:${TAG} with Quartus ${QUARTUS_VERSION} from ${QUARTUS_CONTEXT}"
docker buildx build \
    --platform "${PLATFORM}" \
    --load \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-arg "QUARTUS_VERSION=${QUARTUS_VERSION}" \
    --build-context "quartus-src=${QUARTUS_CONTEXT}" \
    .

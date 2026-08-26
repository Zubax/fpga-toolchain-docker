#!/usr/bin/env bash
# Build the AMD Vivado Zubax FPGA toolchain image.

set -euo pipefail

cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
PLATFORM="${PLATFORM:-linux/amd64}"
TAG_LATEST="${TAG_LATEST:-1}"
REPO="${REGISTRY}/zubax-fpga-toolchain-amd"
OSS_IMAGE="${OSS_IMAGE:-ghcr.io/zubax/zubax-fpga-toolchain-oss:latest}"

vivado_version() {
    "${1}/Vivado/bin/vivado" -version 2>/dev/null \
        | sed -n 's/^vivado v\([^[:space:]]*\).*/\1/p'
}

discover_vivado_context() {
    local executable context version
    local -a candidates=()

    while IFS= read -r -d '' executable; do
        context="${executable%/Vivado/bin/vivado}"
        version="$(vivado_version "${context}")" || continue
        [[ -n "${version}" ]] || continue
        candidates+=("${version}"$'\t'"${context}")
    done < <(find "${HOME}" /opt -type f -path '*/Vivado/bin/vivado' -executable -print0 2>/dev/null)

    ((${#candidates[@]} > 0)) || return 1
    printf '%s\n' "${candidates[@]}" | LC_ALL=C sort -V | tail -n 1 | cut -f 2-
}

if [[ -z "${VIVADO_CONTEXT:-}" ]]; then
    VIVADO_CONTEXT="$(discover_vivado_context)" || {
        echo "ERROR: Could not find a Vivado release root under ${HOME} or /opt." >&2
        echo "Set VIVADO_CONTEXT explicitly to the release root containing Vivado/bin/vivado." >&2
        exit 1
    }
fi
[[ -d "${VIVADO_CONTEXT}" ]] || {
    echo "ERROR: Vivado context does not exist: ${VIVADO_CONTEXT}" >&2
    exit 1
}
VIVADO_CONTEXT="$(realpath "${VIVADO_CONTEXT}")"

[[ -x "${VIVADO_CONTEXT}/Vivado/bin/vivado" ]] || {
    echo "ERROR: Vivado context does not look like an AMD release root: ${VIVADO_CONTEXT}" >&2
    exit 1
}
VIVADO_VERSION="$(vivado_version "${VIVADO_CONTEXT}")"
[[ -n "${VIVADO_VERSION}" ]] || {
    echo "ERROR: Could not determine the Vivado version in ${VIVADO_CONTEXT}" >&2
    exit 1
}

if [[ -z "${VIVADO_LICENSE:-}" ]]; then
    if [[ -f "${XILINXD_LICENSE_FILE:-}" ]]; then
        VIVADO_LICENSE="${XILINXD_LICENSE_FILE}"
    else
        VIVADO_LICENSE="${HOME}/.Xilinx/Xilinx.lic"
    fi
fi
[[ -f "${VIVADO_LICENSE}" ]] || {
    echo "ERROR: Vivado license file not found: ${VIVADO_LICENSE}" >&2
    echo "Set VIVADO_LICENSE explicitly to the license file to embed in the image." >&2
    exit 1
}
VIVADO_LICENSE="$(realpath "${VIVADO_LICENSE}")"
VIVADO_LICENSE_SHA256="$(sha256sum "${VIVADO_LICENSE}" | cut -d ' ' -f 1)"

tags=(--tag "${REPO}:${TAG}")
if [[ "${TAG_LATEST}" == "1" && "${TAG}" != "latest" ]]; then
    tags+=(--tag "${REPO}:latest")
fi

echo "Building AMD image ${REPO}:${TAG} with Vivado ${VIVADO_VERSION} from ${VIVADO_CONTEXT}"
docker buildx build \
    --platform "${PLATFORM}" \
    --load \
    --file Dockerfile \
    "${tags[@]}" \
    --build-arg "OSS_IMAGE=${OSS_IMAGE}" \
    --build-arg "VIVADO_VERSION=${VIVADO_VERSION}" \
    --build-arg "VIVADO_LICENSE_SHA256=${VIVADO_LICENSE_SHA256}" \
    --build-context "vivado-src=${VIVADO_CONTEXT}" \
    --secret "id=vivado-license,src=${VIVADO_LICENSE}" \
    .

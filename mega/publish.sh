#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

REGISTRY="${REGISTRY:-containers.zubax.com}"
TAG="${TAG:-$(date +%F)}"
TAG_LATEST="${TAG_LATEST:-1}"

REGISTRY="${REGISTRY}" TAG="${TAG}" TAG_LATEST="${TAG_LATEST}" PUSH=1 ./build.sh

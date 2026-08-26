#!/usr/bin/env bash
# Run a command (or interactive shell, the default) inside the container, mounting the current directory at /work.
# If $DISPLAY is set, the host X server is shared so GUI tools (GTKWave) work.
#
# Non-OSS images may configure node-locked license MACs internally; grant NET_ADMIN for that setup.

set -euo pipefail

IMAGE=${IMAGE:-ghcr.io/zubax/zubax-fpga-toolchain-oss:latest}

docker_args=(--rm -i)
if [[ -t 0 ]]; then
    docker_args+=(-t)
fi
docker_args+=(-v "$PWD:/work" -w /work)

if [[ -n "${DISPLAY:-}" ]]; then
    docker_args+=(-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix)
fi

if [[ "${IMAGE}" != *zubax-fpga-toolchain-oss* ]]; then
    docker_args+=(--cap-add NET_ADMIN)
fi

exec docker run "${docker_args[@]}" "$IMAGE" "$@"

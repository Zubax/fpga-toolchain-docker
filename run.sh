#!/usr/bin/env bash
# Run a command (or interactive shell, the default) inside the container, mounting the current directory at /work.
# If $DISPLAY is set, the host X server is shared so GUI tools (GTKWave) work.
#
# Lattice/Mega images configure the Diamond license MAC internally; grant NET_ADMIN for that best-effort setup.

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

if [[ "${IMAGE}" == *zubax-fpga-toolchain-lattice* || "${IMAGE}" == *zubax-fpga-toolchain-mega* ]]; then
    docker_args+=(--cap-add NET_ADMIN)
    if [[ -n "${LATTICE_DUMMY_MAC:-}" ]]; then
        docker_args+=(-e "LATTICE_DUMMY_MAC=${LATTICE_DUMMY_MAC}")
    fi
fi

exec docker run "${docker_args[@]}" "$IMAGE" "$@"

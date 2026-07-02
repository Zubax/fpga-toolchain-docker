#!/usr/bin/env bash
# Run a command (or interactive shell, the default) inside the container, mounting the current directory at /work.
# If $DISPLAY is set, the host X server is shared so GUI tools (GTKWave) work.
#
# For Lattice/Mega images, set DIAMOND_LICENSE_MAC for Docker's eth0 MAC override,
# or LATTICE_DUMMY_MAC to request the runtime dummy0 fallback.

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

if [[ -n "${DIAMOND_LICENSE_MAC:-}" ]]; then
    docker_args+=(--mac-address "${DIAMOND_LICENSE_MAC}")
fi

if [[ -n "${LATTICE_DUMMY_MAC:-}" ]]; then
    docker_args+=(--cap-add NET_ADMIN -e "LATTICE_DUMMY_MAC=${LATTICE_DUMMY_MAC}")
    exec docker run "${docker_args[@]}" "$IMAGE" diamond-net-init "$@"
fi

exec docker run "${docker_args[@]}" "$IMAGE" "$@"

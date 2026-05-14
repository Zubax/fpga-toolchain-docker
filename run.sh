#!/usr/bin/env bash
# Run a command (or interactive shell, the default) inside the Zubax FPGA toolchain container,
# mounting the current directory at /work.
# If $DISPLAY is set, the host X server is shared so GUI tools (GTKWave) work.

set -euo pipefail

IMAGE=${IMAGE:-zubax-fpga-toolchain}

[[ -t 0 ]] && tty=-t || tty=

exec docker run --rm -i $tty \
    -v "$PWD:/work" -w /work \
    ${DISPLAY:+-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix} \
    "$IMAGE" "$@"

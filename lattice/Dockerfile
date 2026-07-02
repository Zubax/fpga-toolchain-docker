# syntax=docker/dockerfile:1.7
#
# Lattice Diamond FPGA toolchain image.
#
# This image is private because it contains proprietary tool payloads and the
# local node-locked Diamond license copied from the Diamond build context.
#
# Build:
#   docker buildx build --load \
#       --build-context diamond-src=/usr/local/diamond/3.14 \
#       -f lattice/Dockerfile -t containers.zubax.com/zubax-fpga-toolchain-lattice:latest lattice

ARG OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
FROM ${OSS_IMAGE}

ARG DIAMOND_VERSION=3.14
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-lattice"
LABEL org.opencontainers.image.description="Zubax open-source FPGA toolchain plus Lattice Diamond with a private CI runner license."

USER root

# Build with: --build-context diamond-src=/usr/local/diamond/3.14
COPY --from=diamond-src / /usr/local/diamond/${DIAMOND_VERSION}/
COPY diamond-env diamond-tool diamond-net-init /usr/local/bin/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends iproute2; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chmod 0755 /usr/local/bin/diamond-env /usr/local/bin/diamond-tool /usr/local/bin/diamond-net-init; \
    mkdir -p /lib64; \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3; \
    test -f "/usr/local/diamond/${DIAMOND_VERSION}/license/license.dat"; \
    for tool in \
        diamond diamondc pnmainc fpgac edif2ngd ngdbuild map par trce bitgen \
        synthesis synpwrap pgrcmd ddtcmd cableserver lmutil lmhostid; \
    do \
        ln -sf /usr/local/bin/diamond-tool "/usr/local/bin/${tool}"; \
    done; \
    diamond-env par -h | head -n1 | grep -q 'version Diamond'; \
    lmutil lmhostid >/dev/null

ENV DIAMOND_ROOT=/usr/local/diamond/${DIAMOND_VERSION}

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

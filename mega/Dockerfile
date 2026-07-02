# syntax=docker/dockerfile:1.7
#
# Mega FPGA toolchain image. This image is built only from already-published
# private registry images so local Vivado/Diamond installs are not required.
#
# Build:
#   docker buildx build --load \
#       --build-arg AMD_IMAGE=containers.zubax.com/zubax-fpga-toolchain-amd:latest \
#       --build-arg LATTICE_IMAGE=containers.zubax.com/zubax-fpga-toolchain-lattice:latest \
#       -f mega/Dockerfile -t containers.zubax.com/zubax-fpga-toolchain-mega:latest mega

ARG AMD_IMAGE=containers.zubax.com/zubax-fpga-toolchain-amd:latest
ARG LATTICE_IMAGE=containers.zubax.com/zubax-fpga-toolchain-lattice:latest

FROM ${LATTICE_IMAGE} AS lattice
FROM ${AMD_IMAGE}

ARG DIAMOND_VERSION=3.14
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-mega"
LABEL org.opencontainers.image.description="Zubax FPGA mega toolchain with open-source tools, AMD Vivado, and Lattice Diamond."

USER root

COPY --from=lattice /usr/local/diamond/${DIAMOND_VERSION}/ /usr/local/diamond/${DIAMOND_VERSION}/
COPY --from=lattice /usr/local/bin/diamond-env /usr/local/bin/diamond-env
COPY --from=lattice /usr/local/bin/diamond-tool /usr/local/bin/diamond-tool
COPY --from=lattice /usr/local/bin/diamond-net-init /usr/local/bin/diamond-net-init

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends iproute2; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chmod 0755 /usr/local/bin/diamond-env /usr/local/bin/diamond-tool /usr/local/bin/diamond-net-init; \
    mkdir -p /lib64; \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3; \
    for tool in \
        diamond diamondc pnmainc fpgac edif2ngd ngdbuild map par trce bitgen \
        synthesis synpwrap pgrcmd ddtcmd cableserver lmutil lmhostid; \
    do \
        ln -sf /usr/local/bin/diamond-tool "/usr/local/bin/${tool}"; \
    done; \
    test -f "/usr/local/diamond/${DIAMOND_VERSION}/license/license.dat"; \
    yosys -V; \
    printf '%s\n' 'puts [version -short]' 'exit' > /tmp/vivado-smoke.tcl; \
    vivado -mode batch -nojournal -nolog -notrace -source /tmp/vivado-smoke.tcl; \
    rm -f /tmp/vivado-smoke.tcl; \
    diamond-env par -h | head -n1 | grep -q 'version Diamond'; \
    lmutil lmhostid >/dev/null

ENV DIAMOND_ROOT=/usr/local/diamond/${DIAMOND_VERSION}

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

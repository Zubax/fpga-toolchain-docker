# syntax=docker/dockerfile:1.7
#
# Mega FPGA toolchain image. This image is built only from already-published
# registry images so local Vivado/Diamond installs are not required.
#
# Build:
#   docker buildx build --load \
#       --build-arg OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest \
#       --build-arg AMD_IMAGE=containers.zubax.com/zubax-fpga-toolchain-amd:latest \
#       --build-arg LATTICE_IMAGE=containers.zubax.com/zubax-fpga-toolchain-lattice:latest \
#       -f mega/Dockerfile -t containers.zubax.com/zubax-fpga-toolchain-mega:latest mega

ARG OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
ARG AMD_IMAGE=containers.zubax.com/zubax-fpga-toolchain-amd:latest
ARG LATTICE_IMAGE=containers.zubax.com/zubax-fpga-toolchain-lattice:latest

FROM ${AMD_IMAGE} AS amd
FROM ${LATTICE_IMAGE} AS lattice
FROM ${OSS_IMAGE}

ARG VIVADO_VERSION=2025.2.1
ARG DIAMOND_VERSION=3.14
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-mega"
LABEL org.opencontainers.image.description="Zubax FPGA mega toolchain with open-source tools, AMD Vivado, and Lattice Diamond."

USER root

COPY --from=amd /opt/Xilinx/${VIVADO_VERSION}/ /opt/Xilinx/${VIVADO_VERSION}/
COPY --from=amd /usr/local/bin/amd-tool /usr/local/bin/amd-tool
COPY --from=lattice /usr/local/diamond/${DIAMOND_VERSION}/ /usr/local/diamond/${DIAMOND_VERSION}/
COPY --from=lattice /usr/local/bin/diamond-env /usr/local/bin/diamond-env
COPY --from=lattice /usr/local/bin/diamond-tool /usr/local/bin/diamond-tool
COPY --from=lattice /usr/local/bin/diamond-net-init /usr/local/bin/diamond-net-init

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends iproute2 xvfb xauth; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chmod 0755 /usr/local/bin/amd-tool /usr/local/bin/diamond-env /usr/local/bin/diamond-tool /usr/local/bin/diamond-net-init; \
    ln -sf /usr/local/bin/amd-tool /usr/local/bin/vivado-env; \
    for tool in \
        vivado xvlog xelab xsim xvhdl xsc xtclsh xsdb hw_server bootgen updatemem \
        program_ftdi svf_utility; \
    do \
        ln -sf /usr/local/bin/amd-tool "/usr/local/bin/${tool}"; \
    done; \
    mkdir -p /lib64; \
    ln -sf /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3; \
    for tool in \
        diamond diamondc pnmainc fpgac edif2ngd ngdbuild map par trce bitgen \
        synthesis synpwrap pgrcmd ddtcmd cableserver lmutil lmhostid; \
    do \
        ln -sf /usr/local/bin/diamond-tool "/usr/local/bin/${tool}"; \
    done; \
    test -f "/usr/local/diamond/${DIAMOND_VERSION}/license/license.dat"; \
    test -x "/opt/Xilinx/${VIVADO_VERSION}/Vivado/bin/vivado"; \
    yosys -V | grep -q 'Yosys 0.68'; \
    clang-format --version; \
    clang-tidy --version; \
    printf '%s\n' 'puts [version -short]' 'exit' > /tmp/vivado-smoke.tcl; \
    vivado -mode batch -nojournal -nolog -notrace -source /tmp/vivado-smoke.tcl | grep -qx "${VIVADO_VERSION}"; \
    rm -f /tmp/vivado-smoke.tcl; \
    diamond-env par -h | head -n1 | grep -q 'version Diamond'; \
    lmutil lmhostid >/dev/null

ENV XILINX_VIVADO=/opt/Xilinx/${VIVADO_VERSION}/Vivado \
    DIAMOND_ROOT=/usr/local/diamond/${DIAMOND_VERSION}

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

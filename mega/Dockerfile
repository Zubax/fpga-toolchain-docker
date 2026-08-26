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

ARG DIAMOND_VERSION=3.14
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-mega"
LABEL org.opencontainers.image.description="Zubax FPGA mega toolchain with open-source tools, AMD Vivado, and Lattice Diamond."

USER root

COPY --from=amd /opt/Xilinx/ /opt/Xilinx/
COPY --from=amd /usr/local/bin/amd-tool /usr/local/bin/amd-net-init /usr/local/bin/
COPY --from=amd --chown=ubuntu:ubuntu /home/ubuntu/.Xilinx/ /home/ubuntu/.Xilinx/
COPY --from=lattice /usr/local/diamond/${DIAMOND_VERSION}/ /usr/local/diamond/${DIAMOND_VERSION}/
COPY --from=lattice /usr/local/bin/diamond-env /usr/local/bin/diamond-env
COPY --from=lattice /usr/local/bin/diamond-tool /usr/local/bin/diamond-tool
COPY --from=lattice /usr/local/bin/diamond-net-init /usr/local/bin/diamond-net-init

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends iproute2 xvfb xauth; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chmod 0755 /usr/local/bin/amd-tool /usr/local/bin/amd-net-init /usr/local/bin/diamond-env /usr/local/bin/diamond-tool /usr/local/bin/diamond-net-init; \
    vivado_root="$(find /opt/Xilinx -mindepth 2 -maxdepth 2 -type d -name Vivado -print | LC_ALL=C sort -V | tail -n 1)"; \
    test -n "${vivado_root}"; \
    vivado_release="$(basename "$(dirname "${vivado_root}")")"; \
    ln -s "${vivado_release}" /opt/Xilinx/current; \
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
    test -x /opt/Xilinx/current/Vivado/bin/vivado; \
    test -x /usr/local/bin/amd-net-init; \
    test -f /home/ubuntu/.Xilinx/Xilinx.lic; \
    test "$(stat -c '%a:%U:%G' /home/ubuntu/.Xilinx/Xilinx.lic)" = 600:ubuntu:ubuntu; \
    yosys -V | grep -q 'Yosys 0.68'; \
    clang-format --version; \
    clang-tidy --version; \
    VIVADO_SKIP_NET_INIT=1 vivado -version | grep -Eqi '^vivado v[0-9]+\.[0-9]+(\.[0-9]+)?'; \
    diamond-env par -h | head -n1 | grep -q 'version Diamond'; \
    lmutil lmhostid >/dev/null

ENV XILINX_VIVADO=/opt/Xilinx/current/Vivado \
    XILINXD_LICENSE_FILE=/home/ubuntu/.Xilinx/Xilinx.lic \
    DIAMOND_ROOT=/usr/local/diamond/${DIAMOND_VERSION}

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

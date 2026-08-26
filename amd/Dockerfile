# syntax=docker/dockerfile:1.7
#
# AMD/Xilinx FPGA toolchain image.
#
# Build:
#   ./build.sh

ARG OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
FROM ${OSS_IMAGE}

ARG VIVADO_VERSION
ARG VIVADO_LICENSE_SHA256
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-amd"
LABEL org.opencontainers.image.description="Zubax open-source FPGA toolchain plus AMD Vivado."

USER root

# The Vivado launcher expects the release root layout, not just the Vivado/
# subtree. build.sh discovers the release root and supplies it as vivado-src.
COPY --from=vivado-src / /opt/Xilinx/${VIVADO_VERSION}/
COPY amd-tool amd-net-init /usr/local/bin/

ENV XILINX_VIVADO=/opt/Xilinx/${VIVADO_VERSION}/Vivado \
    XILINXD_LICENSE_FILE=/opt/Xilinx/license/Xilinx.lic

RUN --mount=type=secret,id=vivado-license,required=true set -eux; \
    test -n "${VIVADO_VERSION}"; \
    test -n "${VIVADO_LICENSE_SHA256}"; \
    apt-get update; \
    apt-get install -y --no-install-recommends iproute2 util-linux; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    install -d -m 0755 /opt/Xilinx/license; \
    install -m 0444 /run/secrets/vivado-license "${XILINXD_LICENSE_FILE}"; \
    test "$(sha256sum "${XILINXD_LICENSE_FILE}" | cut -d ' ' -f 1)" = "${VIVADO_LICENSE_SHA256}"; \
    install -d -m 1777 /run/amd-net-init; \
    test -x "$(command -v flock)"; \
    chmod 0755 /usr/local/bin/amd-tool /usr/local/bin/amd-net-init; \
    ln -sf /usr/local/bin/amd-tool /usr/local/bin/vivado-env; \
    for tool in \
        vivado xvlog xelab xsim xvhdl xsc xtclsh xsdb hw_server bootgen updatemem \
        program_ftdi svf_utility; \
    do \
        ln -sf /usr/local/bin/amd-tool "/usr/local/bin/${tool}"; \
    done; \
    test -x "/opt/Xilinx/${VIVADO_VERSION}/Vivado/bin/vivado"; \
    test -f "/opt/Xilinx/${VIVADO_VERSION}/Vivado/lib/lnx64.o/Ubuntu/24/libncurses.so.5"; \
    vivado -version | grep -q "vivado v${VIVADO_VERSION}"

USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/local/bin/amd-net-init"]
CMD ["/bin/bash"]

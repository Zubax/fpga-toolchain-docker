# syntax=docker/dockerfile:1.7
#
# AMD/Xilinx FPGA toolchain image.
#
# Build:
#   docker buildx build --load \
#       --build-context vivado-src=/mnt/storage/xilinx/2025.2.1 \
#       -f amd/Dockerfile -t ghcr.io/zubax/zubax-fpga-toolchain-amd:latest amd

ARG OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
FROM ${OSS_IMAGE}

ARG VIVADO_VERSION=2025.2.1
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-amd"
LABEL org.opencontainers.image.description="Zubax open-source FPGA toolchain plus AMD Vivado."

USER root

# The Vivado launcher expects the release root layout, not just the Vivado/
# subtree. Build with: --build-context vivado-src=/mnt/storage/xilinx/2025.2.1
COPY --from=vivado-src / /opt/Xilinx/${VIVADO_VERSION}/
COPY amd-tool /usr/local/bin/amd-tool

RUN set -eux; \
    chmod 0755 /usr/local/bin/amd-tool; \
    ln -sf /usr/local/bin/amd-tool /usr/local/bin/vivado-env; \
    for tool in \
        vivado xvlog xelab xsim xvhdl xsc xtclsh xsdb hw_server bootgen updatemem \
        program_ftdi svf_utility; \
    do \
        ln -sf /usr/local/bin/amd-tool "/usr/local/bin/${tool}"; \
    done; \
    test -x "/opt/Xilinx/${VIVADO_VERSION}/Vivado/bin/vivado"; \
    test -f "/opt/Xilinx/${VIVADO_VERSION}/Vivado/lib/lnx64.o/Ubuntu/24/libncurses.so.5"; \
    printf '%s\n' 'puts [version -short]' 'exit' > /tmp/vivado-smoke.tcl; \
    vivado -version; \
    vivado -mode batch -nojournal -nolog -notrace -source /tmp/vivado-smoke.tcl | grep -qx "${VIVADO_VERSION}"; \
    rm -f /tmp/vivado-smoke.tcl

ENV XILINX_VIVADO=/opt/Xilinx/${VIVADO_VERSION}/Vivado

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

# syntax=docker/dockerfile:1.7
#
# Altera/Intel Quartus Prime Lite FPGA toolchain image.
#
# Only the Quartus and IP subtrees are shipped; Questa FSE, Nios II EDS, RiscFree,
# and the standalone programmer are omitted to keep the image size manageable.
# Quartus Prime Lite does not require a license.
#
# Build:
#   ./build.sh

ARG OSS_IMAGE=ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
FROM ${OSS_IMAGE}

ARG QUARTUS_VERSION
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-intel"
LABEL org.opencontainers.image.description="Zubax open-source FPGA toolchain plus Altera Quartus Prime Lite."

USER root

# build.sh discovers the release root and supplies it as quartus-src.
COPY --from=quartus-src /quartus/ /opt/altera_lite/${QUARTUS_VERSION}/quartus/
COPY --from=quartus-src /ip/ /opt/altera_lite/${QUARTUS_VERSION}/ip/

ENV QUARTUS_ROOTDIR=/opt/altera_lite/${QUARTUS_VERSION}/quartus \
    PATH=/opt/altera_lite/${QUARTUS_VERSION}/quartus/bin:/opt/altera_lite/${QUARTUS_VERSION}/quartus/sopc_builder/bin:${PATH}

RUN set -eux; \
    test -n "${QUARTUS_VERSION}"; \
    ln -s "${QUARTUS_VERSION}" /opt/altera_lite/current; \
    quartus_sh --version | grep -q "Version ${QUARTUS_VERSION}"

USER ubuntu
WORKDIR /home/ubuntu

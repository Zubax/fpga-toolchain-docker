# syntax=docker/dockerfile:1.7
#
# Open-source FPGA / verification toolchain.
# Some components are built from source with refs pinned via ARG defaults, overridable with --build-arg;
# others are installed from apt.
#
# Build:
#   docker build -t zubax-fpga-toolchain .
#
# Versions are pinned via ARG defaults below. To rebuild against newer refs:
#   docker build --build-arg YOSYS_REF=v0.66 --build-arg YICES2_REF=yices-2.7.0 -t zubax-fpga-toolchain .
#
# Run:
#   docker run --rm -it -v "$PWD":/work -w /work zubax-fpga-toolchain

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

# Pinned to latest published releases as of 2026-05-17.
ARG YOSYS_REF=v0.65
ARG NEXTPNR_REF=nextpnr-0.10
ARG YICES2_REF=yices-2.7.0
# prjtrellis hasn't tagged a release since 1.4 (2023), but its main branch is the
# only branch nextpnr-0.10 will build against. Pin to a recent main commit.
ARG PRJTRELLIS_REF=56bb17047cd8b062f784de8666ceb3f90f77f77a
# sby has no tagged releases; pin to a recent main commit.
ARG SBY_REF=f57802a16613f013e84e024df50fc3f0ea74f88b
ARG VERIBLE_VERSION=v0.0-4053-g89d4d98a
ARG BITWUZLA_VERSION=0.9.0
# nextpnr-xilinx and prjxray have no tagged releases; pin to recent main commits.
ARG NEXTPNR_XILINX_REF=8f178fc6a6d4dfbc57bef66c3ccff34d558047d5
ARG PRJXRAY_REF=c9f02d8576042325425824647ab5555b1bc77833
ARG OPENFPGALOADER_REF=v1.1.1

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain"
LABEL org.opencontainers.image.description="Open-source FPGA synthesis, P&R and verification toolchain (Yosys, nextpnr-ecp5, nextpnr-xilinx, prjtrellis, prjxray, Verilator, Icarus, SymbiYosys, cocotb, FuseSoC, Verible, openFPGALoader)."

# ---------------------------------------------------------------------------
# System packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget gnupg sudo locales tzdata unzip \
        git make pkg-config autoconf gperf \
        build-essential clang cmake bison flex libfl-dev gawk \
        tcl-dev libreadline-dev libffi-dev zlib1g-dev libgmp-dev \
        libboost-all-dev libeigen3-dev \
        python3 python3-dev python3-pip python3-setuptools \
        iverilog verilator gtkwave \
        z3 cvc5 boolector \
        libftdi1-dev libhidapi-dev libudev-dev \
        less vim nano file tree htop graphviz xdot \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# Python tooling on system Python. PIP_BREAK_SYSTEM_PACKAGES=1 side-steps the
# PEP 668 guard, which is meaningless inside an isolated container anyway.
# ---------------------------------------------------------------------------
ENV PIP_BREAK_SYSTEM_PACKAGES=1
# cocotb 2.0.1 (latest release, 2025-11-15) caps itself at Python 3.13 in setup.py,
# but Ubuntu 26.04 ships 3.14. The cocotb maintainers document COCOTB_IGNORE_PYTHON_REQUIRES
# as the escape hatch; pip then builds the C extension from sdist against 3.14's ABI.
RUN COCOTB_IGNORE_PYTHON_REQUIRES=1 pip3 install --no-cache-dir \
        fusesoc \
        cocotb cocotb-bus cocotb-test \
        edalize \
        click \
        numpy scipy sympy matplotlib plotly \
        nox pytest mypy ruff black

# ---------------------------------------------------------------------------
# prjtrellis (provides ecppack + ECP5 chipdb consumed by nextpnr-ecp5).
# ---------------------------------------------------------------------------
RUN git clone --recurse-submodules https://github.com/YosysHQ/prjtrellis.git /tmp/prjtrellis \
    && cd /tmp/prjtrellis \
    && git checkout "${PRJTRELLIS_REF}" \
    && git submodule update --init --recursive \
    && cd libtrellis \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release . \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/prjtrellis

# ---------------------------------------------------------------------------
# Yosys
# ---------------------------------------------------------------------------
RUN git clone --recurse-submodules https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && cd /tmp/yosys \
    && git checkout "${YOSYS_REF}" \
    && git submodule update --init --recursive \
    && make config-gcc \
    && make -j"$(nproc)" PREFIX=/usr/local \
    && make install PREFIX=/usr/local \
    && rm -rf /tmp/yosys

# ---------------------------------------------------------------------------
# Yices 2 (latest published GitHub release).
# ---------------------------------------------------------------------------
RUN set -eux; \
    curl -fsSL "https://github.com/SRI-CSL/yices2/archive/refs/tags/${YICES2_REF}.tar.gz" -o /tmp/yices2.tar.gz; \
    mkdir -p /tmp/yices2; \
    tar -C /tmp/yices2 --strip-components=1 -xzf /tmp/yices2.tar.gz; \
    cd /tmp/yices2; \
    autoconf; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install; \
    rm -rf /tmp/yices2 /tmp/yices2.tar.gz

# ---------------------------------------------------------------------------
# nextpnr with ECP5 backend. Reads chipdb from the prjtrellis install above.
# ---------------------------------------------------------------------------
RUN git clone --recurse-submodules https://github.com/YosysHQ/nextpnr.git /tmp/nextpnr \
    && cd /tmp/nextpnr \
    && git checkout "${NEXTPNR_REF}" \
    && git submodule update --init --recursive \
    && cmake -S . -B build \
             -DARCH=ecp5 \
             -DTRELLIS_INSTALL_PREFIX=/usr/local \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    && rm -rf /tmp/nextpnr

# ---------------------------------------------------------------------------
# prjxray: Xilinx 7-series bitstream tools (xc7frames2bit, xc7patch, ...).
# Vivado is only required to regenerate the fuzz database, not to build the
# C++ tools, so this builds standalone inside the container.
# ---------------------------------------------------------------------------
RUN git clone --recurse-submodules https://github.com/f4pga/prjxray.git /tmp/prjxray \
    && cd /tmp/prjxray \
    && git checkout "${PRJXRAY_REF}" \
    && git submodule update --init --recursive \
    # prjxray's bundled gflags/yaml-cpp submodules still declare CMake < 3.5
    # compatibility, which modern CMake refuses outright; the policy override
    # is the documented escape hatch.
    && cmake -S . -B build \
             -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    && rm -rf /tmp/prjxray

# ---------------------------------------------------------------------------
# nextpnr-xilinx: P&R for Xilinx 7-series (Artix-7, Kintex-7, Zynq-7). Lives in
# a separate fork from upstream nextpnr. Chipdbs are per-part and large, so
# they are not bundled; users generate them at first use via the bbaexport.py
# script shipped under /opt/nextpnr-xilinx/xilinx/python against a prjxray-db
# checkout for their target part.
# ---------------------------------------------------------------------------
RUN git clone --recurse-submodules https://github.com/gatecat/nextpnr-xilinx.git /tmp/nextpnr-xilinx \
    && cd /tmp/nextpnr-xilinx \
    && git checkout "${NEXTPNR_XILINX_REF}" \
    && git submodule update --init --recursive \
    && cmake -S . -B build \
             -DARCH=xilinx \
             -DBUILD_GUI=OFF \
             -DBUILD_TESTS=OFF \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    # Keep the python/ tree around so users can run bbaexport.py to generate
    # chipdbs against a prjxray-db checkout for whichever 7-series part they target.
    && mkdir -p /opt/nextpnr-xilinx \
    && cp -a xilinx /opt/nextpnr-xilinx/ \
    && rm -rf /tmp/nextpnr-xilinx

# ---------------------------------------------------------------------------
# openFPGALoader: vendor-neutral programmer/loader (FTDI/JTAG/USB-Blaster/...)
# for ECP5, Xilinx 7-series, ICE40, Gowin, etc.
# ---------------------------------------------------------------------------
RUN git clone https://github.com/trabucayre/openFPGALoader.git /tmp/openFPGALoader \
    && cd /tmp/openFPGALoader \
    && git checkout "${OPENFPGALOADER_REF}" \
    && cmake -S . -B build \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    && rm -rf /tmp/openFPGALoader

# ---------------------------------------------------------------------------
# SymbiYosys (sby): formal verification driver around Yosys + solvers.
# ---------------------------------------------------------------------------
RUN git clone https://github.com/YosysHQ/sby.git /tmp/sby \
    && cd /tmp/sby \
    && git checkout "${SBY_REF}" \
    && make install PREFIX=/usr/local \
    && rm -rf /tmp/sby

# ---------------------------------------------------------------------------
# Verible (latest published release).
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  vrarch="linux-static-x86_64" ;; \
        aarch64) vrarch="linux-static-arm64"  ;; \
        *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_VERSION}/verible-${VERIBLE_VERSION}-${vrarch}.tar.gz"; \
    curl -fsSL "${url}" -o /tmp/verible.tgz; \
    tar -C /usr/local --strip-components=1 -xzf /tmp/verible.tgz; \
    rm -f /tmp/verible.tgz; \
    # Verible's tarball ships its bin/ as mode 0700, which clobbers /usr/local/bin
    # so non-root users can't traverse it. Restore the standard 0755.
    chmod 0755 /usr/local/bin /usr/local/share /usr/local/share/man 2>/dev/null || true

# ---------------------------------------------------------------------------
# Bitwuzla (latest published release): SMT solver, drop-in alternative to z3
# for sby's smtbmc engine. Upstream ships prebuilt static binaries + headers.
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  bwarch="Linux-x86_64-static" ;; \
        aarch64) bwarch="Linux-arm64-static"  ;; \
        *) echo "Unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/bitwuzla/bitwuzla/releases/download/${BITWUZLA_VERSION}/Bitwuzla-${bwarch}.zip"; \
    curl -fsSL "${url}" -o /tmp/bitwuzla.zip; \
    unzip -q /tmp/bitwuzla.zip -d /tmp/bitwuzla; \
    cp -a "/tmp/bitwuzla/Bitwuzla-${bwarch}/." /usr/local/; \
    rm -rf /tmp/bitwuzla /tmp/bitwuzla.zip

# ---------------------------------------------------------------------------
# Smoke-test the toolchain so a broken build fails here, not at first use.
# ---------------------------------------------------------------------------
RUN set -eux; \
    yosys -V; \
    printf '(set-logic QF_UF)\n(check-sat)\n' | yices-smt2 | grep -qx 'sat'; \
    nextpnr-ecp5 --version; \
    ecppack --help > /dev/null; \
    nextpnr-xilinx --version; \
    command -v xc7frames2bit; \
    command -v xc7patch; \
    command -v bitread; \
    test -f /opt/nextpnr-xilinx/xilinx/python/bbaexport.py; \
    openFPGALoader --Version; \
    iverilog -V 2>&1 | head -n1; \
    verilator --version; \
    verible-verilog-lint --version | head -n1; \
    tmpdir="$(mktemp -d)"; \
    printf '%s\n' \
        'module top(input logic [3:0] a, input logic [3:0] b);' \
        '    always @* begin' \
        '        assert ((a ^ b) == (b ^ a));' \
        '    end' \
        'endmodule' \
        > "${tmpdir}/formal.sv"; \
    printf '%s\n' \
        '[options]' \
        'mode prove' \
        'depth 1' \
        '' \
        '[engines]' \
        'smtbmc z3' \
        '' \
        '[script]' \
        'read -formal formal.sv' \
        'prep -top top' \
        '' \
        '[files]' \
        'formal.sv' \
        > "${tmpdir}/formal.sby"; \
    cd "${tmpdir}"; \
    sby -f -d run formal.sby; \
    rm -rf "${tmpdir}"; \
    z3 --version; \
    cvc5 --version | head -n1; \
    boolector --version | head -n1; \
    bitwuzla --version; \
    printf '(set-logic QF_BV)\n(declare-const x (_ BitVec 8))\n(assert (= x #x2a))\n(check-sat)\n' | bitwuzla | grep -qx 'sat'; \
    fusesoc --version; \
    python3 -c "import cocotb, edalize, pytest; print('cocotb', cocotb.__version__)"

# ---------------------------------------------------------------------------
# Use the default 'ubuntu' user (UID/GID 1000) that ships with the base image;
# just grant passwordless sudo for convenience.
# ---------------------------------------------------------------------------
RUN echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

USER ubuntu
WORKDIR /home/ubuntu
CMD ["/bin/bash"]

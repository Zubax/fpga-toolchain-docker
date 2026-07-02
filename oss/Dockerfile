# syntax=docker/dockerfile:1.7
#
# Open-source FPGA / verification toolchain.
# Some components are built from source with refs pinned via ARG defaults, overridable with --build-arg;
# others are installed from apt.
#
# Build:
#   docker build -f oss/Dockerfile -t zubax-fpga-toolchain-oss oss
#
# Versions are pinned via ARG defaults below. To rebuild against newer refs:
#   docker build -f oss/Dockerfile --build-arg YOSYS_REF=<newer-tag> --build-arg YICES2_REF=<newer-tag> -t zubax-fpga-toolchain-oss oss
#
# Run:
#   docker run --rm -it -v "$PWD":/work -w /work zubax-fpga-toolchain-oss

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

# Pinned to latest published releases/heads as of 2026-07-02.
ARG YOSYS_REF=v0.66
ARG NEXTPNR_REF=nextpnr-0.10
ARG YICES2_REF=yices-2.7.0
# prjtrellis hasn't tagged a release since 1.4 (2023), but its main branch is the
# only branch nextpnr-0.10 will build against. Pin to a recent main commit.
ARG PRJTRELLIS_REF=56bb17047cd8b062f784de8666ceb3f90f77f77a
# sby has no tagged releases; pin to a recent main commit.
ARG SBY_REF=d3e72d26e8634bca4ca16f3e4d84331481f06ab6
ARG VERIBLE_VERSION=v0.0-4080-ga0a8d8eb
ARG BITWUZLA_VERSION=0.9.1
# nextpnr-xilinx and prjxray have no tagged releases; pin to recent commits. nextpnr-xilinx tracks the
# openXC7 fork, which (unlike gatecat's) ships Spartan-7 site metadata + prjxray-db in its submodules.
ARG NEXTPNR_XILINX_REF=1743d0f4b2d796b9c866bcc5bc1e4a2c9e79b472
ARG PRJXRAY_REF=c9f02d8576042325425824647ab5555b1bc77833
ARG OPENFPGALOADER_REF=v1.1.1

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="zubax-fpga-toolchain-oss"
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
        pypy3 \
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
    # GCC 15 is stricter about transitive includes; prjxray uses uint8_t in
    # memory_mapped_file.h without an explicit <cstdint>. Patch upstream's
    # suggested fix in.
    && sed -i '/#include <absl\/types\/span.h>/a #include <cstdint>' lib/include/prjxray/memory_mapped_file.h \
    # Drop -Werror: GCC 15 raises a new free-nonheap-object warning inside
    # libstdc++'s vector destructor when used from bitread.cc, which is a
    # false positive (or at least one we can't fix upstream from here).
    && sed -i 's/-Werror//g' CMakeLists.txt \
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
# nextpnr-xilinx: P&R for Xilinx 7-series (Spartan-7, Artix-7, Kintex-7, Zynq-7).
# Uses the openXC7 fork: unlike gatecat's, its bundled nextpnr-xilinx-meta + prjxray-db
# submodules include Spartan-7, so xc7s* chipdbs can be generated. Chipdbs are per-part
# and large, so they are not bundled; users generate one at first use by running the
# bbaexport.py shipped under /opt/nextpnr-xilinx/xilinx/python (its prjxray-db and
# nextpnr-xilinx-meta submodules sit alongside, so its argument defaults resolve them)
# and assembling the result into a binary database with bbasm.
# ---------------------------------------------------------------------------
RUN git clone https://github.com/openXC7/nextpnr-xilinx.git /tmp/nextpnr-xilinx \
    && cd /tmp/nextpnr-xilinx \
    && git checkout "${NEXTPNR_XILINX_REF}" \
    # Init only the data submodules bbaexport.py needs; skip the large nextpnr-tests submodule.
    && git submodule update --init --recursive xilinx/external/prjxray-db xilinx/external/nextpnr-xilinx-meta \
    # CMake 4.x's legacy FindBoost module no longer maps Boost 1.90 components correctly; force the
    # CMake-config code path supplied by Boost itself. (openXC7 already omits the header-only 'system'
    # component from its requested libs, and its json11 already includes <cstdint>, so no other patches.)
    && sed -i 's/find_package(Boost REQUIRED COMPONENTS/find_package(Boost CONFIG REQUIRED COMPONENTS/' CMakeLists.txt \
    && cmake -S . -B build \
             -DARCH=xilinx \
             -DBUILD_GUI=OFF \
             -DBUILD_TESTS=OFF \
             -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build \
    # openXC7's CMake installs only nextpnr-xilinx; bbasm (built from bba/bba.cmake) assembles the
    # .bba chipdb into nextpnr's binary format and is not installed, so place it on PATH ourselves.
    && install -Dm755 build/bbasm /usr/local/bin/bbasm \
    # Keep the xilinx/ tree (bbaexport.py + its prjxray-db / nextpnr-xilinx-meta submodules +
    # constids.inc) so users can generate chipdbs for whichever 7-series part they target.
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
# Verilator from source (pinned tag). The apt 'verilator' installed above lags
# upstream by several minor releases, and its --coverage instrumentation differs
# from current Verilator (e.g. 5.050 toggles generate-block coverage points that
# older builds skip), which our consumers' coverage gates depend on. We therefore
# build the exact upstream tag and let it shadow the apt binary: this RUN installs
# to /usr/local/bin, which precedes /usr/bin on PATH, so /usr/local/bin/verilator
# wins. Deliberately placed late so the heavy toolchain layers above stay cached.
# Most build deps are already present from the system-packages layer; only help2man
# and ccache are added here.
# ---------------------------------------------------------------------------
ARG VERILATOR_REF=v5.050
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends help2man ccache; \
    git clone https://github.com/verilator/verilator /tmp/verilator; \
    cd /tmp/verilator; \
    git checkout "${VERILATOR_REF}"; \
    autoconf; \
    ./configure --prefix=/usr/local; \
    make -j"$(nproc)"; \
    make install; \
    cd /; \
    rm -rf /tmp/verilator; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

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
    bbasm --help > /dev/null; \
    test -f /opt/nextpnr-xilinx/xilinx/python/bbaexport.py; \
    # Spartan-7 chipdb prerequisites: the metadata + prjxray-db submodules must carry xc7s* data
    # (the gatecat fork's pinned metadata did not, which silently broke xc7s50 chipdb generation).
    test -f /opt/nextpnr-xilinx/xilinx/external/nextpnr-xilinx-meta/spartan7/wire_intents.json; \
    test -d /opt/nextpnr-xilinx/xilinx/external/prjxray-db/spartan7; \
    openFPGALoader --Version; \
    iverilog -V 2>&1 | head -n1; \
    # Assert the source-built Verilator (not apt's older one) is the one on PATH.
    verilator --version; \
    verilator --version | grep -q 'Verilator 5\.050'; \
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

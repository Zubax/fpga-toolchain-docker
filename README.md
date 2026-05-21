# Zubax FPGA toolchain container

Open-source FPGA synthesis, place-and-route, and verification toolchain bundled into a single Ubuntu container.
Built around the YosysHQ flow with both Lattice ECP5 and Xilinx 7-series targets out of the box,
and usable for any open-source-supported FPGA family that Yosys / nextpnr cover.

Published to **`ghcr.io/zubax/zubax-fpga-toolchain`**. The image is public; no
authentication is required to pull.

## What's inside

- Yosys
- nextpnr (ECP5)
- nextpnr-xilinx (openXC7 fork — 7-series: Spartan-7 / Artix-7 / Kintex-7 / Zynq-7) + `bbasm` chipdb assembler
- prjtrellis / ecppack
- prjxray (`xc7frames2bit`, `xc7patch`, `bitread`, …)
- openFPGALoader (vendor-neutral JTAG/USB programmer)
- SymbiYosys (`sby`)
- Yices 2
- Verible
- Icarus Verilog
- Verilator
- edalize
- GTKWave
- SMT solvers: `z3`, `cvc5`, `boolector`, `yices-smt2`, `bitwuzla`
- FuseSoC
- cocotb (+ bus/test): `cocotb`, `cocotb-bus`, `cocotb-test`
- Scientific Python: `numpy`, `scipy`, `sympy`, `matplotlib`, `plotly`
- Python tooling: `nox`, `pytest`, `mypy`, `ruff`, `black`
- PyPy 3 (`pypy3`) — greatly speeds heavy Python steps such as nextpnr-xilinx chipdb export (`bbaexport.py`)

See [`Dockerfile`](./Dockerfile) for the authoritative list and pinned refs.

## Pull

```sh
docker pull ghcr.io/zubax/zubax-fpga-toolchain:latest
```

For reproducible CI, pin to a specific tag or digest rather than `latest`:

```sh
docker pull ghcr.io/zubax/zubax-fpga-toolchain:2026-05-14
# or by content digest
docker pull ghcr.io/zubax/zubax-fpga-toolchain@sha256:<digest>
```

## Run

Interactive shell with the current directory mounted at `/work`:

```sh
docker run --rm -it -v "$PWD":/work -w /work ghcr.io/zubax/zubax-fpga-toolchain
```

Or use the included [`run.sh`](./run.sh) helper, which adds X11 forwarding for GUI tools (GTKWave) when `$DISPLAY`
is set and downgrades the TTY flag in non-interactive contexts (CI):

```sh
./run.sh                              # interactive shell
./run.sh yosys -V                     # one-shot command
IMAGE=ghcr.io/zubax/zubax-fpga-toolchain ./run.sh make verify
```

The container runs as the default `ubuntu` user (UID/GID 1000) with passwordless `sudo`, in the `dialout` / `plugdev`
groups so USB-attached programmers work when the host device is passed through.

## Use in GitHub Actions

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/zubax/zubax-fpga-toolchain:latest
    steps:
      - uses: actions/checkout@v4
      - run: make verify
```

## Building locally

```sh
docker build -t zubax-fpga-toolchain .
```

Override pinned refs via build-args if needed:

```sh
docker build --build-arg YOSYS_REF=v0.66 --build-arg YICES2_REF=yices-2.7.0 -t zubax-fpga-toolchain .
```

Full build takes 30–60 min on 8 cores (Yosys and nextpnr dominate).
The `Dockerfile` has a smoke-test layer that exercises every tool at the end of the build,
so a broken pin fails the build instead of breaking at first use.

### Xilinx 7-series chipdb

`nextpnr-xilinx` chipdbs are per-part and large, so the generated databases are **not** bundled in the
image. The openXC7 fork does, however, ship its `prjxray-db` and `nextpnr-xilinx-meta` sources as
submodules under `/opt/nextpnr-xilinx/xilinx/`, so the bundled exporter resolves them by default — no
separate `prjxray-db` checkout is required. Generate a chipdb at first use (use `pypy3`; CPython also
works but is far slower — over an hour for a large part):

```sh
# inside the container, e.g. for the Spartan-7 xc7s50
pypy3 /opt/nextpnr-xilinx/xilinx/python/bbaexport.py \
    --device xc7s50csga324-1 --bba xc7s50.bba
bbasm --le xc7s50.bba xc7s50.bin
```

Pass the resulting `.bin` to `nextpnr-xilinx --chipdb xc7s50.bin …`. A `.bin` is not portable across
nextpnr-xilinx versions, so regenerate it after upgrading the image.

## License

MIT for the container glue (Dockerfile, scripts, workflows).
The bundled tools retain their own upstream licenses — see each project for details.

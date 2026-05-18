# Zubax FPGA toolchain container

Open-source FPGA synthesis, place-and-route, and verification toolchain bundled into a single Ubuntu container.
Built around the YosysHQ flow with both Lattice ECP5 and Xilinx 7-series (Artix-7, Kintex-7, Zynq-7) targets
out of the box, and usable for any open-source-supported FPGA family that Yosys / nextpnr cover.

Published to **`ghcr.io/zubax/zubax-fpga-toolchain`**. The image is public; no
authentication is required to pull.

## What's inside

- Yosys
- nextpnr (ECP5)
- nextpnr-xilinx (7-series: Artix-7 / Kintex-7 / Zynq-7)
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

`nextpnr-xilinx` chipdbs are per-part and large, so they are **not** bundled in the image.
Generate one at first use against a [prjxray-db](https://github.com/f4pga/prjxray-db) checkout
with the bundled exporter:

```sh
# inside the container
git clone https://github.com/f4pga/prjxray-db /work/prjxray-db
export XRAY_DIR=/work/prjxray-db
python3 /opt/nextpnr-xilinx/xilinx/python/bbaexport.py \
    --device xc7a35tcsg324-1 --bba xc7a35t.bba
bbasm --l xc7a35t.bba xc7a35t.bin
```

Pass the resulting `.bin` to `nextpnr-xilinx --chipdb xc7a35t.bin …`.

## License

MIT for the container glue (Dockerfile, scripts, workflows).
The bundled tools retain their own upstream licenses — see each project for details.

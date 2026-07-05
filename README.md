# Zubax FPGA toolchain containers

This repository builds the Zubax FPGA toolchain images:

- `zubax-fpga-toolchain-oss` - Open-source FPGA synthesis, PnR, verification, simulation, and programming tools.
- `zubax-fpga-toolchain-amd` - OSS image plus AMD Vivado.
- `zubax-fpga-toolchain-lattice` - OSS image plus Lattice Diamond.
- `zubax-fpga-toolchain-mega` - EVERYTHING.

The containers are designed to be built separately,
because it is understood that vendor tools may not always be available.
Each has its own `build.sh` and Dockerfile; refer there for details.

Run using bare Docker:

```sh
docker pull ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
docker run --rm -it -v "$PWD":/work -w /work ghcr.io/zubax/zubax-fpga-toolchain-oss:latest
```

Using the helper script:

```sh
IMAGE=containers.zubax.com/zubax-fpga-toolchain-mega:latest ./run.sh make verify
```

The OSS image is published via CI/CD on push.
The vendor tool images are published by running the publish scripts locally due to availability of tools.
The mega image is huge and for that reason it is also supposed to be published using the local script.

## zubax-fpga-toolchain-oss

Refer to the Dockerfile for detailed version information.

- Yosys
- nextpnr (ECP5)
- nextpnr-xilinx (openXC7 fork) plus `bbasm`
- prjtrellis / `ecppack`
- prjxray (`xc7frames2bit`, `xc7patch`, `bitread`, ...)
- openFPGALoader
- SymbiYosys (`sby`)
- Yices 2
- Verible
- Icarus Verilog
- Verilator
- edalize
- GTKWave
- SMT solvers: `z3`, `cvc5`, `boolector`, `yices-smt2`, `bitwuzla`
- FuseSoC
- cocotb, cocotb-bus, cocotb-test
- Scientific Python: `numpy`, `scipy`, `sympy`, `matplotlib`, `plotly`
- Python tooling: `nox`, `pytest`, `mypy`, `ruff`, `black`
- PyPy 3 (`pypy3`) for heavy Python steps such as nextpnr-xilinx chipdb export

### Xilinx 7-series chipdb

`nextpnr-xilinx` chipdbs are per-part and large, so the generated databases are not bundled in
the image. Generate a chipdb at first use:

```sh
pypy3 /opt/nextpnr-xilinx/xilinx/python/bbaexport.py --device xc7s50csga324-1 --bba xc7s50.bba
bbasm --le xc7s50.bba xc7s50.bin
```

Pass the resulting `.bin` to `nextpnr-xilinx --chipdb xc7s50.bin ...`. Regenerate chipdbs after upgrading the image.


## zubax-fpga-toolchain-lattice

The Diamond license is bound to a NIC MAC address. The Diamond wrappers attempt to set `eth0`, falling back to
`dummy0`, with the CI license MAC (`44:8a:5b:83:24:0e`) before launching the tool. This requires `NET_ADMIN`; without
it the helper continues best-effort, so workflows that need Diamond should grant the capability:

```sh
docker run --rm --cap-add NET_ADMIN \
    -v "$PWD":/work -w /work \
    containers.zubax.com/zubax-fpga-toolchain-mega:latest \
    ...
```

The helper script uses the same automatic setup:

```sh
IMAGE=containers.zubax.com/zubax-fpga-toolchain-mega:latest ./run.sh make verify
```

Set `LATTICE_DUMMY_MAC` only to override the default:

```sh
docker run --rm --cap-add NET_ADMIN \
    -e LATTICE_DUMMY_MAC="44:8a:5b:83:24:0e" \
    -v "$PWD":/work -w /work \
    containers.zubax.com/zubax-fpga-toolchain-mega:latest \
    ...
```

## Remote bitstream CI (BuildKit)

Build FPGA bitstreams on a remote build host **inside the mega image**, driven
from your laptop. `buildkitd` on the build host reuses the mega base from its
containerd image store (no re-pull), runs Vivado in a Dockerfile `RUN`, and
exports just the bitstream. Synthesis only — board programming stays in the
project.

**Build host, once** (LAN, insecure — fine on a trusted network). Extract the
buildkit binaries from the `moby/buildkit` image, then run `buildkitd` with a
containerd worker sharing docker's image store (namespace `moby`):

```sh
buildkitd --addr tcp://0.0.0.0:1234 \
  --oci-worker=false --containerd-worker=true \
  --containerd-worker-addr=/run/containerd/containerd.sock \
  --containerd-worker-namespace=moby --containerd-worker-snapshotter=overlayfs
```

**Project setup** — copy `ci/Dockerfile.template` → `Dockerfile` (adjust the
`build.tcl` and artifact path), vendor `ci/bitstream.mk` → your `ci/bitstream.mk`,
add a `.dockerignore` that keeps the context small, and a `Makefile`:

```makefile
# GEN = <codegen>           # optional local codegen; omit if none
include ci/bitstream.mk
```

**Build** (primary path — no runner):

```sh
make bit          # buildctl … --output type=local  ->  out/<name>.bit
make bit-push PUSH_REF=<registry>/proj/bitstream:$(git rev-parse --short HEAD)
```

Set `BUILDKIT_ADDR` (e.g. `tcp://host:1234`) in the project Makefile or the
environment (`BUILDKIT_HOST`); override `TARGET`, `OUT` as needed. This repo ships
no infrastructure defaults — projects pin their own.

**Or via act** — `.github/workflows/vivado-bitstream.yml` is a reusable workflow
(`docker/setup-buildx-action` remote driver + `docker/build-push-action`) doing
the same build. A project calls it from a tiny `workflow_dispatch`:

```yaml
jobs:
  bitstream:
    uses: Zubax/fpga-toolchain-docker/.github/workflows/vivado-bitstream.yml@main
    with: { buildkit_endpoint: tcp://<host>:1234, target: artifact, outputs: type=local,dest=out }
```

Run codegen locally first, then
`act workflow_dispatch -s GITHUB_TOKEN="$(gh auth token)"`.

## License

The container glue in this repository is MIT licensed.
Bundled tools retain their own upstream licenses.
Vendor images are private Zubax artifacts, are not redistributable outside the authorized organization scope,
and cannot be used outside of Zubax without an explicit approval.

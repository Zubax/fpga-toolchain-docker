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
- Clang, clang-format, and clang-tidy
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

The Diamond license is bound to a NIC MAC address. The container entrypoint and Diamond tool launchers lazily
configure a matching container NIC once per container. This remains reliable when a job-container runtime such as
GitHub Actions replaces the image entrypoint. Network initialization is best-effort so commands unrelated to licensed
tools still run without `NET_ADMIN`; workflows that need Diamond should grant the capability:

```sh
docker run --rm --cap-add NET_ADMIN \
    -v "$PWD":/work -w /work \
    containers.zubax.com/zubax-fpga-toolchain-mega:latest \
    ...
```

The helper script grants the capability automatically:

```sh
IMAGE=containers.zubax.com/zubax-fpga-toolchain-mega:latest ./run.sh make verify
```

## zubax-fpga-toolchain-amd

Vivado 2026.1 requires a license even for the free BASIC tier. The private AMD image stores that license under
`/opt/Xilinx`, outside user home directories. Its entrypoint and AMD tool launchers lazily configure the node-locked
MAC once per container, including when a job-container runtime replaces the entrypoint. Network initialization is
best-effort so commands unrelated to licensed tools still run without `NET_ADMIN`. Grant the capability when invoking
licensed tools directly:

```sh
docker run --rm --cap-add NET_ADMIN \
    -v "$PWD":/work -w /work \
    containers.zubax.com/zubax-fpga-toolchain-amd:latest \
    vivado -version
```

The repository's `run.sh` grants the capability automatically for AMD and Mega images.

## License

The container glue in this repository is MIT licensed.
Bundled tools retain their own upstream licenses.
Vendor images are private Zubax artifacts, are not redistributable outside the authorized organization scope,
and cannot be used outside of Zubax without an explicit approval.

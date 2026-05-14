# Zubax FPGA toolchain container

Open-source FPGA synthesis, place-and-route, and verification toolchain bundled
into a single Ubuntu-based container image. Built primarily around the YosysHQ
flow with an ECP5 focus, but usable for any open-source-supported FPGA family
that Yosys / nextpnr cover.

Published to **`ghcr.io/zubax/fpga-toolchain`**. The image is public; no
authentication is required to pull.

## What's inside

Base: `ubuntu:26.04`.

| Tool                 | Version       | Source           |
|----------------------|---------------|------------------|
| Yosys                | `v0.65`       | built from source |
| nextpnr (ECP5)       | `nextpnr-0.10`| built from source |
| prjtrellis / ecppack | `main` @ pinned commit | built from source |
| SymbiYosys (`sby`)   | `main` @ pinned commit | built from source |
| Verible              | `v0.0-4053-g89d4d98a` | upstream binary release |
| Icarus Verilog       | apt           | `iverilog` |
| Verilator            | apt           | `verilator` |
| GTKWave              | apt           | `gtkwave` |
| SMT solvers          | apt           | `z3`, `cvc5`, `boolector` |
| FuseSoC              | PyPI          | `fusesoc` |
| cocotb (+ bus/test)  | PyPI          | `cocotb`, `cocotb-bus`, `cocotb-test` |
| edalize              | PyPI          | `edalize` |
| Python tooling       | PyPI          | `nox`, `pytest`, `mypy`, `ruff`, `black` |

See [`Dockerfile`](./Dockerfile) for the authoritative list and pinned refs.

## Pull

```sh
docker pull ghcr.io/zubax/fpga-toolchain:latest
```

For reproducible CI, pin to a specific tag or digest rather than `latest`:

```sh
docker pull ghcr.io/zubax/fpga-toolchain:2026-05-14
# or by content digest
docker pull ghcr.io/zubax/fpga-toolchain@sha256:<digest>
```

Available tags:

- `latest` — most recent build from `main`
- `main` — same as `latest`
- `YYYY-MM-DD` — date-stamped build
- `sha-<7chars>` — commit-pinned
- `vX.Y.Z` / `X.Y` / `X` — semver, if/when releases are tagged

## Run

Interactive shell with the current directory mounted at `/work`:

```sh
docker run --rm -it -v "$PWD":/work -w /work ghcr.io/zubax/fpga-toolchain
```

Or use the included [`run.sh`](./run.sh) helper, which adds X11 forwarding for
GUI tools (GTKWave) when `$DISPLAY` is set and downgrades the TTY flag in
non-interactive contexts (CI):

```sh
./run.sh                              # interactive shell
./run.sh yosys -V                     # one-shot command
IMAGE=ghcr.io/zubax/fpga-toolchain ./run.sh make verify
```

The container runs as the default `ubuntu` user (UID/GID 1000) with
passwordless `sudo`, in the `dialout` / `plugdev` groups so USB-attached
programmers work when the host device is passed through.

## Use in GitHub Actions

```yaml
jobs:
  verify:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/zubax/fpga-toolchain:latest
    steps:
      - uses: actions/checkout@v4
      - run: make verify
```

## Building locally

```sh
docker build -t fpga-toolchain .
```

Override pinned refs via build-args if needed:

```sh
docker build --build-arg YOSYS_REF=v0.66 -t fpga-toolchain .
```

Full build takes 30–60 min on 8 cores (Yosys and nextpnr dominate). The
`Dockerfile` has a smoke-test layer that exercises every tool at the end of the
build, so a broken pin fails the build instead of breaking at first use.

## Notes & caveats

- **Python 3.14**: Ubuntu 26.04 ships Python 3.14; cocotb 2.0.1 self-caps at
  3.13 in `setup.py`. We install with `COCOTB_IGNORE_PYTHON_REQUIRES=1`, which
  forces a source build against the local Python ABI. This has worked for the
  upstream test suite; if you hit a runtime issue, please open an issue.
- **prjtrellis**: no upstream tag since 1.4 (2023), but `nextpnr-0.10` only
  builds against current `main`. We pin to a recent `main` commit; bump
  `PRJTRELLIS_REF` when refreshing.
- **Arch**: `linux/amd64` only at the moment. The Dockerfile already detects
  `aarch64` for the Verible step, but the publishing workflow doesn't build
  arm64 yet.

## License

MIT for the container glue (Dockerfile, scripts, workflows). The bundled tools
retain their own upstream licenses — see each project for details.

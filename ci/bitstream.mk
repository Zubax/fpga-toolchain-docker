# Shared make logic for remote containerized FPGA bitstream builds via BuildKit.
# Vendor this file into a project (ci/bitstream.mk) and `include` it from the
# project Makefile — keep the copy in sync with Zubax/fpga-toolchain-docker.
#
# The project Makefile sets these and includes this file:
#   BUILDKIT_ADDR  buildkitd endpoint, e.g. tcp://HOST:1234
#                  (or leave empty and set BUILDKIT_HOST in the environment)
#   GEN            optional codegen command to run before the build (blank = none)
#   CONTEXT        build context dir      (default .)
#   TARGET         Dockerfile stage       (default artifact)
#   OUT            local output dir       (default out)
#   PUSH_REF       registry ref for bit-push, e.g. <registry>/<proj>/bitstream:<tag>
#
# Targets:
#   make bit        build + export the bitstream to $(OUT)/
#   make bit-push   build + push a thin bitstream image to $(PUSH_REF)

BUILDKIT_ADDR ?=
CONTEXT       ?= .
TARGET        ?= artifact
OUT           ?= out

# Pass --addr only when BUILDKIT_ADDR is set; otherwise buildctl uses $BUILDKIT_HOST.
_addr := $(if $(BUILDKIT_ADDR),--addr $(BUILDKIT_ADDR),)

.PHONY: bit bit-push _gen _need-endpoint

_need-endpoint:
	@test -n "$(BUILDKIT_ADDR)$(BUILDKIT_HOST)" || \
	  { echo "error: set BUILDKIT_ADDR (e.g. tcp://host:1234) or BUILDKIT_HOST"; exit 1; }

_gen:
	@$(if $(GEN),$(GEN),true)

bit: _need-endpoint _gen
	buildctl $(_addr) build \
	  --frontend dockerfile.v0 \
	  --local context=$(CONTEXT) --local dockerfile=$(CONTEXT) \
	  --opt target=$(TARGET) --opt image-resolve-mode=local \
	  --output type=local,dest=$(OUT)
	@echo "==> bitstream exported to $(OUT)/"

bit-push: _need-endpoint _gen
	@test -n "$(PUSH_REF)" || { echo "error: set PUSH_REF=<registry>/<proj>/bitstream:<tag>"; exit 1; }
	buildctl $(_addr) build \
	  --frontend dockerfile.v0 \
	  --local context=$(CONTEXT) --local dockerfile=$(CONTEXT) \
	  --opt target=$(TARGET) --opt image-resolve-mode=local \
	  --output type=image,name=$(PUSH_REF),push=true
	@echo "==> pushed $(PUSH_REF)"

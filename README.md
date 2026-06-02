# llama-cpp-mtp-tq — ROCm Build with MTP Speculative Decoding

Builds **mainline ggml-org/llama.cpp** with MTP (`--spec-type draft-mtp`) for Qwen3.6 MoE models, compiled for AMD ROCm GPUs.

**This is the successor to `llama-cpp-rocm-tq`.** No TurboQuant (tbq3) in this variant — uses standard `q8_0` KV cache. tbq3 integration is planned for a future iteration.

## Models

Target: **Qwen3.6-35B-A3B-MTP-GGUF** (UD-Q4_K_XL or similar)
- MoE: 35B total params, ~3B active per token
- MTP: Built-in multi-token prediction heads (no separate draft model)

Benchmark target: ~65–75 tok/s decode (MTP enabled) vs ~51 tok/s baseline (no MTP).

## Hardware

- AMD RX 7900 XT/XTX (RDNA3) — 3× GPU asymmetric PCIe topology (GPU0 x16, GPU1/2 x4)
- ROCm 7.2.4

## Usage

### Build

```bash
docker build -t llama-cpp-mtp-tq .
```

Build time: ~20-40 min depending on hardware.

### Run (standalone)

```bash
docker run --rm \
  --device=/dev/kfd --device=/dev/dri \
  -v /path/to/model.gguf:/models/model.gguf:ro \
  -p 8080:8080 \
  -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest \
  -m /models/model.gguf \
  -c 8192 -fa on \
  -ctk q8_0 -ctv q8_0 \
  --spec-type draft-mtp --spec-draft-n-max 2
```

### Multi-GPU

```bash
docker run --rm \
  --device=/dev/kfd --device=/dev/dri \
  -v /path/to/model.gguf:/models/model.gguf:ro \
  -p 8080:8080 \
  -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  -e HIP_VISIBLE_DEVICES=0,1,2 \
  nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest \
  -m /models/model.gguf \
  --tensor-split 2,1,1 --main-gpu 0 \
  -c 8192 -fa on \
  -ctk q8_0 -ctv q8_0 \
  --spec-type draft-mtp --spec-draft-n-max 2
```

### Verify MTP is working

```bash
# Check server logs for MTP confirmation
docker logs llama-cpp-mtp-tq 2>&1 | grep -i "draft-mtp\|mtp\|speculative"

# Benchmark MTP vs no MTP
docker exec llama-cpp-mtp-tq llama-bench -m /models/model.gguf --spec-type draft-mtp --spec-draft-n-max 2
```

## Upstream Tracking

| Repo | Branch | Purpose |
|------|--------|---------|
| [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | `master` | Mainline — has MTP `--spec-type draft-mtp` |

`.upstream-hash` tracks the mainline commit SHA. CI auto-detects changes and rebuilds.

## Building for Lemonade

This image serves as the ROCm backend source for `lemonade-tq`. The lemonade-tq Dockerfile pulls `llama-server` binary from `${REGISTRY}/mkadrlik/llama-cpp-mtp-tq-ubuntu:latest` (Stage 1 `rocm_binaries`) and places it at `/opt/lemonade/llama/rocm/llama-server`.

The standard `llama-cpp-rocm-tq` is still the active Lemonade backend until this image is verified and cut over.

## MTP Flags

| Flag | Value | Description |
|------|-------|-------------|
| `--spec-type` | `draft-mtp` | MTP speculative decoding (baked into model) |
| `--spec-draft-n-max` | `2` or `3` | Max draft tokens (Qwen3.6 supports up to 3) |
| `--spec-draft-p-min` | `0.75` (optional) | Min speculative probability |

## Future: tbq3 Integration

TurboQuant tbq3 KV cache compression is **not** in mainline ggml-org/llama.cpp. Path to add:

1. **TheTom/llama-cpp-turboquant** — Has both MTP and tbq3 but CUDA-only. Needs HIP port.
2. **domvox/llama.cpp-turboquant-hip** — Has tbq3+ROCm but no MTP (stale fork). Needs MTP backported.
3. **AmesianX/TurboQuant patches on mainline** — tbq3 as modified_files, applied as patches.

The cleanest path is (1): take TheTom fork (has MTP), apply domvox's HIP port patches.

## CI

- Runner: `rocm/linux` (Gitea Actions)
- Pushes to: `ghcr.io/mkadrlik/llama-cpp-mtp-tq:latest` and `nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest`
- Trigger: push to main + daily schedule (06:00 UTC)
- The CI auto-pins upstream SHA when changes are detected

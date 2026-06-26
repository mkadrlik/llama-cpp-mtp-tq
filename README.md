# llama-cpp-mtp-tq — ROCm Build with TurboQuant + MTP Speculative Decoding

Builds **AtomicBot-ai/atomic-llama-cpp-turboquant** (branch `feature/turboquant-kv-cache`) with TurboQuant tbq3 KV cache compression and MTP speculative decoding for Qwen3.6 MoE models, compiled for AMD ROCm GPUs.

**This is the successor to `llama-cpp-rocm-tq`.** It combines both TurboQuant (tbq3) and MTP (draft-mtp / NextN) in one build.

## Upstream

[AtomicBot-ai/atomic-llama-cpp-turboquant](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant) — branch `feature/turboquant-kv-cache`.

This fork has:
- **TurboQuant tbq3** KV cache compression (~4.3× via WHT-rotated quantization)
- **NextN** speculative decoding internals (used by `draft-mtp` for Qwen3.6 MTP models)
- Native HIP/ROCm support for AMD GPUs

`.upstream-hash` tracks the pinned commit. CI auto-detects upstream changes and triggers rebuilds.

## Models

Target: **Qwen3.6-35B-A3B-MTP-GGUF** (UD-Q4_K_XL or similar)
- MoE: 35B total params, ~3B active per token
- MTP: Built-in multi-token prediction heads (no separate draft model needed)

### Performance (from AtomicBot benchmarks on M4 Max)

| Model | Mode | n=128 TPS | Accept Rate |
|-------|------|-----------|-------------|
| qwen-35B-A3B MoE | f16-base | 70.1 | — |
| qwen-35B-A3B MoE | f16-nextn | 95.2 | 88.2% |
| qwen-35B-A3B MoE | turbo3-base | 61.8 | — |
| qwen-35B-A3B MoE | **turbo3-nextn** | **82.7** | **82.9%** |

## Hardware

- AMD RX 7900 XT/XTX (RDNA3, gfx1100) — 3× GPU asymmetric PCIe topology (GPU0 x16, GPU1/2 x4)
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
  -ctk turbo3 -ctv turbo3 \
  --spec-type draft-mtp \
  --spec-draft-n-max 2 --spec-draft-n-min 1
```

### Multi-GPU (3× RX 7900 XT)

```bash
docker run --rm \
  --device=/dev/kfd --device=/dev/dri \
  -v /path/to/model.gguf:/models/model.gguf:ro \
  -p 8080:8080 \
  -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  -e HIP_VISIBLE_DEVICES=0,1,2 \
  nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest \
  -m /models/model.gguf \
  -c 8192 -fa on \
  -ctk turbo3 -ctv turbo3 \
  --spec-type draft-mtp \
  --spec-draft-n-max 2 --spec-draft-n-min 1 \
  -ts 2,1,1
```

### Inference Flags

| Flag | Value | Purpose |
|------|-------|---------|
| `-ctk` / `-ctv` | `turbo3` | TurboQuant 3-bit KV cache (~4.3× compression) |
| `--spec-type` | `draft-mtp` | Multi-token prediction (NextN is the internal embedding mechanism) |
| `--spec-draft-n-max` | `2` | Max draft tokens per step (replaces removed `--draft-max`) |
| `--spec-draft-n-min` | `1` | Min draft tokens per step (replaces removed `--draft-min`) |
| `-ts` | `2,1,1` | Tensor split for 3× GPU (GPU0 gets 2 shares, GPU1/GPU2 get 1) |
| `-fa` | `on` | Flash attention (rocWMMA) |

> **Note:** `--model-draft` is not needed for `draft-mtp` — it auto-discovers MTP heads from the combined GGUF.

## Build History

| Phase | Source | KV Cache | Spec Decode | Status |
|-------|--------|----------|-------------|--------|
| 1 | ggml-org/llama.cpp (mainline) | q8_0 | `--spec-type draft-mtp` | ✅ Tested, cut over |
| 2 | AtomicBot-ai/atomic-llama-cpp-turboquant | **tbq3** (turbo3) | `--spec-type draft-mtp` (NextN internals) | ✅ Current |

## Lemonade Integration

This image serves as the ROCm backend source for `lemonade-tq`. The lemonade-tq Dockerfile
currently pulls `llama-server` from `${REGISTRY}/mkadrlik/llama-cpp-rocm-tq-ubuntu:latest`
(Stage 1 `rocm_binaries`, the old TheTom/domvox TurboQuant fork without MTP).

**Cutover** (after this image is built and verified):
1. Update lemonade-tq Dockerfile line 26: `FROM ${REGISTRY}/mkadrlik/llama-cpp-mtp-tq:latest AS rocm_binaries`
2. Update `recipe_options.json` for MTP model entries to add `turbo3` KV cache + `draft-mtp` spec flags
3. Rebuild lemonade-tq image and verify llama-server works with lemonade's entrypoint wrapper

## CI Notes

- Default branch: main
- Gitea runner label: `self-hosted,rocm`
- Registries: ghcr.io (primary push) + nas.kadrlik.home:3042 (Gitea, via pull/tag/push)
- GitHub mirror: auto-pushed excluding `.gitea/` and `.upstream-hash`
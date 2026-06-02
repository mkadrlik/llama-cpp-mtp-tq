# llama-cpp-mtp-tq

ROCm build of mainline ggml-org/llama.cpp with MTP speculative decoding.

## Purpose

Successor to `llama-cpp-rocm-tq` for Qwen3.6 MoE models with built-in MTP
(Multi-Token Prediction) heads. No separate draft model needed.

## Current State

- Source: ggml-org/llama.cpp master (has --spec-type draft-mtp)
- Backend: ROCm/HIP (gfx1100)
- KV Cache: q8_0 (no tbq3 yet)
- Multi-GPU: Yes (3x RX 7900 XT, asymmetric PCIe)

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage ROCm build of mainline llama.cpp |
| `docker-compose.yml` | Standalone deployment |
| `.env.example` | Environment variable template |
| `.gitea/workflows/ci.yml` | CI: auto-pin upstream SHA, build, push to registries |
| `.upstream-hash` | Pinned mainline commit SHA |

## Upstream

Mainline ggml-org/llama.cpp master. `.upstream-hash` tracks the pinned commit.
CI auto-detects changes and triggers rebuilds.

## MTP Integration

Qwen3.6 MTP models have built-in draft heads — no separate draft.gguf needed.
Flags: `--spec-type draft-mtp --spec-draft-n-max 2`

## tbq3 (Future)

TurboQuant tbq3 KV cache is NOT in mainline. Planned path:
1. Take TheTom/llama-cpp-turboquant (has MTP + tbq3)
2. Apply domvox HIP port patches for ROCm
3. Test and cut over

## Lemonade Integration

This repo builds the llama-server binary. The lemonade-tq Docker build pulls
from this image's ubuntu variant. Currently, the active Lemonade backend still
points at llama-cpp-rocm-tq — cut over after verification.

## CI Notes

- Default branch: main
- Gitea runner label: rocm/linux
- Gitea registry: nas.kadrlik.home:3042
- GHCR registry: ghcr.io

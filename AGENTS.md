---
name: llama-cpp-mtp-tq
description: ROCm build of AtomicBot-ai/atomic-llama-cpp-turboquant with tbq3 KV cache compression and MTP speculative decoding
---

# llama-cpp-mtp-tq

ROCm build of [AtomicBot-ai/atomic-llama-cpp-turboquant](https://github.com/AtomicBot-ai/atomic-llama-cpp-turboquant)
with TurboQuant tbq3 KV cache compression (~4.3×) and MTP speculative decoding
for Qwen3.6 MoE models with built-in MTP heads.

## Purpose

Successor to `llama-cpp-rocm-tq` (TheTom/domvox TurboQuant fork) for Qwen3.6 MoE
models. Phase 2 combines MTP speculative decoding + tbq3 KV compression in one build.

## Current State

- **Source:** AtomicBot-ai/atomic-llama-cpp-turboquant (feature/turboquant-kv-cache)
- **Backend:** ROCm/HIP (gfx1100, 3× RX 7900 XT)
- **KV Cache:** TurboQuant tbq3 (`-ctk turbo3 -ctv turbo3`, ~4.3× compression)
- **Speculative Decoding:** MTP (`--spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-n-min 1`)
  - NextN is the internal embedding mechanism used by draft-mtp for Qwen3.6
  - No separate `--model-draft` needed — MTP heads auto-discovered from combined GGUF
- **Multi-GPU:** Yes (3× RX 7900 XT, asymmetric PCIe, `-ts 2,1,1`)

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage ROCm build from AtomicBot fork |
| `docker-compose.yml` | Standalone deployment |
| `.env.example` | Environment variable template |
| `.gitea/workflows/ci.yml` | CI: validate commits, check upstream, verify source, build, dual-registry push, mirror, SemVer |
| `.upstream-hash` | Pinned AtomicBot commit SHA |

## Upstream

AtomicBot-ai/atomic-llama-cpp-turboquant, branch `feature/turboquant-kv-cache`.
`.upstream-hash` tracks the pinned commit. CI auto-detects changes and triggers rebuilds.

## MTP Integration

Qwen3.6 MTP models have built-in draft heads — no separate draft.gguf needed.
When using `--spec-type draft-mtp` without an explicit `--model-draft` path,
the binary auto-discovers the MTP heads from the combined GGUF.

### Phase 2 Flags

```
--spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-n-min 1
-ctk turbo3 -ctv turbo3
-ts 2,1,1
```

### Performance (from AtomicBot benchmarks on M4 Max)

| Model | Mode | n=128 TPS | Accept Rate |
|-------|------|-----------|-------------|
| qwen-35B-A3B MoE | f16-base | 70.1 | — |
| qwen-35B-A3B MoE | f16-nextn | 95.2 | 88.2% |
| qwen-35B-A3B MoE | turbo3-base | 61.8 | — |
| qwen-35B-A3B MoE | **turbo3-nextn** | **82.7** | **82.9%** |

## Build History

| Phase | Source | KV Cache | Spec Decode | Status |
|-------|--------|----------|-------------|--------|
| 1 | ggml-org/llama.cpp (mainline) | q8_0 | `--spec-type draft-mtp` | ✅ Tested, cut over |
| 2 | AtomicBot-ai/atomic-llama-cpp-turboquant | **tbq3** (turbo3) | `--spec-type draft-mtp` (NextN internals) | ✅ Current |

## Lemonade Integration

The lemonade-tq Docker build pulls from this image (`llama-cpp-mtp-tq:latest`) as
the ROCm backend. After building and testing Phase 2, the recipe_options.json will
be updated with the new flags.

## CI Notes

- Default branch: main
- Gitea runner labels: self-hosted, rocm, linux, docker, amd64
- Registries: ghcr.io (primary) + nas.kadrlik.home:3042 (Gitea, via pull/tag/push)
- GitHub mirror: auto-pushed excluding .gitea/ and .upstream-hash
- Supply chain guard: Gitea is source of truth, GitHub is read-only replica
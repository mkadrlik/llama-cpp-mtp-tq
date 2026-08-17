---
name: llama-cpp-mtp-tq
description: ROCm build of TheTom/llama-cpp-turboquant with tbq3 KV cache compression and MTP speculative decoding
---

# llama-cpp-mtp-tq

ROCm build of [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant)
with TurboQuant tbq3 KV cache compression (~4.3×) and MTP speculative decoding
for Qwen3.6 MoE models with built-in MTP heads.

## Purpose

Successor to `llama-cpp-rocm-tq` (TheTom/domvox TurboQuant fork) for Qwen3.6 MoE
models. Phase 2 combines MTP speculative decoding + tbq3 KV compression in one build.

## Current State

- **Source:** TheTom/llama-cpp-turboquant (feature/turboquant-kv-cache)
- **Backend:** ROCm/HIP (gfx1100, 3× RX 7900 XT)
- **KV Cache:** TurboQuant tbq3 (`-ctk turbo3 -ctv turbo3`, ~4.3× compression)
- **Speculative Decoding:** MTP (`--spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-n-min 1`)
  - NextN is the internal embedding mechanism used by draft-mtp for Qwen3.6
  - No separate `--model-draft` needed — MTP heads auto-discovered from combined GGUF
- **Multi-GPU:** Yes (3× RX 7900 XT, asymmetric PCIe, `-ts 2,1,1`)

## Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Multi-stage ROCm build from TheTom fork |
| `docker-compose.yml` | Standalone deployment |
| `.env.example` | Environment variable template |
| `.gitea/workflows/ci.yml` | CI: validate commits, check upstream, verify source, build, dual-registry push, mirror, SemVer |
| `.upstream-hash` | Pinned TheTom commit SHA |

## Upstream

TheTom/llama-cpp-turboquant, branch `feature/turboquant-kv-cache`.
`.upstream-hash` tracks the pinned commit. CI auto-detects changes and triggers rebuilds.

## Upstream reconciliation (2026-08-17)

**This repo re-based onto TheTom on 2026-08-17.** The prior AtomicBot upstream had diverged from the canonical TurboQuant fork and was missing 456 commits of active ROCm work.

### Lineage

| Fork | `feature/turboquant-kv-cache` HEAD | Date |
|------|-----------------------------------|------|
| TheTom/llama-cpp-turboquant (canonical) | `f6124e91` | 2026-08-17 |
| AtomicBot-ai/atomic-llama-cpp-turboquant (current) | `066cc29b` | 2026-07-17 |
| This repo (`.upstream-hash`) | `d86eb0b8` | 2026-06-22 |

### What diverged

- **TheTom** — 456 commits AtomicBot lacks; active ROCm/HIP TurboQuant work:
  `tq3-fused-hip` (fused HIP turbo3 kernel), `fix/turbo-k-vgpr-spill`, `rdna2-hip-graph-capture` (GPF fix), `moe-cache`, SYCL turbo-wht port. MTP support for Qwen3-Next/GLM/DeepSeek/MiMo.
- **AtomicBot** — 336 commits TheTom lacks; mostly irrelevant here: Inkling + Laguna architectures, Windows CI, and "adopt **upstream** native Qwen3.5/3.6 NextN" (redundant — TheTom tracks the same upstream).

The HIP TURBO_WHT kernel (`ggml-cuda/turbo-wht.cu`) exists in **both** branches — re-basing onto TheTom keeps ROCm TurboQuant.

### Decision & plan

Re-base onto TheTom `feature/turboquant-kv-cache` (a superset: TurboQuant + HIP + MTP + active fixes). Drop AtomicBot.

1. Retag current `d86eb0b8` image as rollback.
2. Branch off TheTom `f6124e91`; re-apply Dockerfile + CI (`.upstream-hash` → `f6124e91`, `UPSTREAM_REPO` → TheTom).
3. Build ROCm gfx1100; verify `turbo3` + `--spec-type draft-mtp` on Qwen3.6-35B-A3B (decode t/s ≥ baseline, `cache_type_v=turbo3`, no `TURBO_WHT` SIGABRT).
4. Cut over `ghcr.io:latest`; re-point the 35B compose.

### Related

`llama-cpp-rocm-tq` still tracks the dead `domvox/llama.cpp-turboquant-hip` port (pinned `11aced9b`, no movement) — the same TheTom re-base applies there later.

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
| 2 | AtomicBot-ai/atomic-llama-cpp-turboquant | **tbq3** (turbo3) | `--spec-type draft-mtp` (NextN internals) | ✅ Superseded |
| 3 | TheTom/llama-cpp-turboquant | **tbq3** (turbo3) | `--spec-type draft-mtp` (NextN internals) | 🔄 Re-based 2026-08-17 |

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
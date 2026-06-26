# llama-cpp-mtp-tq — Build & Run Commands

## Build

```bash
# Local build from current source
cd /tmp/llama-cpp-mtp-tq
docker build -t llama-cpp-mtp-tq:local .

# Alternatively, pull latest from CI
docker pull ghcr.io/mkadrlik/llama-cpp-mtp-tq:latest
```

Build time: ~20-40 min (ROCm HIP compilation, 6-stage multi-arch build).

## Smoke Test (no GPU required)

```bash
# Verify binary exists and flags parse
docker run --rm llama-cpp-mtp-tq:local --help

# Expected flags confirmed working:
# -ctk turbo3 / -ctv turbo3 — TurboQuant 3-bit KV cache
# --spec-type draft-mtp — MTP speculative decoding
# --spec-draft-n-max N / --spec-draft-n-min N — draft token control
```

## Run (standalone, single GPU)

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

## Run (3x RX 7900 XT, asymmetric PCIe)

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

## Run (via docker-compose)

```bash
cd /tmp/llama-cpp-mtp-tq
docker compose up -d
```

## CI Workflow

CI at `.gitea/workflows/ci.yml` handles:
1. **validate-commits** — conventional commit format check
2. **check-upstream** — detect AtomicBot upstream changes (daily schedule)
3. **verify-patches** — verify upstream source files exist
4. **build** — build + push to ghcr.io (3 tags: `{version}`, `{date}`, `latest`)
5. **push-gitea-registry** — pull from ghcr.io, tag, push to Gitea registry
6. **mirror** — push clean copy (no .gitea/ or .upstream-hash) to GitHub
7. **semver-release** — SemVer tag on `workflow_dispatch`

## Verified Flags (as of 2026-06-26)

| Flag | Value | Status |
|------|-------|--------|
| `--spec-type` | `draft-mtp` | ✅ Valid enum option |
| `--spec-draft-n-max` | `2` | ✅ Replaces removed `--draft-max` |
| `--spec-draft-n-min` | `1` | ✅ Replaces removed `--draft-min` |
| `-ctk` / `-ctv` | `turbo3` | ✅ TurboQuant 3-bit |
| `-fa` | `on` | ✅ Flash attention |
| `-ts` | `2,1,1` | ✅ 3-GPU tensor split |
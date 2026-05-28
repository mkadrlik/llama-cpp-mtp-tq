# llama-cpp-mtp-tq — Hybrid ROCm Build

Builds a custom `llama.cpp` combining:
- **Mainline** — `--spec-type draft-mtp` (MTP speculative decoding, ~30% decode speedup)
- **TurboQuant tbq3** — 3-bit KV cache compression (5× smaller, full 256K context in 24GB)
- **ROCm/HIP** — Native AMD GPU support (gfx1100/gfx1151)

## Hardware

- AMD RX 7900 XT/XTX (RDNA3) — 3× GPU asymmetric PCIe topology
- AMD Ryzen AI MAX+ 395 (Strix Halo / RDNA3.5)

## Usage

### Pull

```bash
docker pull nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest
```

### Run

```bash
docker run --rm \
  --device=/dev/kfd --device=/dev/dri \
  -v /path/to/model.gguf:/models/model.gguf:ro \
  -p 8080:8080 \
  -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
  nas.kadrlik.home:3042/mkadrlik/llama-cpp-mtp-tq:latest \
  -m /models/model.gguf \
  -c 8192 \
  -fa on \
  -ctk tbq3 -ctv tbq3 \
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
  --tensor-split 2,1,1 \
  --main-gpu 0 \
  -c 8192 -fa on \
  -ctk tbq3 -ctv tbq3 \
  --spec-type draft-mtp --spec-draft-n-max 2
```

## Verification

```bash
# Check MTP support
llama-server --help | grep draft-mtp

# Check tbq3 support
llama-server --help | grep tbq3
```

## Model

Target model: `unsloth/Qwen3.6-35B-A3B-MTP-GGUF` (UD-Q4_K_XL)

Benchmark target: ~65–75 tok/s decode (MTP enabled) vs ~51 tok/s baseline.

## Upstream Tracking

| Repo | Branch | Purpose |
|------|--------|---------|
| [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | `master` | Mainline with MTP `--spec-type draft-mtp` |
| [AmesianX/TurboQuant](https://github.com/AmesianX/TurboQuant) | `main` | tbq3 KV cache compression patches |

`.upstream-hash` tracks the mainline commit SHA. CI auto-detects changes and rebuilds.
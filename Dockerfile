# =============================================================================
# llama-cpp-mtp-tq — Hybrid ROCm build with MTP + TurboQuant
# =============================================================================
# Clones mainline llama.cpp (for MTP speculative decoding support),
# then patches in TurboQuant KV cache compression (tbq3) from the
# AmesianX/TurboQuant reference fork.
#
# ARG UPSTREAM_SHA — pin to a specific mainline commit (CI auto-updates).
# When empty, clones the latest HEAD.
# =============================================================================

ARG ROCM_BASE=rocm/dev-ubuntu-22.04
FROM ${ROCM_BASE} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG UPSTREAM_SHA=
ARG UPSTREAM_REPO=https://github.com/ggml-org/llama.cpp.git
ARG AMESIANX_REPO=https://github.com/AmesianX/TurboQuant.git

# Install build deps
RUN apt-get update && apt-get install -y \
    cmake git build-essential libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone mainline llama.cpp (has MTP --spec-type draft-mtp)
WORKDIR /opt
RUN git clone --depth 1 ${UPSTREAM_REPO} llama.cpp
WORKDIR /opt/llama.cpp
RUN if [ -n "${UPSTREAM_SHA}" ]; then \
        git fetch --depth 1 origin ${UPSTREAM_SHA} && git checkout ${UPSTREAM_SHA}; \
    fi

# Clone AmesianX/TurboQuant for tbq3 KV cache patches
RUN git clone --depth 1 ${AMESIANX_REPO} /opt/turboquant

# Apply tbq3 patches on top of mainline
# (Patches are maintained in this repo's patches/ directory)
COPY patches/ /opt/patches/
RUN if [ -d /opt/patches ]; then \
        for p in /opt/patches/*.patch; do \
            [ -f "$p" ] && git am "$p" || true; \
        done; \
    fi

# Build with ROCm HIP
RUN HIPCXX="$(hipconfig -l)/clang" HIP_PATH="$(hipconfig -R)" \
    cmake -B build \
    -DGGML_HIP=ON \
    -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS \
    -DGGML_NATIVE=OFF \
    -DGGML_AVX=OFF -DGGML_AVX2=OFF -DGGML_AVX512=OFF \
    -DCMAKE_BUILD_TYPE=Release

RUN cmake --build build --config Release -j$(nproc) --target llama-server

# =============================================================================
# Runtime stage
# =============================================================================
FROM ${ROCM_BASE}

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    libopenblas0-pthread \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/llama.cpp/build/bin/llama-server /usr/local/bin/
COPY --from=builder /opt/llama.cpp/build/bin/llama-bench /usr/local/bin/
COPY --from=builder /opt/llama.cpp/build/bin/libggml*.so* /usr/local/lib/ || true
COPY --from=builder /opt/llama.cpp/build/bin/libllama*.so* /usr/local/lib/ || true
COPY --from=builder /opt/llama.cpp/build/bin/libmtmd*.so* /usr/local/lib/ || true

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0

ENTRYPOINT ["llama-server"]
CMD ["--host", "0.0.0.0", "--port", "8080", \
     "-fa", "on", \
     "-ctk", "tbq3", "-ctv", "tbq3", \
     "--spec-type", "draft-mtp", "--spec-draft-n-max", "2"]
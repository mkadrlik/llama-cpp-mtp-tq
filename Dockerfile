###############################################################################
# llama-cpp-mtp-tq
# ROCm build of mainline ggml-org/llama.cpp with MTP speculative decoding.
#
# Source: ggml-org/llama.cpp (master) — includes --spec-type draft-mtp
# for Qwen3.6 MTP models (no separate draft model required).
#
# ARG UPSTREAM_SHA — pin to a specific commit (CI auto-updates).
# When empty, clones the latest HEAD.
###############################################################################

FROM rocm/dev-ubuntu-24.04:7.2.4-complete AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG UPSTREAM_SHA=
ARG UPSTREAM_REPO=https://github.com/ggml-org/llama.cpp.git
ARG UPSTREAM_BRANCH=master

# Install build deps
RUN apt-get update && apt-get install -y \
    cmake \
    git \
    build-essential \
    pkg-config \
    libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone mainline llama.cpp (has MTP --spec-type draft-mtp)
RUN git clone --branch ${UPSTREAM_BRANCH} --depth 1 ${UPSTREAM_REPO} /opt/llama.cpp
WORKDIR /opt/llama.cpp
RUN if [ -n "${UPSTREAM_SHA}" ]; then \
        git fetch --depth 1 origin ${UPSTREAM_SHA} && git checkout ${UPSTREAM_SHA}; \
    fi

# Build with ROCm HIP backend
# GGML_HIP=ON enables the HIP/ROCm backend for AMD GPU compute
# GGML_HIP_ROCWMMA_FATTN=ON enables rocWMMA flash attention (RDNA3 optimization)
# GPU_TARGETS defaults to native (auto-detected)
RUN HIPCXX="$(hipconfig -l)/clang" \
    HIP_PATH="$(hipconfig -R)" \
    cmake -B build \
        -DGGML_HIP=ON \
        -DGGML_HIP_ROCWMMA_FATTN=ON \
        -DCMAKE_BUILD_TYPE=Release \
    && cmake --build build --config Release -j$(nproc)

# Consolidate build artifacts into /opt/export for reliable copying
# (handles the case where files may or may not exist)
RUN mkdir -p /opt/export/bin /opt/export/lib && \
    cp /opt/llama.cpp/build/bin/llama-server /opt/export/bin/ && \
    cp /opt/llama.cpp/build/bin/llama-bench /opt/export/bin/ 2>/dev/null; \
    cp /opt/llama.cpp/build/bin/libggml*.so* /opt/export/lib/ 2>/dev/null; \
    cp /opt/llama.cpp/build/bin/libllama*.so* /opt/export/lib/ 2>/dev/null; \
    cp /opt/llama.cpp/build/bin/libmtmd*.so* /opt/export/lib/ 2>/dev/null; true

###############################################################################
# Runtime image
###############################################################################
FROM rocm/dev-ubuntu-24.04:7.2.4

ARG DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopenblas0-pthread \
    && rm -rf /var/lib/apt/lists/*

# Copy built binaries and shared libs from export directory
COPY --from=builder /opt/export/bin/llama-server /usr/local/bin/
COPY --from=builder /opt/export/bin/llama-bench /usr/local/bin/
COPY --from=builder /opt/export/lib/ /usr/local/lib/

# Copy ROCm runtime libraries
COPY --from=builder /opt/rocm/lib/ /opt/rocm/lib/

ENV LD_LIBRARY_PATH=/usr/local/lib

# Default: serve with MTP speculative decoding + q8_0 KV cache
ENTRYPOINT ["llama-server"]
CMD ["--host", "0.0.0.0", "--port", "8080", \
     "-fa", "on", \
     "-ctk", "q8_0", "-ctv", "q8_0", \
     "--spec-type", "draft-mtp", "--spec-draft-n-max", "2"]
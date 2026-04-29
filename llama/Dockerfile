ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm
FROM ${BUILD_FROM} AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ik_llama_sha /tmp/ik_llama_sha

RUN git clone https://github.com/ikawrakow/ik_llama.cpp.git . \
    && git checkout $(cat /tmp/ik_llama_sha) \
    && sed -i '1i #include <cstdint>\n#define GGML_COMMON_DECL_C' ggml/src/iqk/iqk_common.h \
    && sed -i '1i #include <algorithm>\n#ifndef MIN\n#define MIN(a, b) ((a) < (b) ? (a) : (b))\n#endif\n#ifndef MAX\n#define MAX(a, b) ((a) > (b) ? (a) : (b))\n#endif' ggml/src/iqk/iqk_cpu_ops.cpp \
    && sed -i 's/defined __ARM_FEATURE_DOTPROD/defined __ARM_FEATURE_DOTPROD || defined __ARM_NEON/' ggml/src/iqk/iqk_config.h \
    && cmake -B build -DGGML_NATIVE=OFF -DGGML_ARCH_FLAGS="-march=armv8.2-a+fp16+dotprod" \
    && cmake --build build --config Release -j$(nproc) --target llama-server

# Final stage
FROM ${BUILD_FROM}

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/build/bin/llama-server /app/llama-server
COPY run.sh /app/run.sh
RUN chmod +x /app/run.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD [ "/app/run.sh" ]

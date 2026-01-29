# --- Stage 1: Builder ---
# Use the standard image (Ubuntu-based) which has excellent ARM64 support
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

# Install development headers
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic-dev \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    curl

# 1. Install dependencies
COPY shard.yml shard.lock ./
RUN shards install --production

# 2. Copy source code
COPY src ./src

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

# 3. Build the binary
RUN echo "Build revision: ${BUILD_REV}" && \
    APP_ENV=production crystal build --release --no-debug -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# --- Stage 2: Runner ---
# Use Ubuntu to match the Builder's OS architecture
FROM ubuntu:22.04

WORKDIR /app

# Install runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/public

ENV TZ=UTC
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

COPY --from=builder /app/server .
COPY public/elm.js ./public/elm.js
COPY feeds.yml ./feeds.yml

EXPOSE 8080/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD curl -f http://localhost:8080/version || exit 1

ENTRYPOINT ["./server"]

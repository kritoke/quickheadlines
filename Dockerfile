# Multi-stage build for QuickHeadlines with Svelte 5 frontend
# Using Ubuntu-based images for ARM64 compatibility

# Stage 1: Build Svelte frontend
FROM node:22-slim AS svelte-builder

WORKDIR /app/frontend

# Install pnpm
RUN npm install -g pnpm

# Copy frontend package files
COPY frontend/package.json frontend/pnpm-lock.yaml* ./

# Install dependencies
RUN pnpm install --frozen-lockfile || pnpm install

# Copy frontend source
COPY frontend/ ./

# Build Svelte frontend
RUN pnpm run build

# Stage 2: Build Crystal binary with embedded frontend
FROM 84codes/crystal:1.18.2-ubuntu-22.04 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic-dev \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    libreadline-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy shard files first for better caching
COPY shard.yml shard.lock ./
RUN shards install --production

# Copy source code
COPY src ./src

# Copy built Svelte assets from svelte-builder
COPY --from=svelte-builder /app/frontend/dist ./frontend/dist
COPY --from=svelte-builder /app/frontend/static/logo.svg ./frontend/dist/logo.svg

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

# Build with BakedFileSystem (frontend assets embedded in binary)
# Using -Os -Dpreview_lto for optimized size (~27% smaller)
RUN touch src/web/assets.cr && \
    APP_ENV=production crystal build --release --no-debug -Os -Dpreview_lto -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# Stage 3: Minimal runtime
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libxml2 \
    libssl3 \
    libyaml-0-2 \
    libsqlite3-0 \
    libreadline8 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash appuser

WORKDIR /home/appuser

ENV APP_ENV=production

# Copy binary (assets are baked in)
COPY --from=builder /app/server /home/appuser/server
COPY --from=builder /app/feeds.yml /home/appuser/feeds.yml.default

# Copy feeds.yml from build context if it exists, otherwise use default
COPY feeds.yml /home/appuser/feeds.yml 2>/dev/null || cp /home/appuser/feeds.yml.default /home/appuser/feeds.yml

USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

EXPOSE 8080

ENTRYPOINT ["/home/appuser/server", "--config=/home/appuser/feeds.yml"]

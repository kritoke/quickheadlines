# Multi-stage build for QuickHeadlines with Svelte 5 frontend
# Uses native amd64 build for speed; arm64 built separately in CI

# Stage 1: Build Svelte frontend
FROM --platform=linux/arm64 node:22 AS svelte-builder

WORKDIR /app/frontend

RUN npm install -g pnpm@9

COPY frontend/package.json frontend/pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile || pnpm install

COPY frontend/ ./
RUN pnpm run build

# Stage 2: Build Crystal binary (ARM64 native)
FROM --platform=linux/arm64 84codes/crystal:1.18.2-ubuntu-22.04 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic-dev libxml2-dev libssl-dev libyaml-dev libsqlite3-dev libreadline-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY feeds.yml ./
COPY shard.yml shard.lock ./
RUN shards install --production

COPY src ./src
COPY --from=svelte-builder /app/frontend/dist ./frontend/dist
COPY --from=svelte-builder /app/frontend/static/logo.svg ./frontend/dist/logo.svg

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

RUN touch src/web/assets.cr && \
    APP_ENV=production crystal build --release --no-debug -Os -Dpreview_lto -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# Stage 3: Minimal runtime
FROM --platform=linux/arm64 debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 libxml2 libssl3 libyaml-0-2 libsqlite3-0 libreadline8 ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash appuser

WORKDIR /home/appuser

ENV APP_ENV=production

COPY --from=builder /app/server /home/appuser/server
COPY --from=builder /app/feeds.yml /home/appuser/feeds.yml

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

EXPOSE 8080

ENTRYPOINT ["/home/appuser/server", "--config=/home/appuser/feeds.yml"]

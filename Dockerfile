# syntax=docker/dockerfile:1.4
# --- Stage 1: Builder ---
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

RUN echo 'DNS_SERVERS="8.8.8.8 8.8.4.4"' > /etc/resolv.conf && \
    cat /etc/resolv.conf

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get -o Acquire::Retries=3 -o Acquire::Retry-Delay=5 update && \
    apt-get -o Acquire::Retries=3 -o Acquire::Retry-Delay=5 install -y --no-install-recommends \
    libmagic-dev \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    curl

COPY shard.yml shard.lock ./
RUN shards install --production

COPY src ./src

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

RUN echo "Build revision: ${BUILD_REV}" && \
    APP_ENV=production crystal build --release --no-debug -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# --- Stage 2: Runner ---
FROM ubuntu:22.04

WORKDIR /app

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get -o Acquire::Retries=3 -o Acquire::Retry-Delay=5 update && \
    apt-get -o Acquire::Retries=3 -o Acquire::Retry-Delay=5 install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    ca-certificates \
    curl

ENV TZ=UTC
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

COPY --from=builder /app/server .
COPY feeds.yml ./feeds.yml

EXPOSE 3030/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f http://localhost:3030/version || exit 1

ENTRYPOINT ["./server"]

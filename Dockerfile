# syntax=docker/dockerfile:1.4
# --- Stage 1: Builder ---
FROM ubuntu:22.04 AS builder

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's|archive.ubuntu.com|ports.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true
RUN apt-get -o Acquire::Retries=3 update 2>&1 | head -20 || true

RUN apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
    crystal \
    libmagic-dev \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    curl 2>&1 | tail -20

COPY shard.yml shard.lock ./
RUN shards install --production

COPY src ./src

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

RUN echo "Build revision: ${BUILD_REV}" && \
    APP_ENV=production crystal build --release --no-debug -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# --- Stage 2: Runner ---
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's|archive.ubuntu.com|ports.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null || true

RUN apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    ca-certificates \
    curl && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=UTC
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

COPY --from=builder /app/server .
COPY feeds.yml ./feeds.yml

EXPOSE 3030/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f http://localhost:3030/version || exit 1

ENTRYPOINT ["./server"]

# --- Stage 1: Builder ---
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    libmagic-dev \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    libreadline-dev \
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-utils \
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/public/favicons

# Copy app files to /srv (not affected by volume mount at /app)
COPY --from=builder /app/server /srv/
COPY public/elm.js /srv/public/elm.js
COPY ui/elm.js /srv/ui/elm.js
COPY assets /srv/assets
COPY views /srv/views
COPY feeds.yml /srv/feeds.yml.default

# Use feeds.yml from /app if present, otherwise use default
COPY --from=builder /app/feeds.yml /srv/feeds.yml 2>/dev/null || \
    cp /srv/feeds.yml.default /srv/feeds.yml

# Also copy feeds.yml to /app for editing (will be overwritten by volume mount if present)
COPY --from=builder /app/feeds.yml /app/feeds.yml 2>/dev/null || \
    cp /srv/feeds.yml.default /app/feeds.yml 2>/dev/null || true

ENV TZ=UTC
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

EXPOSE 8080/tcp

WORKDIR /srv
ENTRYPOINT ["./server", "--config=/app/feeds.yml"]

# --- Stage 1: Builder ---
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
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
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/public/favicons

COPY --from=builder /app/server /srv/
COPY public/elm.js /srv/public/elm.js
COPY ui/elm.js /srv/ui/elm.js
COPY assets /srv/assets
COPY views /srv/views
COPY feeds.yml /srv/feeds.yml.default

RUN if [ ! -f /app/feeds.yml ] && [ -f /srv/feeds.yml.default ]; then \
        cp /srv/feeds.yml.default /app/feeds.yml; \
    fi

ENV TZ=UTC
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

EXPOSE 8080/tcp

WORKDIR /srv
ENTRYPOINT ["./server", "--config=/app/feeds.yml"]

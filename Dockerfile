# Multi-stage build
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

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

COPY shard.yml shard.lock ./
RUN shards install --production

COPY src ./src

ARG BUILD_REV=unknown
ENV CRYSTAL_WORKERS=4

RUN APP_ENV=production crystal build --release --no-debug -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# Runtime
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libssl-dev \
    libyaml-0-2 \
    libsqlite3-0 \
    libreadline8 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /public/favicons

COPY --from=builder /app/server /server
COPY public/elm.js /public/elm.js
COPY ui/elm.js /ui/elm.js
COPY assets /assets
COPY views /views
COPY feeds.yml /feeds.yml.default

RUN if [ ! -f /feeds.yml ]; then cp /feeds.yml.default /feeds.yml; fi

EXPOSE 8080

ENTRYPOINT ["/server", "--config=/feeds.yml"]

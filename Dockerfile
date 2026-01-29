# --- Stage 1: Builder ---
# Use the standard image (Ubuntu-based) which has excellent ARM64 support
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

# Install development headers for XML and SSL
# We do NOT need static versions anymore
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libxslt-dev \
    gcc \
    python3-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    curl \
    libevent-dev \
    libpcre2-dev \
    build-essential

# 1. Install dependencies
COPY shard.yml shard.lock ./
RUN shards install --production

# 2. Copy source code and assets
# We copy specific directories to avoid cache invalidation when feeds.yml changes
COPY src ./src
COPY assets ./assets

# 2.5 Build Tailwind CSS for production
# Download standalone tailwindcss cli
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="x64"; fi && \
    curl -sLO "https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-$ARCH" && \
    chmod +x "tailwindcss-linux-$ARCH" && \
    mv "tailwindcss-linux-$ARCH" tailwindcss

# Generate production CSS (combining custom styles with tailwind directives)
RUN ./tailwindcss -i assets/css/input.css -o assets/css/production.css --minify

ARG BUILD_REV=unknown

# 3. Build the binary
# CRYSTAL_WORKERS: Set number of parallel workers for compilation (optimized for ARM64)
# Using 4 workers provides good balance between speed and memory usage on ARM64
ENV CRYSTAL_WORKERS=4

# REMOVED: --static (This is the key fix for ARM64 stability)
# The binary will now rely on shared system libraries (Dynamic Linking)
# We echo the build revision to force cache invalidation if the ARG changes
RUN echo "Build revision: ${BUILD_REV}" && echo "CRYSTAL_WORKERS: ${CRYSTAL_WORKERS}" && APP_ENV=production crystal build --release --no-debug -Dversion=${BUILD_REV} src/quickheadlines.cr -o /app/server

# --- Stage 2: Runner ---
# Use Ubuntu (Slim) to match the Builder's OS architecture
# This ensures "glibc" versions match perfectly.
FROM ubuntu:22.04

WORKDIR /app

# Install the RUNTIME versions of the libraries
# We also need ca-certificates for HTTPS/RSS fetching
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    libxml2-dev \
    libxslt-dev \
    gcc \
    python3-dev \
    libssl-dev \
    libyaml-dev \
    libsqlite3-dev \
    curl \
    libevent-dev \
    libpcre2-dev \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Try to resolve issue where it can't locate the timezone sometimes and fails to run outright.
ENV TZ=UTC

# GC Tuning:
# GC_MARKERS=1 reduces CPU usage during collection in small containers.
# GC_INITIAL_HEAP_SIZE sets a baseline to avoid frequent early reallocations.
# GC_FREE_SPACE_DIVISOR=20 makes the GC much more aggressive at returning memory to the OS.
ENV GC_MARKERS=1
ENV GC_FREE_SPACE_DIVISOR=20

# Copy the compiled binary
COPY --from=builder /app/server .
COPY feeds.yml ./feeds.yml

# Setup environment
EXPOSE 3030/tcp

# Healthcheck to ensure the server is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 CMD curl -f http://localhost:3030/version || exit 1

# Run it
ENTRYPOINT ["./server"]

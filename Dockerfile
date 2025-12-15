# --- Stage 1: Builder ---
# Use the standard image (Ubuntu-based) which has excellent ARM64 support
FROM 84codes/crystal:latest-ubuntu-22.04 AS builder

WORKDIR /app

# Install development headers for XML and SSL
# We do NOT need static versions anymore
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libssl-dev \
    libyaml-dev \
    build-essential

# 1. Install dependencies
COPY shard.yml shard.lock ./
COPY feeds.yml ./feeds.yml
RUN shards install --production

# 2. Copy code
COPY . .

# 3. Build the binary
# REMOVED: --static (This is the key fix for ARM64 stability)
# The binary will now rely on shared system libraries (Dynamic Linking)
RUN crystal build src/quickheadlines.cr --release -o /app/server

# --- Stage 2: Runner ---
# Use Ubuntu (Slim) to match the Builder's OS architecture
# This ensures "glibc" versions match perfectly.
FROM ubuntu:22.04

WORKDIR /app

# Install the RUNTIME versions of the libraries
# We also need ca-certificates for HTTPS/RSS fetching
RUN apt-get update && apt-get install -y \
    libxml2 \
    libssl3 \
    libyaml-0-2 \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary
COPY --from=builder /app/server .

# Setup environment
EXPOSE 3000

# Run it
CMD ["./server -- feed.yml"]
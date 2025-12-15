# --- Stage 1: Builder ---
# We use the Alpine version of the Crystal image to ensure easy static linking with musl-libc
FROM crystallang/crystal:latest-alpine AS builder

WORKDIR /app

# Install static C-libraries needed for XML and SSL
# "libxml2-static" is crucial because you are using XML.parse
RUN apk add --no-cache libxml2-dev libxml2-static openssl-dev openssl-libs-static yaml-static

# 1. Copy shard definitions first (Docker Cache optimization)
COPY shard.yml shard.lock ./

# 2. Install dependencies
RUN shards install --production --static

# 3. Copy the rest of the source code
COPY . .

# 4. Build the binary
# --release: Optimizes for performance
# --static:  Links libraries (like libxml2) inside the binary so it runs anywhere
RUN crystal build src/quickheadlines.cr --release --static -o /app/server

# --- Stage 2: Runner ---
# We use a clean, tiny Alpine image. 
# You could use 'scratch' (empty image), but Alpine allows you to shell in for debugging.
FROM alpine:latest

# Install CA Certificates so your app can make HTTPS requests (RSS feeds)
RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copy only the compiled binary from the builder stage
COPY --from=builder /app/server .

# Copy default feeds.yml file (would be better to mount this so it isn't overwritten each time, i.e. -v $(pwd)/feeds.yml:/app/feeds.yml)
COPY feeds.yml ./feeds.yml

# Set the production environment
ENV KEMAL_ENV=production

# Expose the port (Change 3000 to whatever your app uses)
EXPOSE 3000

# Run the app
CMD ["./server"]
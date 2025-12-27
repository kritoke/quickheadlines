#!/bin/sh

# Install dependencies (skip if already installed)
shards install --production

# Run clean build
make clean

# Build the release binary
make build

# Run the program
bin/quickheadlines
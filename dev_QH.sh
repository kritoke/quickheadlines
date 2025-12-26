#!/bin/sh

# Install dependencies (skip if already installed)
shards install

# Run clean build
make clean

# Build the release binary
make run
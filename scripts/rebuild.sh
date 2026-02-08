#!/usr/bin/env bash
# QuickHeadlines Build Script
# Usage: ./scripts/rebuild.sh

set -e

echo "🚀 Rebuilding QuickHeadlines..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Install shards
echo "📦 Installing shards..."
nix develop . --command shards install

# Rebuild Elm
echo "🎨 Rebuilding Elm..."
# Use the Makefile's elm-build target which runs Elm inside the nix devshell
# This avoids embedding `cd` inside the `--command` string which can be
# interpreted incorrectly by some wrappers. Prefer `make elm-build`.
nix develop . --command make elm-build

# Run specs
echo "🧪 Running specs..."
nix develop . --command crystal spec

echo "✅ Build complete!"
echo ""
echo "To start the server:"
echo "  nix develop . --command make run"

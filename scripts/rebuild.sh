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
nix develop . --command cd ui && elm make src/Main.elm --output=../public/elm.js

# Run specs
echo "🧪 Running specs..."
nix develop . --command crystal spec

echo "✅ Build complete!"
echo ""
echo "To start the server:"
echo "  nix develop . --command make run"

#!/bin/bash

# QuickHeadlines Devcontainer Setup Script

set -e  # Exit on error
set -x  # Print commands

echo "🚀 Setting up QuickHeadlines development environment..."

# Determine if we're in a Docker container
if [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
    echo "🐳 Running in Docker container"
    IS_DOCKER=true
else
    echo "💻 Running in local environment"
    IS_DOCKER=false
fi

# Determine if we're in WSL2
if [ -f /proc/version ] && grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
    echo "🌐 Running in WSL2 environment"
    IS_WSL2=true
else
    IS_WSL2=false
fi

# Configure beads mode
USE_NO_DAEMON=false
if [ "$IS_DOCKER" = true ] || [ "$IS_WSL2" = true ] || [ "$BEADS_NO_DAEMON" = "true" ]; then
    USE_NO_DAEMON=true
    echo "🚫 Using --no-daemon mode (Docker/WSL2 environment detected)"
fi

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update package manager and install system dependencies
echo "📦 Updating system packages..."
if command_exists apt-get; then
    # Check if we have root access before running apt-get
    if [ "$(id -u)" = "0" ]; then
        apt-get update && apt-get install -y --no-install-recommends \
            build-essential \
            git \
            curl \
            sqlite3 \
            libsqlite3-dev \
            libssl-dev \
            libmagic-dev \
            nodejs \
            npm \
            golang \
            python3 \
            python3-pip \
            pipx
    else
        echo "⚠️  Running as non-root user, skipping apt-get update"
        echo "   Assuming system packages are already installed"
    fi
elif command_exists apk; then
    apk update && apk add --no-cache \
        build-base \
        git \
        curl \
        sqlite-dev \
        openssl-dev \
        libmagic-dev \
        nodejs \
        npm \
        go
elif command_exists yum; then
    yum -y update && yum -y install \
        gcc \
        gcc-c++ \
        make \
        git \
        curl \
        sqlite-devel \
        openssl-devel \
        file-devel \
        nodejs \
        npm \
        golang
fi

# Install Beads (bd) tool
echo "📦 Installing Beads (bd) tool..."

# Ensure Go is installed and GOPATH is set
if ! command_exists go; then
    echo "❌ Go is not installed. Cannot install bd."
    echo "   Please install Go first or ensure it's in your PATH."
    exit 1
fi

# Set up Go environment
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:$GOPATH/bin"

# Set up pipx environment
export PIPX_HOME="${PIPX_HOME:-$HOME/.local/pipx}"
export PIPX_BIN_DIR="${PIPX_BIN_DIR:-$HOME/.local/bin}"
export PATH="$PATH:$PIPX_BIN_DIR"

# Create bin directory for bd
mkdir -p bin

# Install bd if not already in PATH
if ! command_exists bd; then
    echo "Installing bd from GitHub..."
    if go install github.com/steveyegge/beads/cmd/bd@latest; then
        echo "✅ bd installed successfully"
    else
        echo "❌ Failed to install bd"
        exit 1
    fi
else
    echo "✅ bd already installed: $(bd --version 2>/dev/null || echo "Unknown version")"
fi

# Verify bd is accessible and get its path
BD_PATH=""
if command_exists bd; then
    BD_PATH=$(which bd)
    echo "✅ bd found at: $BD_PATH"
else
    # Check if bd exists in GOPATH/bin
    if [ -f "$GOPATH/bin/bd" ]; then
        BD_PATH="$GOPATH/bin/bd"
        echo "✅ bd found at: $BD_PATH"
    else
        echo "❌ bd executable not found in PATH or GOPATH/bin"
        echo "   GOPATH: $GOPATH"
        echo "   PATH: $PATH"
        exit 1
    fi
fi

# Symlink bd to project bin directory
if [ -n "$BD_PATH" ] && [ -f "$BD_PATH" ]; then
    # Resolve actual path of BD_PATH (in case it's a symlink)
    RESOLVED_BD_PATH=$(readlink -f "$BD_PATH")
    PROJECT_BD_PATH=$(readlink -f "bin")/bd
    
    # If BD_PATH is already project bin/bd, don't do anything
    if [ "$RESOLVED_BD_PATH" = "$PROJECT_BD_PATH" ]; then
        echo "✅ bd already in project bin directory"
    else
        # Remove existing bin/bd (file or symlink, even if broken) before creating new symlink
        if [ -e "bin/bd" ] || [ -L "bin/bd" ]; then
            rm -f bin/bd
        fi
        ln -sf "$RESOLVED_BD_PATH" bin/bd
        echo "✅ bd symlinked to bin/bd -> $RESOLVED_BD_PATH"
    fi
    
    # Verify symlink works
    if [ -L "bin/bd" ]; then
        TARGET=$(readlink "bin/bd")
        if [ -x "$TARGET" ]; then
            echo "✅ bin/bd symlink target is executable"
        else
            echo "⚠️  bin/bd symlink target is not executable"
            chmod +x "$TARGET"
        fi
    elif [ -x "bin/bd" ]; then
        echo "✅ bin/bd is executable"
    else
        echo "⚠️  bin/bd is not executable, attempting to fix..."
        chmod +x bin/bd
    fi
else
    echo "❌ Cannot create symlink: bd path is invalid or file doesn't exist"
    exit 1
fi

# Verify Crystal installation
echo "🔍 Verifying Crystal installation..."
if ! command_exists crystal; then
    echo "❌ Crystal compiler not found"
    exit 1
fi
echo "✅ Crystal version: $(crystal --version)"

# Verify Elm installation
echo "🔍 Verifying Elm installation..."
if ! command_exists elm; then
    echo "❌ Elm compiler not found, installing via npm..."
    npm install -g elm
fi
echo "✅ Elm version: $(elm --version)"

if ! command_exists elm-format; then
    echo "❌ elm-format not found, installing via npm..."
    npm install -g elm-format
fi
echo "✅ elm-format version: $(elm-format --version)"

# Install spec-kitty-cli
echo "📦 Installing spec-kitty-cli..."
if ! command_exists spec-kitty; then
    echo "Installing spec-kitty-cli via pipx..."
    if pipx install spec-kitty-cli; then
        echo "✅ spec-kitty-cli installed successfully"
    else
        echo "❌ Failed to install spec-kitty-cli"
        exit 1
    fi
else
    echo "✅ spec-kitty-cli already installed: $(spec-kitty --version 2>/dev/null || echo "Unknown version")"
fi

# Configure bd for devcontainer (no-daemon mode)
echo "🚀 Configuring bd for devcontainer..."
mkdir -p .beads

# Always use no-daemon mode in devcontainer
echo "🚫 Using --no-daemon mode (devcontainer environment)"
touch .beads/no-daemon
echo "✅ bd configured for no-daemon mode"

# Verify bd is working
echo "🔍 Verifying bd installation..."
if ./bin/bd ready; then
    echo "✅ bd is working correctly"
else
    echo "⚠️  bd ready check failed, but installation may still work"
fi

echo ""
echo "✨ QuickHeadlines development environment setup complete!"

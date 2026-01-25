#!/bin/bash

# Dev Sandbox Devcontainer Setup Script

set -e  # Exit on error
set -x  # Print commands

echo "🚀 Setting up Dev Sandbox development environment..."

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

# Determine project name from workspace path
if [ -n "$WORKSPACE_NAME" ]; then
    PROJECT_NAME="$WORKSPACE_NAME"
elif [ -d "/workspaces" ]; then
    # Get the actual project directory name from /workspaces
    PROJECT_NAME=$(ls -1 /workspaces | head -n 1)
    # If still empty, try to get from current directory
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(basename "$(pwd)")
    fi
else
    PROJECT_NAME=$(basename "$(pwd)")
fi

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
            pipx \
            locales
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

# Generate and configure locales
if command_exists locale-gen; then
    echo "🌍 Configuring locales..."
    if [ "$(id -u)" = "0" ]; then
        locale-gen en_US.UTF-8 2>/dev/null || true
        update-locale LANG=en_US.UTF-8 2>/dev/null || true
        export LANG=en_US.UTF-8
        echo "✅ Locales configured: en_US.UTF-8"
    else
        echo "⚠️  Running as non-root user, skipping locale configuration"
    fi
elif command_exists localedef; then
    echo "🌍 Configuring locales with localedef..."
    if [ "$(id -u)" = "0" ]; then
        localedef -i en_US -f UTF-8 en_US.UTF-8 2>/dev/null || true
        export LANG=en_US.UTF-8
        echo "✅ Locales configured: en_US.UTF-8"
    else
        echo "⚠️  Running as non-root user, skipping locale configuration"
    fi
else
    echo "⚠️  No locale generation tool found, skipping locale configuration"
fi

# Install Beads (bd) tool
echo "📦 Configuring Beads (bd) tool..."

# bd is now pre-installed in Docker image at /go/bin/bd
# We just need to set up the environment and symlink
export GOPATH="${GOPATH:-/go}"
export PATH="$PATH:$GOPATH/bin"

# Create bin directory for bd
mkdir -p bin

# Check if bd is already installed (pre-installed in Docker image)
if command_exists bd; then
    echo "✅ bd already installed: $(bd --version 2>/dev/null || echo "Unknown version")"
else
    echo "⚠️  bd not found in PATH, checking /go/bin..."
    if [ -f "$GOPATH/bin/bd" ]; then
        export PATH="$PATH:$GOPATH/bin"
        echo "✅ bd found at $GOPATH/bin/bd: $(bd --version 2>/dev/null || echo "Unknown version")"
    else
        echo "❌ bd executable not found. Please rebuild the Docker image."
        echo "   Expected location: $GOPATH/bin/bd"
        exit 1
    fi
fi

# Verify bd is accessible and get its path
BD_PATH=""
if command_exists bd; then
    BD_PATH=$(which bd)
    echo "✅ bd found at: $BD_PATH"
elif [ -f "$GOPATH/bin/bd" ]; then
    BD_PATH="$GOPATH/bin/bd"
    echo "✅ bd found at: $BD_PATH"
else
    echo "❌ bd executable not found in PATH or $GOPATH/bin"
    echo "   GOPATH: $GOPATH"
    echo "   PATH: $PATH"
    exit 1
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
    echo "✅ Elm installed successfully: $(elm --version)"
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

# Set up Kilo Code configuration
echo "🔧 Setting up Kilo Code configuration..."
mkdir -p /home/vscode/.kilocode
mkdir -p /home/vscode/.kilocode/rules
mkdir -p /home/vscode/.kilocode/skills
mkdir -p /home/vscode/.kilocode/memory_bank

# Copy rules, skills, and memory_bank from mounted docs directory
# The docs directory is mounted from aiworkflow to /home/vscode/.kilocode/rules
if [ -d "/home/vscode/.kilocode/rules/generic" ]; then
    echo "📚 Copying generic rules from mounted docs..."
    # Rules are already mounted at /home/vscode/.kilocode/rules
    echo "✅ Generic rules available at /home/vscode/.kilocode/rules"
else
    echo "⚠️  Generic rules not found at /home/vscode/.kilocode/rules/generic"
fi

# Verify skills directory exists (created by setup-skills.sh)
if [ -d "/home/vscode/.kilocode/skills" ]; then
    echo "✅ Skills directory exists: /home/vscode/.kilocode/skills"
else
    echo "⚠️  Skills directory not found: /home/vscode/.kilocode/skills"
    echo "   Running setup-skills.sh to create it..."
    bash /workspaces/$PROJECT_NAME/.devcontainer/setup-skills.sh
fi

# Verify memory_bank directory exists (mounted directly)
if [ -d "/home/vscode/.kilocode/memory_bank" ]; then
    echo "✅ Memory bank directory exists: /home/vscode/.kilocode/memory_bank"
else
    echo "⚠️  Memory bank directory not found: /home/vscode/.kilocode/memory_bank"
    echo "   Check if devcontainer mount is configured correctly"
fi

# Create symlinks for custom modes and settings (like bootstrap script)
echo "🔧 Setting up Kilo Code symlinks..."
mkdir -p /home/vscode/.kilocode

# Change to project directory to create relative symlinks
cd /workspaces/$PROJECT_NAME

# Create symlinks for custom_modes.yaml and mcp_settings.json
# These symlinks point to the backup files in rules/backups/kilo/
if [ -f ".kilocode/rules/backups/kilo/custom_modes.yaml" ]; then
    rm -f .kilocode/custom_modes.yaml
    ln -sf "rules/backups/kilo/custom_modes.yaml" .kilocode/custom_modes.yaml
    echo "✅ Kilo Code custom_modes.yaml symlinked"
else
    echo "⚠️  custom_modes.yaml not found in .kilocode/rules/backups/kilo/"
fi

if [ -f ".kilocode/rules/backups/kilo/mcp_settings.json" ]; then
    rm -f .kilocode/mcp_settings.json
    ln -sf "rules/backups/kilo/mcp_settings.json" .kilocode/mcp_settings.json
    echo "✅ Kilo Code mcp_settings.json symlinked"
else
    echo "⚠️  mcp_settings.json not found in .kilocode/rules/backups/kilo/"
fi

# Also create symlinks in /home/vscode/.kilocode/ (mounted directory)
cd /home/vscode
if [ -f ".kilocode/rules/backups/kilo/custom_modes.yaml" ]; then
    rm -f .kilocode/custom_modes.yaml 2>/dev/null || true
    ln -sf "rules/backups/kilo/custom_modes.yaml" .kilocode/custom_modes.yaml
    echo "✅ Kilo Code custom_modes.yaml symlinked in /home/vscode"
else
    echo "⚠️  custom_modes.yaml not found in mounted directory"
fi

if [ -f ".kilocode/rules/backups/kilo/mcp_settings.json" ]; then
    rm -f .kilocode/mcp_settings.json 2>/dev/null || true
    ln -sf "rules/backups/kilo/mcp_settings.json" .kilocode/mcp_settings.json
    echo "✅ Kilo Code mcp_settings.json symlinked in /home/vscode"
else
    echo "⚠️  mcp_settings.json not found in mounted directory"
fi

# Return to project directory
cd /workspaces/$PROJECT_NAME

# LucasDB Health Check
LUCASDB_LOCATION="${LUCASDB_LOCATION:-/workspaces/lang-db}"
echo "🔍 Running LucasDB health check..."

if [ -d "$LUCASDB_LOCATION" ]; then
    echo "✅ LucasDB directory exists: $LUCASDB_LOCATION"
    
    # Check if database files are accessible
    DB_FILE_COUNT=$(find "$LUCASDB_LOCATION" -name "*.db" -o -name "*.luc" -o -name "*lucas*" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DB_FILE_COUNT" -gt 0 ]; then
        echo "✅ LucasDB database files found: $DB_FILE_COUNT files"
    else
        echo "⚠️  No LucasDB database files found in $LUCASDB_LOCATION"
        echo "   (This may be normal for a fresh setup)"
    fi
    
    # Verify directory is readable
    if [ -r "$LUCASDB_LOCATION" ]; then
        echo "✅ LucasDB directory is readable"
    else
        echo "⚠️  LucasDB directory is not readable: $LUCASDB_LOCATION"
    fi
else
    echo "⚠️  LucasDB directory not found: $LUCASDB_LOCATION"
    echo "   The Kilo Code index will use default location"
    echo "   To fix: Ensure /workspaces/lang-db is mounted or set LUCASDB_LOCATION env var"
fi

# Configure Git (for container environment)
echo "🔧 Configuring Git..."

# Try to use existing Git configuration from host, or environment variables
GIT_USER_NAME=""
GIT_USER_EMAIL=""

# Check if already configured
EXISTING_USER_NAME=$(git config --global user.name 2>/dev/null || echo "")
EXISTING_USER_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "$EXISTING_USER_NAME" ] && [ -n "$EXISTING_USER_EMAIL" ]; then
    echo "✅ Git user already configured: $EXISTING_USER_NAME <$EXISTING_USER_EMAIL>"
else
    # Try to get from environment variables
    GIT_USER_NAME="${GIT_AUTHOR_NAME:-${GIT_COMMITTER_NAME:-${USER:-Dev Sandbox Dev}}}"
    GIT_USER_EMAIL="${GIT_AUTHOR_EMAIL:-${GIT_COMMITTER_EMAIL:-${EMAIL:-dev@devsandbox.local}}}"
    
    # Use host's git config if available via mount
    if [ -f "/home/vscode/.gitconfig" ]; then
        HOST_USER_NAME=$(git config --file /home/vscode/.gitconfig user.name 2>/dev/null || echo "")
        HOST_USER_EMAIL=$(git config --file /home/vscode/.gitconfig user.email 2>/dev/null || echo "")
        if [ -n "$HOST_USER_NAME" ]; then
            GIT_USER_NAME="$HOST_USER_NAME"
        fi
        if [ -n "$HOST_USER_EMAIL" ]; then
            GIT_USER_EMAIL="$HOST_USER_EMAIL"
        fi
    fi
    
    # Apply the configuration
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
        echo "✅ Git user name set: $GIT_USER_NAME"
    fi
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
        echo "✅ Git email set: $GIT_USER_EMAIL"
    fi
fi

# Set common Git configurations
git config --global pull.rebase false
git config --global init.defaultBranch main

# Set up environment variables
echo "📝 Setting up environment variables..."
cat > .env << 'EOF'
APP_ENV=development
TZ=UTC
BEADS_OFFLINE=1
EOF

export BEADS_OFFLINE=1

# Set execute permissions on scripts
echo "⚡ Setting script permissions..."
chmod +x safe-run.sh 2>/dev/null || true
chmod +x safe-spec.sh 2>/dev/null || true
chmod +x safe-spec-global.sh 2>/dev/null || true
chmod +x land-the-plane 2>/dev/null || true
chmod +x check-sandbox.sh 2>/dev/null || true
chmod +x .devcontainer/verify-mcp-settings.sh 2>/dev/null || true
chmod +x .devcontainer/setup-mcp-settings.sh 2>/dev/null || true

# Success message
echo ""
echo "🎉 Dev Sandbox development environment setup complete!"
echo ""
echo "Note: Application build was skipped for faster setup."
echo "      Build your application manually when ready."
echo ""

# Cleanup temporary files
rm -f /tmp/*.tmp

echo "✅ Setup Complete. Action: Run 'Developer: Reload Window' if modes are missing."

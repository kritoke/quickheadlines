#!/bin/bash
# Setup MCP Settings and Custom Modes for Kilo Code Extension in DevContainer

set -e

echo "🔧 Setting up MCP settings and custom modes for Kilo Code extension..."

# Target directory for MCP settings
TARGET_DIR="/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings"
TARGET_MCP_FILE="$TARGET_DIR/mcp_settings.json"
TARGET_CUSTOM_MODES_FILE="$TARGET_DIR/custom_modes.yaml"

# Source files in project
SOURCE_MCP_FILE="/workspaces/quickheadlines/.kilocode/mcp_settings.json"
SOURCE_CUSTOM_MODES_FILE="/workspaces/quickheadlines/.kilocode/custom_modes.yaml"

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Copy MCP settings
if [ -f "$SOURCE_MCP_FILE" ]; then
    echo "📋 Copying MCP settings from $SOURCE_MCP_FILE to $TARGET_MCP_FILE"
    cp "$SOURCE_MCP_FILE" "$TARGET_MCP_FILE"
    
    # Verify copy
    if [ -f "$TARGET_MCP_FILE" ]; then
        echo "✅ MCP settings copied successfully"
        echo "📄 File location: $TARGET_MCP_FILE"
    else
        echo "❌ Failed to copy MCP settings"
        exit 1
    fi
else
    echo "⚠️  MCP settings source file not found: $SOURCE_MCP_FILE"
fi

# Copy custom modes
if [ -f "$SOURCE_CUSTOM_MODES_FILE" ]; then
    echo "📋 Copying custom modes from $SOURCE_CUSTOM_MODES_FILE to $TARGET_CUSTOM_MODES_FILE"
    cp "$SOURCE_CUSTOM_MODES_FILE" "$TARGET_CUSTOM_MODES_FILE"
    
    # Verify copy
    if [ -f "$TARGET_CUSTOM_MODES_FILE" ]; then
        echo "✅ Custom modes copied successfully"
        echo "📄 File location: $TARGET_CUSTOM_MODES_FILE"
    else
        echo "❌ Failed to copy custom modes"
        exit 1
    fi
else
    echo "⚠️  Custom modes source file not found: $SOURCE_CUSTOM_MODES_FILE"
fi

echo ""
echo "📋 MCP settings content:"
if [ -f "$TARGET_MCP_FILE" ]; then
    cat "$TARGET_MCP_FILE"
else
    echo "(MCP settings file not present)"
fi

echo ""
echo "📋 Custom modes content:"
if [ -f "$TARGET_CUSTOM_MODES_FILE" ]; then
    cat "$TARGET_CUSTOM_MODES_FILE"
else
    echo "(Custom modes file not present)"
fi

echo ""
echo "✨ MCP settings and custom modes setup complete!"

#!/bin/bash
# Setup MCP Settings and Custom Modes for Kilo Code Extension in DevContainer

set -e

echo "🔧 Setting up MCP settings and custom modes for Kilo Code extension..."

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

# Target directory for MCP settings (Kilo Code extension stores settings in globalStorage)
TARGET_DIR="/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings"
TARGET_MCP_FILE="$TARGET_DIR/mcp_settings.json"
TARGET_CUSTOM_MODES_FILE="$TARGET_DIR/custom_modes.yaml"

# Source files in project
SOURCE_MCP_FILE="/workspaces/$PROJECT_NAME/.kilocode/mcp_settings.json"
SOURCE_CUSTOM_MODES_FILE="/workspaces/$PROJECT_NAME/.kilocode/custom_modes.yaml"

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
        FILE_SIZE=$(wc -c < "$TARGET_MCP_FILE")
        if [ "$FILE_SIZE" -lt 10 ]; then
            echo "❌ MCP settings file is too small (corrupted?)"
            exit 1
        fi
        echo "✅ MCP settings copied successfully"
        echo "📄 File location: $TARGET_MCP_FILE"
        echo "📊 File size: $FILE_SIZE bytes"
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
        FILE_SIZE=$(wc -c < "$TARGET_CUSTOM_MODES_FILE")
        if [ "$FILE_SIZE" -lt 10 ]; then
            echo "❌ Custom modes file is too small (corrupted?)"
            exit 1
        fi
        echo "✅ Custom modes copied successfully"
        echo "📄 File location: $TARGET_CUSTOM_MODES_FILE"
        echo "📊 File size: $FILE_SIZE bytes"
    else
        echo "❌ Failed to copy custom modes"
        exit 1
    fi
else
    echo "⚠️  Custom modes source file not found: $SOURCE_CUSTOM_MODES_FILE"
fi

echo ""
echo "✨ MCP settings and custom modes setup complete!"

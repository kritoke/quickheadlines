#!/bin/bash
# Verify MCP Settings and Custom Modes for Kilo Code Extension in DevContainer

set -e

echo "🔍 Verifying MCP settings and custom modes for Kilo Code extension..."

# Target directory and files
TARGET_DIR="/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings"
TARGET_MCP_FILE="$TARGET_DIR/mcp_settings.json"
TARGET_CUSTOM_MODES_FILE="$TARGET_DIR/custom_modes.yaml"

# Source files in project
SOURCE_MCP_FILE="/workspaces/quickheadlines/.kilocode/mcp_settings.json"
SOURCE_CUSTOM_MODES_FILE="/workspaces/quickheadlines/.kilocode/custom_modes.yaml"

# Check if source files exist
echo ""
echo "📋 Checking source files..."
if [ -f "$SOURCE_MCP_FILE" ]; then
    echo "✅ MCP settings source file exists: $SOURCE_MCP_FILE"
    echo "   File size: $(wc -c < "$SOURCE_MCP_FILE") bytes"
else
    echo "❌ MCP settings source file not found: $SOURCE_MCP_FILE"
fi

if [ -f "$SOURCE_CUSTOM_MODES_FILE" ]; then
    echo "✅ Custom modes source file exists: $SOURCE_CUSTOM_MODES_FILE"
    echo "   File size: $(wc -c < "$SOURCE_CUSTOM_MODES_FILE") bytes"
else
    echo "❌ Custom modes source file not found: $SOURCE_CUSTOM_MODES_FILE"
fi

# Check if target directory exists
echo ""
echo "📁 Checking target directory..."
if [ -d "$TARGET_DIR" ]; then
    echo "✅ Target directory exists: $TARGET_DIR"
else
    echo "❌ Target directory not found: $TARGET_DIR"
    echo "   Run 'bash .devcontainer/setup-sandbox.sh' to create it"
    exit 1
fi

# Check if target files exist
echo ""
echo "📄 Checking target files..."
MCP_EXISTS=false
CUSTOM_MODES_EXISTS=false

if [ -f "$TARGET_MCP_FILE" ]; then
    echo "✅ MCP settings target file exists: $TARGET_MCP_FILE"
    echo "   File size: $(wc -c < "$TARGET_MCP_FILE") bytes"
    MCP_EXISTS=true
else
    echo "❌ MCP settings target file not found: $TARGET_MCP_FILE"
    echo "   Run 'bash .devcontainer/setup-sandbox.sh' to copy it"
fi

if [ -f "$TARGET_CUSTOM_MODES_FILE" ]; then
    echo "✅ Custom modes target file exists: $TARGET_CUSTOM_MODES_FILE"
    echo "   File size: $(wc -c < "$TARGET_CUSTOM_MODES_FILE") bytes"
    CUSTOM_MODES_EXISTS=true
else
    echo "❌ Custom modes target file not found: $TARGET_CUSTOM_MODES_FILE"
    echo "   Run 'bash .devcontainer/setup-sandbox.sh' to copy it"
fi

# Verify MCP settings file content is valid JSON
if [ "$MCP_EXISTS" = true ]; then
    echo ""
    echo "🔍 Verifying MCP settings JSON validity..."
    if command -v jq &> /dev/null; then
        if jq empty "$TARGET_MCP_FILE" 2>/dev/null; then
            echo "✅ MCP settings file contains valid JSON"
        else
            echo "❌ MCP settings file contains invalid JSON"
            exit 1
        fi
    else
        echo "⚠️  jq not installed, skipping JSON validation"
    fi
fi

# Compare source and target files
echo ""
echo "🔄 Comparing source and target files..."

if [ -f "$SOURCE_MCP_FILE" ] && [ "$MCP_EXISTS" = true ]; then
    if diff -q "$SOURCE_MCP_FILE" "$TARGET_MCP_FILE" > /dev/null 2>&1; then
        echo "✅ MCP settings source and target files are identical"
    else
        echo "⚠️  MCP settings source and target files differ"
        echo "   Run 'bash .devcontainer/setup-sandbox.sh' to update"
    fi
fi

if [ -f "$SOURCE_CUSTOM_MODES_FILE" ] && [ "$CUSTOM_MODES_EXISTS" = true ]; then
    if diff -q "$SOURCE_CUSTOM_MODES_FILE" "$TARGET_CUSTOM_MODES_FILE" > /dev/null 2>&1; then
        echo "✅ Custom modes source and target files are identical"
    else
        echo "⚠️  Custom modes source and target files differ"
        echo "   Run 'bash .devcontainer/setup-sandbox.sh' to update"
    fi
fi

# Display MCP servers configured
if [ "$MCP_EXISTS" = true ]; then
    echo ""
    echo "📋 Configured MCP servers:"
    if command -v jq &> /dev/null; then
        jq -r '.mcpServers | keys[]' "$TARGET_MCP_FILE" 2>/dev/null | while read -r server; do
            echo "   - $server"
        done
    else
        echo "   (Install jq to see server list)"
    fi
fi

# Display custom modes configured
if [ "$CUSTOM_MODES_EXISTS" = true ]; then
    echo ""
    echo "📋 Custom modes configured:"
    if command -v yq &> /dev/null; then
        yq eval '.modes | keys[]' "$TARGET_CUSTOM_MODES_FILE" 2>/dev/null | while read -r mode; do
            echo "   - $mode"
        done
    else
        echo "   (Install yq to see mode list)"
    fi
fi

# Summary
echo ""
echo "✨ MCP settings and custom modes verification complete!"
echo ""
echo "Next steps:"
echo "  1. Reload VSCode window (Ctrl+Shift+P > 'Developer: Reload Window')"
echo "  2. Check Kilo Code extension output panel for MCP server status"
echo "  3. Verify MCP servers are connected in Kilo Code settings"
echo "  4. Verify custom modes are available in Kilo Code mode selector"

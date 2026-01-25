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

# Define multiple possible source locations for MCP settings
# Priority order: project .kilocode, rules/backups, host .kilocode mount
SOURCE_MCP_LOCATIONS=(
    "/workspaces/$PROJECT_NAME/.kilocode/mcp_settings.json"
    "/workspaces/$PROJECT_NAME/.kilocode/rules/backups/kilo/mcp_settings.json"
    "/home/vscode/.kilocode/rules/backups/kilo/mcp_settings.json"
    "/home/vscode/.kilocode/mcp_settings.json"
)

# Define multiple possible source locations for custom modes
SOURCE_CUSTOM_MODES_LOCATIONS=(
    "/workspaces/$PROJECT_NAME/.kilocode/custom_modes.yaml"
    "/workspaces/$PROJECT_NAME/.kilocode/rules/backups/kilo/custom_modes.yaml"
    "/home/vscode/.kilocode/rules/backups/kilo/custom_modes.yaml"
    "/home/vscode/.kilocode/custom_modes.yaml"
)

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    echo "📁 Creating target directory: $TARGET_DIR"
    mkdir -p "$TARGET_DIR"
fi

# Function to find and copy from multiple locations
find_and_copy() {
    local target_file=$1
    shift
    local source_locations=("$@")
    local found_source=""

    for source in "${source_locations[@]}"; do
        if [ -f "$source" ]; then
            found_source="$source"
            break
        fi
    done

    if [ -n "$found_source" ]; then
        echo "📋 Copying from $found_source to $target_file"
        cp "$found_source" "$target_file"
        
        # Verify copy
        if [ -f "$target_file" ]; then
            FILE_SIZE=$(wc -c < "$target_file")
            if [ "$FILE_SIZE" -lt 10 ]; then
                echo "❌ File is too small (corrupted?)"
                return 1
            fi
            echo "✅ Copied successfully"
            echo "📄 File location: $target_file"
            echo "📊 File size: $FILE_SIZE bytes"
            return 0
        else
            echo "❌ Failed to copy"
            return 1
        fi
    else
        echo "⚠️  Source file not found in any of these locations:"
        printf "   - %s\n" "${source_locations[@]}"
        return 1
    fi
}

# Copy MCP settings
echo ""
echo "🔍 Searching for MCP settings..."
if find_and_copy "$TARGET_MCP_FILE" "${SOURCE_MCP_LOCATIONS[@]}"; then
    MCP_COPIED=true
else
    MCP_COPIED=false
fi

# Copy custom modes
echo ""
echo "🔍 Searching for custom modes..."
if find_and_copy "$TARGET_CUSTOM_MODES_FILE" "${SOURCE_CUSTOM_MODES_LOCATIONS[@]}"; then
    CUSTOM_MODES_COPIED=true
else
    CUSTOM_MODES_COPIED=false
fi

echo ""
echo "✨ MCP settings and custom modes setup complete!"
echo ""
echo "📊 Summary:"
if [ "$MCP_COPIED" = true ]; then
    echo "  ✅ MCP settings: Copied"
else
    echo "  ⚠️  MCP settings: Not found"
fi
if [ "$CUSTOM_MODES_COPIED" = true ]; then
    echo "  ✅ Custom modes: Copied"
else
    echo "  ⚠️  Custom modes: Not found"
fi
echo ""
echo "💡 Tip: Reload VSCode window to apply changes (Ctrl+Shift+P > Developer: Reload Window)"

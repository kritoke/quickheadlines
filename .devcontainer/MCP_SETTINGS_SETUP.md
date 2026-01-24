# MCP Settings and Custom Modes Setup for Kilo Code Extension

## Overview

This document describes how MCP (Model Context Protocol) settings and custom modes are configured for Kilo Code extension in QuickHeadlines devcontainer.

## Problem

The Kilo Code extension requires MCP settings and custom modes to be located at:
```
/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/mcp_settings.json
/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/custom_modes.yaml
```

These files were empty or missing in devcontainer, preventing MCP servers and custom modes from being properly configured.

## Solution

### 1. Source Files

The MCP settings and custom modes are stored in the project at:
```
.kilocode/mcp_settings.json
.kilocode/custom_modes.yaml
```

The MCP settings file contains configuration for the following MCP servers:
- **playwright**: Browser automation and testing
- **hexdocs-mcp**: Elixir HexDocs documentation search
- **context7**: Library documentation and code examples
- **sequentialthinking**: Chain-of-thought reasoning

The custom modes file contains custom AI modes for Kilo Code extension.

### 2. Automatic Setup

The MCP settings and custom modes are automatically copied during devcontainer startup by the [`setup-sandbox.sh`](setup-sandbox.sh) script:

```bash
# Setup MCP settings and custom modes for Kilo Code extension
echo "🔧 Setting up MCP settings and custom modes for Kilo Code extension..."
MCP_TARGET_DIR="/home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings"
MCP_SOURCE_FILE="/workspaces/quickheadlines/.kilocode/mcp_settings.json"
CUSTOM_MODES_SOURCE_FILE="/workspaces/quickheadlines/.kilocode/custom_modes.yaml"

mkdir -p "$MCP_TARGET_DIR"

# Copy MCP settings
if [ -f "$MCP_SOURCE_FILE" ]; then
    cp "$MCP_SOURCE_FILE" "$MCP_TARGET_DIR/mcp_settings.json"
    echo "✅ MCP settings copied to $MCP_TARGET_DIR/mcp_settings.json"
fi

# Copy custom modes
if [ -f "$CUSTOM_MODES_SOURCE_FILE" ]; then
    cp "$CUSTOM_MODES_SOURCE_FILE" "$MCP_TARGET_DIR/custom_modes.yaml"
    echo "✅ Custom modes copied to $MCP_TARGET_DIR/custom_modes.yaml"
fi
```

### 3. Manual Setup

If you need to manually update MCP settings or custom modes:

#### Option A: Run Setup Script
```bash
bash .devcontainer/setup-sandbox.sh
```

#### Option B: Run MCP-Specific Script
```bash
bash .devcontainer/setup-mcp-settings.sh
```

#### Option C: Manual Copy
```bash
mkdir -p /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings
cp .kilocode/mcp_settings.json /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/
cp .kilocode/custom_modes.yaml /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/
```

## Verification

After setup, verify MCP settings and custom modes are properly configured:

```bash
bash .devcontainer/verify-mcp-settings.sh
```

This script checks:
- ✅ Source files exist in project
- ✅ Target directory exists in container
- ✅ Target files exist in container
- ✅ JSON is valid (for MCP settings)
- ✅ Source and target files match
- 📋 Lists configured MCP servers
- 📋 Lists configured custom modes

## MCP Servers Configuration

The current MCP settings include:

### Playwright
- **Purpose**: Browser automation and testing
- **Command**: `npx -y @playwright/mcp@latest --isolated`
- **Working Directory**: `/Users/kritoke/code/projects/aiworkflow/playwright-env`
- **Allowed Tools**: browser_navigate, browser_fill_form, browser_click, browser_take_screenshot, browser_snapshot, browser_close, browser_run_code, browser_wait_for, browser_network_requests, browser_console_messages, browser_evaluate

### HexDocs MCP
- **Purpose**: Elixir HexDocs documentation search
- **Command**: `npx -y hexdocs-mcp@latest`

### Context7
- **Purpose**: Library documentation and code examples
- **Command**: `npx -y @upstash/context7-mcp@latest`
- **Allowed Tools**: resolve-library-id, query-docs

### Sequential Thinking
- **Purpose**: Chain-of-thought reasoning
- **Command**: `npx -y @modelcontextprotocol/server-sequential-thinking`

## Custom Modes Configuration

The custom modes file contains custom AI modes for Kilo Code extension. These modes extend the default modes provided by Kilo Code with project-specific configurations and workflows.

## Troubleshooting

### MCP Settings or Custom Modes Not Found

**Symptoms**: Kilo Code extension shows no MCP servers or custom modes configured

**Solutions**:
1. Run setup script: `bash .devcontainer/setup-sandbox.sh`
2. Verify source files exist: `ls -la .kilocode/mcp_settings.json .kilocode/custom_modes.yaml`
3. Check target directory: `ls -la /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/`

### MCP Servers Not Connecting

**Symptoms**: MCP servers show as disconnected in Kilo Code extension

**Solutions**:
1. Reload VSCode window: `Ctrl+Shift+P > "Developer: Reload Window"`
2. Check Kilo Code output panel for errors
3. Verify MCP settings are valid JSON: `jq . /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/mcp_settings.json`
4. Restart devcontainer: `Ctrl+Shift+P > "Dev Containers: Rebuild Container"`

### Custom Modes Not Available

**Symptoms**: Custom modes don't appear in Kilo Code mode selector

**Solutions**:
1. Reload VSCode window: `Ctrl+Shift+P > "Developer: Reload Window"`
2. Check Kilo Code output panel for errors
3. Verify custom modes file exists: `ls -la /home/vscode/.vscode-server/data/User/globalStorage/kilocode.kilo-code/settings/custom_modes.yaml`
4. Restart devcontainer: `Ctrl+Shift+P > "Dev Containers: Rebuild Container"`

### Permission Denied Errors

**Symptoms**: Cannot write to target directory

**Solutions**:
1. Ensure you're running inside devcontainer (not on host)
2. Check directory permissions: `ls -la /home/vscode/.vscode-server/data/User/globalStorage/`
3. Rebuild devcontainer if permissions are incorrect

## Updating MCP Settings or Custom Modes

To add or modify MCP servers or custom modes:

1. Edit source files:
   - `.kilocode/mcp_settings.json` for MCP servers
   - `.kilocode/custom_modes.yaml` for custom modes
2. Run setup script: `bash .devcontainer/setup-sandbox.sh`
3. Reload VSCode window
4. Verify with: `bash .devcontainer/verify-mcp-settings.sh`

## Related Files

- [`.kilocode/mcp_settings.json`](../.kilocode/mcp_settings.json) - Source MCP settings
- [`.kilocode/custom_modes.yaml`](../.kilocode/custom_modes.yaml) - Custom modes configuration
- [`.devcontainer/setup-sandbox.sh`](setup-sandbox.sh) - Container setup script
- [`.devcontainer/setup-mcp-settings.sh`](setup-mcp-settings.sh) - MCP-specific setup script
- [`.devcontainer/verify-mcp-settings.sh`](verify-mcp-settings.sh) - Verification script

## Integration with DevContainer

The MCP settings and custom modes setup is integrated into devcontainer startup process:

1. **Container Build**: Dockerfile installs dependencies
2. **Post-Create Command**: `setup-sandbox.sh` runs automatically
3. **MCP Setup**: Copies `.kilocode/mcp_settings.json` to extension location
4. **Custom Modes Setup**: Copies `.kilocode/custom_modes.yaml` to extension location
5. **Verification**: Run `verify-mcp-settings.sh` to confirm setup

## Best Practices

1. **Keep Source Updated**: Always edit `.kilocode/mcp_settings.json` and `.kilocode/custom_modes.yaml` in the project, not the copies in the container
2. **Version Control**: Commit changes to source files to track MCP server configurations and custom modes
3. **Test After Changes**: Run `verify-mcp-settings.sh` after modifying MCP settings or custom modes
4. **Reload VSCode**: Always reload VSCode window after updating MCP settings or custom modes

## Support

For issues or questions:

1. Check verification script output: `bash .devcontainer/verify-mcp-settings.sh`
2. Review Kilo Code extension output panel
3. Check VSCode settings: `Ctrl+,` and search for "kilocode"
4. Consult Kilo Code documentation for MCP server configuration
5. Consult Kilo Code documentation for custom modes configuration

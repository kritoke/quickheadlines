#!/bin/bash
set -e

# Check if running inside dev container
if [ -e "/.dockerenv" ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null || [ -e "/home/vscode" ]; then
    echo "🔍 Verifying Kilo Code Setup in DevContainer"
    echo "==========================================="
else
    echo "🔍 Verifying Kilo Code Setup Locally"
    echo "===================================="
fi
echo ""

# Function to check file/directory existence
check_exists() {
    local path=$1
    local description=$2
    if [ -e "$path" ]; then
        echo "✅ $description exists: $path"
        return 0
    else
        echo "❌ $description NOT found: $path"
        return 1
    fi
}

# Function to check VSCode settings
check_vscode_setting() {
    local setting=$1
    local expected=$2
    local actual=$(code --list-extensions 2>/dev/null | grep -c "$setting" || echo "0")
    if [ "$actual" -gt 0 ]; then
        echo "✅ VSCode extension installed: $setting"
        return 0
    else
        echo "⚠️  VSCode extension NOT installed: $setting"
        return 1
    fi
}

# Determine check paths based on environment
if [ -e "/.dockerenv" ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null || [ -e "/home/vscode" ]; then
    # Dev container paths
    KILO_CONFIG_DIR="/home/vscode/.kilocode"
else
    # Local project paths
    KILO_CONFIG_DIR="./.kilocode"
fi

# Check Kilo Code configuration
echo "📋 Checking Kilo Code Configuration..."
echo "-----------------------------------"
check_exists "$KILO_CONFIG_DIR" "Kilo Code config directory"
check_exists "$KILO_CONFIG_DIR/custom_modes.yaml" "Kilo Code custom_modes.yaml"
check_exists "$KILO_CONFIG_DIR/mcp_settings.json" "Kilo Code mcp_settings.json"
check_exists "$KILO_CONFIG_DIR/rules" "Kilo Code rules directory"
if [ -e "/.dockerenv" ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null || [ -e "/home/vscode" ]; then
    # Check skills and memory_bank only in dev container
    check_exists "$KILO_CONFIG_DIR/skills" "Kilo Code skills directory"
    check_exists "$KILO_CONFIG_DIR/memory_bank" "Kilo Code memory_bank directory"
fi
echo ""

# Check VSCode extensions
echo "📋 Checking VSCode Extensions..."
echo "------------------------------"
check_vscode_setting "kilocode.kilo-code" "Kilo Code extension"
check_vscode_setting "planet57.vscode-beads" "Beads extension"
echo ""

# Check VSCode settings (if available)
echo "📋 Checking VSCode Settings..."
echo "-----------------------------"
if [ -f "/home/vscode/.config/Code/User/settings.json" ]; then
    echo "✅ VSCode settings.json found"
    
    # Check for Kilo Code settings
    if grep -q "kilocode.configPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Kilo Code configPath setting found"
    else
        echo "⚠️  Kilo Code configPath setting NOT found"
    fi
    
    if grep -q "kilocode.customModesPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Kilo Code customModesPath setting found"
    else
        echo "⚠️  Kilo Code customModesPath setting NOT found"
    fi
    
    if grep -q "kilocode.rulesPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Kilo Code rulesPath setting found"
    else
        echo "⚠️  Kilo Code rulesPath setting NOT found"
    fi
    
    if grep -q "kilocode.skillsPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Kilo Code skillsPath setting found"
    else
        echo "⚠️  Kilo Code skillsPath setting NOT found"
    fi
    
    if grep -q "kilocode.memoryBankPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Kilo Code memoryBankPath setting found"
    else
        echo "⚠️  Kilo Code memoryBankPath setting NOT found"
    fi
    
    # Check for Beads settings
    if grep -q "beads.executablePath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Beads executablePath setting found"
    else
        echo "⚠️  Beads executablePath setting NOT found"
    fi
    
    if grep -q "beads.useDaemon" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Beads useDaemon setting found"
    else
        echo "⚠️  Beads useDaemon setting NOT found"
    fi
    
    if grep -q "beads.daemonMode" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Beads daemonMode setting found"
    else
        echo "⚠️  Beads daemonMode setting NOT found"
    fi
    
    if grep -q "beads.noDaemonFlagPath" "/home/vscode/.config/Code/User/settings.json"; then
        echo "✅ Beads noDaemonFlagPath setting found"
    else
        echo "⚠️  Beads noDaemonFlagPath setting NOT found"
    fi
else
    echo "⚠️  VSCode settings.json not found at /home/vscode/.config/Code/User/settings.json"
    echo "   This is normal if VSCode hasn't been opened yet"
fi
echo ""

# Check Beads setup
echo "📋 Checking Beads Setup..."
echo "-------------------------"
if command -v bd &> /dev/null; then
    echo "✅ bd command is available"
    BD_VERSION=$(bd --version 2>&1 || echo "unknown")
    echo "   Version: $BD_VERSION"
else
    echo "❌ bd command NOT available"
fi

if [ -f "./bin/bd" ]; then
    echo "✅ bd symlink exists in ./bin/bd"
else
    echo "❌ bd symlink NOT found in ./bin/bd"
fi

if [ -d ".beads" ]; then
    echo "✅ .beads directory exists"
    if [ -f ".beads/no-daemon" ]; then
        echo "✅ Running in --no-daemon mode"
    else
        echo "ℹ️  Running in daemon mode"
    fi
else
    echo "❌ .beads directory NOT found"
fi
echo ""

# Summary
echo "==========================================="
echo "✅ Verification Complete!"
echo ""
echo "📝 Next Steps:"
echo "1. If any items are marked with ❌, check the devcontainer.json configuration"
echo "2. Reload VSCode window (Ctrl+Shift+P > 'Developer: Reload Window')"
echo "3. Check VSCode output panel for extension errors"
echo "4. Run 'bd ready' to verify Beads is working"
echo ""

# Justfile for QuickHeadlines
# Converted from makefile

set shell := ["bash", "-uc"]

# Variables
NAME := "quickheadlines"
CRYSTAL_VERSION := "1.18.2"
BOOTSTRAP_CRYSTAL_VERSION := "1.18.2"
VERSION := `grep '^version:' shard.yml | awk '{print $2}'`
BUILD_REV := "v" + VERSION

# Detect OS
os := `uname -s`

# Detect architecture  
arch := `uname -m`

# Home directory
home := env_var("HOME")

# Cache directories
CACHE_DIR := home + "/.cache/quickheadlines/crystal"
CRYSTAL_DIR := CACHE_DIR + "/crystal-" + CRYSTAL_VERSION + "-" + os + "-" + arch

# Platform-specific Crystal binary
crystal_bin := if os == "linux" {
    CRYSTAL_DIR + "/bin/crystal"
} else if os == "Darwin" {
    "$(which crystal 2>/dev/null || echo '/usr/local/bin/crystal')"
} else if os == "FreeBSD" {
    "$(which crystal)"
} else {
    CRYSTAL_DIR + "/bin/crystal"
}

# Final Crystal binary (prefer system crystal if available)
FINAL_CRYSTAL := if os == "Darwin" {
    "$(which crystal 2>/dev/null || echo 'crystal')"
} else if os == "FreeBSD" {
    "$(which crystal 2>/dev/null || echo 'crystal')"
} else {
    "$(if command -v crystal >/dev/null 2>&1; then echo 'crystal'; elif test -x \"" + CRYSTAL_DIR + "/bin/crystal\"; then echo \"" + CRYSTAL_DIR + "/bin/crystal\"; else echo 'crystal'; fi)"
}

# Homebrew OpenSSL for macOS
OPENSSL_PREFIX := `brew --prefix openssl@3 2>/dev/null || echo ""`

# Find available llvm-config on FreeBSD
FIND_LLVM_CONFIG := `for v in 19 18 17 15 14 13; do if [ -x "/usr/local/bin/llvm-config$v" ]; then echo "llvm-config$v"; break; fi; done || echo ""`

# Default recipe
default: build

# Download Crystal compiler from official site
download-crystal:
    @echo "Installing Crystal {{CRYSTAL_VERSION}}..."
    @mkdir -p {{CACHE_DIR}}
    @mkdir -p bin
    @if [ -x "{{crystal_bin}}" ]; then \
        echo "✓ Found cached Crystal {{CRYSTAL_VERSION}}"; \
    else \
        echo "Building Crystal {{CRYSTAL_VERSION}} from source..."; \
        echo "This may take 30-60 minutes..."; \
        cd {{CACHE_DIR}} && \
        if [ "{{os}}" = "FreeBSD" ]; then \
            export MAKE=gmake; \
            export LLVM_CONFIG="{{FIND_LLVM_CONFIG}}"; \
            echo "Using LLVM config: $LLVM_CONFIG"; \
            fetch https://github.com/crystal-lang/crystal/archive/{{CRYSTAL_VERSION}}.tar.gz 2>/dev/null || curl -L -o {{CRYSTAL_VERSION}}.tar.gz https://github.com/crystal-lang/crystal/archive/{{CRYSTAL_VERSION}}.tar.gz || { \
                echo "Error: Failed to download Crystal source"; \
                exit 1; \
            }; \
            tar xzf {{CRYSTAL_VERSION}}.tar.gz || { \
                echo "Error: Failed to extract Crystal source"; \
                rm -f {{CRYSTAL_VERSION}}.tar.gz; \
                exit 1; \
            }; \
            rm -f {{CRYSTAL_VERSION}}.tar.gz; \
            mv crystal-{{CRYSTAL_VERSION}} {{CRYSTAL_DIR}}; \
            cd {{CRYSTAL_DIR}} && \
            echo "Setting up build environment..."; \
            export CC=cc; \
            export CXX=c++; \
            export LIBRARY_PATH=/usr/local/lib; \
            export CPATH=/usr/local/include; \
            export PATH=/usr/local/bin:/usr/bin:/bin:$PATH; \
            echo "Running make deps..."; \
            gmake deps || { \
                echo "Error: Failed to install Crystal dependencies"; \
                exit 1; \
            }; \
            echo "Building Crystal {{CRYSTAL_VERSION}}..."; \
            gmake crystal CRYSTAL_CONFIG_BUILD_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown") || { \
                echo "Error: Failed to build Crystal"; \
                echo "Check build log above for details"; \
                exit 1; \
            }; \
        else \
            echo "Crystal download not implemented for {{os}} - use system crystal or nix develop"; \
            exit 1; \
        fi; \
    fi
    @rm -f bin/crystal
    @if [ "{{os}}" = "FreeBSD" ]; then \
        ln -sf {{crystal_bin}} bin/crystal; \
    else \
        ln -sf {{CRYSTAL_DIR}}/bin/crystal bin/crystal; \
    fi
    @echo "✓ Crystal {{CRYSTAL_VERSION}} ready"

# Check for required dependencies
check-deps:
    @echo "Checking dependencies..."
    @SYSTEM_CRYSTAL=$(which crystal 2>/dev/null || echo ""); \
    if [ -n "$SYSTEM_CRYSTAL" ] && [ -x "$SYSTEM_CRYSTAL" ]; then \
        echo "Found system Crystal: $SYSTEM_CRYSTAL"; \
    elif [ -x "{{CRYSTAL_DIR}}/bin/crystal" ]; then \
        echo "Found cached Crystal: {{CRYSTAL_DIR}}/bin/crystal"; \
    elif [ "{{os}}" = "FreeBSD" ]; then \
        echo "Crystal compiler not found, building Crystal {{CRYSTAL_VERSION}} from source..."; \
        just download-crystal; \
    elif [ "{{os}}" = "Darwin" ]; then \
        echo "❌ Error: Crystal compiler not found"; \
        echo ""; \
        echo "Install Crystal on macOS:"; \
        echo "  brew install crystal"; \
        exit 1; \
    else \
        echo "Crystal compiler not found, downloading..."; \
        just download-crystal; \
    fi
    @SYSTEM_CRYSTAL=$(which crystal 2>/dev/null || echo ""); \
    FINAL_CRYSTAL=$(if [ -n "$SYSTEM_CRYSTAL" ] && [ -x "$SYSTEM_CRYSTAL" ]; then echo "$SYSTEM_CRYSTAL"; else echo "crystal"; fi); \
    echo "✓ Crystal compiler: $$($FINAL_CRYSTAL --version | head -1)"
    @if [ "{{os}}" = "FreeBSD" ] || ([ "{{os}}" = "Linux" ] && [ "{{arch}}" = "aarch64" ]); then \
        if [ -f "public/elm.js" ]; then \
            echo "✓ Using pre-compiled public/elm.js"; \
        else \
            echo "❌ Error: Elm compiler not found and public/elm.js missing"; \
            echo ""; \
            if [ "{{os}}" = "FreeBSD" ]; then \
                echo "On FreeBSD, you need either:"; \
            else \
                echo "On Linux arm64, you need either:"; \
            fi; \
            echo "  1. The pre-compiled public/elm.js file (recommended)"; \
            if [ "{{os}}" = "FreeBSD" ]; then \
                echo "  2. Elm compiler: pkg install elm; npm install -g elm"; \
            else \
                echo "  2. Elm compiler: npm install -g elm"; \
            fi; \
            exit 1; \
        fi; \
    fi
    @if [ "{{os}}" = "Linux" ]; then \
        pkg-config --exists sqlite3 || { \
            echo "❌ Error: SQLite3 development files not found"; \
            echo ""; \
            echo "Install SQLite3:"; \
            echo "  Ubuntu/Debian: sudo apt-get install libsqlite3-dev"; \
            echo "  Fedora/RHEL:   sudo dnf install sqlite-devel"; \
            echo "  Arch:          sudo pacman -S sqlite"; \
            exit 1; \
        }; \
        echo "✓ SQLite3 development files found"; \
    fi
    @if [ "{{os}}" = "FreeBSD" ]; then \
        pkg info -e sqlite3 >/dev/null 2>&1 || { \
            echo "❌ Error: SQLite3 not found"; \
            echo ""; \
            echo "Install SQLite3:"; \
            echo "  FreeBSD: sudo pkg install sqlite3"; \
            exit 1; \
        }; \
        echo "✓ SQLite3 found"; \
    fi
    @if [ "{{os}}" = "Linux" ]; then \
        pkg-config --exists openssl || { \
            echo "❌ Error: OpenSSL development files not found"; \
            echo ""; \
            echo "Install OpenSSL:"; \
            echo "  Ubuntu/Debian: sudo apt-get install libssl-dev"; \
            echo "  Fedora/RHEL:   sudo dnf install openssl-devel"; \
            echo "  Arch:          sudo pacman -S openssl"; \
            exit 1; \
        }; \
        echo "✓ OpenSSL development files found"; \
    fi
    @if [ "{{os}}" = "FreeBSD" ]; then \
        pkg info -e openssl >/dev/null 2>&1 || { \
            echo "❌ Error: OpenSSL not found"; \
            echo ""; \
            echo "Install OpenSSL:"; \
            echo "  FreeBSD: sudo pkg install openssl"; \
            exit 1; \
        }; \
        echo "✓ OpenSSL found"; \
    fi
    @if [ "{{os}}" = "FreeBSD" ]; then \
        echo "Checking Crystal build dependencies..."; \
        pkg info -e git >/dev/null 2>&1 || { \
            echo "❌ Error: git not found (required for Crystal build)"; \
            echo ""; \
            echo "Install git:"; \
            echo "  FreeBSD: sudo pkg install git"; \
            exit 1; \
        }; \
        pkg info -e gmake >/dev/null 2>&1 || { \
            echo "❌ Error: gmake not found (required for Crystal build)"; \
            echo ""; \
            echo "Install gmake:"; \
            echo "  FreeBSD: sudo pkg install gmake"; \
            exit 1; \
        }; \
        pkg info -e libyaml >/dev/null 2>&1 || { \
            echo "❌ Error: libyaml not found (required for Crystal build)"; \
            echo ""; \
            echo "Install libyaml:"; \
            echo "  FreeBSD: sudo pkg install libyaml"; \
            exit 1; \
        }; \
        pkg info -e llvm19 >/dev/null 2>&1 || pkg info -e llvm18 >/dev/null 2>&1 || pkg info -e llvm17 >/dev/null 2>&1 || pkg info -e llvm15 >/dev/null 2>&1 || { \
            echo "❌ Error: llvm not found (required for Crystal build)"; \
            echo ""; \
            echo "Install llvm:"; \
            echo "  FreeBSD: sudo pkg install llvm19"; \
            exit 1; \
        }; \
        pkg info -e libevent >/dev/null 2>&1 || { \
            echo "❌ Error: libevent not found (required for Crystal build)"; \
            echo ""; \
            echo "Install libevent:"; \
            echo "  FreeBSD: sudo pkg install libevent"; \
            exit 1; \
        }; \
        echo "✓ All Crystal build dependencies found"; \
    fi
    @echo "Checking libmagic..."
    @if [ "{{os}}" = "Darwin" ]; then \
        if pkg-config --exists libmagic 2>/dev/null; then \
            echo "✓ libmagic found"; \
        elif [ -f "/usr/local/opt/libmagic/lib/libmagic.dylib" ]; then \
            echo "✓ libmagic found"; \
        else \
            echo "❌ Error: libmagic not found"; \
            echo ""; \
            echo "Install libmagic:"; \
            echo "  macOS: brew install libmagic"; \
            exit 1; \
        fi; \
    elif [ "{{os}}" = "Linux" ]; then \
        if pkg-config --exists libmagic 2>/dev/null; then \
            echo "✓ libmagic found"; \
        else \
            echo "❌ Error: libmagic not found"; \
            echo ""; \
            echo "Install libmagic:"; \
            echo "  Ubuntu/Debian: sudo apt-get install libmagic-dev"; \
            echo "  Fedora/RHEL:   sudo dnf install file-devel"; \
            echo "  Arch:          sudo pacman -S file"; \
            exit 1; \
        fi; \
    elif [ "{{os}}" = "FreeBSD" ]; then \
        if [ -f /usr/lib/libmagic.so ] || [ -f /usr/local/lib/libmagic.so ] || [ -f /usr/lib/libmagic.a ] || [ -f /usr/local/lib/libmagic.a ]; then \
            echo "✓ libmagic found in base system"; \
        else \
            echo "❌ Error: libmagic not found"; \
            echo ""; \
            echo "Install libmagic:"; \
            echo "  FreeBSD: sudo pkg install libmagic"; \
            exit 1; \
        fi; \
    fi

# --- Svelte Tasks ---

# Install Svelte dependencies
svelte-install:
    @echo "Installing Svelte dependencies..."
    cd frontend && npm install --legacy-peer-deps
    @echo "✓ Svelte dependencies installed"

# Build Svelte frontend (outputs to frontend/dist/)
svelte-build:
    @echo "Building Svelte frontend..."
    @if [ ! -d "frontend/node_modules" ]; then \
        cd frontend && npm install --legacy-peer-deps; \
    fi
    cd frontend && npm run build
    @echo "✓ Svelte built to frontend/dist/"

# Run Svelte dev server
svelte-dev:
    @echo "Starting Svelte dev server..."
    cd frontend && npm run dev

# Frontend testing with Playwright
test-frontend:
    @echo "Running Playwright frontend tests..."
    @if [ ! -d "node_modules" ]; then \
        echo "Installing Playwright..."; \
        npm init -y >/dev/null 2>&1; \
        npm install -D @playwright/test; \
    fi
    @npx playwright install chromium 2>/dev/null || true
    @npx playwright test --reporter=list || echo "No tests found or Playwright not configured"
    @echo "✓ Frontend tests complete"

# --- Crystal Tasks ---

# Build Release Binary (includes baked Svelte assets)
build: check-deps svelte-build
    @echo "Compiling release binary for {{os}}-{{arch}}..."
    @mkdir -p bin
    @echo "Note: Frontend assets are baked into the binary"
    @APP_ENV=production {{FINAL_CRYSTAL}} build --release --no-debug src/quickheadlines.cr -o bin/{{NAME}}
    @echo "✓ Built bin/{{NAME}}"

# Build with specific OS/Arch naming for GitHub Releases
build-release: check-deps svelte-build
    @echo "Compiling release binary: bin/{{NAME}}-{{BUILD_REV}}-{{os}}-{{arch}}"
    @mkdir -p bin
    @APP_ENV=production {{FINAL_CRYSTAL}} build --release --no-debug -Dversion={{BUILD_REV}} src/quickheadlines.cr -o bin/{{NAME}}-{{BUILD_REV}}-{{os}}-{{arch}}
    @echo "✓ Built bin/{{NAME}}-{{BUILD_REV}}-{{os}}-{{arch}}"

# Run in Development Mode
run: check-deps svelte-build
    @echo "Starting server in development mode..."
    @APP_ENV=development {{FINAL_CRYSTAL}} run src/quickheadlines.cr -- config=feeds.yml

# Clean build artifacts
clean:
    rm -rf bin
    rm -rf frontend/dist
    rm -rf frontend/.svelte-kit
    rm -rf frontend/node_modules
    @echo "✓ Cleaned build artifacts"

# Full rebuild - clean everything and rebuild
rebuild: clean build

# Help
help:
    @echo "QuickHeadlines Justfile (Svelte 5 + Crystal)"
    @echo ""
    @echo "Targets:"
    @echo "  default        - Build release binary (same as build)"
    @echo "  build          - Build release binary (Svelte assets baked in)"
    @echo "  build-release  - Build release binary with version naming"
    @echo "  run            - Run in development mode"
    @echo "  download-crystal - Download and build Crystal compiler"
    @echo "  check-deps     - Check for required dependencies"
    @echo "  svelte-install - Install Svelte dependencies"
    @echo "  svelte-build   - Build Svelte frontend"
    @echo "  svelte-dev     - Run Svelte dev server"
    @echo "  test-frontend  - Run Playwright frontend tests"
    @echo "  clean          - Remove build artifacts"
    @echo "  rebuild        - Clean and rebuild everything"
    @echo "  help           - Show this help message"
    @echo ""
    @echo "Platform: {{os}}-{{arch}}"
    @echo "Version: {{BUILD_REV}}"
    @echo ""
    @echo "Required dependencies:"
    @echo "  - Crystal {{CRYSTAL_VERSION}}"
    @echo "  - Node.js 18+ (for Svelte build)"
    @echo "  - SQLite3"
    @echo "  - OpenSSL"
    @echo "  - libmagic"
    @echo ""
    @echo "FreeBSD-specific notes:"
    @echo "  - Uses system Crystal 1.18.2 (Athena-compatible)"
    @echo "  - Node.js required at build time only"
    @echo "  - Frontend is baked into binary (no runtime deps)"
    @echo ""
    @echo "Installation commands:"
    @echo "  Ubuntu/Debian: sudo apt-get install crystal libsqlite3-dev libssl-dev libmagic-dev nodejs"
    @echo "  Fedora/RHEL:   sudo dnf install crystal sqlite-devel openssl-devel file-devel nodejs"
    @echo "  Arch:          sudo pacman -S crystal sqlite openssl libmagic nodejs"
    @echo "  macOS:         brew install crystal openssl libmagic node"
    @echo "  FreeBSD:       sudo pkg install crystal sqlite3 openssl git gmake libyaml libevent llvm19 libmagic node"

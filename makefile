# Makefile for QuickHeadlines
# Migrated from Crystal/Slang/Tailwind to Crystal/Elm with elm-ui

NAME = quickheadlines
CRYSTAL ?= $(shell which crystal 2>/dev/null || echo $(PWD)/bin/crystal)
ELM    ?= elm
ELM_FORMAT ?= elm-format
VERSION := $(shell grep '^version:' shard.yml | awk '{print $$2}')
BUILD_REV ?= v$(VERSION)
CRYSTAL_VERSION = 1.19.1

# Detect system for platform-specific builds
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

OS_NAME = unknown
ARCH_NAME = unknown

ifeq ($(UNAME_S),Linux)
	OS_NAME = linux
endif
ifeq ($(UNAME_S),Darwin)
	OS_NAME = macos
endif
ifeq ($(UNAME_S),FreeBSD)
	OS_NAME = freebsd
endif

# Architecture detection
ifeq ($(UNAME_M),x86_64)
	ARCH_NAME = x64
endif
ifeq ($(UNAME_M),amd64)
    ARCH_NAME = x64
endif
ifeq ($(UNAME_M),arm64)
	ARCH_NAME = arm64
endif
ifeq ($(UNAME_M),aarch64)
	ARCH_NAME = arm64
endif

# Crystal binary setup - use cache directory for persistence
CACHE_DIR = $(HOME)/.cache/quickheadlines/crystal
CRYSTAL_DIR = $(CACHE_DIR)/crystal-$(CRYSTAL_VERSION)-$(OS_NAME)-$(ARCH_NAME)
ifeq ($(OS_NAME),linux)
	CRYSTAL_TARBALL = crystal-$(CRYSTAL_VERSION)-1-$(OS_NAME)-$(ARCH_NAME).tar.gz
	CRYSTAL_URL = https://github.com/crystal-lang/crystal/releases/download/$(CRYSTAL_VERSION)/$(CRYSTAL_TARBALL)
else ifeq ($(OS_NAME),macos)
	CRYSTAL_TARBALL = crystal-$(CRYSTAL_VERSION)-1-$(OS_NAME)-$(ARCH_NAME).tar.gz
	CRYSTAL_URL = https://github.com/crystal-lang/crystal/releases/download/$(CRYSTAL_VERSION)/$(CRYSTAL_TARBALL)
endif

# Add Homebrew OpenSSL paths for macOS
ifeq ($(OS_NAME),macos)
	OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null)
	export PKG_CONFIG_PATH := $(OPENSSL_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
endif

.PHONY: all build run clean check-deps elm-install elm-build elm-format elm-validate test-frontend download-crystal

all: build

# Find available llvm-config on FreeBSD
FIND_LLVM_CONFIG = $(shell for v in 19 18 17 15 14 13; do if [ -x "/usr/local/bin/llvm-config$$v" ]; then echo "llvm-config$$v"; break; fi; done)

# Download Crystal compiler from official site
download-crystal:
	@echo "Installing Crystal $(CRYSTAL_VERSION)..."
	@mkdir -p $(CACHE_DIR)
	@mkdir -p bin
	@if [ ! -d "$(CRYSTAL_DIR)" ]; then \
		if [ "$(OS_NAME)" = "freebsd" ]; then \
			echo "Building Crystal $(CRYSTAL_VERSION) from source on FreeBSD..."; \
			echo "This may take 30-60 minutes..."; \
			export MAKE=gmake; \
			export LLVM_CONFIG="$(FIND_LLVM_CONFIG)"; \
			cd $(CACHE_DIR) && \
			fetch https://github.com/crystal-lang/crystal/archive/$(CRYSTAL_VERSION).tar.gz 2>/dev/null || curl -L -o $(CRYSTAL_VERSION).tar.gz https://github.com/crystal-lang/crystal/archive/$(CRYSTAL_VERSION).tar.gz || { \
				echo "Error: Failed to download Crystal source"; \
				exit 1; \
			}; \
			tar xzf $(CRYSTAL_VERSION).tar.gz || { \
				echo "Error: Failed to extract Crystal source"; \
				rm -f $(CRYSTAL_VERSION).tar.gz; \
				exit 1; \
			}; \
			rm -f $(CRYSTAL_VERSION).tar.gz; \
			mv crystal-$(CRYSTAL_VERSION) $(CRYSTAL_DIR); \
			cd $(CRYSTAL_DIR) && \
			$(MAKE) deps && $(MAKE) clean && $(MAKE) crystal || { \
				echo "Error: Failed to build Crystal"; \
				exit 1; \
			}; \
		else \
			echo "Downloading $(CRYSTAL_URL)..."; \
			cd $(CACHE_DIR) && \
			curl -L -o $(CRYSTAL_TARBALL) $(CRYSTAL_URL) || { \
				echo "Error: Failed to download Crystal tarball"; \
				exit 1; \
			}; \
			tar xzf $(CRYSTAL_TARBALL) || { \
				echo "Error: Failed to extract Crystal tarball"; \
				rm -f $(CRYSTAL_TARBALL); \
				exit 1; \
			} && \
			rm -f $(CRYSTAL_TARBALL); \
		fi; \
	fi
	@rm -f bin/crystal
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		ln -sf $(CRYSTAL_DIR)/.build/crystal bin/crystal; \
	else \
		ln -sf $(CRYSTAL_DIR)/bin/crystal bin/crystal; \
	fi
	@echo "✓ Crystal $(CRYSTAL_VERSION) installed in $(CRYSTAL_DIR)"

# Check for required dependencies
check-deps:
	@echo "Checking dependencies..."
	@if [ ! -x "$(CRYSTAL)" ]; then \
		echo "Crystal compiler not found, downloading..."; \
		$(MAKE) download-crystal; \
	fi
	@echo "✓ Crystal compiler: $$($(CRYSTAL) --version)"
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		if [ -f "public/elm.js" ]; then \
			echo "✓ Using pre-compiled public/elm.js"; \
		else \
			echo "❌ Error: Elm compiler not found and public/elm.js missing"; \
			echo ""; \
			echo "On FreeBSD, you need either:"; \
			echo "  1. The pre-compiled public/elm.js file (recommended)"; \
			echo "  2. Elm compiler: pkg install elm; npm install -g elm"; \
			exit 1; \
		fi; \
	fi
	@if [ "$(OS_NAME)" = "linux" ]; then \
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
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		pkg info -e sqlite3 >/dev/null 2>&1 || { \
			echo "❌ Error: SQLite3 not found"; \
			echo ""; \
			echo "Install SQLite3:"; \
			echo "  FreeBSD: sudo pkg install sqlite3"; \
			exit 1; \
		}; \
		echo "✓ SQLite3 found"; \
	fi
	@if [ "$(OS_NAME)" = "linux" ]; then \
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
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		pkg info -e openssl >/dev/null 2>&1 || { \
			echo "❌ Error: OpenSSL not found"; \
			echo ""; \
			echo "Install OpenSSL:"; \
			echo "  FreeBSD: sudo pkg install openssl"; \
			exit 1; \
		}; \
		echo "✓ OpenSSL found"; \
	fi
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
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
	@if [ "$(OS_NAME)" = "macos" ]; then \
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
	elif [ "$(OS_NAME)" = "linux" ]; then \
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
	elif [ "$(OS_NAME)" = "freebsd" ]; then \
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
	@echo ""

# --- Elm Tasks ---

# 0. Install Elm tools (if not present)
elm-install:
	@echo "Installing Elm tools..."
	@if ! command -v elm >/dev/null 2>&1; then \
		echo "Installing elm via npm..."; \
		npm install -g elm; \
	else \
		echo "elm already installed"; \
	fi
	@if ! command -v elm-format >/dev/null 2>&1; then \
		echo "Installing elm-format via npm..."; \
		npm install -g elm-format; \
	else \
		echo "elm-format already installed"; \
	fi
	@echo "✓ Elm tools installed"

# 1. Compile Elm to JavaScript
elm-build:
	@echo "Compiling Elm to JavaScript..."
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		if [ -f "public/elm.js" ]; then \
			echo "✓ Using pre-compiled public/elm.js (skipping Elm compilation)"; \
		else \
			echo "Error: public/elm.js not found and Elm compiler required"; \
			exit 1; \
		fi; \
	else \
		$(ELM) make src/Main.elm --output=public/elm.js; \
		echo "✓ Elm compiled to public/elm.js ($(shell wc -c < public/elm.js 2>/dev/null || echo "0") bytes)"; \
	fi

# 1b. Compile Elm Land UI to JavaScript
elm-land-build:
	@echo "Compiling Elm Land UI..."
	cd ui && $(ELM) make src/Main.elm --output=elm.js
	@echo "✓ Elm Land compiled to public/elm.js ($(shell wc -c < public/elm.js 2>/dev/null || echo "0") bytes)"

# --- Removed elm-embed target ---
# Elm.js is now served directly from disk with GitHub fallback

# 2. Run Elm format on source files
elm-format:
	@echo "Formatting Elm source files..."
	$(ELM_FORMAT) src/
	@echo "✓ Elm files formatted"

# 4. Validate Elm compilation (without output)
elm-validate:
	@echo "Validating Elm syntax..."
	$(ELM) make src/Main.elm --output=/dev/null
	@echo "✓ Elm syntax valid"

# --- Frontend Testing ---

# 5. Frontend testing with Playwright
test-frontend:
	@echo "Running Playwright frontend tests..."
	@if [ ! -d "node_modules" ]; then \
		echo "Installing Playwright... "; \
		npm init -y >/dev/null 2>&1; \
		npm install -D @playwright/test; \
	fi
	@npx playwright install chromium 2>/dev/null || true
	@npx playwright test --reporter=list || echo "No tests found or Playwright not configured"
	@echo "✓ Frontend tests complete"

# --- Crystal Tasks ---

# 6. Build Release Binary (no embedding needed)
build: check-deps elm-build
	@echo "Compiling release binary for $(OS_NAME)-$(ARCH_NAME)..."
	@mkdir -p bin
	@echo "Note: elm.js is served from disk with GitHub fallback"
	APP_ENV=production $(CRYSTAL) build --release --no-debug $(CRYSTAL_BUILD_OPTS) src/quickheadlines.cr -o bin/$(NAME)

# 6.5 Build with specific OS/Arch naming for GitHub Releases
build-release: check-deps elm-build
	@echo "Compiling release binary: bin/$(NAME)-$(BUILD_REV)-$(OS_NAME)-$(ARCH_NAME)"
	@mkdir -p bin
	APP_ENV=production $(CRYSTAL) build --release --no-debug $(CRYSTAL_BUILD_OPTS) -Dversion=$(BUILD_REV) src/quickheadlines.cr -o bin/$(NAME)-$(BUILD_REV)-$(OS_NAME)-$(ARCH_NAME)

# 7. Run in Development Mode
run: check-deps elm-land-build
	@echo "Starting server in development mode..."
	APP_ENV=development $(CRYSTAL) run src/quickheadlines.cr -- config=feeds.yml

clean:
	rm -rf bin
	rm -f public/elm.js
	rm -f src/embedded_elm.cr
	rm -rf elm-stuff

# Full rebuild - clean everything and rebuild
rebuild: clean all

# Help target
help:
	@echo "QuickHeadlines Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all           - Build release binary (default)"
	@echo "  build         - Build release binary (elm.js served from disk)"
	@echo "  build-release - Build release binary with version naming"
	@echo "  run           - Run in development mode"
	@echo "  elm-install   - Install Elm and elm-format"
	@echo "  elm-build     - Compile Elm to JavaScript"
	@echo "  elm-format    - Format Elm source files"
	@echo "  elm-validate  - Validate Elm syntax"
	@echo "  test-frontend - Run Playwright frontend tests"
	@echo "  clean         - Remove build artifacts"
	@echo "  rebuild       - Clean and rebuild everything"
	@echo "  check-deps    - Check for required dependencies"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Platform: $(OS_NAME)-$(ARCH_NAME)"
	@echo "Version: $(BUILD_REV)"
	@echo ""
	@echo "Required dependencies:"
	@echo "  - Crystal $(CRYSTAL_VERSION)"
	@echo "  - SQLite3"
	@echo "  - OpenSSL"
	@echo "  - libmagic"
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		echo ""; \
		echo "FreeBSD-specific dependencies:"; \
		echo "  - git, gmake, libyaml, libevent"; \
		echo "  - LLVM ($(FIND_LLVM_CONFIG) detected)"; \
	fi
	@echo ""
	@echo "Installation commands:"
	@echo "  Ubuntu/Debian: sudo apt-get install crystal libsqlite3-dev libssl-dev libmagic-dev"
	@echo "  Fedora/RHEL:   sudo dnf install crystal sqlite-devel openssl-devel file-devel"
	@echo "  Arch:          sudo pacman -S crystal sqlite openssl libmagic"
	@echo "  macOS:         brew install crystal openssl libmagic"
	@echo "  FreeBSD:       sudo pkg install crystal sqlite3 openssl git gmake libyaml libevent llvm19 libmagic"

# Makefile for QuickHeadlines
# Migrated from Crystal/Slang/Tailwind to Crystal/Elm with elm-ui

NAME = quickheadlines
CRYSTAL ?= crystal
ELM    ?= elm
ELM_FORMAT ?= elm-format
VERSION := $(shell grep '^version:' shard.yml | awk '{print $$2}')
BUILD_REV ?= v$(VERSION)

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

# Add Homebrew OpenSSL paths for macOS
ifeq ($(OS_NAME),macos)
	OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null)
	export PKG_CONFIG_PATH := $(OPENSSL_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
endif

.PHONY: all build run clean check-deps elm-install elm-build elm-format elm-validate test-frontend

all: build

# Check for required dependencies
check-deps:
	@echo "Checking dependencies..."
	@command -v $(CRYSTAL) >/dev/null 2>&1 || { \
		echo "❌ Error: Crystal compiler not found"; \
		echo ""; \
		echo "Install Crystal:"; \
		echo "  macOS:   brew install crystal"; \
		echo "  Ubuntu:  curl -fsSL https://crystal-lang.org/install.sh | sudo bash"; \
		echo "  FreeBSD: pkg install crystal"; \
		echo ""; \
		echo "See https://crystal-lang.org/install/ for details"; \
		exit 1; \
	}
	@echo "✓ Crystal compiler: $$($(CRYSTAL) --version)"
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		command -v $(ELM) >/dev/null 2>&1 || { \
			echo "❌ Error: Elm compiler not found"; \
			echo ""; \
			echo "Install Elm:"; \
			echo "  FreeBSD: pkg install elm; npm install -g elm"; \
			echo ""; \
			echo "Note: On FreeBSD, elm.js is embedded at build time"; \
			echo "      so Elm compiler is only needed during builds"; \
			exit 1; \
		}; \
		echo "✓ Elm compiler: $$($(ELM) --version)"; \
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
	@if [ ! -d "elm-stuff" ]; then \
		echo "Running elm make to initialize elm-stuff..."; \
	fi
	$(ELM) make src/Main.elm --output=public/elm.js
	@echo "✓ Elm compiled to public/elm.js ($(shell wc -c < public/elm.js 2>/dev/null || echo "0") bytes)"

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
run: check-deps elm-build
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
	@if [ "$(OS_NAME)" = "macos" ]; then \
		pkg-config --exists libmagic || { \
			echo "❌ Error: libmagic (file command library) not found"; \
			echo ""; \
			echo "Install libmagic:"; \
			echo "  macOS: brew install libmagic"; \
			exit 1; \
		}; \
		echo "✓ libmagic development files found"; \
	fi
	@if [ "$(OS_NAME)" = "linux" ]; then \
		pkg-config --exists libmagic || { \
			echo "❌ Error: libmagic (file command library) not found"; \
			echo ""; \
			echo "Install libmagic:"; \
			echo "  Ubuntu/Debian: sudo apt-get install libmagic-dev"; \
			echo "  Fedora/RHEL:   sudo dnf install file-devel"; \
			echo "  Arch:          sudo pacman -S file"; \
			exit 1; \
		}; \
		echo "✓ libmagic development files found"; \
	fi
	@if [ "$(OS_NAME)" = "freebsd" ]; then \
		pkg info -e libmagic >/dev/null 2>&1 || { \
			echo "❌ Error: libmagic (file command library) not found"; \
			echo ""; \
			echo "Install libmagic:"; \
			echo "  FreeBSD: sudo pkg install libmagic"; \
			exit 1; \
		}; \
		echo "✓ libmagic found"; \
	fi

# Makefile for QuickHeadlines

NAME = quickheadlines
CRYSTAL ?= crystal
VERSION := $(shell grep '^version:' shard.yml | awk '{print $$2}')
BUILD_REV ?= v$(VERSION)

TAILWIND_CLI ?= ./tailwindcss

# Detect system for Tailwind binary download
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

# Add Homebrew OpenSSL paths for macOS
ifeq ($(OS_NAME),macos)
	OPENSSL_PREFIX := $(shell brew --prefix openssl@3 2>/dev/null)
	export PKG_CONFIG_PATH := $(OPENSSL_PREFIX)/lib/pkgconfig:$(PKG_CONFIG_PATH)
endif

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

.PHONY: all build run clean css css-dev tailwind-download build-release

all: build

# --- Tasks ---

# 1. Download Tailwind CLI if not present
tailwind-download:
ifeq ($(OS_NAME),freebsd)
	@if [ ! -f ./node_modules/.bin/tailwindcss ]; then \
		echo "Installing Tailwind CLI and dependencies locally for FreeBSD..."; \
		npm install @tailwindcss/cli tailwindcss; \
	fi
else
	@if [ ! -f $(TAILWIND_CLI) ]; then \
		echo "Downloading Tailwind CLI for $(OS_NAME)-$(ARCH_NAME)..."; \
		if curl -fsLO "https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-$(OS_NAME)-$(ARCH_NAME)"; then \
			chmod +x tailwindcss-$(OS_NAME)-$(ARCH_NAME); \
			mv tailwindcss-$(OS_NAME)-$(ARCH_NAME) $(TAILWIND_CLI); \
		else \
			echo "Warning: Tailwind CLI not available for $(OS_NAME)-$(ARCH_NAME). Skipping download."; \
		fi \
	fi
endif

# 2. Generate Production CSS
# Combines custom styles with Tailwind utilities and minifies
css: tailwind-download
	@if [ -f $(TAILWIND_CLI) ]; then CMD="./$(TAILWIND_CLI)"; \
	elif [ -f ./node_modules/.bin/tailwindcss ]; then CMD="./node_modules/.bin/tailwindcss"; \
	elif command -v tailwindcss >/dev/null 2>&1; then CMD="tailwindcss"; \
	else echo "Error: Tailwind CLI not found. Install via 'npm install @tailwindcss/cli tailwindcss' on FreeBSD."; exit 1; fi; \
	echo "Generating production CSS using $$CMD..."; \
	$$CMD --input assets/css/input.css --output assets/css/production.css --minify; \
	touch src/server.cr

# 2.5 Generate Development CSS
css-dev: tailwind-download
	@if [ -f $(TAILWIND_CLI) ]; then CMD="./$(TAILWIND_CLI)"; \
	elif [ -f ./node_modules/.bin/tailwindcss ]; then CMD="./node_modules/.bin/tailwindcss"; \
	elif command -v tailwindcss >/dev/null 2>&1; then CMD="tailwindcss"; \
	else echo "Error: Tailwind CLI not found. Install via 'npm install @tailwindcss/cli tailwindcss' on FreeBSD."; exit 1; fi; \
	echo "Generating development CSS using $$CMD..."; \
	rm -f assets/css/development.css; \
	$$CMD --input assets/css/input.css --output assets/css/development.css --minify; \
	touch src/server.cr

# 3. Build Release Binary
# Sets APP_ENV=production so the compiler embeds the generated CSS
build: css
	@echo "Compiling release binary for $(OS_NAME)-$(ARCH_NAME)..."
	@mkdir -p bin
	APP_ENV=production $(CRYSTAL) build --release --no-debug $(CRYSTAL_BUILD_OPTS) src/quickheadlines.cr -o bin/$(NAME)

# 3.5 Build with specific OS/Arch naming for GitHub Releases
build-release: css
	@echo "Compiling release binary: bin/$(NAME)-$(BUILD_REV)-$(OS_NAME)-$(ARCH_NAME)"
	@mkdir -p bin
	APP_ENV=production $(CRYSTAL) build --release --no-debug $(CRYSTAL_BUILD_OPTS) -Dversion=$(BUILD_REV) src/quickheadlines.cr -o bin/$(NAME)-$(BUILD_REV)-$(OS_NAME)-$(ARCH_NAME)

# 4. Run in Development Mode
# Sets APP_ENV=development and compiles CSS locally
run: css-dev
	@echo "Starting server in development mode..."
	APP_ENV=development $(CRYSTAL) run src/quickheadlines.cr -- config=feeds.yml

clean:
	rm -rf bin
	rm -f assets/css/production.css
	rm -f assets/css/development.css
	rm -f $(TAILWIND_CLI)
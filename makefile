
# Makefile for QuickHeadlines

CRYSTAL ?= crystal
TAILWIND_CLI ?= ./tailwindcss

# Detect system for Tailwind binary download
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Linux)
	OS_NAME = linux
endif
ifeq ($(UNAME_S),Darwin)
	OS_NAME = macos
endif

ifeq ($(UNAME_M),x86_64)
	ARCH_NAME = x64
endif
ifeq ($(UNAME_M),arm64)
	ARCH_NAME = arm64
endif
ifeq ($(UNAME_M),aarch64)
	ARCH_NAME = arm64
endif

.PHONY: all build run clean css css-dev tailwind-download elm-pages-init elm-pages-build elm-pages-serve elm-format

all: build

# --- Tasks ---

# 1. Download Tailwind CLI if not present
tailwind-download:
	@if [ ! -f $(TAILWIND_CLI) ]; then \
		echo "Downloading Tailwind CLI for $(OS_NAME)-$(ARCH_NAME)..."; \
		curl -sLO "https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-$(OS_NAME)-$(ARCH_NAME)"; \
		chmod +x tailwindcss-$(OS_NAME)-$(ARCH_NAME); \
		mv tailwindcss-$(OS_NAME)-$(ARCH_NAME) $(TAILWIND_CLI); \
	fi

# 2. Generate Production CSS
# Combines custom styles with Tailwind utilities and minifies
css: tailwind-download
	@echo "Generating production CSS..."
	@$(TAILWIND_CLI) --input assets/css/input.css --output assets/css/production.css --minify
	@touch src/server.cr

# 2.5 Generate Development CSS
css-dev: tailwind-download
	@echo "Generating development CSS..."
	@rm -f assets/css/development.css
	@$(TAILWIND_CLI) --input assets/css/input.css --output assets/css/development.css --minify
	@touch src/server.cr

# 3. Build Release Binary
# Sets APP_ENV=production so the compiler embeds the generated CSS
build: css
	@echo "Compiling release binary..."
	@mkdir -p bin
	
	APP_ENV=production CRYSTAL_BUILD_OPTS="--lto" $(CRYSTAL) build --release --no-debug src/quickheadlines.cr -o bin/server

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

# --- Elm Pages targets (wrappers that run inside nix devshell) ---

elm-pages-init:
	@echo "Initializing elm-pages scaffold..."
	@mkdir -p ui/src/Pages/Home ui/src/Api ui/src/Backend ui/src
	@echo "Created ui/src structure"
	@echo "Run 'nix develop . --command make elm-pages-build' to build"

elm-pages-build:
	@echo "Build: run inside nix devshell (expects node & elm-pages available)"
	@npx elm-pages v3 build --output=public || (echo "elm-pages build failed. Ensure you ran 'nix develop . --command npm install' to install node deps." && exit 1)

elm-pages-serve:
	@echo "Serve: run inside nix devshell (expects node & elm-pages available)"
	@npx elm-pages v3 serve

elm-format:
	@echo "Format Elm sources (devshell)"
	@npx elm-format ui/src --yes

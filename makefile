
# Makefile for QuickHeadlines (updated)

# Keep Crystal build/run targets; remove Tailwind-specific tasks (project no longer uses Tailwind)
CRYSTAL ?= crystal

# System detection (used for platform-specific handling)
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Architecture name mapping (useful for platform-specific binaries)
ifeq ($(UNAME_M),x86_64)
ARCH_NAME = x64
endif
ifeq ($(UNAME_M),arm64)
ARCH_NAME = arm64
endif
ifeq ($(UNAME_M),aarch64)
ARCH_NAME = arm64
endif

# OS name mapping (used by download helpers)
ifeq ($(UNAME_S),Linux)
OS_NAME = linux
endif
ifeq ($(UNAME_S),Darwin)
OS_NAME = macos
endif
ifeq ($(UNAME_S),FreeBSD)
OS_NAME = freebsd
endif

# Prefer gmake on FreeBSD for GNU-make compatibility. This selects a
# recommended make program (gmake if available) so we can warn users
# when they run a non-gmake 'make' on FreeBSD.
ifeq ($(UNAME_S),FreeBSD)
  # Prefer GNU make (gmake) on FreeBSD. If gmake is installed set MAKE to gmake
  # so that recursive make invocations use the GNU-compatible binary.
  ifneq (,$(shell command -v gmake 2>/dev/null))
    MAKE := gmake
  else
    $(warning "Detected FreeBSD but 'gmake' not found. Install gmake or some targets may fail.")
  endif
endif

# Prefer a system-installed `crystal` when available. If not present, fall back
# to a bundled `bin/crystal` (used in some developer setups) or the CRYSTAL var.
## Final crystal resolver with FreeBSD pin support
# On FreeBSD prefer a system `crystal` that matches 1.18.2 (Athena compatibility).
FINAL_CRYSTAL := $(shell sh -c 'if [ "$(UNAME_S)" = "FreeBSD" ]; then if command -v crystal >/dev/null 2>&1; then ver=$$(crystal --version 2>/dev/null | sed -n "s/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p"); if [ "$$ver" = "1.18.2" ]; then echo crystal; elif [ -x bin/crystal ]; then echo bin/crystal; else echo crystal; fi; else if [ -x bin/crystal ]; then echo bin/crystal; else echo crystal; fi; fi; elif [ "$(UNAME_S)" = "Darwin" ]; then if command -v crystal >/dev/null 2>&1; then echo crystal; elif [ -x bin/crystal ]; then echo bin/crystal; else echo "$(CRYSTAL)"; fi; elif [ "$(UNAME_S)" = "Linux" ]; then if command -v crystal >/dev/null 2>&1; then echo crystal; elif [ -x bin/crystal ]; then echo bin/crystal; else echo "$(CRYSTAL)"; fi; else if command -v crystal >/dev/null 2>&1; then echo crystal; elif [ -x bin/crystal ]; then echo bin/crystal; else echo "$(CRYSTAL)"; fi; fi')

.PHONY: all build run clean elm-pages-init elm-pages-build elm-pages-serve elm-format

all: build

# Build release binary
build:
	@echo "Compiling release binary..."
	@mkdir -p bin
	APP_ENV=production CRYSTAL_BUILD_OPTS="--lto" $(FINAL_CRYSTAL) build --release --no-debug src/quickheadlines.cr -o bin/server

# Run in development mode
run:
	@echo "Starting server in development mode..."
	APP_ENV=development $(FINAL_CRYSTAL) run src/quickheadlines.cr -- config=feeds.yml

clean:
	@rm -rf bin
	@rm -f public/elm.js

# --- Elm Pages helpers (use inside nix devshell) ---
# These are thin wrappers; node & elm-pages should be available in the dev environment

elm-pages-init:
	@echo "Initializing elm-pages scaffold..."
	@mkdir -p ui/src/Pages/Home ui/src/Api ui/src/Backend ui/src
	@echo "Created ui/src structure"

elm-pages-build:
	@echo "Building elm-pages (requires node & elm-pages)."
	@npx elm-pages build --output=public || (echo "elm-pages build failed. If running in nix devshell, run 'npm install' in project root to install node deps." && exit 1)

elm-pages-serve:
	@echo "Serving elm-pages (requires node & elm-pages)."
	@npx elm-pages serve

elm-format:
	@echo "Format Elm sources (requires npx elm-format)"
	@npx elm-format ui/src --yes

# --- Utilities ---
# download-cli: download a platform-specific CLI into $(DOWNLOAD_DIR)
# Usage:
#   make download-cli NAME=tool-name URL="https://.../__OS__/.../__ARCH__/..." \
#       DOWNLOAD_DIR=bin
# The URL may include placeholders __OS__ and __ARCH__ that will be replaced.
DOWNLOAD_DIR ?= bin

.PHONY: download-cli ensure-crystal env

download-cli:
	@if [ -z "$(NAME)" -o -z "$(URL)" ]; then \
		echo "Usage: make download-cli NAME=<name> URL='<url-with-__OS__ or __ARCH__ placeholders>' [DOWNLOAD_DIR=bin]"; exit 1; \
	fi; \
	mkdir -p $(DOWNLOAD_DIR); \
	url=$$(echo "$(URL)" | sed "s/__OS__/$(OS_NAME)/g" | sed "s/__ARCH__/$(ARCH_NAME)/g"); \
	echo "Downloading $$url -> $(DOWNLOAD_DIR)/$(NAME)"; \
	curl -fsSL "$$url" -o "$(DOWNLOAD_DIR)/$(NAME)" || { echo "download failed"; exit 1; }; \
	chmod +x "$(DOWNLOAD_DIR)/$(NAME)"; \
	echo "Saved to $(DOWNLOAD_DIR)/$(NAME)"

ensure-crystal:
	@echo "OS: $(UNAME_S) $(UNAME_M) -> OS_NAME=$(OS_NAME) ARCH_NAME=$(ARCH_NAME)"
	@echo "Using Crystal: $(FINAL_CRYSTAL)"
	@$(FINAL_CRYSTAL) --version || echo "Crystal not found or not executable. Install a compatible Crystal or provide bin/crystal."

env:
	@echo "UNAME_S=$(UNAME_S) UNAME_M=$(UNAME_M) OS_NAME=$(OS_NAME) ARCH_NAME=$(ARCH_NAME)"

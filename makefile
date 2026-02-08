
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

# Prefer a system-installed `crystal` when available. If not present, fall back
# to a bundled `bin/crystal` (used in some developer setups) or the CRYSTAL var.
## Final crystal resolver with FreeBSD pin support
# On FreeBSD prefer a system `crystal` that matches 1.18.2 (Athena compatibility).
FINAL_CRYSTAL := $(shell \
  case "$(UNAME_S)" in \
    FreeBSD) \
      # Prefer system Crystal on FreeBSD only if it's the Athena-compatible 1.18.2
      if command -v crystal >/dev/null 2>&1; then \
        ver=$$(crystal --version 2>/dev/null | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p'); \
        if [ "$$ver" = "1.18.2" ]; then echo "crystal"; else if [ -x bin/crystal ]; then echo "bin/crystal"; else echo "crystal"; fi; fi; \
      else \
        if [ -x bin/crystal ]; then echo "bin/crystal"; else echo "crystal"; fi; \
      fi;; \
    Darwin) \
      # macOS: prefer the system/homebrew crystal if available, otherwise bundled
      if command -v crystal >/dev/null 2>&1; then echo "crystal"; elif [ -x bin/crystal ]; then echo "bin/crystal"; else echo "$(CRYSTAL)"; fi;; \
    Linux) \
      # Linux: prefer system crystal when present, fall back to bundled binary
      if command -v crystal >/dev/null 2>&1; then echo "crystal"; elif [ -x bin/crystal ]; then echo "bin/crystal"; else echo "$(CRYSTAL)"; fi;; \
    *) \
      # Default: try system, then bundle, then CRYSTAL env
      if command -v crystal >/dev/null 2>&1; then echo "crystal"; elif [ -x bin/crystal ]; then echo "bin/crystal"; else echo "$(CRYSTAL)"; fi;; \
  esac)

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

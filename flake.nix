{
  description = "Full Crystal & Beads Dev Environment with KiloCode Integration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        
        # User Home Directory (automatically detects based on your system)
        homeDir = builtins.getEnv "HOME";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # General depedencies
            git
            
            # 💎 Crystal Language & Web Dependencies
            crystal
            shards
            pkg-config
            openssl
            sqlite
            libxml2
            libyaml
            libevent
            zlib
            protobuf
            # For libgc and general compilation:
            boehmgc
            pkg-config
            pcre2

            # 🟢 Node.js & Frontend (for beads-ui and carafe.cr)
            nodejs_22
            playwright-driver.browsers # Native Nix browsers for Playwright
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-test

            # 🐹 Go & Python Tools
            go
            python3
            python3Packages.pip

            # 🛠️ Standard Build Tools
            gnumake
            gcc
            git
            curl
            bashInteractive
            tzdata
            docker-client # Matches your DOCKER_HOST setup
          ];

          shellHook = ''
            # --- Docker Compose Environment Equivalence ---
            export APP_ENV=development
            export TZ=America/Chicago
            
            # --- Native KiloCode & Project Bindings ---
            export KILOCODE_PATH="${homeDir}/.kilocode"
            export LANG_DB_PATH="${homeDir}/code/lang-db"
            export THE_BRAIN_PATH="${homeDir}/code/thebrain"

            # --- Tooling Paths ---
            # Ensures pipx, beads (bd), and local bin are priority
            export PATH="$PWD/bin:$HOME/.local/bin:$(go env GOPATH)/bin:$PATH"
            
            # Playwright Configuration
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

            # --- Logic for Beads (bd) and Spec-Kitty ---
            if ! command -v bd &> /dev/null; then
              echo "Installing beads (bd) to GOBIN..."
              go install github.com/steveyegge/beads/cmd/bd@latest
            fi

          # 1. Create a virtual environment for python tools if it doesn't exist
          if [ ! -d ".venv" ]; then
            python3 -m venv .venv
          fi
          source .venv/bin/activate

          # 2. Install/Update spec-kitty inside the venv
          # This keeps it isolated from the system but accessible to the flake
          pip install -q spec-kitty-cli

          # 3. BRIDGE: Create the symlink so Kilo Code/Beads can find it
          mkdir -p ~/.local/bin
          ln -sf $(which spec-kitty) ~/.local/bin/spec-kitty

          echo "✅ Spec Kitty bridged to ~/.local/bin/spec-kitty"
          
          # This tells the linker where to find libgc.so.1
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent ]}:$LD_LIBRARY_PATH"
          
          # Ensure pkg-config can find the .pc files for Crystal
          export PKG_CONFIG_PATH="${pkgs.boehmgc.dev}/lib/pkgconfig:${pkgs.libevent.dev}/lib/pkgconfig"
          
          # Refresh our bridge links
          mkdir -p ~/.local/bin
          ln -sf $(which elm-format) ~/.local/bin/elm-format

          echo "🚀 Environment Loaded Successfully!"
          echo "💎 Crystal: $(crystal --version | head -n1)"
          echo "🛠️ KiloCode Rules: $KILOCODE_RULES_PATH"
          echo "📂 Linked Project: $LANG_DB_PATH"

          # 1. Ensure the directory for the socket exists
          mkdir -p /workspaces/quickheadlines/.beads

          # 2. Check if the daemon is running; if not, start it
          if ! bd daemon status >/dev/null 2>&1; then
            echo "🤖 Starting Beads daemon..."
            bd daemon start
            
            # Optional: wait a moment for the socket to initialize
            sleep 1
          fi

          # 3. Set the environment variable for tools that look for it
          export BD_SOCKET="/workspaces/quickheadlines/.beads/bd.sock"
          
          echo "✅ Beads environment active"

          # Get the absolute paths for our tools
          export CRYSTAL_BIN="$(which crystal)"
          export SPEC_KITTY_BIN="$(which spec-kitty)"
          
          # Inject them into the environment variables the AI looks for
          export PATH="$PATH:$(dirname $CRYSTAL_BIN):$(dirname $SPEC_KITTY_BIN)"
          
          # Restart the daemon so it inherits this new PATH
          bd daemon stop >/dev/null 2>&1
          bd daemon start

          '';
        };
      });
}

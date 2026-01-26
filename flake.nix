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

            # 🟢 Node.js & Frontend (for beads-ui and carafe.cr)
            nodejs_22
            playwright-driver.browsers # Native Nix browsers for Playwright
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-test

            # 🐹 Go & Python Tools
            go
            (python3.withPackages (ps: with ps; [ pipx ]))

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

            if ! command -v spec-kitty &> /dev/null; then
              echo "Installing spec-kitty-cli..."
              pipx install spec-kitty-cli
            fi

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
          '';
        };
      });
}
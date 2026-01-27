{
  description = "Full Crystal 1.19.1 & Beads Dev Environment with KiloCode Integration";

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
        
        homeDir = builtins.getEnv "HOME";

        # 💎 Official Crystal 1.19.1 Binary (Statically Linked for ARM64)
        crystal_1_19 = pkgs.stdenv.mkDerivation rec {
          pname = "crystal";
          version = "1.19.1";

          src = pkgs.fetchurl {
            url = "https://github.com/crystal-lang/crystal/releases/download/${version}/crystal-${version}-1-linux-aarch64.tar.gz";
            sha256 = "sha256-5L/JfRj6HAVd+Umy2MSunk6P5RfaLepTbP85kuw096M="; 
          };

          # We don't need patchelf for static binaries!
          installPhase = ''
            mkdir -p $out
            cp -r ./* $out/
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # 💎 Crystal 1.19.1 & Core Deps
            crystal_1_19
            shards
            pkg-config
            openssl
            sqlite
            libxml2
            libyaml
            libevent
            zlib
            protobuf
            boehmgc
            pcre2
            file

            # 🟢 Node & Frontend
            nodejs_22
            playwright-driver.browsers
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-test

            # 🐹 Go & Python
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
            docker-client
          ];

          shellHook = ''
            # --- Docker & Env ---
            export APP_ENV=development
            export TZ=America/Chicago
            
            # --- Project Bindings ---
            export KILOCODE_PATH="${homeDir}/.kilocode"
            export LANG_DB_PATH="${homeDir}/code/lang-db"
            export THE_BRAIN_PATH="${homeDir}/code/thebrain"

            # --- Tooling Paths ---
            export PATH="$PWD/bin:$HOME/.local/bin:$(go env GOPATH)/bin:$PATH"
            
            # Playwright
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true

            # --- Beads (bd) & Spec-Kitty Logic ---
            if ! command -v bd &> /dev/null; then
              echo "Installing beads (bd)..."
              go install github.com/steveyegge/beads/cmd/bd@latest
            fi

            if [ ! -d ".venv" ]; then
              python3 -m venv .venv
            fi
            source .venv/bin/activate
            pip install -q spec-kitty-cli

            # --- Bridges ---
            mkdir -p ~/.local/bin
            ln -sf $(which spec-kitty) ~/.local/bin/spec-kitty
            ln -sf ${crystal_1_19}/bin/crystal ~/.local/bin/crystal
            ln -sf ${crystal_1_19}/bin/shards ~/.local/bin/shards
            ln -sf $(which elm-format) ~/.local/bin/elm-format
            
            # --- Library Paths (libgc and libmagic fixes) ---
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent pkgs.libyaml pkgs.openssl pkgs.pcre2 pkgs.file ]}:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="${pkgs.boehmgc.dev}/lib/pkgconfig:${pkgs.libevent.dev}/lib/pkgconfig:${pkgs.file.dev}/lib/pkgconfig"

            # --- Beads Daemon Management (The 'bd' fixes) ---
            mkdir -p /workspaces/quickheadlines/.beads
            export BD_SOCKET="/workspaces/quickheadlines/.beads/bd.sock"

            if ! bd daemon status >/dev/null 2>&1; then
              echo "🤖 Starting Beads daemon..."
              bd daemon start
              sleep 1
            fi

            # --- AI Path Injection ---
            export CRYSTAL_BIN="$(which crystal)"
            export SPEC_KITTY_BIN="$(which spec-kitty)"
            export PATH="$PATH:$(dirname $CRYSTAL_BIN):$(dirname $SPEC_KITTY_BIN)"

            # Force daemon to pick up the new PATH
            bd daemon stop >/dev/null 2>&1
            bd daemon start

            echo "🚀 Environment Ready! Crystal: $(crystal --version | head -n1)"
          '';
        };
      });
}
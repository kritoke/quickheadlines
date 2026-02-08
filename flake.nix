{
  description = "Quickheadlines Spoke - Crystal & Elm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs = { self, nixpkgs, openspec }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # 💎 Use nixpkgs Crystal 1.18.2
      crystal_1_18 = pkgs.crystal;
    in {
      # Nesting under the system fixes the 'attribute missing' error
      devShells.${system} = {
        default = pkgs.mkShell {
            buildInputs = with pkgs; [
              crystal
              bash
              shards pkg-config openssl sqlite libxml2 libyaml
              libevent zlib pcre2 gmp boehmgc file
              elmPackages.elm elmPackages.elm-format elmPackages.elm-review
              git curl gnumake gcc
              openspec.packages.${system}.default
              pkgs.playwright-driver.browsers
              ameba
            ];

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent pkgs.openssl pkgs.file pkgs.pcre2 pkgs.gmp ]}:$LD_LIBRARY_PATH"

            mkdir -p ~/.local/bin
            ln -sf ${pkgs.crystal}/bin/crystal ~/.local/bin/crystal
            ln -sf ${pkgs.crystal}/bin/shards ~/.local/bin/shards
            ln -sf ${openspec.packages.${system}.default}/bin/openspec ~/.local/bin/openspec

            # Ensure the openspec package's bin directory is first on PATH so the
            # binary is resolvable in all subsequent shell commands.
            export PATH="${openspec.packages.${system}.default}/bin:$HOME/.local/bin:$PWD/bin:$PATH"
            export HUB_ROOT="/workspaces"
            export PATH="$PATH:$HUB_ROOT/aiworkflow/bin:$HOME/go/bin"
            export SSH_AUTH_SOCK="/workspaces/.ssh-auth.sock"

            # [ -f "/workspaces/aiworkflow/bin/env.sh" ] && source /workspaces/aiworkflow/bin/env.sh

            export APP_ENV=development
            echo "🚀 Quickheadlines Loaded with Crystal"

            # Avoid creating aliases that interfere with command lookup; rely on PATH
            export OPEN_SPEC_PROJECT_DIR="$PWD"
            
            # 🌐 Playwright ARM64 Setup
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            echo "🌐 Playwright ARM64 Environment Ready"

            # Guarded check for OpenSpec so shell initialization doesn't fail if
            # the binary is not present or PATH isn't set yet.
            if command -v openspec >/dev/null 2>&1; then
              echo "🚀 Quickheadlines DevShell Active | OpenSpec $(openspec --version)"
            else
              echo "🚀 Quickheadlines DevShell Active | OpenSpec (not found on PATH)"
            fi
          '';
        };
      };
    };
}

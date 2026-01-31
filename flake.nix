{
  description = "Quickheadlines Spoke - Crystal 1.19.1 & Elm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs = { self, nixpkgs, openspec }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # 💎 Manual Crystal 1.19.1 Derivation
      crystal_1_19 = pkgs.stdenv.mkDerivation rec {
        pname = "crystal";
        version = "1.19.1";
        src = pkgs.fetchurl {
          url = "https://github.com/crystal-lang/crystal/releases/download/${version}/crystal-${version}-1-linux-aarch64.tar.gz";
          sha256 = "sha256-5L/JfRj6HAVd+Umy2MSunk6P5RfaLepTbP85kuw096M="; 
        };
        installPhase = "mkdir -p $out && cp -r ./* $out/";
      };
    in {
      # Nesting under the system fixes the 'attribute missing' error
      devShells.${system} = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            crystal_1_19
            shards pkg-config openssl sqlite libxml2 libyaml
            libevent zlib pcre2 gmp boehmgc file
            elmPackages.elm elmPackages.elm-format
            git curl gnumake gcc
            openspec.packages.${system}.default
            pkgs.playwright-driver.browsers
          ];

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent pkgs.openssl pkgs.file pkgs.pcre2 pkgs.gmp ]}:$LD_LIBRARY_PATH"

            mkdir -p ~/.local/bin
            ln -sf ${crystal_1_19}/bin/crystal ~/.local/bin/crystal
            ln -sf ${crystal_1_19}/bin/shards ~/.local/bin/shards

            export PATH="$PWD/bin:$PATH"
            export HUB_ROOT="/workspaces"
            export PATH="$PATH:$HUB_ROOT/aiworkflow/bin:$HOME/go/bin:$HOME/.local/bin"
            export SSH_AUTH_SOCK="/workspaces/.ssh-auth.sock"

            # [ -f "/workspaces/aiworkflow/bin/env.sh" ] && source /workspaces/aiworkflow/bin/env.sh

            export APP_ENV=development
            echo "🚀 Quickheadlines Loaded with Crystal 1.19.1"

            # 3. Add the alias to prevent the 'directory collision' error
            alias openspec='command openspec'
            
            # 4. Explicitly export the path to ensure AI tools find it
            export PATH="${openspec.packages.${system}.default}/bin:$PATH"
            
            # 🌐 Playwright ARM64 Setup
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            echo "🌐 Playwright ARM64 Environment Ready"

            echo "🚀 Quickheadlines DevShell Active | OpenSpec $(openspec --version)"
          '';
        };
      };
    };
}

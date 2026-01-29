{
  description = "Quickheadlines Spoke - Crystal 1.19.1 & Elm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
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
            libevent zlib pcre2 gmp boehmgc file nodejs_22 
            elmPackages.elm elmPackages.elm-format playwright-driver.browsers
            git curl gnumake gcc 
          ];

          shellHook = ''
            # 1. Library Path Fixes
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent pkgs.openssl pkgs.file pkgs.pcre2 pkgs.gmp ]}:$LD_LIBRARY_PATH"
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
            
            # 2. Bridge to home bin for VS Code & KiloCode
            mkdir -p ~/.local/bin
            ln -sf ${crystal_1_19}/bin/crystal ~/.local/bin/crystal
            ln -sf ${crystal_1_19}/bin/shards ~/.local/bin/shards

            # 3. Load Hub/Workflow Logic
            [ -f "/workspaces/aiworkflow/bin/env.sh" ] && source /workspaces/aiworkflow/bin/env.sh
            
            export APP_ENV=development
            export BD_SOCKET="/workspaces/quickheadlines/.beads/bd.sock"
            
            echo "🚀 Quickheadlines Loaded with Crystal 1.19.1"
          '';
        };
      };
    };
}

{
  description = "Quickheadlines Spoke - Nim backend (port) & Svelte 5 frontend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs = { self, nixpkgs, openspec }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Nim toolchain (nim-backend-port branch). Replaces the Crystal
      # toolchain from main. nim + nimble come straight from nixpkgs;
      # verified via spoke-gen (kritoke/aiworkflow#1): nim 2.2.4.
      nimToolchain = [ pkgs.nim pkgs.nimble ];

      # Frontend toolchain is carried over verbatim from the Crystal spoke
      # (Svelte 5 SPA is out of scope for the port).
      frontendToolchain = [ pkgs.nodejs_22 pkgs.pnpm ];

      # Native libs the Nim backend will bind to: SQLite (stores), libxml2
      # (RSS/Atom parsing), openssl (TLS), zlib. pkg-config to locate them.
      nativeLibs = with pkgs; [ sqlite libxml2 openssl zlib pcre2 gmp pkg-config ];

      # Read a local flake.private.nix if present (same shape as the Crystal spoke).
      private_hook = builtins.tryEval (if builtins.pathExists ./flake.private.nix then builtins.readFile ./flake.private.nix else "");

    in {
      devShells.${system} = {
        default = pkgs.mkShell {
          buildInputs = nimToolchain ++ frontendToolchain ++ nativeLibs ++ (with pkgs; [
            git curl gnumake gcc file
            openspec.packages.${system}.default
            shot-scraper
          ]);

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.sqlite pkgs.libxml2 pkgs.openssl pkgs.zlib pkgs.pcre2 pkgs.gmp ]}:$LD_LIBRARY_PATH"

            mkdir -p ~/.local/bin
            ln -sf ${pkgs.nim}/bin/nim ~/.local/bin/nim
            ln -sf ${pkgs.nimble}/bin/nimble ~/.local/bin/nimble
            ln -sf ${openspec.packages.${system}.default}/bin/openspec ~/.local/bin/openspec

            export PATH="${openspec.packages.${system}.default}/bin:$HOME/.local/bin:$PWD/bin:$PATH"
            export OPEN_SPEC_PROJECT_DIR="$PWD"
            export APP_ENV=development

            echo "🚀 Quickheadlines Nim Port DevShell | Nim $(nim --version | head -1)"

            if command -v openspec >/dev/null 2>&1; then
              echo "🚀 OpenSpec $(openspec --version)"
            fi

            ${if private_hook.success then private_hook.value else ""}
          '';
        };
      };
    };
}

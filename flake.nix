{
  description = "Quickheadlines Spoke - Crystal & Svelte 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs = { self, nixpkgs, openspec }:
    let
      system = "aarch64-linux";

      # Crystal 1.21.0 - nixpkgs unstable still packages 1.19.1, so wrap the
      # official prebuilt release tarballs (statically-linked compiler ELF,
      # stdlib under lib/crystal). Provided as a separate `crystal1_21` attr so
      # nixpkgs' `crystal` (and its passthru.buildCrystalPackage, needed by
      # `shards`) stays intact. Swap the devshell back to pkgs.crystal once
      # nixpkgs catches up.
      crystalOverlay = final: prev: {
        crystal1_21 = final.stdenv.mkDerivation rec {
          pname = "crystal";
          version = "1.21.0";

          arch = {
            aarch64-linux = "aarch64";
            x86_64-linux = "x86_64";
          }.${final.stdenv.system} or (throw "crystal ${version}: unsupported system ${final.stdenv.system}");

          src = final.fetchurl {
            url = "https://github.com/crystal-lang/crystal/releases/download/${version}/crystal-${version}-1-linux-${arch}.tar.gz";
            sha256 = {
              aarch64-linux = "sha256-TzDan/CD3EhWUuPZsE1+gsxMSftuirO6x2y94k2WB3g=";
              x86_64-linux = "sha256-dEVh7jzuGwbRBs+a6ZuAZLTgF1GKxBTW3SPPr+NlYMk=";
            }.${final.stdenv.system} or (throw "no hash for ${final.stdenv.system}");
          };

          nativeBuildInputs = with final; [ autoPatchelfHook ];
          buildInputs = with final; [
            boehmgc gmp libevent libyaml libxml2 libffi openssl pcre2 zlib
          ];

          strictDeps = true;

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r * $out/
            runHook postInstall
          '';

          meta = with final.lib; {
            description = "Crystal ${version} (official prebuilt, auto-patched)";
            platforms = [ "aarch64-linux" "x86_64-linux" ];
          };
        };
      };

      pkgs = nixpkgs.legacyPackages.${system}.extend crystalOverlay;


      # Read a local flake.private.nix if present. We wrap it in a guard so
      # Nix evaluation doesn't error when the file is missing.
      private_hook = builtins.tryEval (if builtins.pathExists ./flake.private.nix then builtins.readFile ./flake.private.nix else "");

    in {
      # Nesting under the system fixes the 'attribute missing' error
      devShells.${system} = {
        default = pkgs.mkShell {
            buildInputs = with pkgs; [
              crystal1_21
              bash
              shards pkg-config openssl sqlite libxml2 libyaml
              libevent zlib pcre2 gmp boehmgc file
              # Svelte 5 build tools
              nodejs_22 pnpm
              git curl gnumake gcc
              openspec.packages.${system}.default
              ameba
              # Screenshot tools
              shot-scraper
            ];

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.boehmgc pkgs.libevent pkgs.openssl pkgs.file pkgs.pcre2 pkgs.gmp ]}:$LD_LIBRARY_PATH"

            mkdir -p ~/.local/bin
            ln -sf ${pkgs.crystal1_21}/bin/crystal ~/.local/bin/crystal
            ln -sf ${pkgs.crystal1_21}/bin/shards ~/.local/bin/shards
            ln -sf ${openspec.packages.${system}.default}/bin/openspec ~/.local/bin/openspec

            # Ensure the openspec package's bin directory is first on PATH so the
            # binary is resolvable in all subsequent shell commands.
            export PATH="${openspec.packages.${system}.default}/bin:$HOME/.local/bin:$PWD/bin:$PATH"

            export APP_ENV=development
            echo "🚀 Quickheadlines Loaded with Crystal & Svelte 5"

            # Avoid creating aliases that interfere with command lookup; rely on PATH
            export OPEN_SPEC_PROJECT_DIR="$PWD"

            # Guarded check for OpenSpec so shell initialization doesn't fail if
            # the binary is not present or PATH isn't set yet.
            if command -v openspec >/dev/null 2>&1; then
              echo "🚀 Quickheadlines DevShell Active | OpenSpec $(openspec --version)"
            else
              echo "🚀 Quickheadlines DevShell Active | OpenSpec (not found on PATH)"
            fi

            # Private system-specific configuration (from flake.private.nix)
            ${if private_hook.success then private_hook.value else ""}
          '';
        };
      };
    };
}

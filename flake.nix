{
  description = "Quickheadlines Spoke - Crystal & Svelte 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    openspec.url = "github:Fission-AI/OpenSpec";
    ticket-src = {
      url = "github:wedow/ticket";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, openspec, ticket-src }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Import private configuration (not tracked in git)
      privateConfig = if builtins.pathExists ./flake.private.nix
        then import ./flake.private.nix
        else {};

      # 💎 Use nixpkgs Crystal 1.18.2
      crystal_1_18 = pkgs.crystal;

      # Minimal derivation for the ticket bash script
      ticket = pkgs.stdenv.mkDerivation {
        pname = "ticket";
        version = "latest";
        src = ticket-src;
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/bin
          cp ticket $out/bin/ticket
          chmod +x $out/bin/ticket
        '';
      };
<<<<<<< HEAD

      # Read a local flake.private.nix if present. We wrap it in a guard so
      # Nix evaluation doesn't error when the file is missing.
      private_hook = builtins.tryEval (if builtins.pathExists ./flake.private.nix then builtins.readFile ./flake.private.nix else "");

=======
>>>>>>> 22b6938 (Remove deprecated root package.json and package-lock.json)
    in {
      # Nesting under the system fixes the 'attribute missing' error
      devShells.${system} = {
        default = pkgs.mkShell {
            buildInputs = with pkgs; [
              crystal
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
              # Ticket AI task management
              ticket
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
            # Add ticket to PATH for AI task management
            export PATH="$PATH:${ticket}/bin"
<<<<<<< HEAD
<<<<<<< HEAD

            # Ticket AI Task Management
            export TICKET_DIR="$PWD/.tickets"
            if [ ! -d "$TICKET_DIR" ]; then
              echo "🎟️ Initializing local Ticket storage in $TICKET_DIR"
              mkdir -p "$TICKET_DIR"
            fi
=======
            export HUB_ROOT="/workspaces"
            export PATH="$PATH:$HUB_ROOT/aiworkflow/bin:$HOME/go/bin"
            export SSH_AUTH_SOCK="/workspaces/.ssh-auth.sock"
>>>>>>> 22b6938 (Remove deprecated root package.json and package-lock.json)
=======

            # Private system-specific configuration (from flake.private.nix)
            export HUB_ROOT="${privateConfig.hub-root or "/workspaces"}"
            export PATH="$PATH:${privateConfig.aiworkflow-bin or "$HUB_ROOT/aiworkflow/bin"}:${privateConfig.go-bin or "$HOME/go/bin"}"
            export SSH_AUTH_SOCK="${privateConfig.ssh-auth-sock or "/workspaces/.ssh-auth.sock"}"
>>>>>>> 9cff036 (Move system-specific flake config to flake.private.nix)

            # Ticket AI Task Management
            export TICKET_DIR="$PWD/.tickets"
            if [ ! -d "$TICKET_DIR" ]; then
              echo "🎟️ Initializing local Ticket storage in $TICKET_DIR"
              mkdir -p "$TICKET_DIR"
            fi

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

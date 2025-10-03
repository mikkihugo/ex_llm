{
  description = "Seed Agent development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beam.packages.erlang_28;
        elixirSrc = import ./nix/elixir-gleam-source.nix { inherit pkgs; };
        elixirGleam = import ./nix/elixir-gleam-package.nix {
          inherit pkgs beamPackages;
          src = elixirSrc;
        };

        commonTools = with pkgs; [
          git
          gh
          curl
          openssl
          pkg-config
          direnv
          gnused
          gawk
          coreutils
          findutils
          ripgrep
          fd
          jq
          bat
          htop
          watchexec
          entr
          just
          nil
          nixfmt-rfc-style
        ];

        beamTools = [
          beamPackages.erlang
          elixirGleam
          beamPackages.hex
          beamPackages.rebar3
          pkgs.elixir_ls
          pkgs.gleam
        ];

        dataServices = with pkgs; [
          postgresql_17
          sqlite
          redis
        ];

        webAndCli = with pkgs; [
          # No nodejs - bun is enough
          flyctl
          bun
        ];

        qaTools = with pkgs; [
          semgrep
          shellcheck
          hadolint
          nodePackages.eslint
          nodePackages.typescript-language-server
          nodePackages.typescript
        ];

        # AI CLIs - installed via npm in shellHook for latest versions
        aiCliPackages = [];

        # AI Server package for deployment
        ai-server = pkgs.stdenv.mkDerivation {
          pname = "ai-server";
          version = "1.0.0";
          src = ./ai-server;

          buildInputs = [ pkgs.bun ];

          buildPhase = ''
            # Install dependencies with Bun
            export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
            ${pkgs.bun}/bin/bun install --frozen-lockfile
          '';

          installPhase = ''
            mkdir -p $out/bin $out/ai-server

            # Copy everything to output
            cp -r . $out/ai-server/

            # Create wrapper script that decrypts credentials then runs server
            cat > $out/bin/ai-server << 'EOF'
#!/usr/bin/env bash
cd $out/ai-server

# Decrypt credentials if encrypted files exist and AGE_SECRET_KEY is set
if [ -n "$AGE_SECRET_KEY" ] && [ -d ".credentials.encrypted" ]; then
    echo "🔓 Decrypting credentials..."
    ./scripts/decrypt-credentials.sh .credentials.encrypted 2>/dev/null || true
fi

exec ${pkgs.bun}/bin/bun run src/server.ts "$@"
EOF
            chmod +x $out/bin/ai-server
          '';
        };
        # Integrated package with both Elixir and AI Server
        singularity-integrated = pkgs.stdenv.mkDerivation {
          pname = "singularity-integrated";
          version = "1.0.0";
          src = ./.;

          buildInputs = [
            beamPackages.erlang
            elixirGleam
            pkgs.bun
          ];

          buildPhase = ''
            # Build Elixir app
            export MIX_ENV=prod
            export MIX_HOME=$TMPDIR/mix
            export HEX_HOME=$TMPDIR/hex
            mix local.hex --force
            mix local.rebar --force
            mix deps.get --only prod
            mix compile

            # Build AI Server (bun install happens automatically)
            cd ai-server
            export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
            if [ -f bun.lockb ]; then
              ${pkgs.bun}/bin/bun install --frozen-lockfile
            else
              ${pkgs.bun}/bin/bun install
            fi
            cd ..
          '';

          installPhase = ''
            mkdir -p $out/bin $out/elixir $out/ai-server

            # Install Elixir app
            cp -r . $out/elixir/

            # Install AI Server
            cp -r ai-server/* $out/ai-server/

            # Create start script for both processes
            cat > $out/bin/start-singularity << 'EOF'
#!/usr/bin/env bash
# Start both Elixir and AI Server

# Start AI Server in background
cd $out/ai-server
${pkgs.bun}/bin/bun run src/server.ts &
AI_PID=$!

# Start Elixir app
cd $out/elixir
${elixirGleam}/bin/mix phx.server &
ELIXIR_PID=$!

# Wait for both processes
wait $AI_PID $ELIXIR_PID
EOF
            chmod +x $out/bin/start-singularity

            # Individual process scripts
            cat > $out/bin/web << 'EOF'
#!/usr/bin/env bash
cd $out/elixir
exec ${elixirGleam}/bin/mix phx.server
EOF
            chmod +x $out/bin/web

            cat > $out/bin/ai-server << 'EOF'
#!/usr/bin/env bash
cd $out/ai-server

# Decrypt credentials if encrypted files exist and AGE_SECRET_KEY is set
if [ -n "$AGE_SECRET_KEY" ] && [ -d ".credentials.encrypted" ]; then
    echo "🔓 Decrypting credentials..."
    ./scripts/decrypt-credentials.sh .credentials.encrypted 2>/dev/null || true
fi

exec ${pkgs.bun}/bin/bun run src/server.ts
EOF
            chmod +x $out/bin/ai-server
          '';
        };
      in {
        packages = {
          default = ai-server;
          ai-server = ai-server;
          singularity-integrated = singularity-integrated;
          just = pkgs.just;
        };

        devShells.default = pkgs.mkShell {
          name = "seed-agent-shell";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ webAndCli ++ qaTools ++ aiCliPackages;

          shellHook = ''
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV=''${MIX_ENV:-dev}
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            # Install AI CLIs if not present
            if [ ! -f "$PWD/bin/gemini" ]; then
              echo "Installing AI CLIs..."
              npm install -g @google/gemini-cli 2>/dev/null || true
              npm install -g @anthropic-ai/claude-code 2>/dev/null || true
              npm install -g @openai/codex 2>/dev/null || true
              npm install -g @github/copilot 2>/dev/null || true
              # Cursor Agent: curl https://cursor.com/install -fsSL | bash
            fi

            # Load .env if it exists
            if [ -f .env ]; then
              echo "📝 Loading .env..."
              set -a
              source .env
              set +a
            fi

            if [ -n "${PS1:-}" ]; then
              echo "Loaded seed-agent development shell"
              echo "AI CLIs: gemini, claude, codex, copilot, cursor-agent"
              echo "Run 'just help' for task shortcuts."
            fi
          '';
        };

        devShells.fly = pkgs.mkShell {
          name = "seed-agent-fly";
          buildInputs = [
            pkgs.flyctl
            pkgs.just
            pkgs.git
            pkgs.curl
            pkgs.openssl
            pkgs.jq
            # No docker - pure Nix deployment
          ];
          shellHook = ''
            echo "Fly.io deployment shell loaded (Nix-only)"
            export PATH=$PWD/bin:$PATH
          '';
        };
      });
}

{
  description = "Singularity - Elixir + Gleam development environment";

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

        mixEnvDefault = "$" + "{MIX_ENV:-prod}";
        stateDirDefault = "$" + "{STATE_DIR:-/var/lib/singularity}";
        mixHomeDefault = "$" + "{MIX_HOME:-" + "$" + "STATE_DIR/.mix}";
        hexHomeDefault = "$" + "{HEX_HOME:-" + "$" + "STATE_DIR/.hex}";
        bunCacheDefault = "$" + "{BUN_INSTALL_CACHE_DIR:-" + "$" + "STATE_DIR/.bun-cache}";

        # AI Server package for deployment
        ai-server = pkgs.stdenv.mkDerivation {
          pname = "ai-server";
          version = "1.0.0";
          src = ./ai-server;

          buildInputs = [ pkgs.bun ];

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin $out/ai-server

            # Copy everything to output
            cp -r . $out/ai-server/

            # Create wrapper script that prepares a writable workspace then runs the server
            cat > $out/bin/ai-server <<'EOF'
#!${pkgs.bash}/bin/bash
set -euo pipefail

STATE_DIR="__STATE_DIR_DEFAULT__"
AI_DIR="$STATE_DIR/ai-server"

export BUN_INSTALL_CACHE_DIR="__BUN_CACHE_DEFAULT__"
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR" "$AI_DIR" "$BUN_INSTALL_CACHE_DIR"

sync_tree() {
  local src="$1"
  local dest="$2"
  ${pkgs.coreutils}/bin/mkdir -p "$dest"
  ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership "$src"/. "$dest"/
}

sync_tree "__OUT__/ai-server" "$AI_DIR"

cd "$AI_DIR"

# Decrypt credentials if encrypted files exist and AGE_SECRET_KEY is set
if [ -n "$AGE_SECRET_KEY" ] && [ -d ".credentials.encrypted" ]; then
    echo "🔓 Decrypting credentials..."
    ./scripts/decrypt-credentials.sh .credentials.encrypted 2>/dev/null || true
fi

if [ ! -d node_modules ]; then ${pkgs.bun}/bin/bun install --frozen-lockfile || ${pkgs.bun}/bin/bun install; fi

exec ${pkgs.bun}/bin/bun run src/server.ts "$@"
EOF
            substituteInPlace $out/bin/ai-server \
              --replace "__OUT__" "$out" \
              --replace "__STATE_DIR_DEFAULT__" "${stateDirDefault}" \
              --replace "__BUN_CACHE_DEFAULT__" "${bunCacheDefault}"
            chmod +x $out/bin/ai-server
            runHook postInstall
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
            pkgs.bash
            pkgs.coreutils
          ];

          buildPhase = ''
            patchShebangs ${elixirGleam}/bin
          '';

          installPhase = ''
            mkdir -p $out/bin $out/elixir $out/ai-server

            # Install Elixir app
            cp -r . $out/elixir/

            # Install AI Server
            cp -r ai-server/* $out/ai-server/

            cp ${elixirGleam}/bin/.mix-wrapped $out/bin/mix-wrapped
            substituteInPlace $out/bin/mix-wrapped --replace '#!/usr/bin/env elixir' '#!${elixirGleam}/bin/elixir'
            chmod +x $out/bin/mix-wrapped

            cat > $out/bin/start-singularity <<'EOF'
#!${pkgs.bash}/bin/bash
# Seed-Agent unified start
set -euo pipefail

export MIX_ENV="__MIX_ENV_DEFAULT__"
STATE_DIR="__STATE_DIR_DEFAULT__"
RUNTIME_DIR="$STATE_DIR/runtime"
AI_DIR="$RUNTIME_DIR/ai-server"
ELIXIR_DIR="$RUNTIME_DIR/elixir"

export MIX_HOME="__MIX_HOME_DEFAULT__"
export HEX_HOME="__HEX_HOME_DEFAULT__"
export BUN_INSTALL_CACHE_DIR="__BUN_CACHE_DEFAULT__"
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
export PATH="__OUT__/bin:$PATH"

${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR" "$RUNTIME_DIR" "$AI_DIR" "$ELIXIR_DIR" "$MIX_HOME" "$HEX_HOME" "$BUN_INSTALL_CACHE_DIR"

sync_tree() {
  local src="$1"
  local dest="$2"
  ${pkgs.coreutils}/bin/mkdir -p "$dest"
  ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership "$src"/. "$dest"/
}

sync_tree "__OUT__/ai-server" "$AI_DIR"
sync_tree "__OUT__/elixir" "$ELIXIR_DIR"

cd "$AI_DIR"
if [ ! -d node_modules ]; then ${pkgs.bun}/bin/bun install --frozen-lockfile || ${pkgs.bun}/bin/bun install; fi
${pkgs.bun}/bin/bun run src/server.ts &
AI_PID=$!

cd "$ELIXIR_DIR"
if [ ! -d deps ]; then __OUT__/bin/mix-wrapped deps.get --only prod; fi
if [ ! -d _build/prod ]; then __OUT__/bin/mix-wrapped compile; fi
__OUT__/bin/mix-wrapped phx.server &
WEB_PID=$!

trap 'kill $AI_PID $WEB_PID 2>/dev/null' EXIT
trap 'kill $AI_PID $WEB_PID 2>/dev/null' TERM INT
wait $AI_PID $WEB_PID
EOF
            substituteInPlace $out/bin/start-singularity \
              --replace "__OUT__" "$out" \
              --replace "__MIX_ENV_DEFAULT__" "${mixEnvDefault}" \
              --replace "__STATE_DIR_DEFAULT__" "${stateDirDefault}" \
              --replace "__MIX_HOME_DEFAULT__" "${mixHomeDefault}" \
              --replace "__HEX_HOME_DEFAULT__" "${hexHomeDefault}" \
              --replace "__BUN_CACHE_DEFAULT__" "${bunCacheDefault}"
            chmod +x $out/bin/start-singularity

            # Individual process scripts
            cat > $out/bin/web <<EOF
#!${pkgs.bash}/bin/bash
cd $out/elixir
exec $out/bin/mix-wrapped phx.server
EOF
            chmod +x $out/bin/web

            cat > $out/bin/ai-server <<'EOF'
#!${pkgs.bash}/bin/bash
set -euo pipefail

STATE_DIR="__STATE_DIR_DEFAULT__"
AI_DIR="$STATE_DIR/ai-server"

export BUN_INSTALL_CACHE_DIR="__BUN_CACHE_DEFAULT__"
export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

${pkgs.coreutils}/bin/mkdir -p "$STATE_DIR" "$AI_DIR" "$BUN_INSTALL_CACHE_DIR"

sync_tree() {
  local src="$1"
  local dest="$2"
  ${pkgs.coreutils}/bin/mkdir -p "$dest"
  ${pkgs.coreutils}/bin/cp -R --no-preserve=mode,ownership "$src"/. "$dest"/
}

sync_tree "__OUT__/ai-server" "$AI_DIR"

cd "$AI_DIR"

# Decrypt credentials if encrypted files exist and AGE_SECRET_KEY is set
if [ -n "$AGE_SECRET_KEY" ] && [ -d ".credentials.encrypted" ]; then
    echo "🔓 Decrypting credentials..."
    ./scripts/decrypt-credentials.sh .credentials.encrypted 2>/dev/null || true
fi

if [ ! -d node_modules ]; then ${pkgs.bun}/bin/bun install --frozen-lockfile || ${pkgs.bun}/bin/bun install; fi

exec ${pkgs.bun}/bin/bun run src/server.ts
EOF
            substituteInPlace $out/bin/ai-server \
              --replace "__OUT__" "$out" \
              --replace "__STATE_DIR_DEFAULT__" "${stateDirDefault}" \
              --replace "__BUN_CACHE_DEFAULT__" "${bunCacheDefault}"
            chmod +x $out/bin/ai-server
          '';
        };
      in {
        packages = let
          aiServerPackage = ai-server;
          integratedPackage = singularity-integrated;
          seedAgentRoot = pkgs.buildEnv {
            name = "seed-agent-root";
            paths = [
              integratedPackage
              pkgs.cacert
            ];
          };
        in {
          default = aiServerPackage;
          ai-server = aiServerPackage;
          singularity-integrated = integratedPackage;
          seed-agent-oci = pkgs.dockerTools.buildLayeredImage {
            name = "seed-agent";
            tag = "latest";
            contents = [ seedAgentRoot ];
            config = {
              WorkingDir = "/";
              Cmd = ["${seedAgentRoot}/bin/start-singularity"];
              Env = [
                "PORT=8080"
              ];
            };
          };
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

            if ! command -v claude >/dev/null 2>&1; then
              claude() {
                bunx --bun @anthropic-ai/claude-code "$@"
              }
              export -f claude
            fi

            if ! command -v gemini >/dev/null 2>&1; then
              gemini() {
                bunx --bun @google/gemini-cli "$@"
              }
              export -f gemini
            fi

            if ! command -v copilot >/dev/null 2>&1; then
              copilot() {
                bunx --bun @github/copilot "$@"
              }
              export -f copilot
            fi

            if ! command -v codex >/dev/null 2>&1; then
              codex() {
                bunx --bun @openai/codex "$@"
              }
              export -f codex
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
            pkgs.podman
            pkgs.skopeo
            pkgs.buildah
          ];
          shellHook = ''
            echo "Fly.io deployment shell loaded (Nix-only)"
            export PATH=$PWD/bin:$PATH
          '';
        };
      });
}

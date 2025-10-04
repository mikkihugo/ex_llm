{
  description = "Singularity - AI-powered multi-agent coordination platform with comprehensive Rust tooling analysis";

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

          # Fast linker (mold) for Rust compilation
          mold

          # Rust compilation caching
          sccache

          # Comprehensive Rust development tools
          rust-analyzer       # LSP server for Rust IDE support
          cargo-audit         # Security vulnerability scanning
          cargo-deny          # Dependency policy enforcement
          cargo-edit          # cargo add/rm/upgrade commands
          cargo-expand        # Macro expansion viewer
          cargo-flamegraph    # Performance profiling
          cargo-outdated      # Check for outdated dependencies
          cargo-watch         # File watcher for cargo commands
          cargo-nextest       # Next-generation test runner
          cargo-llvm-cov      # Code coverage with LLVM
          cargo-machete       # Find unused dependencies
          cargo-readme        # Generate README from doc comments
          cargo-bloat         # Find what takes up space in binary
          cargo-license       # License checker
          cargo-modules       # Visualize crate's module structure
          cargo-criterion     # Benchmarking harness
          cargo-cache         # Manage cargo cache
          bacon               # Background rust code checker
          mdbook              # Rust book generator
        ];

        beamTools = [
          beamPackages.erlang
          elixirGleam
          beamPackages.hex
          beamPackages.rebar3
          pkgs.elixir_ls
          pkgs.erlang-ls
          pkgs.gleam
        ];

        postgresqlWithExtensions = pkgs.postgresql_17.withPackages (ps:
          builtins.concatMap (
            v:
              let attempt = builtins.tryEval v;
                  isDrv = attempt.success && pkgs.lib.isDerivation attempt.value;
                  drv = if isDrv then attempt.value else null;
                  broken = if isDrv && drv ? meta && drv.meta ? broken then drv.meta.broken else false;
                  licenseFree =
                    if !isDrv || !(drv ? meta && drv.meta ? license) then true
                    else let lic = drv.meta.license;
                      in if pkgs.lib.isList lic
                         then pkgs.lib.all (l: l ? free && l.free) lic
                         else (lic ? free && lic.free);
              in if isDrv && !broken && licenseFree then [ drv ] else []
          ) (builtins.attrValues ps)
        );

        dataServices = [
          postgresqlWithExtensions
        ];

        webAndCli = with pkgs; [
          # No nodejs - bun is enough
          flyctl
          bun

          # Container tools (rootless development)
          podman
          buildah
          skopeo
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
            cp -r singularity_app/* $out/elixir/

            # Install AI Server
            cp -r ai-server/* $out/ai-server/

            cp ${elixirGleam}/bin/.mix-wrapped $out/bin/mix-wrapped
            substituteInPlace $out/bin/mix-wrapped --replace '#!/usr/bin/env elixir' '#!${elixirGleam}/bin/elixir'
            chmod +x $out/bin/mix-wrapped

            cat > $out/bin/start-singularity <<'EOF'
#!${pkgs.bash}/bin/bash
# Singularity unified start
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
          singularityRoot = pkgs.buildEnv {
            name = "singularity-root";
            paths = [
              integratedPackage
              pkgs.cacert
            ];
          };
        in {
          default = aiServerPackage;
          ai-server = aiServerPackage;
          singularity-integrated = integratedPackage;
          singularity-oci = pkgs.dockerTools.buildLayeredImage {
            name = "singularity";
            tag = "latest";
            contents = [ singularityRoot ];
            config = {
              WorkingDir = "/";
              Cmd = ["${singularityRoot}/bin/start-singularity"];
              Env = [
                "PORT=8080"
              ];
            };
          };
          just = pkgs.just;
        };

        devShells.default = pkgs.mkShell {
          name = "singularity-shell";
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

            export DEV_PGROOT="$PWD/.dev-db"
            export PGDATA="$DEV_PGROOT/pg"
            export PGHOST="localhost"
            if ! printenv PGPORT >/dev/null 2>&1 || [ -z "$PGPORT" ]; then
              if printenv DEV_PGPORT >/dev/null 2>&1 && [ -n "$DEV_PGPORT" ]; then
                export PGPORT="$DEV_PGPORT"
              else
                export PGPORT="5432"
              fi
            fi
            if ! printenv _DEV_SHELL_PG_STARTED >/dev/null 2>&1 || [ -z "$_DEV_SHELL_PG_STARTED" ]; then
              export _DEV_SHELL_PG_STARTED=0
            fi

            if [ ! -d "$PGDATA" ]; then
              mkdir -p "$DEV_PGROOT"
              ${postgresqlWithExtensions}/bin/initdb --no-locale --encoding=UTF8 -D "$PGDATA" >/dev/null
              cat > "$PGDATA/pg_hba.conf" <<'EOF'
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
EOF
              cat >> "$PGDATA/postgresql.conf" <<EOF
listen_addresses = 'localhost'
port = $PGPORT
unix_socket_directories = '$PGDATA'
EOF
            fi

            if ! ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
              ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" -o "-p $PGPORT" start >/dev/null
              export _DEV_SHELL_PG_STARTED=1
              echo "🚀 Started Postgres on port $PGPORT (data: $PGDATA)"
            fi

            if ! printenv _DEV_SHELL_PG_TRAP >/dev/null 2>&1 || [ -z "$_DEV_SHELL_PG_TRAP" ]; then
              trap 'if [ "$_DEV_SHELL_PG_STARTED" = "1" ]; then ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" -m fast stop >/dev/null 2>&1 || true; fi' EXIT
              export _DEV_SHELL_PG_TRAP=1
            fi

            if ! printenv DATABASE_URL >/dev/null 2>&1 || [ -z "$DATABASE_URL" ]; then
              export DATABASE_URL="postgres://localhost:$PGPORT/postgres"
            fi

            # Ensure vector extensions and ANN-ready schema

            bash -c '
            '
              ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1 || true
              ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS pgvecto_rs;" >/dev/null 2>&1 || true
              for db_name in singularity_embeddings singularity_dev singularity_test; do
                if ! ${postgresqlWithExtensions}/bin/psql -d postgres -qAt -c "SELECT 1 FROM pg_database WHERE datname = '$db_name';" | grep -q 1; then
                  ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE \"$db_name\";" >/dev/null 2>&1 || true
                fi
              done
            '
            '

            ${postgresqlWithExtensions}/bin/psql -d singularity_embeddings -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1 || true
            ${postgresqlWithExtensions}/bin/psql -d singularity_embeddings -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS pgvecto_rs;" >/dev/null 2>&1 || true

            ${postgresqlWithExtensions}/bin/psql -d singularity_embeddings -v ON_ERROR_STOP=1 -q <<'EOSQL'
CREATE TABLE IF NOT EXISTS embeddings (
  id          bigserial PRIMARY KEY,
  path        text NOT NULL,
  label       text,
  metadata    jsonb DEFAULT '{}'::jsonb,
  embedding   vector(768) NOT NULL,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
EOSQL

            ${postgresqlWithExtensions}/bin/psql -d singularity_embeddings -v ON_ERROR_STOP=1 -q -c \
"CREATE INDEX IF NOT EXISTS embeddings_embedding_hnsw ON embeddings USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);" \
              >/dev/null

            if [ -n "${PS1:-}" ]; then
              echo "Loaded singularity development shell"
              echo "AI CLIs: gemini, claude, codex, copilot, cursor-agent"
              echo "Run 'just help' for task shortcuts."
            fi
          '';
        };

        devShells.fly = pkgs.mkShell {
          name = "singularity-fly";
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

        # Development environment with full tooling
        devShells.dev = pkgs.mkShell {
          name = "singularity-dev";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ webAndCli ++ qaTools ++ aiCliPackages;

          shellHook = ''
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV="dev"
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            echo "🚀 Singularity Development Environment"
            echo "  MIX_ENV=dev"
            echo "  Full development tooling enabled"
            echo "  Run: mix phx.server"
          '';
        };

        # Testing environment with test-specific tools
        devShells.test = pkgs.mkShell {
          name = "singularity-test";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ qaTools;

          shellHook = ''
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV="test"
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.test-mix"
            export HEX_HOME="$PWD/.test-hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            echo "🧪 Singularity Testing Environment"
            echo "  MIX_ENV=test"
            echo "  Testing and QA tools enabled"
            echo "  Run: mix test"
          '';
        };

        # Production-like environment for staging/validation
        devShells.prod = pkgs.mkShell {
          name = "singularity-prod";
          buildInputs = beamTools ++ webAndCli;

          shellHook = ''
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV="prod"
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.prod-mix"
            export HEX_HOME="$PWD/.prod-hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            echo "🏭 Singularity Production Environment"
            echo "  MIX_ENV=prod"
            echo "  Minimal production dependencies"
            echo "  Run: mix release"
          '';
        };
      });
}

{
  description = "Singularity - Autonomous agent platform with GPU-accelerated semantic code search";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    extra-substituters = [
      "https://mikkihugo.cachix.org"
    ];
    extra-trusted-public-keys = [
      "mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="
    ];
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        # Use stable OTP 28 toolchain from nixpkgs
        beamPackages = pkgs.beam.packages.erlang_28;

        # Base tools without CUDA
        baseTools = with pkgs; [
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

          # Nix binary cache (cachix)
          cachix

          # Rust toolchain (REQUIRED for Rustler NIFs)
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer       # LSP server for Rust IDE support
          cargo-watch         # File watcher for cargo commands (used in justfile)
          
          # Note: Additional cargo tools (cargo-nextest, cargo-audit, etc.) can be installed
          # on-demand via `cargo install` or added here if needed for CI/CD.
          # They are not included by default to speed up initial setup.

          # Tree-sitter parsing tools
          tree-sitter-grammars.tree-sitter-elixir
          tree-sitter-grammars.tree-sitter-rust
        ];

        # CUDA packages (unfree, only for local dev)
        cudaTools = with pkgs; [
          cudaPackages.cudatoolkit
          cudaPackages.cudnn
        ];

        # All tools including CUDA
        commonTools = baseTools ++ cudaTools;

        beamTools = [
          beamPackages.erlang
          beamPackages.elixir
          beamPackages.hex
          beamPackages.rebar3
          pkgs.elixir_ls
          pkgs.erlang-ls
          pkgs.gleam
        ];

        pythonTrainingEnv = pkgs.python311.withPackages (ps: with ps; [
          ps.pip
          ps.setuptools
          ps.wheel
          ps.numpy
          ps.scipy
          ps.pandas
          ps.torch
          ps.torchvision
          ps.torchaudio
          ps.tokenizers
          ps.safetensors
          ps.transformers
          ps.datasets
          ps.accelerate
          ps.peft
          ps.evaluate
          ps.tqdm
          ps.regex
          ps.huggingface-hub
          ps.jinja2
          ps.protobuf
        ]);

        postgresqlWithExtensions = pkgs.postgresql_17.withPackages (ps: [
          ps.timescaledb
          ps.postgis
          ps.pgrouting
          ps.pgtap
          ps.pg_cron
          ps.pgvector        # Vector similarity search (Jina v3, Qodo-Embed-1)
        ]);

        dataServices = [
          postgresqlWithExtensions
        ];

        webAndCli = with pkgs; [
          # No nodejs - bun is enough
          flyctl
          bun
          nats-server  # NATS with JetStream for distributed facts

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
            beamPackages.elixir
            pkgs.bun
            pkgs.bash
            pkgs.coreutils
          ];

          buildPhase = ''
            patchShebangs ${beamPackages.elixir}/bin
          '';

          installPhase = ''
            mkdir -p $out/bin $out/elixir $out/ai-server

            # Install Elixir app
            cp -r singularity_app/* $out/elixir/

            # Install AI Server
            cp -r ai-server/* $out/ai-server/

            # Provide a stable 'mix' wrapper in $out/bin that delegates to nixpkgs Elixir
            cat > $out/bin/mix <<'EOF'
#!${pkgs.bash}/bin/bash
exec ${beamPackages.elixir}/bin/mix "$@"
EOF
            chmod +x $out/bin/mix

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
if [ ! -d deps ]; then __OUT__/bin/mix deps.get --only prod; fi
if [ ! -d _build/prod ]; then __OUT__/bin/mix compile; fi
__OUT__/bin/mix phx.server &
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
exec $out/bin/mix phx.server
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
            # Binary cache configured via flake.nix nixConfig
            # Locale + BEAM flags for stable UTF-8 IO
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV=''${MIX_ENV:-dev}

            # === RUST/CARGO CACHING ===
            export CARGO_HOME="''${HOME}/.cache/singularity/cargo"
            export SCCACHE_DIR="''${HOME}/.cache/singularity/sccache"
            export SCCACHE_CACHE_SIZE="10G"
            export RUSTC_WRAPPER="sccache"
            export CARGO_TARGET_DIR=".cargo-build"
            export CARGO_INCREMENTAL="0"  # Disabled for sccache compatibility
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
            mkdir -p "$CARGO_HOME" "$SCCACHE_DIR" 2>/dev/null || true
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            # Stabilize rebar3 paths for Mix/rebar deps
            export REBAR_CACHE_DIR="$PWD/.rebar3/cache"
            export REBAR_GLOBAL_CONFIG_DIR="$PWD/.rebar3"
            export REBAR_PLUGINS_DIR="$PWD/.rebar3/plugins"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$REBAR_CACHE_DIR" "$REBAR_PLUGINS_DIR" "$PWD/bin"
            # Don't override PATH - let Nix handle it via buildInputs
            # export PATH=$PWD/bin:$PATH

            # CUDA/GPU environment for EXLA (RTX 4080)
            export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
            export CUDNN_HOME="${pkgs.cudaPackages.cudnn}"
            export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:''${LD_LIBRARY_PATH:-}"
            export XLA_FLAGS="--xla_gpu_cuda_data_dir=$CUDA_HOME"
            export EXLA_TARGET="cuda"

            # WSL2: Add Windows NVIDIA drivers to PATH (if available)
            if [ -d /usr/lib/wsl/lib ]; then
              export PATH="/usr/lib/wsl/lib:$PATH"
              export LD_LIBRARY_PATH="/usr/lib/wsl/lib:$LD_LIBRARY_PATH"
            fi

            # Verify CUDA is available (WSL2 gets GPU access from Windows host)
            if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
              echo "🎮 GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null || echo 'NVIDIA GPU available')"
              echo "   CUDA: $(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+')"
            else
              echo "⚠️  GPU: NVIDIA driver not available (install Windows NVIDIA drivers for WSL2)"
              echo "   CUDA: $(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' || echo 'not found')"
            fi

            # NATS JetStream setup
            export NATS_URL="nats://localhost:4222"
            if ! pgrep -x "nats-server" > /dev/null; then
              echo "📡 Starting NATS with JetStream..."
              nats-server -js -sd "$PWD/.nats" -p 4222 > /dev/null 2>&1 &
              sleep 1
              echo "   NATS running on nats://localhost:4222"
            fi

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
            ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1 || true
            ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS pgvecto_rs;" >/dev/null 2>&1 || true
            for db_name in singularity_embeddings singularity_dev singularity_test; do
              if ! ${postgresqlWithExtensions}/bin/psql -d postgres -qAt -c "SELECT 1 FROM pg_database WHERE datname = '$db_name';" | grep -q 1; then
                ${postgresqlWithExtensions}/bin/psql -d postgres -v ON_ERROR_STOP=1 -q -c "CREATE DATABASE \"$db_name\";" >/dev/null 2>&1 || true
              fi
            done

            # Enable vector extensions in all databases (schema managed by migrations)
            for db_name in singularity_embeddings singularity_dev singularity_test; do
              ${postgresqlWithExtensions}/bin/psql -d "$db_name" -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS vector;" >/dev/null 2>&1 || true
              ${postgresqlWithExtensions}/bin/psql -d "$db_name" -v ON_ERROR_STOP=1 -q -c "CREATE EXTENSION IF NOT EXISTS pgvecto_rs;" >/dev/null 2>&1 || true
            done

            # NOTE: Schema (tables, indexes) is managed by Elixir migrations in singularity_app/priv/repo/migrations/
            # Run 'mix ecto.migrate' to create tables

            # Always show shell info (works in both interactive and non-interactive modes)
            echo "Loaded singularity development shell"
            echo "AI CLIs: gemini, claude, codex, copilot, cursor-agent"
            echo "Run 'just help' for task shortcuts."
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
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            echo "Fly.io deployment shell loaded (Nix-only)"
            export PATH=$PWD/bin:$PATH
          '';
        };

        # Development environment with full tooling
        devShells.dev = pkgs.mkShell {
          name = "singularity-dev";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ webAndCli ++ qaTools ++ aiCliPackages;

          shellHook = ''
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV="dev"
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            # === RUST/CARGO CACHING ===
            export CARGO_HOME="''${HOME}/.cache/singularity/cargo"
            export SCCACHE_DIR="''${HOME}/.cache/singularity/sccache"
            export SCCACHE_CACHE_SIZE="10G"
            export RUSTC_WRAPPER="sccache"
            export CARGO_TARGET_DIR=".cargo-build"
            export CARGO_INCREMENTAL="0"
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
            mkdir -p "$CARGO_HOME" "$SCCACHE_DIR" "$CARGO_HOME/bin" 2>/dev/null || true

            # Add cargo bin to PATH for cargo-binstall, cargo-quickinstall, etc.
            export PATH="$CARGO_HOME/bin:$PATH"

            # CUDA setup for GPU-accelerated development
            export CUDA_HOME="${pkgs.cudaPackages.cudatoolkit}"
            export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"
            export PATH="${pkgs.cudaPackages.cudatoolkit}/bin:$PATH"
            export LD_LIBRARY_PATH="${pkgs.cudaPackages.cudatoolkit}/lib:$LD_LIBRARY_PATH"

            # Ensure just is available
            export PATH="${pkgs.just}/bin:$PATH"
            echo "DEBUG: Added just to PATH: ${pkgs.just}/bin"

            echo "🚀 Singularity Development Environment"
            echo "  MIX_ENV=dev"
            echo "  CUDA: $CUDA_HOME"
            echo "  Full development tooling enabled"
            echo "  Run: mix phx.server"
          '';
        };

        # Testing environment with test-specific tools
        devShells.test = pkgs.mkShell {
          name = "singularity-test";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ qaTools;

          shellHook = ''
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
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
        devShells.llm-train = pkgs.mkShell {
          name = "singularity-llm-train";
          buildInputs = commonTools ++ [
            pythonTrainingEnv
            pkgs.git-lfs
          ];

          shellHook = ''
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export PYTHONUTF8=1
            export HF_HOME="$PWD/.cache/huggingface"
            export TRANSFORMERS_CACHE="$PWD/.cache/huggingface"
            export HF_DATASETS_CACHE="$PWD/.cache/huggingface"
            export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
            export CUDNN_HOME=${pkgs.cudaPackages.cudnn}
            export LD_LIBRARY_PATH=${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:''${LD_LIBRARY_PATH:-}
            mkdir -p "$HF_HOME"
            echo "🤖 LLM training shell ready"
            echo "  Python: $(python3 --version)"
            echo "  PyTorch CUDA build: $(python3 -c \"import torch; print(torch.version.cuda if torch.cuda.is_available() else 'cpu')\" 2>/dev/null || echo 'not found')"
            echo "  Use: accelerate launch train_codet5.py"
          '';
        };

        devShells.prod = pkgs.mkShell {
          name = "singularity-prod";
          buildInputs = beamTools ++ webAndCli;

          shellHook = ''
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
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

        # CI environment - like dev but without CUDA (unfree)
        devShells.ci = pkgs.mkShell {
          name = "singularity-ci";
          buildInputs = beamTools ++ baseTools ++ webAndCli ++ qaTools;

          shellHook = ''
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV="test"
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.ci-mix"
            export HEX_HOME="$PWD/.ci-hex"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$PWD/bin"
            export PATH=$PWD/bin:$PATH

            echo "🤖 Singularity CI Environment"
            echo "  MIX_ENV=test"
            echo "  No CUDA (CI-safe)"
          '';
        };
      });
}

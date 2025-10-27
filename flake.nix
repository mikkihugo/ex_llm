{
  description = "Singularity - Autonomous agent platform with GPU-accelerated semantic code search";

  # Environment Configurations:
  # - dev: Local development (any OS via Nix)
  # - ci: Automated testing environment
  # - prod: GPU-accelerated development (Metal on Mac, CUDA on Linux)

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    # Fix download buffer warning - increase buffer size
    download-buffer-size = "2147483648";  # 2GB buffer
    # Binary cache for faster package downloads
    extra-substituters = ["https://mikkihugo.cachix.org"];
    extra-trusted-public-keys = ["mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="];
    # Allow broken packages (pgx_ulid is marked broken in nixpkgs)
    allowBroken = true;
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # LLM-Friendly: Platform detection function
        # Input: Nix system string (e.g., "x86_64-linux")
        # Output: Platform capabilities record
        detectPlatformCapabilities = system: {
          # Can run CUDA workloads (NVIDIA GPU acceleration)
          # Auto-detect on Linux, or set HAS_CUDA=1 on any platform for eGPU/external GPU
          hasCuda = (system == "x86_64-linux") || (builtins.getEnv "HAS_CUDA" == "1");

          # Can run ROCm workloads (AMD GPU acceleration)
          # Set HAS_ROCM=1 in environment to enable ROCm on Linux
          hasROCm = (system == "x86_64-linux") && (builtins.getEnv "HAS_ROCM" == "1");

          # Can run Metal workloads (Apple Silicon GPU acceleration)
          isAppleSilicon = system == "aarch64-darwin";

          # Can run on any macOS (Metal or CUDA via eGPU)
          isMacOS = nixpkgs.lib.hasSuffix "-darwin" system;

          # Is Linux (for GPU and other Linux-specific features)
          isLinux = nixpkgs.lib.hasSuffix "-linux" system;

          # Is macOS (for Metal and other Darwin-specific features)
          isDarwin = nixpkgs.lib.hasSuffix "-darwin" system;
        };

        # LLM-Friendly: GPU configuration function
        # Input: Platform capabilities
        # Output: GPU acceleration settings
        configureGpuAcceleration = platform: {
          # Target for Elixir ML library (EXLA)
          # Priority: CUDA > Metal > CPU
          exlaTarget = if platform.hasCuda then "cuda"
                      else if platform.isAppleSilicon then "metal"
                      else if platform.hasROCm then "rocm"
                      else "cpu";

          # CUDA toolkit paths (empty strings if not available)
          cudaPaths = if platform.hasCuda then {
            toolkit = "${pkgs.cudaPackages.cudatoolkit}";
            lib = "${pkgs.cudaPackages.cudatoolkit}/lib";
            bin = "${pkgs.cudaPackages.cudatoolkit}/bin";
            cudnn = "${pkgs.cudaPackages.cudnn}";
            cudnnLib = "${pkgs.cudaPackages.cudnn}/lib";
          } else {
            toolkit = "";
            lib = "";
            bin = "";
            cudnn = "";
            cudnnLib = "";
          };

          # XLA flags for TensorFlow/JAX acceleration
          xlaFlags = if platform.hasCuda then "--xla_gpu_cuda_data_dir=${pkgs.cudaPackages.cudatoolkit}"
                    else if platform.isAppleSilicon then "--xla_gpu_platform_device_count=1"
                    else if platform.hasROCm then "--xla_rocm_data_dir=/opt/rocm"
                    else "";
        };

        # LLM-Friendly: Simplified environment configurations
        environments = {
          # Local development environment
          dev = {
            name = "Local Development Environment";
            purpose = "Full development with PostgreSQL";
            services = ["postgresql"];
            gpu = true;
            caching = true;
            includePython = false;  # No Python in dev (focus on Elixir/Rust development)
          };

          # CI testing environment
          ci = {
            name = "Continuous Integration Environment";
            purpose = "Automated testing and building";
            services = ["postgresql"];
            gpu = false;
            caching = true;
            includePython = false;  # No Python in CI
          };

          # GPU-accelerated development environment
          prod = {
            name = "GPU Development Environment";
            purpose = "High-performance local development with GPU acceleration (Metal/CUDA auto-detected)";
            services = ["postgresql"];
            gpu = true;  # Enable GPU acceleration (platform auto-detects Metal or CUDA)
            caching = true;
          };
        };

        # LLM-Friendly: Service configuration records
        services = {
          postgresql = {
            name = "PostgreSQL Database";
            purpose = "Primary database with pgvector for embeddings, TimescaleDB for metrics";
            extensions = ["pgvector" "timescaledb" "postgis"];
            ports = [5432];
          };
        };

        # Get platform capabilities for this system
        platform = detectPlatformCapabilities system;
        gpu = configureGpuAcceleration platform;

        # Overlay to add pg_uuidv7 to PostgreSQL extensions
        postgresqlOverlay = final: prev: {
          postgresql_17 = prev.postgresql_17.overrideAttrs (oldAttrs: {
            # Mark that pg_uuidv7 is available
            passthru = (oldAttrs.passthru or {}) // {
              pg_uuidv7_available = true;
            };
          });
        };

        # Base package imports with overlay
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = true;
          };
          overlays = [ postgresqlOverlay ];
        };
        lib = nixpkgs.lib;
        beamPackages = pkgs.beam.packages.erlang_28;

        # PostgreSQL 17 extension: pg_uuidv7 (UUIDv7 for better B-tree performance)
        # Note: pg_uuidv7 is built with Rust + pgrx framework
        # Installation options provided in shell hook:
        #   1. PGXN: pgxn install pg_uuidv7 (pre-built, simplest)
        #   2. Cargo-pgrx: cargo-pgrx available in shell for building from source
        # Both are better than Nix buildRustPackage (avoids Nix complexity)
        pg_uuidv7 = null;  # Installed via pgxn or cargo-pgrx at runtime


        # LLM-Friendly: Package collection functions
        # Each function returns packages for a specific purpose

        getBaseTools = env: with pkgs; [
          git gh curl pkg-config direnv gnused gawk coreutils findutils
          ripgrep fd jq bat htop tree watchexec entr just nil nixfmt-rfc-style lsof
          mold sccache cachix rustc cargo rustfmt clippy rust-analyzer cargo-watch
          postgresql_17  # For pgxn (pg_config and dev headers)
          # Note: Google auth uses @google/gemini-cli-core OAuth (no gcloud needed)
        ] ++ lib.optionals env.gpu (if platform.hasCuda then [
          # CUDA tools only if GPU enabled and CUDA available
          cudaPackages.cudatoolkit cudaPackages.cudnn
        ] else []);

        getBeamTools = env: [
          beamPackages.erlang pkgs.elixir_1_19 beamPackages.hex
          beamPackages.rebar3 pkgs.elixir_ls
        ];

        # Add Erlang development headers for Rustler NIFs
        getRustTools = env: with pkgs; [
          rustc cargo gcc
          beamPackages.erlang  # For NIF linking
        ];

        getDataServices = env: lib.optionals (lib.elem "postgresql" env.services) [
          # PostgreSQL 17 with 20+ extensions for search, time-series, spatial, graph, security, and messaging
          # Built-in extensions (from PostgreSQL): ltree, hstore, pg_trgm, uuid-ossp, fuzzystrmatch, etc
          # pg_uuidv7 installed via: pgxn install pg_uuidv7 (see UUIDV7_SETUP.md)
          # PostgreSQL 18 is stable but Apache AGE PG18_prepare branch is still unstable/incomplete
          # Ready to upgrade to PG18 + AGE once PR #2165 is merged (follow https://github.com/apache/age/pull/2165)
          (pkgs.postgresql_17.withPackages (ps:
            [
              # Search & Vectors
              ps.pgvector           # Vector embeddings for semantic search (2560-dim)
              # ps.lantern            # Alternative vector search engine - broken in nixpkgs (use pgvector instead)

              # Spatial & Geospatial
              ps.postgis            # PostGIS 3.6.0 - full geospatial queries
              ps.h3-pg              # Hexagonal hierarchical geospatial indexing

              # Time Series
              ps.timescaledb        # TimescaleDB 2.22 - time-series optimization
              # ps.timescaledb_toolkit # TimescaleDB analytics extension (broken in nixpkgs - marked as broken package)

              # Graph Database
              ps.age                # Apache AGE - graph database extension (stable on PG17)

              # Distributed IDs & UUIDs
              # pg_uuidv7 - Install via: pgxn install pg_uuidv7 (see UUIDV7_SETUP.md)

              # Security & Encryption
              ps.pgsodium           # Modern encryption & hashing (libsodium binding)

              # Messaging & Message Queue
              ps.pgmq               # In-database message queue (alternative to external queues)
              ps.wal2json           # JSON WAL decoding for event streaming

              # HTTP & External APIs
              # ps.pg_net             # HTTP client from SQL - broken in nixpkgs (compilation error)

              # Testing
              ps.pgtap              # PostgreSQL TAP testing framework

              # Scheduling
              ps.pg_cron            # Cron-like task scheduling

              # Metrics & Monitoring
              # pg_stat_statements is built into PostgreSQL - enable via shared_preload_libraries config

              # Advanced Querying
              ps.plpgsql_check      # PL/pgSQL function validation
              ps.pg_repack          # Online defragmentation and reordering
            ]
          ))
        ];

        getWebAndCliTools = env: with pkgs;
          # Include Bun in dev/prod only, exclude from CI
          if env.name == "Continuous Integration Environment"
          then [ flyctl overmind ]
          else [ flyctl bun overmind ];
          # Note: pgxnclient not in nixpkgs, but shell hook checks for pgxn from system package managers

        getQaTools = env: with pkgs; [
          semgrep shellcheck hadolint
          nodePackages.eslint nodePackages.typescript-language-server nodePackages.typescript
        ];

        getAiCliTools = env: with pkgs; [
          # GitHub CLI (already included in base tools)
          # gh

          # Custom AI CLI tools
          (writeScriptBin "claude" ''
            echo "🤖 Claude Code - AI-powered coding assistant"
            echo "Claude Code is Anthropic's AI assistant for coding tasks."
            echo ""
            exec bunx --yes @anthropic-ai/claude-code "$@"
          '')          (writeScriptBin "gemini" ''
            #!${bash}/bin/bash
            echo "🧠 Gemini CLI - Google's AI assistant"
            echo "Gemini CLI is Google's AI assistant for coding and development."
            echo ""

            # Use bunx directly with the full package name
            exec bunx --yes @google/gemini-cli "$@"
          '')

          (writeScriptBin "copilot" ''
            #!${bash}/bin/bash
            echo "🤖 GitHub Copilot CLI - AI-powered development assistant"
            echo "GitHub Copilot CLI brings AI-powered coding assistance to your terminal."
            echo ""
            exec bunx --yes @github/copilot "$@"
          '')

          (writeScriptBin "kilocode" ''
            #!${bash}/bin/bash
            echo "🚀 Kilocode - AI-powered code generation"
            echo "Kilocode provides fast AI-powered code generation and completion."
            echo ""
            exec bunx --yes @kilocode/cli "$@"
          '')

          (writeScriptBin "cursor-agent" ''
            #!${bash}/bin/bash
            echo "🤖 Cursor Agent - AI-powered development agent"
            echo "Cursor CLI provides autonomous coding assistance."
            echo ""

            # Try to find the real cursor-agent (not this wrapper)
            # Check common installation paths and user's PATH
            for path in "$HOME/.local/bin/cursor-agent" "/usr/local/bin/cursor-agent" "/opt/cursor/bin/cursor-agent" "$HOME/.cursor/bin/cursor-agent"; do
                if [ -x "$path" ] && [[ "$path" != *"/nix/store/"* ]]; then
                    exec "$path" "$@"
                fi
            done

            # Also check if cursor-agent is in the inherited PATH
            if command -v cursor-agent >/dev/null 2>&1; then
                CURSOR_CMD=$(command -v cursor-agent)
                if [[ "$CURSOR_CMD" != *"/nix/store/"* ]]; then
                    exec "$CURSOR_CMD" "$@"
                fi
            fi

            # If we get here, cursor-agent is not installed
            echo "❌ Cursor CLI not found. Please install it first:"
            echo ""
            echo "Installation options:"
            echo "1. Download from: https://cursor.com/download"
            echo "2. Or install via package manager if available"
            echo ""
            echo "After installation, run: cursor-agent login"
            echo ""
            echo "For now, use the AI server:"
            echo "  curl -X POST http://localhost:3000/api/agent -H 'Content-Type: application/json' -d '{\"task\":\"your coding task\"}'"
            exit 1
          '')

          (writeScriptBin "gemini-cli" ''
            #!${bash}/bin/bash
            echo "⚠️  'gemini-cli' is deprecated. Use 'gemini' instead."
            # Call bunx directly to avoid any potential loops
            exec bunx --yes @google/gemini-cli "$@"
          '')

          (writeScriptBin "codex" ''
            #!${bash}/bin/bash
            echo "🧠 OpenAI Codex CLI - Local coding agent"
            echo "OpenAI Codex is a lightweight coding agent that runs locally on your computer."
            echo ""

            # Use npx to run the @openai/codex package
            # This avoids conflicts with our wrapper script
            if command -v npx >/dev/null 2>&1; then
                exec npx --yes @openai/codex "$@"
            fi

            # Fallback: try downloading the binary directly
            echo "❌ npx not found. Falling back to binary download..."
            echo ""

            # Determine platform and architecture
            ARCH=$(uname -m)
            OS=$(uname -s | tr '[:upper:]' '[:lower:]')

            # Map architecture names
            case $ARCH in
                x86_64)
                    ARCH_NAME="x86_64"
                    ;;
                arm64|aarch64)
                    ARCH_NAME="aarch64"
                    ;;
                *)
                    echo "❌ Unsupported architecture: $ARCH"
                    exit 1
                    ;;
            esac

            # Map OS names
            case $OS in
                darwin)
                    OS_NAME="apple-darwin"
                    ;;
                linux)
                    OS_NAME="unknown-linux-gnu"
                    ;;
                *)
                    echo "❌ Unsupported OS: $OS"
                    exit 1
                    ;;
            esac

            # Try to find existing Codex CLI
            CODEX_BINARY=""
            for path in "$HOME/.codex/bin/codex" "$HOME/.local/bin/codex" "/usr/local/bin/codex" "/opt/codex/bin/codex"; do
                if [ -x "$path" ]; then
                    CODEX_BINARY="$path"
                    break
                fi
            done

            # If not found, download it
            if [ -z "$CODEX_BINARY" ]; then
                CODEX_DIR="$HOME/.codex"
                CODEX_BINARY="$CODEX_DIR/bin/codex"

                if [ ! -x "$CODEX_BINARY" ]; then
                    echo "📥 Downloading OpenAI Codex CLI..."
                    mkdir -p "$CODEX_DIR/bin"

                    BINARY_NAME="codex-$ARCH_NAME-$OS_NAME.tar.gz"
                    DOWNLOAD_URL="https://github.com/openai/codex/releases/latest/download/$BINARY_NAME"

                    if command -v curl >/dev/null 2>&1; then
                        if curl -L "$DOWNLOAD_URL" -o "/tmp/$BINARY_NAME" 2>/dev/null; then
                            cd "$CODEX_DIR/bin"
                            tar -xzf "/tmp/$BINARY_NAME" 2>/dev/null || true
                            # The extracted binary has the full name, rename it
                            if [ -f "codex-$ARCH_NAME-$OS_NAME" ]; then
                                mv "codex-$ARCH_NAME-$OS_NAME" codex
                                chmod +x codex
                            fi
                            rm -f "/tmp/$BINARY_NAME"
                            echo "✅ Downloaded Codex CLI to $CODEX_BINARY"
                        else
                            echo "❌ Failed to download Codex CLI"
                            echo "Try: npm install -g @openai/codex"
                            exit 1
                        fi
                    else
                        echo "❌ curl not found. Try: npm install -g @openai/codex"
                        exit 1
                    fi
                fi
            fi

            # Run the binary
            if [ -x "$CODEX_BINARY" ]; then
                exec "$CODEX_BINARY" "$@"
            else
                echo "❌ Failed to find or download Codex CLI"
                echo "Try: npm install -g @openai/codex"
                exit 1
            fi
          '')
        ];

        # LLM-Friendly: Environment builder function
        # Input: Environment configuration record
        # Output: Complete devShell configuration
        buildDevShell = env: let
          allPackages = lib.flatten [
            (getBaseTools env)
            (getBeamTools env)
            (getRustTools env)
            (getDataServices env)
            (getWebAndCliTools env)
            (getQaTools env)
            (getAiCliTools env)
          ];
        in pkgs.mkShell {
          name = "${env.name} Shell";
          buildInputs = allPackages;

          shellHook = ''
            # LLM-Friendly: Environment-specific setup
            echo "🚀 Loading ${env.name}"
            echo "   Purpose: ${env.purpose}"
            echo "   Local development environment"

            # Common environment setup
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export ERL_FLAGS="+sbt u +sbwt very_long +swt very_low"  # Removed -heart for cleaner development logs
            export MIX_ENV=''${MIX_ENV:-${if env.name == "GPU Development Environment" then "prod" else "dev"}}

            # Erlang NIF headers for Rustler (required for NIF compilation)
            # NIFs use Erlang symbols at runtime (provided by BEAM VM), not at link time
            export ERL_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export RUSTFLAGS="-C linker=gcc"

            ${if env.caching then ''
            # Caching setup for performance
            export CARGO_HOME="''${HOME}/.cache/singularity/cargo"
            export SCCACHE_DIR="''${HOME}/.cache/singularity/sccache"
            export SCCACHE_CACHE_SIZE="10G"
            export RUSTC_WRAPPER="sccache"
            export CARGO_TARGET_DIR=".cargo-build"
            export CARGO_INCREMENTAL="0"
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
            export CARGO_BUILD_JOBS="4"
            mkdir -p "$CARGO_HOME" "$SCCACHE_DIR" 2>/dev/null || true
            '' else ""}

            ${if env.gpu then ''
            # GPU acceleration setup (priority: CUDA > Metal > ROCm > CPU)
            ${if platform.hasCuda then ''
            export CUDA_HOME="${gpu.cudaPaths.toolkit}"
            export CUDNN_HOME="${gpu.cudaPaths.cudnn}"
            export LD_LIBRARY_PATH="${gpu.cudaPaths.lib}:${gpu.cudaPaths.cudnnLib}:''${LD_LIBRARY_PATH:-}"
            export XLA_FLAGS="${gpu.xlaFlags}"
            export EXLA_TARGET="cuda"
            echo "🎮 GPU: CUDA available for EXLA acceleration"
            '' else if platform.isAppleSilicon then ''
            export EXLA_TARGET="cpu"
            export XLA_FLAGS="--xla_gpu_platform_device_count=1"
            echo "🍎 GPU: Apple Silicon detected (EXLA uses CPU target, native Metal support pending)"
            '' else if platform.hasROCm then ''
            export ROCM_HOME="/opt/rocm"
            export LD_LIBRARY_PATH="/opt/rocm/lib:''${LD_LIBRARY_PATH:-}"
            export XLA_FLAGS="${gpu.xlaFlags}"
            export EXLA_TARGET="rocm"
            echo "🔴 GPU: ROCm (AMD) available for EXLA acceleration"
            '' else ''
            echo "⚠️  GPU: CPU-only mode (no GPU acceleration available)"
            ''}
            '' else ""}

            ${lib.concatMapStrings (serviceName:
              let service = services.${serviceName}; in
              if serviceName == "postgresql" && lib.elem serviceName env.services then ''
              # PostgreSQL setup
              export PGHOST="localhost"
              export PGPORT="${toString (builtins.head service.ports)}"
              echo "🗄️  ${service.name} configured on port ${toString (builtins.head service.ports)}"

              # pg_uuidv7 setup (timestamp-ordered UUIDs = 20-30% faster polling)
              if command -v pgxn &> /dev/null; then
                echo "      ✅ pg_uuidv7: pgxn install pg_uuidv7"
              else
                echo "      ℹ️  pg_uuidv7: brew install pgxnclient && pgxn install pg_uuidv7"
              fi
              '' else ""
            ) env.services}

            ${if lib.elem "postgresql" env.services then ''
            # Local PostgreSQL setup
            export DEV_PGROOT="$PWD/.dev-db"
            export PGDATA="$DEV_PGROOT/pg"
            echo "   Run 'just db-setup' to initialize PostgreSQL"
            '' else ""}

            echo "   Run 'just help' for available commands"
          '';
        };

      in {
        # LLM-Friendly: Dev shells for different environments
        # Each environment is built using the buildDevShell function
        devShells = {
          # Local development with all services (default)
          default = buildDevShell environments.dev;
          dev = buildDevShell environments.dev;

          # CI testing environment
          ci = buildDevShell environments.ci;

          # GPU-accelerated development environment (Metal on Mac, CUDA on Linux)
          prod = buildDevShell environments.prod;
        };

      });
}
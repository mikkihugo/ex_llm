{
  description = "Singularity - Autonomous agent platform with GPU-accelerated semantic code search";

  # LLM-Friendly: This flake provides multiple deployment environments:
  # - dev: Full local development with all services auto-started
  # - fast: Minimal local development (no services)
  # - test: Remote testing environment with full services
  # - prod: Remote production environment with optimized services
  # - ci: Continuous integration environment

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    # Binary cache for faster package downloads
    extra-substituters = ["https://mikkihugo.cachix.org"];
    extra-trusted-public-keys = ["mikkihugo.cachix.org-1:dxqCDAvMSMefAFwSnXYvUdPnHJYq+pqF8tul8bih9Po="];
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # LLM-Friendly: Platform detection function
        # Input: Nix system string (e.g., "x86_64-linux")
        # Output: Platform capabilities record
        detectPlatformCapabilities = system: {
          # Can run CUDA workloads (NVIDIA GPU acceleration)
          hasCuda = system == "x86_64-linux";

          # Can run Metal workloads (Apple Silicon GPU acceleration)
          isAppleSilicon = system == "aarch64-darwin";

          # Is Linux (for CUDA and other Linux-specific features)
          isLinux = nixpkgs.lib.hasSuffix "-linux" system;

          # Is macOS (for Metal and other Darwin-specific features)
          isDarwin = nixpkgs.lib.hasSuffix "-darwin" system;
        };

        # LLM-Friendly: GPU configuration function
        # Input: Platform capabilities
        # Output: GPU acceleration settings
        configureGpuAcceleration = platform: {
          # Target for Elixir ML library (EXLA)
          exlaTarget = if platform.isAppleSilicon then "metal"
                      else if platform.hasCuda then "cuda"
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
          xlaFlags = if platform.isAppleSilicon then "--xla_gpu_platform_device_count=1"
                    else if platform.hasCuda then "--xla_gpu_cuda_data_dir=${pkgs.cudaPackages.cudatoolkit}"
                    else "";
        };

        # LLM-Friendly: Environment configuration records
        environments = {
          # Local development with all services
          dev = {
            name = "Full Development Environment";
            purpose = "Local development with auto-starting services";
            services = ["nats" "postgresql" "ai-server" "phoenix"];
            gpu = true;
            caching = true;
            remote = false;
          };

          # Minimal local development
          fast = {
            name = "Fast Development Environment";
            purpose = "Minimal local development without services";
            services = [];
            gpu = false;
            caching = true;
            remote = false;
          };

          # Remote testing environment
          test = {
            name = "Remote Testing Environment";
            purpose = "Full testing environment on remote server";
            services = ["nats" "postgresql" "ai-server" "phoenix"];
            gpu = true;
            caching = true;
            remote = true;
            host = "test.singularity.internal";  # Configure your remote host
          };

          # Remote production environment
          prod = {
            name = "Remote Production Environment";
            purpose = "Optimized production environment on remote server";
            services = ["nats" "postgresql" "ai-server" "phoenix"];
            gpu = true;
            caching = true;
            remote = true;
            host = "prod.singularity.internal";  # Configure your remote host
            optimized = true;
          };

          # CI environment
          ci = {
            name = "Continuous Integration Environment";
            purpose = "Automated testing and building";
            services = ["postgresql"];
            gpu = false;
            caching = true;
            remote = false;
          };
        };

        # LLM-Friendly: Service configuration records
        services = {
          nats = {
            name = "NATS Message Bus";
            purpose = "Distributed messaging for LLM requests and service communication";
            ports = [4222 4223];
            jetstream = true;
          };

          postgresql = {
            name = "PostgreSQL Database";
            purpose = "Primary database with pgvector for embeddings, TimescaleDB for metrics";
            extensions = ["pgvector" "timescaledb" "postgis"];
            ports = [5432];
          };

          ai-server = {
            name = "AI Server";
            purpose = "TypeScript service handling LLM API calls (Claude, Gemini, OpenAI, Copilot)";
            ports = [3000];
            runtime = "bun";
          };

          phoenix = {
            name = "Phoenix Web Server";
            purpose = "Elixir web framework serving the Singularity interface";
            ports = [4000];
            runtime = "elixir";
          };
        };

        # Get platform capabilities for this system
        platform = detectPlatformCapabilities system;
        gpu = configureGpuAcceleration platform;

        # Base package imports
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        lib = nixpkgs.lib;
        beamPackages = pkgs.beam.packages.erlang_28;

        # LLM-Friendly: Package collection functions
        # Each function returns packages for a specific purpose

        getBaseTools = env: with pkgs; [
          git gh curl pkg-config direnv gnused gawk coreutils findutils
          ripgrep fd jq bat htop tree watchexec entr just nil nixfmt-rfc-style lsof
          mold sccache cachix rustc cargo rustfmt clippy rust-analyzer cargo-watch
        ] ++ lib.optionals env.gpu (if platform.hasCuda then [
          # CUDA tools only if GPU enabled and CUDA available
          cudaPackages.cudatoolkit cudaPackages.cudnn
        ] else []);

        getBeamTools = env: [
          beamPackages.erlang beamPackages.elixir beamPackages.hex
          beamPackages.rebar3 pkgs.elixir_ls pkgs.erlang-ls pkgs.gleam
        ];

        getDataServices = env: lib.optionals (lib.elem "postgresql" env.services) [
          # PostgreSQL with extensions for vector search and time-series
          (pkgs.postgresql_16.withPackages (ps:
            let
              extensions = ["pgvector" "timescaledb" "postgis" "pgtap" "pg_cron"];
              available = lib.filter (name: lib.hasAttr name ps) extensions;
            in map (name: lib.getAttr name ps) available
          ))
        ];

        getWebAndCliTools = env: with pkgs; [
          flyctl bun nats-server
        ] ++ lib.optionals platform.isLinux [
          podman buildah skopeo
        ];

        getQaTools = env: with pkgs; [
          semgrep shellcheck hadolint
          nodePackages.eslint nodePackages.typescript-language-server nodePackages.typescript
        ];

        getPythonTrainingEnv = env: lib.optionals env.gpu (
          # Python environment for ML training (only if GPU enabled)
          pkgs.python311.withPackages (ps: [
            ps.pip ps.setuptools ps.wheel ps.numpy ps.scipy ps.pandas
            ps.tokenizers ps.safetensors ps.transformers ps.datasets
            ps.accelerate ps.peft ps.evaluate ps.tqdm ps.regex
            ps.huggingface-hub ps.jinja2 ps.protobuf
          ] ++ lib.optionals (lib.hasAttr "torch" ps) [
            ps.torch ps.torchvision ps.torchaudio
          ])
        );

        # LLM-Friendly: Environment builder function
        # Input: Environment configuration record
        # Output: Complete devShell configuration
        buildDevShell = env: let
          allPackages = lib.flatten [
            (getBaseTools env)
            (getBeamTools env)
            (getDataServices env)
            (getWebAndCliTools env)
            (getQaTools env)
            (getPythonTrainingEnv env)
          ];
        in {
          name = "${env.name} Shell";
          buildInputs = allPackages;

          shellHook = ''
            # LLM-Friendly: Environment-specific setup
            echo "🚀 Loading ${env.name}"
            echo "   Purpose: ${env.purpose}"

            ${if env.remote then ''
            # Remote deployment setup
            echo "   Remote host: ${env.host}"
            export REMOTE_DEPLOYMENT=1
            export DEPLOYMENT_HOST="${env.host}"
            '' else ''
            # Local development setup
            echo "   Local development environment"
            ''}

            # Common environment setup
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV=''${MIX_ENV:-${if env.name == "Remote Production Environment" then "prod" else "dev"}}

            ${if env.caching then ''
            # Caching setup for performance
            export CARGO_HOME="''${HOME}/.cache/singularity/cargo"
            export SCCACHE_DIR="''${HOME}/.cache/singularity/sccache"
            export SCCACHE_CACHE_SIZE="10G"
            export RUSTC_WRAPPER="sccache"
            export CARGO_TARGET_DIR=".cargo-build"
            export CARGO_INCREMENTAL="0"
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
            mkdir -p "$CARGO_HOME" "$SCCACHE_DIR" 2>/dev/null || true
            '' else ""}

            ${if env.gpu then ''
            # GPU acceleration setup
            ${if platform.isAppleSilicon then ''
            export EXLA_TARGET="metal"
            export XLA_FLAGS="--xla_gpu_platform_device_count=1"
            echo "🍎 GPU: Apple Silicon Metal available"
            '' else if platform.hasCuda then ''
            export CUDA_HOME="${gpu.cudaPaths.toolkit}"
            export CUDNN_HOME="${gpu.cudaPaths.cudnn}"
            export LD_LIBRARY_PATH="${gpu.cudaPaths.lib}:${gpu.cudaPaths.cudnnLib}:''${LD_LIBRARY_PATH:-}"
            export XLA_FLAGS="${gpu.xlaFlags}"
            export EXLA_TARGET="cuda"
            echo "🎮 GPU: CUDA available for EXLA acceleration"
            '' else ''
            echo "⚠️  GPU: CPU-only mode (no GPU acceleration available)"
            ''}
            '' else ""}

            ${lib.concatMapStrings (serviceName:
              let service = services.${serviceName}; in
              if serviceName == "nats" && lib.elem serviceName env.services then ''
              # NATS setup
              export NATS_URL="nats://localhost:${toString (builtins.head service.ports)}"
              export NATS_JETSTREAM_URL="nats://localhost:${toString (builtins.elemAt service.ports 1)}"
              echo "📡 ${service.name} configured on ports ${lib.concatMapStringsSep "," toString service.ports}"
              '' else if serviceName == "postgresql" && lib.elem serviceName env.services then ''
              # PostgreSQL setup
              export PGHOST="localhost"
              export PGPORT="${toString (builtins.head service.ports)}"
              echo "🗄️  ${service.name} configured on port ${toString (builtins.head service.ports)}"
              '' else if serviceName == "ai-server" && lib.elem serviceName env.services then ''
              # AI Server setup
              echo "🤖 ${service.name} configured on port ${toString (builtins.head service.ports)}"
              '' else if serviceName == "phoenix" && lib.elem serviceName env.services then ''
              # Phoenix setup
              echo "🏗️  ${service.name} configured on port ${toString (builtins.head service.ports)}"
              '' else ""
            ) env.services}

            ${if env.remote then ''
            # Remote deployment commands
            echo ""
            echo "📤 Remote Deployment Commands:"
            echo "   nix copy --to ssh://$DEPLOYMENT_HOST ${self}"
            echo "   ssh $DEPLOYMENT_HOST 'cd /path/to/singularity && nix develop'"
            echo ""
            '' else if lib.elem "postgresql" env.services then ''
            # Local PostgreSQL setup (simplified for brevity)
            export DEV_PGROOT="$PWD/.dev-db"
            export PGDATA="$DEV_PGROOT/pg"
            echo "   Run 'just db-setup' to initialize PostgreSQL"
            '' else ""}

            echo "   Run 'just help' for available commands"
          '';
        };

        # LLM-Friendly: Remote deployment configuration
        # This allows deploying to remote servers via nix copy
        deployToRemote = env: host: {
          name = "deploy-${env.name}";
          value = pkgs.writeScript "deploy-${env.name}" ''
            #!${pkgs.bash}/bin/bash
            set -e

            echo "🚀 Deploying ${env.name} to ${host}"

            # Copy closure to remote host
            echo "📦 Copying Nix closure to ${host}..."
            nix copy --to ssh://${host} ${self}

            # Deploy on remote host
            echo "📤 Starting deployment on ${host}..."
            ssh ${host} "
              cd /opt/singularity || mkdir -p /opt/singularity && cd /opt/singularity
              nix develop ${self}#${env.name} --command bash -c '
                echo \"${env.name} deployed successfully on ${host}\"
                echo \"Services: ${lib.concatStringsSep ", " env.services}\"
                ${if env.gpu then "echo \"GPU acceleration: enabled\"" else "echo \"GPU acceleration: disabled\""}
              '
            "

            echo "✅ Deployment complete!"
          '';
        };
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
            # LLM-Friendly: Environment Setup
            # - UTF-8 locale for stable BEAM IO
            # - Erlang distribution flags for networking
            # - Mix environment configuration
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export MIX_ENV=''${MIX_ENV:-dev}

            # LLM-Friendly: Rust/Cargo Caching
            # - sccache: Fast compilation caching (10GB limit)
            # - Sparse registry: Faster crate downloads
            # - Incremental disabled: Better sccache compatibility
            export CARGO_HOME="''${HOME}/.cache/singularity/cargo"
            export SCCACHE_DIR="''${HOME}/.cache/singularity/sccache"
            export SCCACHE_CACHE_SIZE="10G"
            export RUSTC_WRAPPER="sccache"
            export CARGO_TARGET_DIR=".cargo-build"
            export CARGO_INCREMENTAL="0"  # Disabled for sccache compatibility
            export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="sparse"
            mkdir -p "$CARGO_HOME" "$SCCACHE_DIR" 2>/dev/null || true

            # LLM-Friendly: BEAM Tooling Setup
            # - Gleam: Functional language compiling to BEAM
            # - Mix: Elixir build tool
            # - Hex: Elixir package manager
            # - Rebar3: Erlang build tool
            export GLEAM_ERLANG_INCLUDE_PATH="${beamPackages.erlang}/lib/erlang/usr/include"
            export MIX_HOME="$PWD/.mix"
            export HEX_HOME="$PWD/.hex"
            # Stabilize rebar3 paths for Mix/rebar deps
            export REBAR_CACHE_DIR="$PWD/.rebar3/cache"
            export REBAR_GLOBAL_CONFIG_DIR="$PWD/.rebar3"
            export REBAR_PLUGINS_DIR="$PWD/.rebar3/plugins"
            mkdir -p "$MIX_HOME" "$HEX_HOME" "$REBAR_CACHE_DIR" "$REBAR_PLUGINS_DIR" "$PWD/bin"

            # LLM-Friendly: OpenSSL Setup for Rust NIFs
            # - NIFs: Native Implemented Functions (Rust code called from Elixir)
            # - OpenSSL: Required for cryptography in Rust NIFs
            export OPENSSL_DIR="${pkgs.openssl.out}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:$LD_LIBRARY_PATH"

            if [ -n "${cudaToolkitPath}" ]; then
              # LLM-Friendly: CUDA GPU Setup (Linux/WSL2)
              # - EXLA: Elixir machine learning library using XLA
              # - CUDA: NVIDIA GPU acceleration for ML workloads
              # - WSL2: Windows Subsystem for Linux gets GPU access from Windows host
              export CUDA_HOME="${cudaToolkitPath}"
              export CUDNN_HOME="${cudaCudnnPath}"
              export LD_LIBRARY_PATH="${cudaToolkitLibPath}:${cudaCudnnLibPath}:''${LD_LIBRARY_PATH:-}"
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
            elif [ "${isAppleSilicon}" = "1" ]; then
              # LLM-Friendly: Apple Silicon Metal Setup (macOS)
              # - Metal: Apple's GPU compute framework
              # - EXLA: Uses Metal for ML acceleration on Apple Silicon
              # - system_profiler: macOS tool to detect hardware
              export EXLA_TARGET="metal"
              export XLA_FLAGS="--xla_gpu_platform_device_count=1"

              # Check if Metal is available
              if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Chipset Model"; then
                echo "🍎 GPU: Apple Silicon Metal available"
                echo "   Metal: Enabled for EXLA acceleration"
              else
                echo "⚠️  GPU: Apple Silicon Metal not detected"
                echo "   Metal: CPU-only fallback"
              fi
            fi

            # LLM-Friendly: NATS Message Bus Setup
            # - NATS: Distributed messaging system for service communication
            # - JetStream: NATS persistence layer for streaming and pub/sub
            # - Two servers: Simple NATS (port 4222) for LLM requests, JetStream (port 4223) for other services
            export NATS_URL="nats://localhost:4222"
            export NATS_JETSTREAM_URL="nats://localhost:4223"
            export NATS_PID_FILE="$PWD/.nats/nats-server.pid"
            export NATS_JETSTREAM_PID_FILE="$PWD/.nats/nats-jetstream.pid"
            mkdir -p "$PWD/.nats"

            # Start simple NATS for LLM requests (port 4222)
            if [ -f "$NATS_PID_FILE" ] && kill -0 "$(cat "$NATS_PID_FILE")" 2>/dev/null; then
              echo "📡 NATS (LLM) already running on nats://localhost:4222 (PID: $(cat "$NATS_PID_FILE"))"
            else
              echo "📡 Starting NATS (LLM requests) on port 4222..."
              rm -f "$NATS_PID_FILE"
              nats-server -p 4222 > "$PWD/.nats/nats-server.log" 2>&1 &
              NATS_PID=$!
              echo $NATS_PID > "$NATS_PID_FILE"
              sleep 1
              if kill -0 $NATS_PID 2>/dev/null; then
                echo "   ✅ NATS (LLM) running on nats://localhost:4222 (PID: $NATS_PID)"
              else
                echo "   ❌ Failed to start NATS (LLM) server"
                rm -f "$NATS_PID_FILE"
              fi
            fi

            # Start NATS with JetStream for other services (port 4223)
            if [ -f "$NATS_JETSTREAM_PID_FILE" ] && kill -0 "$(cat "$NATS_JETSTREAM_PID_FILE")" 2>/dev/null; then
              echo "📡 NATS JetStream already running on nats://localhost:4223 (PID: $(cat "$NATS_JETSTREAM_PID_FILE"))"
            else
              echo "📡 Starting NATS JetStream on port 4223..."
              rm -f "$NATS_JETSTREAM_PID_FILE"
              nats-server -js -sd "$PWD/.nats/jetstream" -p 4223 > "$PWD/.nats/nats-jetstream.log" 2>&1 &
              NATS_JS_PID=$!
              echo $NATS_JS_PID > "$NATS_JETSTREAM_PID_FILE"
              sleep 1
              if kill -0 $NATS_JS_PID 2>/dev/null; then
                echo "   ✅ NATS JetStream running on nats://localhost:4223 (PID: $NATS_JS_PID)"
              else
                echo "   ❌ Failed to start NATS JetStream server"
                rm -f "$NATS_JETSTREAM_PID_FILE"
              fi
            fi

            # LLM-Friendly: AI Server Setup (TypeScript/Bun)
            # - AI Server: TypeScript service handling LLM API calls (Claude, Gemini, OpenAI, Copilot)
            # - Bun: Fast JavaScript/TypeScript runtime
            # - Background process: Runs continuously to serve LLM requests
            export AI_SERVER_PID_FILE="$PWD/ai-server/.ai-server.pid"
            mkdir -p "$PWD/ai-server/logs"

            if [ -f "$AI_SERVER_PID_FILE" ] && kill -0 "$(cat "$AI_SERVER_PID_FILE")" 2>/dev/null; then
              echo "🤖 AI Server already running (PID: $(cat "$AI_SERVER_PID_FILE"))"
            else
              if [ -d "$PWD/ai-server" ]; then
                echo "🤖 Starting AI Server..."
                # Clean up any stale PID file
                rm -f "$AI_SERVER_PID_FILE"
                # Start AI Server
                (
                  cd ai-server
                  bun run start > logs/ai-server.log 2>&1 &
                  AI_SERVER_PID=$!
                  echo $AI_SERVER_PID > .ai-server.pid
                  cd ..
                )
                sleep 2
                if [ -f "$AI_SERVER_PID_FILE" ] && kill -0 "$(cat "$AI_SERVER_PID_FILE")" 2>/dev/null; then
                  echo "   ✅ AI Server running (PID: $(cat "$AI_SERVER_PID_FILE"), logs: ai-server/logs/ai-server.log)"
                else
                  echo "   ❌ Failed to start AI Server (check logs: ai-server/logs/ai-server.log)"
                  rm -f "$AI_SERVER_PID_FILE"
                fi
              fi
            fi

            # LLM-Friendly: Phoenix Server Auto-start
            # - Phoenix: Elixir web framework (like Rails for Ruby)
            # - Auto-start: Launches development server automatically
            # - Background process: Runs web interface on http://localhost:4000
            if [ -d "singularity_app" ] && [ ! -f "$PWD/.singularity-server.pid" ]; then
              echo "🚀 Starting Singularity Phoenix server..."
              (
                cd singularity_app
                # Install deps if needed
                if [ ! -d "deps" ]; then
                  echo "   Installing dependencies..."
                  mix deps.get > /dev/null 2>&1
                fi
                # Start server in background
                mix phx.server > "$PWD/../.singularity-server.log" 2>&1 &
                SERVER_PID=$!
                echo $SERVER_PID > "$PWD/../.singularity-server.pid"
                echo "   Phoenix server starting on http://localhost:4000 (logs: .singularity-server.log)"
                echo "   PID: $SERVER_PID (stop with: kill \$(cat .singularity-server.pid))"
              ) &
            elif [ -f "$PWD/.singularity-server.pid" ]; then
              SERVER_PID=$(cat "$PWD/.singularity-server.pid")
              if kill -0 "$SERVER_PID" 2>/dev/null; then
                echo "🚀 Singularity Phoenix server already running (PID: $SERVER_PID)"
              else
                rm "$PWD/.singularity-server.pid"
                echo "   Previous server process died, restart shell to launch again"
              fi
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

            # LLM-Friendly: PostgreSQL Database Setup
            # - PostgreSQL: Primary database for all Singularity data (embeddings, knowledge, agents)
            # - pgvector: Vector similarity search for semantic code search
            # - TimescaleDB: Time-series data for metrics and usage tracking
            # - PostGIS: Geospatial data (optional)
            # - Auto-initialization: Creates database cluster if it doesn't exist
            export DEV_PGROOT="$PWD/.dev-db"
            export PGDATA="$DEV_PGROOT/pg"
            export PGHOST="localhost"
            export PG_PID_FILE="$DEV_PGROOT/postgres.pid"
            
            # LLM-Friendly: Port Selection
            # - Dynamic port allocation: Finds available port starting from 5432
            # - Avoids conflicts: Checks if port is already in use
            find_available_port() {
              local port=5432
              while [ $port -le 65535 ]; do
                if ! lsof -i :$port >/dev/null 2>&1; then
                  echo $port
                  return
                fi
                port=$((port + 1))
              done
              echo "5432"  # fallback
            }
            
            if ! printenv PGPORT >/dev/null 2>&1 || [ -z "$PGPORT" ]; then
              if printenv DEV_PGPORT >/dev/null 2>&1 && [ -n "$DEV_PGPORT" ]; then
                export PGPORT="$DEV_PGPORT"
              else
                export PGPORT=$(find_available_port)
              fi
            fi
            if ! printenv _DEV_SHELL_PG_STARTED >/dev/null 2>&1 || [ -z "$_DEV_SHELL_PG_STARTED" ]; then
              export _DEV_SHELL_PG_STARTED=0
            fi

            # LLM-Friendly: Database Initialization
            # - initdb: Creates new PostgreSQL database cluster
            # - pg_hba.conf: Authentication configuration (trust for local development)
            # - postgresql.conf: Basic configuration (listen on localhost, custom port)
            if [ ! -d "$PGDATA" ]; then
              echo "🗄️  Initializing PostgreSQL database..."
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
log_destination = 'stderr'
logging_collector = off
EOF
              echo "   ✅ PostgreSQL initialized on port $PGPORT"
            fi

            # LLM-Friendly: Database Startup
            # - pg_ctl: PostgreSQL control utility
            # - Background process: Database runs continuously
            # - PID tracking: Stores process ID for management
            if [ -f "$PG_PID_FILE" ] && kill -0 "$(cat "$PG_PID_FILE")" 2>/dev/null; then
              echo "🗄️  PostgreSQL already running on port $PGPORT (PID: $(cat "$PG_PID_FILE"))"
            elif ! ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
              echo "🚀 Starting PostgreSQL on port $PGPORT..."
              ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" -o "-p $PGPORT" start >/dev/null
              if [ $? -eq 0 ]; then
                echo $! > "$PG_PID_FILE" 2>/dev/null || true
                export _DEV_SHELL_PG_STARTED=1
                echo "   ✅ PostgreSQL started on port $PGPORT (data: $PGDATA)"
              else
                echo "   ❌ Failed to start PostgreSQL (check logs: $PGDATA/postgres.log)"
              fi
            fi

            if ! printenv _DEV_SHELL_PG_TRAP >/dev/null 2>&1 || [ -z "$_DEV_SHELL_PG_TRAP" ]; then
              trap 'if [ "$_DEV_SHELL_PG_STARTED" = "1" ]; then echo "🛑 Stopping PostgreSQL..."; ${postgresqlWithExtensions}/bin/pg_ctl -D "$PGDATA" -m fast stop >/dev/null 2>&1 || true; rm -f "$PG_PID_FILE"; fi' EXIT
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
          buildInputs =
            [
              pkgs.flyctl
              pkgs.just
              pkgs.git
              pkgs.curl
              pkgs.openssl
              pkgs.jq
            ]
            ++ lib.optionals isLinux [
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
          preferLocalBuild = true;

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
            export PATH="$HOME/.local/bin:$PATH"
            export PATH="$HOME/.bun/bin:$PATH"

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

            if [ -n "${cudaToolkitPath}" ]; then
              # CUDA setup for GPU-accelerated development
              export CUDA_HOME="${cudaToolkitPath}"
              export CUDA_PATH="${cudaToolkitPath}"
              export PATH="${cudaBinPath}:$PATH"
              export LD_LIBRARY_PATH="${cudaToolkitLibPath}:''${LD_LIBRARY_PATH:-}"
            elif [ "${isAppleSilicon}" = "1" ]; then
              # Apple Silicon Metal acceleration for EXLA
              export EXLA_TARGET="metal"
              export XLA_FLAGS="--xla_gpu_platform_device_count=1"

              # Check if Metal is available (cached check for speed)
              mkdir -p "$HOME/.cache/singularity" 2>/dev/null || true
              if [ ! -f "$HOME/.cache/singularity/metal_available" ]; then
                if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Chipset Model"; then
                  echo "1" > "$HOME/.cache/singularity/metal_available"
                else
                  echo "0" > "$HOME/.cache/singularity/metal_available"
                fi
              fi

              if [ "$(cat "$HOME/.cache/singularity/metal_available" 2>/dev/null)" = "1" ]; then
                echo "🍎 GPU: Apple Silicon Metal available"
                echo "   Metal: Enabled for EXLA acceleration"
              else
                echo "⚠️  GPU: Apple Silicon Metal not detected"
                echo "   Metal: CPU-only fallback"
              fi
            fi

            # OpenSSL for Rust NIF compilation and runtime
            export OPENSSL_DIR="${pkgs.openssl.out}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:$LD_LIBRARY_PATH"

            # Ensure just is available
            export PATH="${pkgs.just}/bin:$PATH"

            if ! command -v codex >/dev/null 2>&1; then
              echo "[setup] Installing Codex CLI (bun global @openai/codex)..."
              if ! ${pkgs.bun}/bin/bun install --global @openai/codex >/dev/null 2>&1; then
                echo "[warn] Failed to install Codex CLI automatically. Install manually with: bun install --global @openai/codex"
              fi
            fi

            if ! command -v cursor-agent >/dev/null 2>&1; then
              echo "[setup] Installing Cursor Agent CLI..."
              # Install to HOME/.local/bin (in PATH via line 646)
              export CURSOR_INSTALL_DIR="$HOME/.local/bin"
              mkdir -p "$CURSOR_INSTALL_DIR" 2>/dev/null || true
              if ${pkgs.curl}/bin/curl https://cursor.com/install -fsSL | ${pkgs.bash}/bin/bash -s -- "$CURSOR_INSTALL_DIR" 2>&1; then
                echo "[OK] cursor-agent installed to $CURSOR_INSTALL_DIR"
              else
                echo "[warn] Failed to install cursor-agent. Install manually: curl https://cursor.com/install -fsSL | bash"
              fi
            fi

            echo "🚀 Singularity Development Environment"
            echo "  MIX_ENV=dev"
            echo "  CUDA: $CUDA_HOME"
            echo "  Metal: $EXLA_TARGET"
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
            if [ -n "${cudaToolkitPath}" ]; then
              export CUDA_HOME="${cudaToolkitPath}"
              export CUDNN_HOME="${cudaCudnnPath}"
              export LD_LIBRARY_PATH="${cudaToolkitLibPath}:${cudaCudnnLibPath}:''${LD_LIBRARY_PATH:-}"
            fi
            mkdir -p "$HF_HOME"

            # OpenSSL for any Rust dependencies
            export OPENSSL_DIR="${pkgs.openssl.out}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:$LD_LIBRARY_PATH"

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

        # Fast/light development environment (no auto-services)
        devShells.fast = pkgs.mkShell {
          name = "singularity-fast";
          buildInputs = beamTools ++ commonTools ++ dataServices ++ webAndCli ++ qaTools ++ aiCliPackages;
          preferLocalBuild = true;

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
            export PATH="$HOME/.local/bin:$PATH"
            export PATH="$HOME/.bun/bin:$PATH"

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

            if [ -n "${cudaToolkitPath}" ]; then
              # CUDA setup for GPU-accelerated development
              export CUDA_HOME="${cudaToolkitPath}"
              export CUDA_PATH="${cudaToolkitPath}"
              export PATH="${cudaBinPath}:$PATH"
              export LD_LIBRARY_PATH="${cudaToolkitLibPath}:''${LD_LIBRARY_PATH:-}"
            elif [ "${isAppleSilicon}" = "1" ]; then
              # Apple Silicon Metal acceleration for EXLA
              export EXLA_TARGET="metal"
              export XLA_FLAGS="--xla_gpu_platform_device_count=1"

              # Check if Metal is available (cached check for speed)
              mkdir -p "$HOME/.cache/singularity" 2>/dev/null || true
              if [ ! -f "$HOME/.cache/singularity/metal_available" ]; then
                if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "Chipset Model"; then
                  echo "1" > "$HOME/.cache/singularity/metal_available"
                else
                  echo "0" > "$HOME/.cache/singularity/metal_available"
                fi
              fi

              if [ "$(cat "$HOME/.cache/singularity/metal_available" 2>/dev/null)" = "1" ]; then
                echo "🍎 GPU: Apple Silicon Metal available"
                echo "   Metal: Enabled for EXLA acceleration"
              else
                echo "⚠️  GPU: Apple Silicon Metal not detected"
                echo "   Metal: CPU-only fallback"
              fi
            fi

            # OpenSSL for Rust NIF compilation and runtime
            export OPENSSL_DIR="${pkgs.openssl.out}"
            export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
            export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
            export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib:${pkgs.zlib.out}/lib:$LD_LIBRARY_PATH"

            # Ensure just is available
            export PATH="${pkgs.just}/bin:$PATH"

            echo "⚡ Singularity Fast Development Environment"
            echo "  MIX_ENV=dev"
            echo "  Metal: $EXLA_TARGET"
            echo "  Services: Manual start only (use 'just dev' to start all)"
            echo "  Run: mix phx.server"
          '';
        };
      });
}

{
  description = "Singularity - Autonomous agent platform with GPU-accelerated semantic code search";

  # Environment Configurations:
  # - dev: Local development (any OS via Nix)
  # - ci: Automated testing environment
  # - prod: NixOS-based production (RTX 4080 optimized, reproducible builds)
  #
  # PRODUCTION DEPLOYMENT (RTX 4080):
  # ✅ RECOMMENDED: NixOS ISO on bare metal
  #    - Best GPU access (CUDA/Metal without layers)
  #    - Direct hardware passthrough (no WSL2/Podman overhead)
  #    - Use: nix build .#singularity-integrated
  #
  # Alternative: Docker/Podman (not recommended for GPU)
  #    - GPU support requires additional setup
  #    - Performance overhead compared to bare metal

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  nixConfig = {
    # Fix download buffer warning - increase buffer size
    download-buffer-size = "2147483648";  # 2GB buffer
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

        # LLM-Friendly: Simplified environment configurations
        environments = {
          # Local development environment
          dev = {
            name = "Local Development Environment";
            purpose = "Full development with all services auto-started locally";
            services = ["nats" "postgresql" "ai-server" "phoenix"];
            gpu = true;
            caching = true;
            remote = false;
            includePython = false;  # No Python in dev (focus on Elixir/Rust development)
          };

          # CI testing environment
          ci = {
            name = "Continuous Integration Environment";
            purpose = "Automated testing and building";
            services = ["postgresql"];
            gpu = false;
            caching = true;
            remote = false;
            includePython = false;  # No Python in CI
          };

          # Remote production environment (Docker/K8s ready)
          # For RTX 4080: Set gpu=true, remote=false, includePython=true
          prod = {
            name = "RTX 4080 Production Environment";
            purpose = "High-performance production on local RTX 4080 GPU";
            services = ["nats" "postgresql" "ai-server" "phoenix"];
            gpu = true;  # Enable RTX 4080 acceleration
            caching = true;
            remote = false;  # Run locally on GPU machine
            host = "localhost";  # Local GPU machine
            docker = false;  # Direct Nix deployment (better GPU access)
            includePython = true;  # Full ML stack for GPU embeddings
            rtx4080 = true;  # RTX 4080 optimized settings
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
          beamPackages.erlang pkgs.elixir_1_19 beamPackages.hex
          beamPackages.rebar3 pkgs.elixir_ls
        ];
        
        # Add Erlang development headers for Rustler NIFs
        getRustTools = env: with pkgs; [
          rustc cargo gcc
          beamPackages.erlang  # For NIF linking
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

        getAiCliTools = env: with pkgs; [
          # GitHub CLI (already included in base tools)
          # gh

          # LLM plugins for unified interface
          python312Packages.llm-anthropic  # Claude access
          python312Packages.llm-github-copilot  # GitHub Copilot access

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
            exec gemini "$@"
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

        getPythonTrainingEnv = env: lib.optionals (env ? includePython && env.includePython) (
          # OPTION 1: Self-hosted ML (GPU required)
          # OPTION 2: Serverless APIs (cheaper for low usage)
          # Current: Self-hosted with GPU acceleration
          # For serverless: Remove this, use API calls instead
          pkgs.python311.withPackages (ps: [
            ps.pip ps.setuptools ps.wheel ps.numpy ps.scipy ps.pandas
            ps.tokenizers ps.safetensors ps.transformers ps.datasets
            ps.accelerate ps.peft ps.evaluate ps.tqdm ps.regex
            ps.huggingface-hub ps.jinja2 ps.protobuf
            # Add requests for API calls: ps.requests
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
            (getRustTools env)
            (getDataServices env)
            (getWebAndCliTools env)
            (getQaTools env)
            (getAiCliTools env)
            (getPythonTrainingEnv env)
          ];
        in pkgs.mkShell {
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
            ${if env ? docker && env.docker then ''
            echo "   Docker/K8s ready: Yes"
            echo "   Run 'nix run .#docker-build' to build Docker image"
            echo "   Run 'nix run .#k8s-deploy' for Kubernetes deployment"
            '' else ""}
            '' else ''
            # Local development setup
            echo "   Local development environment"
            ''}

            # Common environment setup
            export LC_ALL=C.UTF-8
            export LANG=C.UTF-8
            export ELIXIR_ERL_OPTIONS="+fnu"
            export ERL_AFLAGS="-proto_dist inet6_tcp"
            export ERL_FLAGS="-heart +sbt u +sbwt very_long +swt very_low"
            export RUSTFLAGS="-C linker=gcc"
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
            ${if env ? rtx4080 && env.rtx4080 then ''
            # RTX 4080 specific optimizations
            export CUDA_VISIBLE_DEVICES="0"
            export TORCH_CUDA_ARCH_LIST="8.9"  # RTX 4080 architecture
            export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:512"
            echo "🎮 GPU: RTX 4080 16GB CUDA optimized"
            echo "   CUDA Arch: 8.9 (Ada Lovelace)"
            echo "   Memory: 16GB GDDR6X"
            '' else ''
            echo "🎮 GPU: CUDA available for EXLA acceleration"
            ''}
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

      in {
        # LLM-Friendly: Dev shells for different environments
        # Each environment is built using the buildDevShell function
        devShells = {
          # Local development with all services (default)
          default = buildDevShell environments.dev;
          dev = buildDevShell environments.dev;

          # CI testing environment
          ci = buildDevShell environments.ci;

          # Remote production environment (Docker/K8s ready)
          prod = buildDevShell environments.prod;
        };

        # LLM-Friendly: Remote deployment scripts
        # These can be used to deploy environments to remote servers or K8s
        packages = {
          # Docker image for production deployment
          dockerImage = pkgs.dockerTools.buildImage {
            name = "singularity-prod";
            tag = "latest";
            fromImage = null;
            contents = [
              (buildDevShell environments.prod)
              ./singularity_app
              ./ai-server
              ./rust
            ];
            config = {
              Cmd = ["${pkgs.bash}/bin/bash"];
              WorkingDir = "/app";
              Env = [
                "MIX_ENV=prod"
                "LC_ALL=C.UTF-8"
                "LANG=C.UTF-8"
              ];
            };
          };

          # Deployment script for remote production
          deploy-prod = deployToRemote environments.prod environments.prod.host;
        };

        # LLM-Friendly: Apps for easy deployment
        apps = {
          # Remote production deployment
          deploy-prod = {
            type = "app";
            program = "${deployToRemote environments.prod environments.prod.host}";
          };

          # RTX 4080 setup script
          setup-rtx4080 = {
            type = "app";
            program = "${pkgs.writeScript "setup-rtx4080" ''
              #!${pkgs.bash}/bin/bash
              echo "🎮 RTX 4080 Setup for Singularity"
              echo "Run this script on your Windows machine with RTX 4080"
              echo ""
              echo "Copy and run on GPU machine:"
              echo "curl -fsSL https://raw.githubusercontent.com/mikkihugo/singularity-incubation/main/setup_rtx4080.sh | bash"
              echo ""
              echo "This will:"
              echo "- Install Nix in WSL2"
              echo "- Configure CUDA for RTX 4080"
              echo "- Clone and setup Singularity"
              echo "- Test GPU acceleration"
            ''}";
          };

          # Mac to RTX 4080 deployment
          deploy-to-rtx4080 = {
            type = "app";
            program = "${pkgs.writeScript "deploy-to-rtx4080" ''
              #!${pkgs.bash}/bin/bash
              echo "🚀 Mac → RTX 4080 Deployment"
              echo "Deploy your Mac development changes to RTX 4080 production"
              echo ""
              echo "Make sure to set these environment variables:"
              echo "export RTX4080_HOST=your-rtx4080-ip"
              echo "export RTX4080_USER=your-username"
              echo ""
              echo "Then run: ./deploy-to-rtx4080.sh"
              echo ""
              echo "This will:"
              echo "- Push changes to git"
              echo "- SSH to RTX 4080 and pull changes"
              echo "- Restart services with GPU acceleration"
              echo "- Provide access URLs"
            ''}";
          };

          # GitHub Actions runner setup
          setup-github-runner = {
            type = "app";
            program = "${pkgs.writeScript "setup-github-runner" ''
              #!${pkgs.bash}/bin/bash
              echo "🤖 GitHub Actions Self-Hosted Runner Setup"
              echo "Turn your RTX 4080 into a GitHub Actions runner"
              echo ""
              echo "📋 Prerequisites:"
              echo "1. GitHub Personal Access Token with 'repo' scope"
              echo "2. Repository admin access"
              echo ""
              echo "🪟 On Windows RTX 4080 machine:"
              echo ""
              echo "# Download and run setup script:"
              echo "curl -fsSL https://raw.githubusercontent.com/mikkihugo/singularity-incubation/main/setup-github-runner.ps1 -OutFile setup.ps1"
              echo "./setup.ps1 -Token YOUR_GITHUB_TOKEN"
              echo ""
              echo "This will:"
              echo "- Download GitHub Actions runner"
              echo "- Configure for RTX 4080 with GPU labels"
              echo "- Install as Windows service"
              echo "- Auto-start on boot"
              echo ""
              echo "✅ Benefits:"
              echo "- Automatic GPU testing on every push"
              echo "- No manual deployment needed"
              echo "- Trigger workflows from your Mac"
              echo "- Enterprise CI/CD on your hardware"
            ''}";
          };

          # Podman setup for containerization
          setup-podman = {
            type = "app";
            program = "${pkgs.writeScript "setup-podman" ''
              #!${pkgs.bash}/bin/bash
              echo "🐳 Podman Setup for RTX 4080"
              echo "Add container support to your WSL2 setup"
              echo ""
              echo "📋 Why Podman + WSL2:"
              echo "- WSL2: Full GPU acceleration for development"
              echo "- Podman: Containerized deployment & portability"
              echo "- Best of both: GPU dev + container prod"
              echo ""
              echo "🪟 Run in WSL2 on RTX 4080:"
              echo "curl -fsSL https://raw.githubusercontent.com/mikkihugo/singularity-incubation/main/add-podman-to-wsl2.sh | bash"
              echo ""
              echo "This will:"
              echo "- Install Podman in WSL2"
              echo "- Configure rootless operation"
              echo "- Build Singularity container"
              echo "- Test GPU support (limited in WSL2)"
              echo ""
              echo "🚀 Usage:"
              echo "# Development (GPU accelerated)"
              echo "nix develop .#prod"
              echo ""
              echo "# Production (containerized)"
              echo "podman run -p 4000:4000 localhost/singularity:latest"
              echo ""
              echo "# Build & deploy"
              echo "nix build .#dockerImage && podman load < result"
            ''}";
          };

          # Docker deployment commands
          docker-build = {
            type = "app";
            program = "${pkgs.writeScript "docker-build" ''
              #!${pkgs.bash}/bin/bash
              echo "🏗️  Building Singularity Docker image..."
              nix build .#dockerImage
              echo "📦 Loading image into Docker..."
              docker load < result
              echo "✅ Docker image ready: singularity-prod:latest"
              echo ""
              echo "🚀 Run with: docker run -p 4000:4000 -p 3000:3000 singularity-prod:latest"
            ''}";
          };

          # Kubernetes deployment
          k8s-deploy = {
            type = "app";
            program = "${pkgs.writeScript "k8s-deploy" ''
              #!${pkgs.bash}/bin/bash
              echo "☸️  Deploying Singularity to Kubernetes..."
              nix build .#dockerImage
              docker load < result
              echo "📦 Pushing to registry..."
              docker tag singularity-prod:latest your-registry/singularity:latest
              docker push your-registry/singularity:latest
              echo "✅ Ready for Kubernetes deployment"
              echo ""
              echo "📋 Apply manifests:"
              echo "   kubectl apply -f k8s/"
            ''}";
          };

          # Ubuntu version recommendations
          ubuntu-version = {
            type = "app";
            program = "${pkgs.writeScript "ubuntu-version" ''
              #!${pkgs.bash}/bin/bash
              echo "🐧 Ubuntu Version Recommendations for Singularity"
              echo "Current date: $(date)"
              echo ""
              echo "📅 Ubuntu LTS Release Schedule:"
              echo "• Ubuntu 20.04 LTS (Focal) - April 2020 → April 2025 (EOL)"
              echo "• Ubuntu 22.04 LTS (Jammy) - April 2022 → April 2027"
              echo "• Ubuntu 24.04 LTS (Noble) - April 2024 → April 2029 ⭐ RECOMMENDED"
              echo ""
              echo "🎯 For RTX 4080 WSL2 Setup:"
              echo "Use: Ubuntu-24.04 (latest LTS as of October 2025)"
              echo ""
              echo "🪟 Windows WSL2 Installation:"
              echo "wsl --install -d Ubuntu-24.04"
              echo ""
              echo "✅ Benefits of Ubuntu 24.04:"
              echo "• Latest LTS with long-term support until 2029"
              echo "• Updated CUDA compatibility"
              echo "• Latest security patches"
              echo "• Better NVIDIA driver support"
              echo ""
              echo "🔄 If you have older Ubuntu versions:"
              echo "• Consider upgrading: wsl --update && wsl --shutdown"
              echo "• Or reinstall: wsl --unregister Ubuntu && wsl --install -d Ubuntu-24.04"
            ''}";
          };

          # AI Server app - reference the package we just defined
          ai-server = {
            type = "app";
            program = let
              aiServerPkg = pkgs.stdenv.mkDerivation {
                pname = "ai-server";
                version = "1.0.0";
                src = ./ai-server;
                buildInputs = [pkgs.bun];
                installPhase = ''
                  mkdir -p $out/bin $out/ai-server
                  cp -r . $out/ai-server/
                  cat > $out/bin/ai-server <<EOF
                  #!${pkgs.bash}/bin/bash
                  set -euo pipefail
                  STATE_DIR="\''${STATE_DIR:-/var/lib/singularity}"
                  AI_DIR="\$STATE_DIR/ai-server"
                  BUN_CACHE="\$STATE_DIR/.bun-cache"
                  mkdir -p "\$STATE_DIR" "\$AI_DIR" "\$BUN_CACHE"
                  cp -R $out/ai-server/. "\$AI_DIR/"
                  cd "\$AI_DIR"
                  if [ ! -d node_modules ]; then
                    ${pkgs.bun}/bin/bun install --frozen-lockfile || ${pkgs.bun}/bin/bun install
                  fi
                  exec ${pkgs.bun}/bin/bun run start
                  EOF
                  chmod +x $out/bin/ai-server
                '';
              };
            in "${aiServerPkg}/bin/ai-server";
          };
        };
      });
}
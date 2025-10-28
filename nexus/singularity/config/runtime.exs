import Config

port =
  System.get_env("PORT", "4000")
  |> String.to_integer()

mix_env = System.get_env("MIX_ENV") || Atom.to_string(config_env())

server_enabled? =
  case System.get_env("HTTP_SERVER_ENABLED") do
    nil -> Application.get_env(:singularity, :http_server_enabled, false)
    value -> value == "true"
  end

config :singularity, :http_server,
  enabled: server_enabled?,
  port: port,
  acceptors: String.to_integer(System.get_env("HTTP_ACCEPTORS", "16"))

# Note: Singularity is a pure Elixir application with no web endpoint
# Web interfaces are provided by Observer (port 4002)

# Google Chat webhook for human interface
config :singularity,
  google_chat_webhook_url: System.get_env("GOOGLE_CHAT_WEBHOOK_URL"),
  web_url: System.get_env("WEB_URL", "http://localhost:#{port}")

defmodule Singularity.RuntimeConfig do
  @moduledoc false

  def libcluster_topologies do
    base = [
      strategy: Cluster.Strategy.DNSPoll,
      config: [
        service: System.get_env("DNS_CLUSTER_QUERY", default_service()),
        polling_interval: String.to_integer(System.get_env("CLUSTER_POLL_INTERVAL", "5000")),
        node_basename: System.get_env("CLUSTER_NODE_BASENAME", "seed-agent")
      ]
    ]

    hosts = System.get_env("CLUSTER_STATIC_HOSTS")

    static =
      case hosts do
        nil -> []
        hosts -> String.split(hosts, ",", trim: true)
      end

    static_topology =
      if static == [] do
        []
      else
        [
          static: [
            strategy: Cluster.Strategy.Gossip,
            config: [hosts: static]
          ]
        ]
      end

    topologies =
      [fly: base] ++ static_topology

    config :libcluster, topologies: topologies
  end

  defp default_service do
    case System.get_env("FLY_APP_NAME") do
      nil -> System.get_env("DNS_CLUSTER_QUERY_DEFAULT", "seed-agent-internal.local")
      app -> "#{app}.internal"
    end
  end
end

case mix_env do
  "prod" -> Singularity.RuntimeConfig.libcluster_topologies()
  _ -> config :libcluster, topologies: []
end

if mix_env == "prod" do
  secret = System.get_env("RELEASE_COOKIE") || raise "Missing RELEASE_COOKIE"
  config :kernel, :repl_history_size, 0
  config :singularity, :release_cookie, secret
end

# GPU-accelerated ML/AI configuration
if config_env() != :test do
  # Platform detection for XLA configuration
  # Development: Metal (macOS laptops) | Production: CUDA (RTX 4080)
  # Priority: 1) Explicit XLA_TARGET env var, 2) Auto-detect environment, 3) CPU fallback
  platform =
    case System.get_env("XLA_TARGET") do
      nil ->
        # Auto-detect based on environment
        cond do
          # Production: RTX 4080 machine with CUDA
          System.find_executable("nvidia-smi") ->
            :cuda

          # Development: macOS laptops with Metal
          match?({:unix, :darwin}, :os.type()) ->
            :metal

          # Fallback: CPU
          true ->
            :cpu
        end

      # Any explicit CUDA variant → CUDA (production)
      "cuda" <> _ ->
        :cuda

      # Metal: Development on macOS laptops
      "metal" ->
        :metal

      "cpu" ->
        :cpu

      _ ->
        :cpu
    end

  # Try to configure EXLA if available (optional)
  exla_available? = Code.ensure_loaded?(EXLA)

  if exla_available? do
    config :nx, :default_backend, EXLA.Backend

    config :exla,
      default_client:
        (case platform do
           # Production: RTX 4080 with CUDA
           :cuda -> :cuda
           # Development: macOS laptops with Metal (EXLA uses CPU, Metal for other frameworks)
           :metal -> :host
           # CPU fallback
           :cpu -> :host
         end),
      clients: [
        # RTX 4080 16GB (Linux/production) - allocate 75% for models (12GB), leave 4GB for system
        cuda: [platform: :cuda, memory_fraction: 0.75],
        # macOS CPU or CPU-only on unsupported platforms (includes Metal capable Macs)
        host: [platform: :host]
      ]

    # Configure Bumblebee with EXLA if available
    bumblebee_client =
      case platform do
        # Production: RTX 4080 with CUDA
        :cuda -> :cuda
        # Development: macOS laptops with Metal (Bumblebee uses CPU, Metal via CoreML/MLX)
        :metal -> :host
        # CPU fallback
        :cpu -> :host
      end

    config :bumblebee,
      # Cache models in ~/.cache/huggingface
      offline: false,
      # Use EXLA backend with appropriate client
      default_backend: {EXLA.Backend, client: bumblebee_client}
  else
    # EXLA not available - use native NX backends (CPU)
    config :bumblebee,
      offline: false,
      # Fall back to native Nx implementation (CPU-based)
      default_backend: :native
  end
end

# Embedding service configuration (Pure Elixir Nx/Axon)
# Pure local tensor operations, no external inference APIs, works offline
config :singularity,
  # Embedding models: Pure Elixir Nx implementation
  # Downloads safetensors/ONNX weights from HuggingFace and runs inference locally
  #
  # Models:
  # - Qodo-Embed-1: 1536 dims, code-specialized, safetensors format
  # - Jina v3: 1024 dims, general-purpose text, ONNX format
  # - Concatenated: 2560 dims = Qodo (1536) + Jina (1024)
  #
  # Benefits:
  # ✅ Works offline (weights cached locally after download)
  # ✅ No API keys needed
  # ✅ No rate limits or quotas
  # ✅ Deterministic (same input = same embedding always)
  # ✅ GPU support via EXLA backend (CUDA/Metal)
  # ✅ Pure Elixir, no Rust dependencies for inference
  #
  # Implementation: Singularity.Embedding.NxService
  # - Loads safetensors weights via Singularity.Embedding.ModelLoader
  # - Builds Axon models via Singularity.Embedding.Model
  # - Inference via Nx tensor operations (EXLA-accelerated if available)

  # Code generation model configuration
  code_generation: [
    # 770M params, ~1.5GB, fast training, good quality
    model: "Salesforce/codet5p-770m",
    # Alternative models:
    # "bigcode/starcoder2-7b" - 7B params, ~14GB, best quality but slow training
    # "bigcode/starcoder2-3b" - 3B params, ~6GB, balanced
    # "deepseek-ai/deepseek-coder-1.3b-base" - 1.3B params, faster
    max_tokens: 256,
    # Lower = fewer errors, more deterministic
    temperature: 0.2
  ]

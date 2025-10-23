import Config

port =
  System.get_env("PORT", "8080")
  |> String.to_integer()

mix_env = System.get_env("MIX_ENV") || Atom.to_string(config_env())

server_enabled? =
  case System.get_env("HTTP_SERVER_ENABLED") do
    nil -> Application.get_env(:singularity, :http_server_enabled, false)
    value -> value == "true"
  end

config :singularity, SingularityWeb.Endpoint,
  server: server_enabled?,
  http: [port: port, transport_options: [num_acceptors: 10]]

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
  # Detects CUDA availability first, then Metal (macOS), then falls back to CPU
  # Priority: 1) Explicit XLA_TARGET env var, 2) nvidia-smi (CUDA), 3) Metal (macOS), 4) CPU
  # Note: Metal NOT supported by EXLA itself, but XLA_TARGET=metal allows other frameworks
  #       (CoreML, MLX, etc) to use Metal GPU while EXLA stays on CPU
  platform =
    case System.get_env("XLA_TARGET") do
      nil ->
        # Auto-detect based on available GPU
        if System.find_executable("nvidia-smi") do
          # CUDA available (RTX 4080 on Linux, or any NVIDIA GPU)
          :linux
        else
          case :os.type() do
            # macOS with Metal GPU (other frameworks can use it)
            {:unix, :darwin} -> :metal
            # Linux without CUDA (CPU fallback)
            _ -> :linux
          end
        end

      # Any explicit CUDA variant → use CUDA
      "cuda" <> _ ->
        :linux

      # Metal: CPU for EXLA, Metal available for CoreML/MLX
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
           # RTX 4080 with CUDA
           :linux -> :cuda
           # macOS with Metal: EXLA uses CPU, Metal available for other frameworks
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
        # CUDA for Linux
        :linux -> :cuda
        # macOS with Metal: Bumblebee uses CPU, Metal available via CoreML/MLX
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

# Embedding service configuration (Inference - ONNX Runtime)
# Pure local ONNX inference, no API calls, works offline
config :singularity,
  # Embedding strategy: Pure local ONNX via Rust NIF
  # - GPU available (CUDA/Metal/ROCm): Qodo-Embed-1 (1536D) - code-specialized, ~15ms
  # - CPU only: MiniLM-L6-v2 (384D) - lightweight but excellent, ~40ms
  #
  # Benefits:
  # ✅ Works offline (no internet required)
  # ✅ No API keys needed
  # ✅ No rate limits or quotas
  # ✅ Deterministic (same input = same embedding always)
  # ✅ GPU-accelerated on available hardware (CUDA/Metal/ROCm)
  # ✅ Auto device detection
  embedding_provider: :rustler,

  # Rust NIF embedding models (GPU-accelerated ONNX inference)
  # - Jina v3: 1024 dims, general text (8192 tokens) - ONNX Runtime
  # - Qodo-Embed-1: 1536 dims, code-specialized (32k tokens) - Candle backend
  # - MiniLM-L6-v2: 384D dims, lightweight CPU model - ONNX Runtime
  #
  # Device detection is automatic:
  # - CUDA_VISIBLE_DEVICES set → Use GPU model
  # - No GPU → Fall back to MiniLM
  rustler_models: [
    jina_v3: "jina-embeddings-v3",
    qodo_embed: "qodo-embed-1-1.5b",
    minilm: "sentence-transformers/all-MiniLM-L6-v2"
  ],

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

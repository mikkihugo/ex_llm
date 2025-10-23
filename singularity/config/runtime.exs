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
  # Detect platform for appropriate configuration
  platform =
    case System.get_env("XLA_TARGET") do
      nil ->
        # Auto-detect based on platform
        case :os.type() do
          {:unix, :darwin} -> :macos   # macOS (CPU fallback, no Metal XLA binaries)
          _ -> :linux                  # Linux (CUDA for RTX 4080)
        end
      "cuda" -> :linux
      "metal" -> :macos
      "cpu" -> :cpu
      _ -> :cpu
    end

  # Try to configure EXLA if available (optional)
  exla_available? = Code.ensure_loaded?(EXLA)

  if exla_available? do
    config :nx, :default_backend, EXLA.Backend

    config :exla,
      default_client: (
        case platform do
          :linux -> :cuda   # RTX 4080 with CUDA
          :macos -> :host   # macOS CPU (no Metal XLA binaries available)
          :cpu -> :host     # CPU fallback
        end
      ),
      clients: [
        # RTX 4080 16GB (Linux/production) - allocate 75% for models (12GB), leave 4GB for system
        cuda: [platform: :cuda, memory_fraction: 0.75],
        # macOS CPU or CPU-only on unsupported platforms
        host: [platform: :host]
      ]

    # Configure Bumblebee with EXLA if available
    bumblebee_client =
      case platform do
        :linux -> :cuda   # CUDA for Linux
        :macos -> :host   # CPU for macOS
        :cpu -> :host     # CPU fallback
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

# Embedding service configuration
config :singularity,
  # Embedding provider: :rustler for GPU-accelerated Rust NIF embeddings
  # Jina v3 + Qodo-Embed-1 with CUDA acceleration on RTX 4080
  # - 1024 dims (Jina v3) / 1536 dims (Qodo-Embed)
  # - GPU-accelerated with ONNX Runtime + Candle
  # - No rate limits, no API costs, full privacy
  embedding_provider: :rustler,

  # Rust NIF embedding models (RTX 4080 GPU with CUDA)
  # - Jina v3: 1024 dims, text/docs (8192 tokens)
  # - Qodo-Embed-1: 1536 dims, code (32k tokens) - SOTA 2025
  rustler_models: [
    jina_v3: "jina-embeddings-v3",
    qodo_embed: "qodo-embed-1-1.5b"
  ],

  # Google AI API key (optional - not used for embeddings anymore)
  google_ai_api_key: System.get_env("GOOGLE_AI_STUDIO_API_KEY"),

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

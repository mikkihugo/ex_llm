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
  # Use EXLA backend with CUDA (RTX 4080)
  config :nx, :default_backend, EXLA.Backend

  config :exla,
    # Use GPU 0 (your RTX 4080 - 16GB VRAM)
    default_client: :cuda,
    clients: [
      # RTX 4080 16GB - allocate 75% for models (12GB), leave 4GB for system
      cuda: [platform: :cuda, memory_fraction: 0.75],
      host: [platform: :host]  # CPU fallback if CUDA unavailable
    ]

  # Configure Bumblebee
  config :bumblebee,
    # Cache models in ~/.cache/huggingface
    offline: false,
    # RTX 4080 16GB - use GPU acceleration
    default_backend: {EXLA.Backend, client: :cuda}
end

# Embedding service configuration
config :singularity,
  # Embedding provider: :bumblebee for local GPU-accelerated code embeddings
  # Jina-embeddings-v2-base-code is BEST for code (beats Google/Salesforce/Microsoft)
  embedding_provider: :bumblebee,  # Local Jina only - no external API calls!

  # Bumblebee embedding model (runs on RTX 4080 GPU with EXLA)
  # - 768 dims (matches all DB tables)
  # - Trained on 150M coding Q&A pairs
  # - Supports 30 programming languages
  # - 8192 token context (handles entire functions)
  # - No rate limits, no API costs, full privacy
  bumblebee_model: "jina-embeddings-v2-base-code",  # 161M params, 768 dims, code-optimized

  # Google AI API key (optional - not used for embeddings anymore)
  google_ai_api_key: System.get_env("GOOGLE_AI_STUDIO_API_KEY"),

  # Code generation model configuration
  code_generation: [
    model: "bigcode/starcoder2-7b",  # 7B params, ~14GB, best quality
    # Alternative models:
    # "deepseek-ai/deepseek-coder-1.3b-base" - 1.3B params, faster
    # "bigcode/starcoder2-3b" - 3B params, balanced
    max_tokens: 256,
    temperature: 0.2  # Lower = fewer errors, more deterministic
  ]

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

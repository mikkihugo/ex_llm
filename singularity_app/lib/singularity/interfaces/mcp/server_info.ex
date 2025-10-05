defmodule Singularity.MCP.ServerInfo do
  @moduledoc """
  MCP Server information and metadata.

  Tracks information about registered MCP servers in the federation.
  """

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    base_url: String.t(),
    protocol: :mcp | :http | :grpc | :stdio | :internal,
    domains: [String.t()],
    tools: [String.t()],
    health_status: :healthy | :degraded | :down,
    last_health_check: integer(),
    cache_hit_rate: float(),
    avg_response_time: integer(),
    mcp_version: String.t() | nil,
    capabilities: [String.t()] | nil,
    connection_type: :websocket | :stdio | :http | :internal
  }

  defstruct [
    :id,
    :name,
    :base_url,
    :protocol,
    :domains,
    :tools,
    :health_status,
    :last_health_check,
    :cache_hit_rate,
    :avg_response_time,
    :mcp_version,
    :capabilities,
    :connection_type
  ]

  @doc """
  Create a new ServerInfo struct.

  ## Examples

      ServerInfo.new(
        id: "elixir-tools",
        name: "Singularity Elixir Tools",
        base_url: "stdio://elixir",
        protocol: :stdio,
        domains: ["elixir", "code", "git"],
        tools: ["search_code", "git_commit"],
        connection_type: :stdio
      )
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
    |> set_defaults()
  end

  defp set_defaults(info) do
    %{info |
      health_status: info.health_status || :healthy,
      last_health_check: info.last_health_check || System.system_time(:second),
      cache_hit_rate: info.cache_hit_rate || 0.0,
      avg_response_time: info.avg_response_time || 0,
      mcp_version: info.mcp_version || "2024-11-05",
      capabilities: info.capabilities || [],
      domains: info.domains || [],
      tools: info.tools || []
    }
  end
end

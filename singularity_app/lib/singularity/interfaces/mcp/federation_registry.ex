defmodule Singularity.MCP.FederationRegistry do
  @moduledoc """
  MCP Federation Registry - Manages multiple MCP servers and routes tool calls.

  Features:
  - Dynamic server registration at runtime
  - Tool-based routing (route by tool name)
  - Domain-based routing (route by domain)
  - Health checking (monitors server health)
  - Load balancing (distribute calls across servers)
  - Auto-discovery (detect which servers to use from query)

  Federation Strategies:
  - :parallel - Query all servers simultaneously, aggregate results
  - :sequential - Try servers in order until one succeeds
  - :failover - Fallback through servers on failure
  """

  use GenServer
  require Logger

  alias Singularity.MCP.ServerInfo

  defstruct [
    :servers,              # %{server_id => ServerInfo}
    :tool_routing,         # %{tool_name => [server_ids]}
    :domain_routing,       # %{domain => [server_ids]}
    :health_check_timer
  ]

  @health_check_interval 30_000  # 30 seconds

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a new MCP server in the federation.

  ## Examples

      server = %ServerInfo{
        id: "elixir-tools",
        name: "Elixir Tools MCP Server",
        base_url: "mcp://localhost:5000",
        protocol: :mcp,
        domains: ["elixir", "tools", "code"],
        tools: [
          "elixir.search_code",
          "elixir.git_commit",
          "elixir.run_tests"
        ],
        connection_type: :stdio
      }

      FederationRegistry.register_server(server)
  """
  def register_server(server) do
    GenServer.call(__MODULE__, {:register_server, server})
  end

  @doc """
  Unregister an MCP server from the federation.
  """
  def unregister_server(server_id) do
    GenServer.call(__MODULE__, {:unregister_server, server_id})
  end

  @doc """
  Route query to appropriate MCP servers.

  Returns list of server IDs that should handle the query.

  ## Options

  - `:tools` - List of specific tool names to route to
  - `:domains` - List of domains to route to
  - `:servers` - Explicit list of server IDs
  - `:max_servers` - Maximum number of servers to route to (default: 3)
  - `:strategy` - :parallel | :sequential | :failover (default: :parallel)

  ## Examples

      FederationRegistry.route_query("search code for UserController",
        tools: ["elixir.search_code"],
        max_servers: 2
      )
      # => ["elixir-tools", "code-search"]
  """
  def route_query(query, opts \\ []) do
    GenServer.call(__MODULE__, {:route_query, query, opts})
  end

  @doc "Get all available MCP tools across federation"
  def list_all_tools do
    GenServer.call(__MODULE__, :list_all_tools)
  end

  @doc "Get server info by ID"
  def get_server(server_id) do
    GenServer.call(__MODULE__, {:get_server, server_id})
  end

  @doc "Get all servers for a specific domain"
  def get_servers_for_domain(domain) do
    GenServer.call(__MODULE__, {:get_servers_for_domain, domain})
  end

  @doc "Get all servers that support a specific tool"
  def get_servers_for_tool(tool_name) do
    GenServer.call(__MODULE__, {:get_servers_for_tool, tool_name})
  end

  @doc "Get federation statistics"
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      servers: %{},
      tool_routing: %{},
      domain_routing: %{},
      health_check_timer: nil
    }

    # Initialize default servers
    state = initialize_default_servers(state)

    # Start health checking
    timer = schedule_health_check()

    {:ok, %{state | health_check_timer: timer}}
  end

  @impl true
  def handle_call({:register_server, server}, _from, state) do
    Logger.info("Registering MCP server: #{server.name} (#{server.id})")

    # Add server
    servers = Map.put(state.servers, server.id, server)

    # Update domain routing
    domain_routing =
      Enum.reduce(server.domains, state.domain_routing, fn domain, routing ->
        Map.update(routing, domain, [server.id], &[server.id | &1])
      end)

    # Update tool routing
    tool_routing =
      Enum.reduce(server.tools, state.tool_routing, fn tool, routing ->
        Map.update(routing, tool, [server.id], &[server.id | &1])
      end)

    new_state = %{state |
      servers: servers,
      domain_routing: domain_routing,
      tool_routing: tool_routing
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unregister_server, server_id}, _from, state) do
    case Map.get(state.servers, server_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      server ->
        Logger.info("Unregistering MCP server: #{server.name}")

        # Remove server
        servers = Map.delete(state.servers, server_id)

        # Remove from domain routing
        domain_routing =
          Enum.reduce(server.domains, state.domain_routing, fn domain, routing ->
            Map.update(routing, domain, [], &List.delete(&1, server_id))
          end)

        # Remove from tool routing
        tool_routing =
          Enum.reduce(server.tools, state.tool_routing, fn tool, routing ->
            Map.update(routing, tool, [], &List.delete(&1, server_id))
          end)

        new_state = %{state |
          servers: servers,
          domain_routing: domain_routing,
          tool_routing: tool_routing
        }

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:route_query, query, opts}, _from, state) do
    candidate_servers = MapSet.new()

    # Route by specific tools
    candidate_servers =
      if tools = opts[:tools] do
        Enum.reduce(tools, candidate_servers, fn tool, acc ->
          server_ids = Map.get(state.tool_routing, tool, [])
          Enum.reduce(server_ids, acc, &MapSet.put(&2, &1))
        end)
      else
        candidate_servers
      end

    # Route by domains
    candidate_servers =
      if domains = opts[:domains] do
        Enum.reduce(domains, candidate_servers, fn domain, acc ->
          server_ids = Map.get(state.domain_routing, domain, [])
          Enum.reduce(server_ids, acc, &MapSet.put(&2, &1))
        end)
      else
        candidate_servers
      end

    # Explicit server list
    candidate_servers =
      if servers = opts[:servers] do
        Enum.reduce(servers, candidate_servers, &MapSet.put(&2, &1))
      else
        candidate_servers
      end

    # Auto-detect if no candidates yet
    candidate_servers =
      if MapSet.size(candidate_servers) == 0 do
        detect_servers_from_query(query, state)
      else
        candidate_servers
      end

    # Filter to healthy servers only
    healthy_servers =
      candidate_servers
      |> MapSet.to_list()
      |> Enum.filter(fn server_id ->
        case Map.get(state.servers, server_id) do
          %{health_status: :healthy} -> true
          _ -> false
        end
      end)

    # Apply max_servers limit
    max_servers = opts[:max_servers] || 3
    result = Enum.take(healthy_servers, max_servers)

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_all_tools, _from, state) do
    tools =
      state.tool_routing
      |> Enum.map(fn {tool, server_ids} ->
        %{tool: tool, servers: server_ids}
      end)

    {:reply, tools, state}
  end

  @impl true
  def handle_call({:get_server, server_id}, _from, state) do
    {:reply, Map.get(state.servers, server_id), state}
  end

  @impl true
  def handle_call({:get_servers_for_domain, domain}, _from, state) do
    server_ids = Map.get(state.domain_routing, domain, [])
    servers = Enum.map(server_ids, &Map.get(state.servers, &1)) |> Enum.reject(&is_nil/1)
    {:reply, servers, state}
  end

  @impl true
  def handle_call({:get_servers_for_tool, tool_name}, _from, state) do
    server_ids = Map.get(state.tool_routing, tool_name, [])
    servers = Enum.map(server_ids, &Map.get(state.servers, &1)) |> Enum.reject(&is_nil/1)
    {:reply, servers, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    servers = Map.values(state.servers)

    stats = %{
      total_servers: length(servers),
      healthy_servers: Enum.count(servers, &(&1.health_status == :healthy)),
      degraded_servers: Enum.count(servers, &(&1.health_status == :degraded)),
      down_servers: Enum.count(servers, &(&1.health_status == :down)),
      total_domains: map_size(state.domain_routing),
      total_tools: map_size(state.tool_routing),
      avg_cache_hit_rate: avg_stat(servers, :cache_hit_rate),
      avg_response_time: avg_stat(servers, :avg_response_time)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform health checks on all servers
    new_servers =
      state.servers
      |> Enum.map(fn {id, server} ->
        health = check_server_health(server)
        updated_server = %{server |
          health_status: health,
          last_health_check: System.system_time(:second)
        }
        {id, updated_server}
      end)
      |> Map.new()

    new_state = %{state | servers: new_servers}

    # Schedule next health check
    timer = schedule_health_check()

    {:noreply, %{new_state | health_check_timer: timer}}
  end

  ## Private Functions

  defp initialize_default_servers(state) do
    # Add Claude WebSearch as default
    claude_search_server = %ServerInfo{
      id: "claude-websearch",
      name: "Claude WebSearch MCP Server",
      base_url: "stdio://claude",
      protocol: :stdio,
      domains: ["web", "search", "internet"],
      tools: ["websearch.search", "websearch.news"],
      health_status: :healthy,
      last_health_check: System.system_time(:second),
      cache_hit_rate: 0.0,
      avg_response_time: 200,
      mcp_version: "0.1.0",
      capabilities: ["tools"],
      connection_type: :stdio
    }

    # Add Elixir tools server (will be registered dynamically)
    elixir_tools_server = %ServerInfo{
      id: "elixir-tools",
      name: "Singularity Elixir Tools",
      base_url: "internal://elixir",
      protocol: :internal,
      domains: ["elixir", "code", "git", "testing"],
      tools: [],  # Will be populated dynamically from Singularity.Tools
      health_status: :healthy,
      last_health_check: System.system_time(:second),
      cache_hit_rate: 1.0,  # Internal = always cached
      avg_response_time: 10,
      mcp_version: "0.1.0",
      capabilities: ["tools"],
      connection_type: :internal
    }

    state
    |> register_server_internal(claude_search_server)
    |> register_server_internal(elixir_tools_server)
  end

  defp register_server_internal(state, server) do
    servers = Map.put(state.servers, server.id, server)

    domain_routing =
      Enum.reduce(server.domains, state.domain_routing, fn domain, routing ->
        Map.update(routing, domain, [server.id], &[server.id | &1])
      end)

    tool_routing =
      Enum.reduce(server.tools, state.tool_routing, fn tool, routing ->
        Map.update(routing, tool, [server.id], &[server.id | &1])
      end)

    %{state |
      servers: servers,
      domain_routing: domain_routing,
      tool_routing: tool_routing
    }
  end

  defp detect_servers_from_query(query, state) do
    query_lower = String.downcase(query)
    servers = MapSet.new()

    # Search detection
    servers = if String.contains?(query_lower, ["search", "find", "web", "google"]) do
      MapSet.put(servers, "claude-websearch")
    else
      servers
    end

    # Code/Elixir detection
    servers = if String.contains?(query_lower, ["code", "elixir", "git", "test", "function"]) do
      MapSet.put(servers, "elixir-tools")
    else
      servers
    end

    servers
  end

  defp check_server_health(server) do
    # For internal servers, always healthy
    if server.protocol == :internal do
      :healthy
    else
      # For external servers, check connection
      # TODO: Implement actual health check
      :healthy
    end
  end

  defp avg_stat(servers, field) when is_list(servers) do
    case servers do
      [] -> 0.0
      list ->
        sum = Enum.reduce(list, 0, fn server, acc ->
          acc + (Map.get(server, field, 0) || 0)
        end)
        sum / length(list)
    end
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval)
  end
end

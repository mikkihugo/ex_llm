defmodule Singularity.MCP.ElixirToolsServer do
  @moduledoc """
  MCP Server that exposes Singularity Elixir tools to LLM clients.

  Clients (Claude, Cursor, Codex, etc.) connect via MCP protocol and can:
  - Discover available tools dynamically
  - Call tools with arguments
  - Get results back

  Client Identification:
  During MCP initialize, clients send clientInfo with name/version:
  - Claude: {name: "claude", version: "..."}
  - Cursor: {name: "cursor-agent", version: "..."}
  - Codex: {name: "codex", version: "..."}

  We track which client is calling so we can provide client-specific behavior.
  """

  use Hermes.Server,
    name: "singularity-elixir-tools",
    version: "1.0.0",
    protocol_version: "2024-11-05"

  require Logger
  alias Singularity.Tools.{Tool, Runner}
  alias Singularity.Autonomy.Correlation

  # State tracks active client sessions
  defstruct [
    :client_sessions,  # %{session_id => %{client_name, client_version, connected_at}}
    :tool_registry    # Dynamically loaded tools from Singularity.Tools
  ]

  @impl true
  def init(_transport, opts) do
    Logger.info("MCP ElixirTools Server initializing")

    state = %__MODULE__{
      client_sessions: %{},
      tool_registry: load_available_tools()
    }

    # Register all tools with Hermes
    Enum.each(state.tool_registry, fn {tool_name, tool} ->
      register_tool_with_hermes(tool_name, tool)
    end)

    {:ok, state}
  end

  @impl true
  def handle_initialize(params, state) do
    # Extract client info from MCP initialize request
    client_info = params["clientInfo"] || %{}
    client_name = client_info["name"] || "unknown"
    client_version = client_info["version"] || "unknown"

    # Generate session ID for this client
    session_id = generate_session_id()

    Logger.info("MCP client connected",
      client: client_name,
      version: client_version,
      session_id: session_id
    )

    # Track client session
    session_data = %{
      client_name: client_name,
      client_version: client_version,
      connected_at: DateTime.utc_now(),
      session_id: session_id
    }

    new_state = %{state |
      client_sessions: Map.put(state.client_sessions, session_id, session_data)
    }

    # Return server capabilities
    capabilities = %{
      tools: %{listChanged: true},
      resources: %{},
      prompts: %{}
    }

    {:ok, capabilities, put_session_id(new_state, session_id)}
  end

  @impl true
  def handle_tool(tool_name, arguments, state) do
    # Get current client from state
    session_id = get_session_id(state)
    client_session = Map.get(state.client_sessions, session_id, %{})
    client_name = client_session[:client_name] || "unknown"

    Logger.info("MCP tool call",
      tool: tool_name,
      client: client_name,
      session_id: session_id
    )

    # Get tool from registry
    case Map.get(state.tool_registry, tool_name) do
      nil ->
        {:error, "Tool '#{tool_name}' not found", state}

      tool ->
        # Create correlation context with client info
        correlation_id = Correlation.start("mcp_tool_call")
        Logger.metadata(
          correlation_id: correlation_id,
          mcp_client: client_name,
          mcp_tool: tool_name
        )

        # Build context with client information
        context = %{
          correlation_id: correlation_id,
          mcp_client: client_name,
          mcp_session_id: session_id,
          called_at: DateTime.utc_now()
        }

        # Store MCP client info in process dictionary
        # This flows through to LLM.Provider when tools call LLMs
        Process.put(:mcp_client, client_name)
        Process.put(:mcp_session_id, session_id)

        # Execute tool
        case Tool.execute(tool, arguments, context) do
          {:ok, content} ->
            Logger.info("MCP tool succeeded",
              tool: tool_name,
              client: client_name,
              correlation_id: correlation_id
            )

            result = %{
              content: [%{type: "text", text: content}],
              isError: false
            }

            {:ok, result, state}

          {:error, reason} ->
            Logger.error("MCP tool failed",
              tool: tool_name,
              client: client_name,
              reason: reason,
              correlation_id: correlation_id
            )

            error_result = %{
              content: [%{type: "text", text: "Error: #{reason}"}],
              isError: true
            }

            {:ok, error_result, state}
        end
    end
  end

  @impl true
  def handle_list_tools(_params, state) do
    # Return list of available tools
    tools = Enum.map(state.tool_registry, fn {tool_name, tool} ->
      %{
        name: tool_name,
        description: tool.description || "No description",
        inputSchema: tool.parameters_schema || %{
          type: "object",
          properties: %{},
          required: []
        }
      }
    end)

    {:ok, tools, state}
  end

  ## Private Functions

  defp load_available_tools do
    # TODO: Load from Singularity.Tools.Registry
    # For now, return example tools
    %{
      "search_code" => Tool.new!(%{
        name: "search_code",
        description: "Search codebase for patterns",
        parameters_schema: %{
          type: "object",
          properties: %{
            query: %{type: "string", description: "Search query"},
            path: %{type: "string", description: "Path to search in"}
          },
          required: ["query"]
        },
        function: fn args, context ->
          # Placeholder implementation
          {:ok, "Search results for: #{args["query"]}"}
        end
      }),

      "git_commit" => Tool.new!(%{
        name: "git_commit",
        description: "Create a git commit",
        parameters_schema: %{
          type: "object",
          properties: %{
            message: %{type: "string", description: "Commit message"},
            files: %{type: "array", items: %{type: "string"}, description: "Files to commit"}
          },
          required: ["message"]
        },
        function: fn args, context ->
          # Placeholder implementation
          {:ok, "Committed: #{args["message"]}"}
        end
      }),

      "run_tests" => Tool.new!(%{
        name: "run_tests",
        description: "Run Elixir tests",
        parameters_schema: %{
          type: "object",
          properties: %{
            path: %{type: "string", description: "Test file or directory"}
          }
        },
        function: fn args, context ->
          # Placeholder implementation
          path = args["path"] || "all tests"
          {:ok, "Running tests: #{path}"}
        end
      })
    }
  end

  defp register_tool_with_hermes(tool_name, tool) do
    # Convert Tool struct to Hermes tool registration
    input_schema = tool.parameters_schema || %{}

    # Hermes expects schema as keyword list for validation
    schema_props =
      (input_schema["properties"] || %{})
      |> Enum.map(fn {key, prop_schema} ->
        type = String.to_atom(prop_schema["type"] || "string")
        description = prop_schema["description"]
        required = (input_schema["required"] || []) |> Enum.member?(key)

        opts = [description: description]
        opts = if required, do: [{:required, type} | opts], else: [type | opts]

        {String.to_atom(key), List.to_tuple(opts)}
      end)

    register_tool(tool_name,
      input_schema: schema_props,
      description: tool.description || "No description"
    )
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  defp put_session_id(state, session_id) do
    # Store session_id in process dictionary for this connection
    Process.put(:mcp_session_id, session_id)
    state
  end

  defp get_session_id(_state) do
    Process.get(:mcp_session_id, "unknown")
  end
end

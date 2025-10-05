defmodule Singularity.Interfaces.MCP do
  @moduledoc """
  MCP (Model Context Protocol) interface implementation.

  Handles tool execution requests from MCP clients like:
  - Claude Desktop
  - Cursor IDE
  - Continue.dev
  - Any MCP-compatible client

  ## Example

      interface = %Singularity.Interfaces.MCP{
        session_id: "sess_abc123",
        client_info: %{name: "Claude Desktop", version: "1.0"},
        capabilities: [:tools, :resources, :prompts]
      }

      tool_call = %Singularity.Tools.ToolCall{
        name: "sh_run_command",
        arguments: %{"command" => "ls", "args" => ["-la"]}
      }

      {:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)
  """

  alias Singularity.Tools.{Runner, ToolCall}

  @enforce_keys [:session_id]
  defstruct [
    :session_id,
    :client_info,
    :capabilities,
    provider: :mcp,
    streaming: false
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          client_info: map() | nil,
          capabilities: [atom()] | nil,
          provider: atom(),
          streaming: boolean()
        }
end

defimpl Singularity.Interfaces.Protocol, for: Singularity.Interfaces.MCP do
  alias Singularity.Tools.{Runner, ToolCall}

  @doc """
  Execute a tool call via MCP interface.

  Returns MCP-formatted response:
  - Success: `{:ok, %{content: [...], isError: false}}`
  - Error: `{:ok, %{content: [...], isError: true}}`

  Note: Always returns `{:ok, map()}` for MCP compatibility,
  errors are indicated by `isError: true` field.
  """
  def execute_tool(interface, %ToolCall{} = tool_call) do
    context = %{
      interface: :mcp,
      session_id: interface.session_id,
      client_info: interface.client_info
    }

    case Runner.execute(interface.provider, tool_call, context) do
      {:ok, result} ->
        {:ok, format_success(result)}

      {:error, reason} ->
        {:ok, format_error(reason)}
    end
  end

  def metadata(_interface) do
    %{
      name: "MCP",
      version: "2024-11-05",
      protocol: "Model Context Protocol",
      capabilities: [:tools, :resources, :prompts, :sampling]
    }
  end

  def supports_streaming?(_interface), do: false

  # Private helpers

  defp format_success(result) when is_binary(result) do
    %{
      content: [%{type: "text", text: result}],
      isError: false
    }
  end

  defp format_success(result) when is_map(result) do
    %{
      content: [%{type: "text", text: Jason.encode!(result)}],
      isError: false
    }
  end

  defp format_success(result) do
    %{
      content: [%{type: "text", text: inspect(result)}],
      isError: false
    }
  end

  defp format_error(reason) when is_binary(reason) do
    %{
      content: [%{type: "text", text: "Error: #{reason}"}],
      isError: true
    }
  end

  defp format_error(reason) do
    %{
      content: [%{type: "text", text: "Error: #{inspect(reason)}"}],
      isError: true
    }
  end
end

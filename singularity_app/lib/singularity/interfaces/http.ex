defmodule Singularity.Interfaces.HTTP do
  @moduledoc """
  HTTP/REST interface implementation for tool execution.

  Handles tool execution requests via HTTP API:
  - JSON request/response
  - Standard HTTP status codes
  - RESTful conventions

  ## Example

      interface = %Singularity.Interfaces.HTTP{
        request_id: "req_abc123",
        user_id: "user_456",
        api_version: "v1"
      }

      tool_call = %Singularity.Tools.ToolCall{
        name: "web_search",
        arguments: %{"query" => "Elixir protocols"}
      }

      {:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)
  """

  alias Singularity.Tools.{Runner, ToolCall}

  @enforce_keys [:request_id]
  defstruct [
    :request_id,
    :user_id,
    :api_version,
    :headers,
    provider: :http,
    streaming: false
  ]

  @type t :: %__MODULE__{
          request_id: String.t(),
          user_id: String.t() | nil,
          api_version: String.t() | nil,
          headers: map() | nil,
          provider: atom(),
          streaming: boolean()
        }
end

defimpl Singularity.Interfaces.Protocol, for: Singularity.Interfaces.HTTP do
  alias Singularity.Tools.Runner

  @doc """
  Execute a tool call via HTTP interface.

  Returns HTTP-formatted JSON response:
  - Success: `{:ok, %{data: ..., status: 200}}`
  - Error: `{:error, %{error: ..., status: 4xx/5xx}}`
  """
  def execute_tool(interface, %ToolCall{} = tool_call) do
    context = %{
      interface: :http,
      request_id: interface.request_id,
      user_id: interface.user_id,
      api_version: interface.api_version,
      headers: interface.headers
    }

    case Runner.execute(interface.provider, tool_call, context) do
      {:ok, result} ->
        {:ok, format_success(result, interface)}

      {:error, reason} ->
        {:error, format_error(reason, interface)}
    end
  end

  def metadata(_interface) do
    %{
      name: "HTTP",
      version: "1.0.0",
      protocol: "HTTP/REST",
      capabilities: [:json, :streaming, :webhooks]
    }
  end

  def supports_streaming?(_interface), do: true

  # Private helpers

  defp format_success(result, interface) do
    %{
      data: result,
      status: 200,
      request_id: interface.request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp format_error(reason, interface) do
    {status, message} = categorize_error(reason)

    %{
      error: %{
        message: message,
        type: error_type(status)
      },
      status: status,
      request_id: interface.request_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp categorize_error(reason) when is_binary(reason) do
    cond do
      String.contains?(reason, "not found") -> {404, reason}
      String.contains?(reason, "not allowed") -> {403, reason}
      String.contains?(reason, "invalid") -> {400, reason}
      String.contains?(reason, "timeout") -> {504, reason}
      true -> {500, reason}
    end
  end

  defp categorize_error(_reason), do: {500, "Internal server error"}

  defp error_type(status) when status in 400..499, do: "client_error"
  defp error_type(status) when status in 500..599, do: "server_error"
  defp error_type(_), do: "error"
end

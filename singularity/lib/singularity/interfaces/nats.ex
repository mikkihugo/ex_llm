defmodule Singularity.Interfaces.NATS do
  @moduledoc """
  NATS interface implementation for distributed tool execution.

  Handles tool execution requests via NATS messaging:
  - Request/Reply pattern for synchronous calls
  - Pub/Sub for async notifications
  - JetStream for persistence

  ## Example

      interface = %Singularity.Interfaces.NATS{
        reply_to: "responses.abc123",
        subject: "tools.execute.request",
        correlation_id: "req_xyz"
      }

      tool_call = %Singularity.Tools.ToolCall{
        name: "quality_check",
        arguments: %{"file_path" => "lib/my_module.ex"}
      }

      {:ok, result} = Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)
  """

  alias Singularity.Tools.{Runner, ToolCall}

  @enforce_keys [:reply_to]
  defstruct [
    :reply_to,
    :subject,
    :correlation_id,
    :headers,
    provider: :nats,
    streaming: false
  ]

  @type t :: %__MODULE__{
          reply_to: String.t(),
          subject: String.t() | nil,
          correlation_id: String.t() | nil,
          headers: map() | nil,
          provider: atom(),
          streaming: boolean()
        }
end

defimpl Singularity.Interfaces.Protocol, for: Singularity.Interfaces.NATS do
  alias Singularity.Tools.{Runner, ToolCall}

  @doc """
  Execute a tool call via NATS interface.

  Returns NATS-formatted response for message bus:
  - Success: `{:ok, %{result: ..., status: "success"}}`
  - Error: `{:error, %{error: ..., status: "error"}}`
  """
  def execute_tool(interface, %ToolCall{} = tool_call) do
    context = %{
      interface: :nats,
      reply_to: interface.reply_to,
      subject: interface.subject,
      correlation_id: interface.correlation_id,
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
      name: "NATS",
      version: "1.0.0",
      protocol: "NATS Messaging",
      capabilities: [:request_reply, :pub_sub, :jetstream]
    }
  end

  def supports_streaming?(_interface), do: true

  # Private helpers

  defp format_success(result, interface) do
    %{
      result: result,
      status: "success",
      correlation_id: interface.correlation_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp format_error(reason, interface) do
    %{
      error: format_error_message(reason),
      status: "error",
      correlation_id: interface.correlation_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)
end

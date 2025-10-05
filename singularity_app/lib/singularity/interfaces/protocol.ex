defprotocol Singularity.Interfaces.Protocol do
  @moduledoc """
  Protocol for executing tool calls across different interfaces.

  Enables uniform tool execution regardless of the interface:
  - NATS - For distributed messaging and AI Server integration
  - HTTP - For REST APIs
  - CLI - For command-line tools
  - WebSocket - For real-time connections

  ## Example

      # NATS interface
      interface = %Singularity.Interfaces.NATS{reply_to: "responses.123"}
      Singularity.Interfaces.Protocol.execute_tool(interface, tool_call)

  ## Interface Responsibilities

  Each interface implementation must:
  1. Accept a tool call
  2. Execute it via Tools.Runner
  3. Format the result for that interface
  4. Handle errors appropriately
  5. Return the result in interface-specific format
  """

  @doc """
  Execute a tool call via this interface.

  Returns `{:ok, result}` on success or `{:error, reason}` on failure.
  The result format depends on the interface implementation.
  """
  @spec execute_tool(t(), Singularity.Tools.ToolCall.t()) ::
          {:ok, term()} | {:error, term()}
  def execute_tool(interface, tool_call)

  @doc """
  Get interface metadata (name, version, capabilities).
  """
  @spec metadata(t()) :: map()
  def metadata(interface)

  @doc """
  Check if interface supports streaming responses.
  """
  @spec supports_streaming?(t()) :: boolean()
  def supports_streaming?(interface)
end

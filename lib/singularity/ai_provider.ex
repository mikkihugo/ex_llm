defmodule Singularity.AIProvider do
  @moduledoc """
  Client for the AI Providers HTTP Server.

  Supports multiple AI providers:
  - gemini-code-cli (SDK with ADC)
  - gemini-code (Direct Code Assist API)
  - claude-code-cli (SDK with OAuth)
  - codex (ChatGPT Plus/Pro)
  - cursor-agent (OAuth)
  - copilot (GitHub OAuth)

  ## Examples

      # Simple chat
      {:ok, response} = AIProvider.chat("gemini-code", [
        %{role: "user", content: "Explain this code"}
      ])

      # With options
      {:ok, response} = AIProvider.chat("claude-code-cli",
        [%{role: "user", content: "Write tests"}],
        model: "opus",
        temperature: 0.3,
        max_tokens: 4096
      )

      # Stream response
      AIProvider.stream("gemini-code", [
        %{role: "user", content: "Generate code"}
      ], fn chunk -> IO.write(chunk) end)
  """

  require Logger

  @base_url Application.compile_env(:singularity, :ai_server_url, "http://localhost:3000")
  @timeout 120_000  # 2 minutes
  @recv_timeout 120_000

  @type message :: %{role: String.t(), content: String.t()}
  @type provider :: String.t()
  @type option :: {:model, String.t()}
                | {:temperature, float()}
                | {:max_tokens, integer()}

  @doc """
  Send a chat request to an AI provider.

  ## Parameters
  - provider: One of "gemini-code-cli", "gemini-code", "claude-code-cli", "codex", "cursor-agent", "copilot"
  - messages: List of message maps with :role and :content
  - opts: Optional keyword list with :model, :temperature, :max_tokens

  ## Returns
  - {:ok, response_map} on success
  - {:error, reason} on failure
  """
  @spec chat(provider(), list(message()), list(option())) ::
    {:ok, map()} | {:error, term()}
  def chat(provider, messages, opts \\ []) do
    body = build_request_body(provider, messages, opts)

    case Req.post("#{@base_url}/chat",
      json: body,
      receive_timeout: @recv_timeout,
      retry: false
    ) do
      {:ok, %{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %{status: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{inspect(response_body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the text response from a chat request.

  Same as chat/3 but returns just the text string.
  """
  @spec chat_text(provider(), list(message()), list(option())) ::
    {:ok, String.t()} | {:error, term()}
  def chat_text(provider, messages, opts \\ []) do
    case chat(provider, messages, opts) do
      {:ok, %{"text" => text}} -> {:ok, text}
      {:ok, response} -> {:error, "No text in response: #{inspect(response)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stream a chat response, calling the callback function with each chunk.

  Note: Streaming support varies by provider.
  """
  @spec stream(provider(), list(message()), function(), list(option())) ::
    {:ok, :complete} | {:error, term()}
  def stream(provider, messages, callback, opts \\ []) do
    # For now, fall back to regular chat and call callback with full response
    # TODO: Implement true streaming when AI server supports it
    case chat_text(provider, messages, opts) do
      {:ok, text} ->
        callback.(text)
        {:ok, :complete}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if the AI server is healthy.
  """
  @spec health_check() :: {:ok, map()} | {:error, term()}
  def health_check do
    case Req.get("#{@base_url}/health", receive_timeout: 5_000, retry: false) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: status}} ->
        {:error, "Health check failed: HTTP #{status}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List available providers and their authentication status.
  """
  @spec list_providers() :: {:ok, list(String.t())} | {:error, term()}
  def list_providers do
    case health_check() do
      {:ok, %{"providers" => providers}} -> {:ok, providers}
      {:ok, _} -> {:error, "No providers in health response"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helpers

  defp build_request_body(provider, messages, opts) do
    %{
      provider: provider,
      messages: messages
    }
    |> maybe_add(:model, opts[:model])
    |> maybe_add(:temperature, opts[:temperature])
    |> maybe_add(:maxTokens, opts[:max_tokens])
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end

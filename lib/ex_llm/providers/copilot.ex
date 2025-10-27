defmodule ExLLM.Providers.Copilot do
  @moduledoc """
  GitHub Copilot Provider for ExLLM.

  Implements the ExLLM.Provider behavior for GitHub Copilot Chat API.

  ## Authentication Flow

  1. Get GitHub token (from `gh auth token` or device OAuth)
  2. Exchange for Copilot token (POST to `/copilot_internal/v2/token`)
  3. Use Copilot token for chat API calls
  4. Auto-refresh Copilot token every `refresh_in` seconds

  ## Usage

      iex> {:ok, response} = ExLLM.Providers.Copilot.chat([
      ...>   %{role: "user", content: "Hello Copilot"}
      ...> ])
      iex> response.content
      "Hello! How can I help you today?"
  """

  @behaviour ExLLM.Provider

  require Logger
  alias ExLLM.Providers.{GitHub, Copilot}
  alias ExLLM.Types

  @impl true
  def chat(messages, opts \\ []) do
    with {:ok, github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(github_token),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, response} <- Copilot.API.chat_completions(copilot_token, messages, opts) do
      content = extract_content_from_response(response)

      {:ok,
       %ExLLM.Types.LLMResponse{
         content: content,
         model: Map.get(response, "model", "copilot"),
         usage: extract_tokens(response),
         cost: 0.0,
         metadata: %{raw_response: response}
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream_chat(messages, opts \\ []) do
    with {:ok, _github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(""),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token() do
      Copilot.API.chat_completions_stream(copilot_token, messages, nil, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def configured?(_opts \\ []) do
    case GitHub.TokenManager.get_token() do
      {:ok, _token} -> true
      {:error, _} -> false
    end
  end

  @impl true
  def default_model() do
    "gpt-4.1"
  end

  @impl true
  def list_models(_opts \\ []) do
    {:ok, [
      %Types.Model{
        id: "gpt-4.1",
        name: "GPT-4.1",
        description: "GitHub Copilot with GPT-4.1 - 128K context, 16K output for search & analysis",
        context_window: 128_000,
        max_output_tokens: 16_384,
        pricing: %{input: 0.002, output: 0.008},
        capabilities: ["streaming", "chat", "code_generation", "vision", "structured_output", "search"]
      }
    ]}
  end

  # Private helpers

  defp ensure_copilot_token_manager(github_token) do
    case :global.whereis_name(Copilot.TokenManager) do
      :undefined ->
        # Start token manager if not already running
        case Copilot.TokenManager.start_link(github_token: github_token) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _pid ->
        :ok
    end
  end

  defp extract_content_from_response(response) when is_map(response) do
    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        content

      %{"choices" => [%{"delta" => %{"content" => content}} | _]} ->
        content

      _ ->
        Logger.warning("Could not extract content from Copilot response: #{inspect(response)}")
        ""
    end
  end

  defp extract_tokens(response) when is_map(response) do
    case response do
      %{"usage" => usage} when is_map(usage) ->
        %{
          prompt_tokens: Map.get(usage, "prompt_tokens", 0),
          completion_tokens: Map.get(usage, "completion_tokens", 0),
          total_tokens: Map.get(usage, "total_tokens", 0)
        }

      _ ->
        %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}
    end
  end
end

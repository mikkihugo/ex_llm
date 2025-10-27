defmodule Nexus.Providers.Codex do
  @moduledoc """
  Nexus-specific Codex provider using ChatGPT Pro OAuth2.

  This extends ex_llm's provider system with Nexus-specific OAuth token storage
  and ChatGPT Pro integration.

  ## Architecture

  ```
  Nexus.Providers.Codex (this module)
    ↓ uses
  Nexus.OAuthToken (PostgreSQL storage)
    ↓ calls
  ChatGPT Pro Backend API
  ```

  ## Usage

  ```elixir
  # Via Nexus LLMRouter (automatic)
  Nexus.LLMRouter.route(%{
    complexity: :complex,
    task_type: :code_generation,
    messages: [...]
  })

  # Direct call
  {:ok, response} = Nexus.Providers.Codex.chat([
    %{role: "user", content: "Write merge sort"}
  ])
  ```

  ## Configuration

  See `nexus/config/config.exs` and `CODEX_SETUP.md`.
  """

  require Logger
  alias Nexus.OAuthToken
  alias Nexus.Providers.Codex.OAuth2
  alias Nexus.Providers.Codex.OAuth2

  @base_url "https://chatgpt.com/backend-api"
  @default_model "gpt-5-codex"

  @doc """
  Send chat request to ChatGPT Pro using OAuth tokens.
  """
  def chat(messages, opts \\ []) do
    with {:ok, token} <- get_valid_token(),
         {:ok, response} <- call_api(messages, token, opts) do
      {:ok, parse_response(response)}
    end
  end

  @doc """
  Stream chat response (when implemented).
  """
  def stream(messages, callback, opts \\ []) do
    with {:ok, token} <- get_valid_token(),
         {:ok, _} <- stream_api(messages, token, callback, opts) do
      {:ok, :complete}
    end
  end

  @doc """
  Check if Codex is configured (has valid OAuth tokens).
  """
  def configured? do
    case OAuthToken.get("codex") do
      {:ok, _token} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  List available Codex models.
  """
  def list_models do
    [
      %{
        id: "gpt-5-codex",
        name: "GPT-5 Codex",
        context_window: 128_000,
        max_output_tokens: 4096,
        capabilities: [:chat, :streaming, :code_generation]
      },
      %{
        id: "gpt-4o",
        name: "GPT-4 Optimized",
        context_window: 128_000,
        max_output_tokens: 4096,
        capabilities: [:chat, :streaming, :vision]
      },
      %{
        id: "o1",
        name: "o1 (Reasoning)",
        context_window: 200_000,
        max_output_tokens: 100_000,
        capabilities: [:chat, :reasoning]
      }
    ]
  end

  # Private functions

  defp get_valid_token do
    with {:ok, token} <- OAuthToken.get("codex"),
         {:ok, token} <- ensure_not_expired(token) do
      {:ok, token}
    end
  end

  defp ensure_not_expired(token) do
    if OAuthToken.expired?(token) do
      refresh_token(token)
    else
      {:ok, token}
    end
  end

  defp refresh_token(token) do
    case OAuth2.refresh(token) do
      {:ok, new_tokens} ->
        attrs = OAuthToken.from_ex_llm_format(new_tokens)
        OAuthToken.upsert("codex", attrs)

      error ->
        error
    end
  end

  defp call_api(messages, token, opts) do
    model = opts[:model] || @default_model

    body = %{
      model: model,
      messages: format_messages(messages),
      stream: false,
      temperature: opts[:temperature] || 0.7,
      max_tokens: opts[:max_tokens] || 4096
    }

    headers = [
      {"Authorization", "Bearer #{token.access_token}"},
      {"Content-Type", "application/json"}
    ]

    case Req.post("#{@base_url}/conversation", json: body, headers: headers) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: 401}} ->
        Logger.warning("Codex auth failed, attempting refresh")
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        Logger.warning("Codex rate limit exceeded")
        {:error, :rate_limit}

      {:ok, %{status: status, body: body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stream_api(_messages, _token, _callback, _opts) do
    # TODO: Implement streaming
    {:error, :not_implemented}
  end

  defp format_messages(messages) do
    Enum.map(messages, fn
      %{role: role, content: content} -> %{role: role, content: content}
      %{"role" => role, "content" => content} -> %{role: role, content: content}
    end)
  end

  defp parse_response(%{"message" => %{"content" => content}} = response) do
    %{
      text: content,
      model: response["model"],
      usage: parse_usage(response["usage"])
    }
  end
  defp parse_response(response) do
    %{
      text: extract_text(response),
      raw: response
    }
  end

  defp parse_usage(%{"prompt_tokens" => prompt, "completion_tokens" => completion}) do
    %{
      prompt_tokens: prompt,
      completion_tokens: completion,
      total_tokens: prompt + completion
    }
  end
  defp parse_usage(_), do: nil

  defp extract_text(%{"message" => %{"content" => content}}), do: content
  defp extract_text(%{"content" => content}), do: content
  defp extract_text(_), do: ""
end

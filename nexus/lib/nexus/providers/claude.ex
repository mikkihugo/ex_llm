defmodule Nexus.Providers.Claude do
  @moduledoc """
  Claude provider for Anthropic Claude integration via HTTP API.

  This provider handles authentication, model selection, and API calls
  to the Claude API using the standard Anthropic API key.
  
  Uses the existing ExLLM.Providers.Anthropic module for HTTP API calls.
  """

  require Logger
  alias ExLLM.Providers.Anthropic

  @default_model "claude-3-5-sonnet-20241022"

  # ======================================================================
  # ExLLM.Provider Behavior Implementation
  # ======================================================================

  @doc """
  Send chat request to Claude using OAuth tokens.
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
  Check if Claude is configured (has valid OAuth tokens).
  
  Uses OAuth2 tokens from Claude Code authentication.
  """
  def configured? do
    case token_repository().get("claude_code") do
      {:ok, _token} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Get the provider name.
  """
  def provider_name, do: "claude"

  @doc """
  Get the default model.
  """
  def default_model, do: @default_model

  @doc """
  List available Claude models.
  """
  def list_models do
    [
      %{
        id: "claude-3-5-sonnet-20241022",
        name: "Claude 3.5 Sonnet",
        context_window: 200_000,
        max_output_tokens: 8_192,
        capabilities: [:chat, :streaming, :vision, :thinking],
        thinking_levels: [:low, :medium, :high],
        cost: :free,
        pricing: "Free with Claude Pro subscription",
        quota_usage: %{
          low: 1.0,
          medium: 2.0,
          high: 4.0
        }
      },
      %{
        id: "claude-3-5-haiku-20241022",
        name: "Claude 3.5 Haiku",
        context_window: 200_000,
        max_output_tokens: 8_192,
        capabilities: [:chat, :streaming, :vision],
        thinking_levels: nil,
        cost: :free,
        pricing: "Free with Claude Pro subscription",
        quota_usage: %{
          default: 1.0
        }
      },
      %{
        id: "claude-3-opus-20240229",
        name: "Claude 3 Opus",
        context_window: 200_000,
        max_output_tokens: 4_096,
        capabilities: [:chat, :streaming, :vision],
        thinking_levels: nil,
        cost: :free,
        pricing: "Free with Claude Pro subscription",
        quota_usage: %{
          default: 1.0
        }
      }
    ]
  end

  # ======================================================================
  # Private Functions
  # ======================================================================

  defp token_repository do
    Application.get_env(:nexus, :token_repository, OAuthToken)
  end

  defp get_valid_token do
    with {:ok, token} <- token_repository().get("claude_code"),
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
        token_repository().upsert("claude_code", attrs)
      {:error, reason} ->
        Logger.error("Failed to refresh Claude token: #{inspect(reason)}")
        {:error, :refresh_failed}
    end
  end

  defp call_api(messages, token, opts) do
    model = opts[:model] || @default_model
    max_tokens = opts[:max_tokens] || 4_096
    
    request = %{
      model: model,
      max_tokens: max_tokens,
      messages: messages
    }

    headers = [
      {"Authorization", "Bearer #{token.access_token}"},
      {"Content-Type", "application/json"},
      {"anthropic-version", "2023-06-01"}
    ]

    case http_client().post("#{@base_url}/messages", request, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        Logger.error("Claude API error: #{status} - #{inspect(body)}")
        {:error, {:api_error, status, body}}
      {:error, reason} ->
        Logger.error("Claude API request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp stream_api(_messages, _token, _callback, _opts) do
    # TODO: Implement streaming
    {:error, :not_implemented}
  end

  defp parse_response(%{"content" => content}) when is_list(content) do
    # Extract text from content array
    text = content
    |> Enum.filter(&(&1["type"] == "text"))
    |> Enum.map(&(&1["text"]))
    |> Enum.join("")
    
    %{
      content: text,
      model: @default_model,
      usage: %{
        prompt_tokens: 0,  # Claude doesn't return usage in response
        completion_tokens: 0,
        total_tokens: 0
      }
    }
  end

  defp parse_response(response) do
    Logger.error("Unexpected Claude API response: #{inspect(response)}")
    {:error, :invalid_response}
  end

  defp http_client do
    Application.get_env(:nexus, :http_client, Req)
  end
end

defmodule ExLLM.Providers.Codex do
  @moduledoc """
  OpenAI Codex CLI Provider for ExLLM.

  Integrates with OpenAI's Codex CLI tool, which stores OAuth2 credentials in `~/.codex/auth.json`.
  This provider acts as a bridge to use Codex-authenticated LLM access from ExLLM.

  ## Credential Management

  TokenManager automatically:
  - Loads credentials from `~/.codex/auth.json` (Codex CLI credentials) first
  - Falls back to local `.codex_oauth_token` cache if needed
  - Extracts token expiration from JWT `exp` claim
  - Auto-refreshes tokens 60 seconds before expiration
  - Syncs refreshed tokens back to `~/.codex/auth.json`

  ## Authentication Flow

  1. User authenticates with Codex CLI: `codex auth`
  2. Credentials stored in `~/.codex/auth.json`
  3. ExLLM loads and uses these same credentials
  4. Tokens auto-refresh and stay in sync with Codex CLI

  ## Usage

      iex> {:ok, response} = ExLLM.Providers.Codex.chat([
      ...>   %{role: "user", content: "Write a binary search function"}
      ...> ])
      iex> response.content
      "def binary_search(arr, target):\\n..."

  ## Requirements

  - Codex CLI must be authenticated: `npm install -g @openai/codex && codex auth`
  - `~/.codex/auth.json` will be created with valid OpenAI OAuth2 tokens
  """

  @behaviour ExLLM.Provider

  require Logger
  alias ExLLM.Providers.Codex.TokenManager
  alias ExLLM.Providers.Shared.HTTP.Core
  alias ExLLM.Types

  @codex_api_base "https://chatgpt.com/backend-api"
  @codex_chat_endpoint "/conversation"

  @impl true
  def chat(messages, opts \\ []) do
    with {:ok, token} <- TokenManager.get_token(),
         {:ok, response} <- call_api(messages, token, opts) do
      content = extract_content_from_response(response)

      {:ok,
       %ExLLM.Types.LLMResponse{
         content: content,
         model: Map.get(response, "model", "gpt-5-codex"),
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
    with {:ok, token} <- TokenManager.get_token() do
      call_api_stream(messages, token, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def configured?(_opts \\ []) do
    case TokenManager.get_token() do
      {:ok, _token} -> true
      {:error, _} -> false
    end
  end

  @impl true
  def default_model() do
    "gpt-5-codex"
  end

  @impl true
  def list_models(_opts \\ []) do
    # Load models from YAML registry (config/models/codex.yml)
    case load_models_from_registry() do
      {:ok, models} -> {:ok, models}
      {:error, _} -> {:error, "Failed to load Codex models from registry"}
    end
  end

  # Private helpers for model loading

  defp load_models_from_registry() do
    config_path = get_config_path()

    case File.read(config_path) do
      {:ok, content} ->
        case YamlElixir.read_from_string(content) do
          {:ok, %{"models" => models}} when is_map(models) ->
            registry_models = build_models_from_registry(models)
            {:ok, registry_models}

          {:ok, _} ->
            Logger.error("Invalid Codex config format: missing 'models' key")
            {:error, "Invalid config format"}

          {:error, reason} ->
            Logger.error("Failed to parse Codex config: #{inspect(reason)}")
            {:error, "Failed to parse config"}
        end

      {:error, reason} ->
        Logger.error("Failed to read Codex config: #{inspect(reason)}")
        {:error, "Config file not found"}
    end
  end

  defp get_config_path() do
    Path.expand("config/models/codex.yml")
  end

  defp build_models_from_registry(models) when is_map(models) do
    Enum.map(models, fn {model_id, config} ->
      %Types.Model{
        id: model_id,
        name: Map.get(config, "name", "Codex #{model_id}"),
        description: Map.get(config, "description", "ChatGPT Pro model #{model_id}"),
        context_window: Map.get(config, "context_window", 128_000),
        max_output_tokens: Map.get(config, "max_output_tokens", 4096),
        pricing: build_pricing(Map.get(config, "pricing", %{})),
        capabilities: Map.get(config, "capabilities", [])
      }
    end)
  end

  defp build_pricing(pricing) when is_map(pricing) do
    %{
      input: pricing["input"] || 0.0,
      output: pricing["output"] || 0.0
    }
  end

  defp build_pricing(_), do: %{input: 0.0, output: 0.0}

  # API communication

  defp call_api(messages, token, opts) do
    headers = codex_headers(token)

    model = Keyword.get(opts, :model, default_model())
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      model: model,
      messages: format_messages(messages),
      temperature: temperature,
      max_tokens: max_tokens,
      stream: false
    }

    client_opts = [
      provider: :codex,
      base_url: @codex_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :post, @codex_chat_endpoint, body, headers) do
      {:ok, %{"message" => _} = response} ->
        Logger.debug("Codex API response received")
        {:ok, response}

      {:ok, response} ->
        Logger.error("Codex API unexpected response: #{inspect(response)}")
        {:error, "Codex API returned unexpected format"}

      {:error, reason} ->
        Logger.error("Codex API request failed: #{inspect(reason)}")
        {:error, "Codex API request failed: #{inspect(reason)}"}
    end
  end

  defp call_api_stream(messages, token, opts) do
    headers = codex_headers(token)

    model = Keyword.get(opts, :model, default_model())
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 4096)

    body = %{
      model: model,
      messages: format_messages(messages),
      temperature: temperature,
      max_tokens: max_tokens,
      stream: true
    }

    client_opts = [
      provider: :codex,
      base_url: @codex_api_base
    ]

    client = Core.client(client_opts)

    case execute_request(client, :post, @codex_chat_endpoint, body, headers) do
      {:ok, stream} when is_function(stream) ->
        stream
        |> Stream.map(&parse_stream_chunk/1)
        |> Stream.each(fn
          {:ok, content} -> Logger.debug("Stream chunk: #{String.length(content)} chars")
          {:error, _} -> :ok
        end)
        |> Stream.run()

        {:ok, "Streaming complete"}

      {:error, reason} ->
        Logger.error("Codex streaming request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helpers

  defp format_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: get_role(msg),
        content: get_content(msg)
      }
    end)
  end

  defp get_role(msg) when is_map(msg) do
    Map.get(msg, :role) || Map.get(msg, "role") || "user"
  end

  defp get_content(msg) when is_map(msg) do
    Map.get(msg, :content) || Map.get(msg, "content") || ""
  end

  defp codex_headers(token) do
    [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "ExLLM/1.0.0"}
    ]
  end

  defp execute_request(client, method, path, body, headers) do
    case Tesla.request(client, method: method, url: path, body: body, headers: headers) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %Tesla.Env{status: 401}} ->
        Logger.warning("Codex auth failed, token may be expired")
        {:error, "unauthorized"}

      {:ok, %Tesla.Env{status: 429}} ->
        Logger.warning("Codex rate limit exceeded")
        {:error, "rate_limit"}

      {:ok, %Tesla.Env{status: code, body: response_body}} ->
        {:error, "Codex API failed with status #{code}: #{response_body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_stream_chunk(chunk) when is_binary(chunk) do
    case String.split(chunk, "\n") do
      chunks ->
        chunks
        |> Enum.filter(&String.starts_with?(&1, "data: "))
        |> Enum.map(&String.replace_leading(&1, "data: ", ""))
        |> Enum.map(&Jason.decode/1)
        |> Enum.find_value(fn
          {:ok, %{"message" => %{"content" => content}}} -> {:ok, content}
          _ -> nil
        end)
        |> case do
          nil -> {:error, :no_content}
          result -> result
        end
    end
  end

  defp parse_stream_chunk(_chunk), do: {:error, :invalid_chunk}

  defp extract_content_from_response(response) when is_map(response) do
    case response do
      %{"message" => %{"content" => content}} ->
        content

      %{"content" => content} ->
        content

      _ ->
        Logger.warning("Could not extract content from Codex response: #{inspect(response)}")
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

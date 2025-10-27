defmodule ExLLM.Providers.Codex do
  @moduledoc """
  OpenAI Codex CLI Provider for ExLLM.

  Integrates with OpenAI's Codex CLI tool, which stores OAuth2 credentials in `~/.codex/auth.json`.
  This provider acts as a bridge to use Codex-authenticated LLM access from ExLLM.

  ## Supported APIs

  ### Chat API (Streaming)
  For real-time chat completions with streaming responses.

      iex> {:ok, response} = ExLLM.Providers.Codex.chat([
      ...>   %{role: "user", content: "Write a binary search function"}
      ...> ])

  ### Task API (Long-running)
  For code generation tasks using the WHAM protocol.

      iex> {:ok, task_id} = ExLLM.Providers.Codex.create_task(
      ...>   environment_id: "owner/repo",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support"
      ...> )
      iex> {:ok, response} = ExLLM.Providers.Codex.poll_task(task_id)

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

  ## Available Models

  - `gpt-5-codex` (default) - Specialized code generation (272K context)
  - `gpt-5` - General-purpose reasoning (400K context)
  - `codex-mini-latest` - Fast lightweight model (200K context)

  All models are **FREE** to use with Codex CLI subscription.

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

  # Task API Methods (WHAM Protocol)

  @doc """
  Create a new code generation task using the WHAM API.

  ## Options

  - `:environment_id` (required) - Repository identifier (e.g., "owner/repo")
  - `:branch` (required) - Git branch name
  - `:prompt` (required) - Code generation instruction
  - `:model` - Model ID (default: "gpt-5-codex")
  - `:qa_mode` - Run in QA mode (default: false)
  - `:best_of_n` - Number of attempts (default: 1)
  - `:poll_interval_ms` - Polling interval (default: 3000)
  - `:max_attempts` - Max poll attempts (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000)

  ## Returns

  - `{:ok, task_id}` - Task created successfully
  - `{:error, reason}` - Creation failed

  ## Example

      iex> {:ok, task_id} = create_task(
      ...>   environment_id: "mikkihugo/singularity-incubation",
      ...>   branch: "main",
      ...>   prompt: "Add dark mode support to the Phoenix dashboard"
      ...> )
  """
  def create_task(opts) when is_list(opts) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.create_task(opts)
  end

  @doc """
  Create a task and wait for completion (blocking).

  ## Returns

  - `{:ok, task_id, response}` - Task completed with response
  - `{:error, reason}` - Failed

  ## Example

      iex> {:ok, task_id, response} = create_task_and_wait(
      ...>   environment_id: "owner/repo",
      ...>   branch: "main",
      ...>   prompt: "Generate tests",
      ...>   max_attempts: 60
      ...> )
  """
  def create_task_and_wait(opts) when is_list(opts) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.create_task_and_wait(opts)
  end

  @doc """
  Poll a task for completion.

  Continuously polls until completion or timeout.

  ## Options

  - `:poll_interval_ms` - Wait between polls (default: 3000)
  - `:max_attempts` - Maximum polls (default: 30)
  - `:timeout_ms` - Total timeout (default: 120000)

  ## Returns

  - `{:ok, response}` - Task completed
  - `{:error, reason}` - Failed or timed out

  ## Example

      iex> {:ok, response} = poll_task("task_e_...", max_attempts: 60)
  """
  def poll_task(task_id, opts \\ []) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.poll_task(task_id, opts)
  end

  @doc """
  Get task status without waiting.

  ## Returns

  - `{:ok, status}` - Current status ("queued", "in_progress", "completed", etc.)
  - `{:error, reason}` - Request failed
  """
  def get_task_status(task_id) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_task_status(task_id)
  end

  @doc """
  Get full task response without polling.

  ## Returns

  - `{:ok, response}` - Full WHAM response
  - `{:error, reason}` - Request failed
  """
  def get_task_response(task_id) when is_binary(task_id) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_task_response(task_id)
  end

  @doc """
  Extract structured data from a task response.

  ## Returns

  Map with extracted message, code_diff, pr_info, and files.

  ## Example

      iex> {:ok, response} = get_task_response(task_id)
      iex> extracted = extract_response(response)
      iex> extracted.code_diff
      "diff --git a/lib/..."
  """
  def extract_response(response) when is_map(response) do
    alias ExLLM.Providers.Codex.ResponseExtractor
    ResponseExtractor.extract(response)
  end

  @doc """
  List user's tasks.

  ## Options

  - `:limit` - Number of tasks (default: 10)
  - `:offset` - Pagination offset (default: 0)

  ## Returns

  - `{:ok, tasks}` - List of task summaries
  - `{:error, reason}` - Request failed
  """
  def list_tasks(opts \\ []) do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.list_tasks(opts)
  end

  @doc """
  Check rate limit usage.

  ## Returns

  - `{:ok, usage}` - Rate limit information
  - `{:error, reason}` - Request failed

  ## Example Response

      %{
        "primary_window" => %{"used_percent" => 8, ...},
        "secondary_window" => %{"used_percent" => 15, ...}
      }
  """
  def get_usage() do
    alias ExLLM.Providers.Codex.TaskClient
    TaskClient.get_usage()
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

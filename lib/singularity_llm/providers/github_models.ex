defmodule SingularityLLM.Providers.GitHubModels do
  @moduledoc """
  GitHub Models Provider for SingularityLLM.

  Provides access to GitHub's FREE tier LLM inference service with multiple models:
  - OpenAI models (GPT-4o, GPT-4o-mini)
  - Meta models (Llama 3.2, Llama 3.3)
  - DeepSeek models
  - Mistral models
  - Microsoft models (Phi-4)
  - And many more (all FREE tier)

  ## Authentication

  Uses GitHub token from:
  1. `GITHUB_TOKEN` environment variable
  2. `GH_TOKEN` environment variable
  3. `~/.local/share/copilot-api/github_token` file

  ## API Endpoints

  - Models: `https://models.github.ai/catalog/models`
  - Chat: `https://models.github.ai/inference/chat/completions` (OpenAI-compatible)

  ## Usage

      iex> SingularityLLM.Providers.GitHubModels.chat([
      ...>   %{role: "user", content: "Hello from GitHub Models!"}
      ...> ])
      {:ok, %SingularityLLM.Types.LLMResponse{content: "Hello! How can I help you today?"}}

  ## Rate Limits

  FREE tier with rate limits per GitHub account:
  - Low tier: 8K input + 4K output tokens
  - High tier: 8K input + 4K output tokens  
  - Custom tier: 4K input + 4K output tokens
  """

  @behaviour SingularityLLM.Provider

  require Logger
  alias SingularityLLM.Types

  @api_base "https://models.github.ai"
  @cache_table :github_models_cache
  @cache_ttl :timer.minutes(5)  # 5 minutes

  @impl true
  def chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, default_model())
    
    with {:ok, _models} <- fetch_models_from_api(),  # Ensure models are available
         {:ok, github_token} <- get_github_token(),
         {:ok, response} <- call_github_models_api(github_token, model, messages, opts) do
      content = extract_content_from_response(response)
      
      {:ok,
       %Types.LLMResponse{
         content: content,
         model: model,
         usage: extract_tokens(response),
         cost: 0.0,  # FREE tier
         metadata: %{raw_response: response}
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream_chat(messages, opts \\ []) do
    model = Keyword.get(opts, :model, default_model())
    
    with {:ok, _models} <- fetch_models_from_api(),  # Ensure models are available
         {:ok, github_token} <- get_github_token() do
      call_github_models_api_stream(github_token, model, messages, opts)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def configured?(opts \\ []) do
    # Check if we can actually fetch models from the API
    case fetch_models_from_api() do
      {:ok, _models} -> true
      {:error, _} -> false
    end
  end

  @impl true
  def default_model() do
    "openai/gpt-4o-mini"
  end

  @impl true
  def list_models(opts \\ []) do
    # Fetch models dynamically from GitHub Models API
    fetch_models_from_api()
  end

  # Private helpers

  defp get_github_token do
    # Try gh auth token first (preferred)
    case System.cmd("gh", ["auth", "token"], stderr_to_stdout: true) do
      {token, 0} ->
        {:ok, String.trim(token)}

      {_error, _code} ->
        # Fallback to environment variables
        token = System.get_env("GITHUB_TOKEN") || System.get_env("GH_TOKEN")

        if token do
          {:ok, token}
        else
          # Try reading from Copilot API token file
          token_file = Path.join([System.user_home!(), ".local", "share", "copilot-api", "github_token"])

          if File.exists?(token_file) do
            case File.read(token_file) do
              {:ok, content} -> {:ok, String.trim(content)}
              _ -> {:error, "Failed to read GitHub token file"}
            end
          else
            {:error, "GitHub token not found"}
          end
        end
    end
  end

  defp call_github_models_api(token, model, messages, opts) do
    # Check if this is a newer OpenAI model
    is_newer_openai_model? = String.contains?(model, ["gpt-5", "o1", "o3", "o4"])

    body =
      %{
        model: model,
        messages: messages,
        stream: false
      }
      |> maybe_add_max_tokens(is_newer_openai_model?, opts)
      |> maybe_add_temperature(opts)

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    Logger.debug("[GitHubModels] Calling model: #{model}")

    case Req.post("#{@api_base}/inference/chat/completions",
           json: body,
           headers: headers,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[GitHubModels] HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} = error ->
        Logger.error("[GitHubModels] Request failed: #{inspect(reason)}")
        error
    end
  end

  defp call_github_models_api_stream(token, model, messages, opts) do
    body =
      %{
        model: model,
        messages: messages,
        stream: true
      }
      |> maybe_add_max_tokens(false, opts)
      |> maybe_add_temperature(opts)

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    Logger.debug("[GitHubModels] Streaming model: #{model}")

    case Req.post("#{@api_base}/inference/chat/completions",
           json: body,
           headers: headers,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: 200, body: response}} ->
        {:ok, response}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[GitHubModels] HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} = error ->
        Logger.error("[GitHubModels] Request failed: #{inspect(reason)}")
        error
    end
  end

  defp maybe_add_max_tokens(body, true, opts) do
    # Newer OpenAI models use max_completion_tokens
    Map.put(body, :max_completion_tokens, Keyword.get(opts, :max_tokens, 1000))
  end

  defp maybe_add_max_tokens(body, false, opts) do
    # Older models use max_tokens
    Map.put(body, :max_tokens, Keyword.get(opts, :max_tokens, 1000))
  end

  defp maybe_add_temperature(body, opts) do
    case Keyword.get(opts, :temperature) do
      nil -> body
      temp -> Map.put(body, :temperature, temp)
    end
  end

  defp extract_content_from_response(response) when is_map(response) do
    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        content

      %{"choices" => [%{"delta" => %{"content" => content}} | _]} ->
        content

      _ ->
        Logger.warning("Could not extract content from GitHub Models response: #{inspect(response)}")
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

  # Dynamic model fetching from GitHub Models API

  defp fetch_models_from_api do
    with {:ok, token} <- get_github_token() do
      headers = [
        {"Accept", "application/vnd.github+json"},
        {"Authorization", "Bearer #{token}"},
        {"X-GitHub-Api-Version", "2022-11-28"}
      ]

      case Req.get("#{@api_base}/catalog/models", headers: headers, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: models}} when is_list(models) ->
          parsed_models =
            models
            |> Enum.filter(&is_chat_model?/1)
            |> Enum.map(&parse_model/1)
            |> Enum.filter(& &1)

          Logger.info("[GitHubModels] Fetched #{length(parsed_models)} chat models from API")
          {:ok, parsed_models}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[GitHubModels] HTTP #{status}: #{inspect(body)}")
          {:error, {:http_error, status}}

        {:error, reason} = error ->
          Logger.error("[GitHubModels] API request failed: #{inspect(reason)}")
          error
      end
    else
      {:error, reason} ->
        Logger.warning("[GitHubModels] GitHub token not found, using fallback models: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp is_chat_model?(model) do
    tier = model["rate_limit_tier"]
    # Filter out embedding models
    tier != "embeddings" && !String.contains?(model["id"] || "", "embedding")
  end

  defp parse_model(model_data) when is_map(model_data) do
    id = model_data["id"]
    friendly_name = model_data["friendly_name"] || id
    tier = model_data["rate_limit_tier"]

    # Apply GitHub Models free tier limits
    {max_input, max_output} = get_tier_limits(tier)

    description = "#{friendly_name} via GitHub Models (#{div(max_input, 1000)}K input, #{div(max_output, 1000)}K output)"

    %Types.Model{
      id: id,
      name: friendly_name,
      description: description,
      context_window: max_input + max_output,
      max_output_tokens: max_output,
      pricing: %{input: 0.0, output: 0.0},  # FREE tier
      capabilities: build_capabilities(model_data)
    }
  end

  defp parse_model(_), do: nil

  defp get_tier_limits("low"), do: {8_000, 4_000}
  defp get_tier_limits("high"), do: {8_000, 4_000}
  defp get_tier_limits("custom"), do: {4_000, 4_000}  # Mini/Nano/DeepSeek/Grok
  defp get_tier_limits(_), do: {8_000, 4_000}  # Default fallback

  defp build_capabilities(model_data) do
    capabilities = []
    
    # Check for vision capability
    capabilities = if Enum.member?(model_data["supported_input_modalities"] || [], "image") do
      capabilities ++ ["vision"]
    else
      capabilities
    end
    
    # Check for tool calling capability
    capabilities = if Enum.member?(model_data["capabilities"] || [], "tool-calling") do
      capabilities ++ ["tools"]
    else
      capabilities
    end
    
    # All models support basic chat and streaming
    capabilities ++ ["streaming", "chat_completions", "code_generation"]
  end

end
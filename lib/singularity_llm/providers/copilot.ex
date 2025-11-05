defmodule SingularityLLM.Providers.Copilot do
  @moduledoc """
  GitHub Copilot Provider for SingularityLLM.

  Implements the SingularityLLM.Provider behavior for GitHub Copilot Chat API.

  ## Authentication Flow

  1. Get GitHub token (from `gh auth token` or device OAuth)
  2. Exchange for Copilot token (POST to `/copilot_internal/v2/token`)
  3. Use Copilot token for chat API calls
  4. Auto-refresh Copilot token every `refresh_in` seconds

  ## Usage

      iex> {:ok, response} = SingularityLLM.Providers.Copilot.chat([
      ...>   %{role: "user", content: "Hello Copilot"}
      ...> ])
      iex> response.content
      "Hello! How can I help you today?"
  """

  @behaviour SingularityLLM.Provider

  require Logger
  alias SingularityLLM.Providers.{GitHub, Copilot}
  alias SingularityLLM.Types

  @impl true
  def chat(messages, opts \\ []) do
    with {:ok, github_token} <- GitHub.TokenManager.get_token(),
         :ok <- ensure_copilot_token_manager(github_token),
         {:ok, copilot_token} <- Copilot.TokenManager.get_token(),
         {:ok, response} <- Copilot.API.chat_completions(copilot_token, messages, opts) do
      content = extract_content_from_response(response)

      {:ok,
       %SingularityLLM.Types.LLMResponse{
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
    # Load models from YAML registry (config/models/github_copilot.yml)
    case load_models_from_registry() do
      {:ok, models} -> {:ok, models}
      {:error, _} -> {:error, "Failed to load GitHub Copilot models from registry"}
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
            Logger.error("Invalid GitHub Copilot config format: missing 'models' key")
            {:error, "Invalid config format"}

          {:error, reason} ->
            Logger.error("Failed to parse GitHub Copilot config: #{inspect(reason)}")
            {:error, "Failed to parse config"}
        end

      {:error, reason} ->
        Logger.error("Failed to read GitHub Copilot config: #{inspect(reason)}")
        {:error, "Config file not found"}
    end
  end

  defp get_config_path() do
    Path.expand("config/models/github_copilot.yml")
  end

  defp build_models_from_registry(models) when is_map(models) do
    Enum.map(models, fn {model_id, config} ->
      %Types.Model{
        id: model_id,
        name: String.upcase(model_id),
        description: Map.get(config, "description", "GitHub Copilot #{model_id}"),
        context_window: Map.get(config, "context_window", 128_000),
        max_output_tokens: Map.get(config, "max_output_tokens", 16_384),
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

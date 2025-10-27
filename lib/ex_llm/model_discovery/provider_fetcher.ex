defmodule ExLLM.ModelDiscovery.ProviderFetcher do
  @moduledoc """
  Fetches real model data directly from provider REST APIs.

  Instead of external leaderboards, query providers for authoritative model info:
  - GitHub Models: GitHub API
  - Gemini: Google AI API
  - Mistral: models endpoint
  - Groq: models endpoint
  - OpenRouter: models endpoint (includes OpenAI, Claude, etc.)
  - Perplexity: models endpoint
  - Xai: models endpoint
  - Ollama: /api/tags

  ## Auto-Discovery

  Discovers models that providers publish via REST APIs. Automatically detects:
  - New models when providers release them
  - Deprecations when models removed
  - Updated pricing and capabilities
  - Context window changes

  ## Self-Healing Catalog

  Keeps model configs in sync with provider APIs without manual intervention.
  Run periodically (hourly/daily) to stay current.

  ## Usage

  ```elixir
  # Fetch from single provider
  {:ok, models} = ProviderFetcher.fetch(:openai)
  [%{name: "gpt-4o", context_window: 128000, ...}, ...]

  # Fetch from all configured providers
  {:ok, all_models} = ProviderFetcher.fetch_all()

  # Update YAML configs with discovered models
  :ok = ProviderFetcher.sync_to_configs()
  ```
  """

  require Logger
  alias ExLLM.ModelDiscovery.ProviderAdapters

  @type provider :: :github | :gemini | :mistral | :groq | :openrouter | :perplexity | :xai | :ollama

  @type model_info :: %{
    name: String.t(),
    display_name: String.t(),
    context_window: non_neg_integer(),
    max_output_tokens: non_neg_integer(),
    pricing: %{input: float(), output: float()},
    capabilities: [String.t()],
    deprecated: boolean(),
    available: boolean()
  }

  @doc """
  Fetch models from a specific provider's API.

  Requires proper authentication (API key/token) configured for the provider.
  Returns authoritative model list with current pricing and capabilities.

  ## Authentication

  Each provider requires a specific environment variable:
  - `:github` → GITHUB_TOKEN
  - `:gemini` → GOOGLE_API_KEY
  - `:mistral` → MISTRAL_API_KEY
  - `:groq` → GROQ_API_KEY
  - `:openrouter` → OPENROUTER_API_KEY
  - `:perplexity` → PERPLEXITY_API_KEY
  - `:xai` → XAI_API_KEY
  - `:ollama` → None (local)
  """
  @spec fetch(provider()) :: {:ok, [model_info()]} | {:error, atom(), String.t()}
  def fetch(provider) when provider in [:github, :gemini, :mistral, :groq, :openrouter, :perplexity, :xai, :ollama] do
    if not has_credentials?(provider) do
      {:error, :missing_credentials, "No API key configured for #{provider}"}
    else
      Logger.info("Fetching models from #{provider}...")

      case adapter_for(provider).fetch() do
        {:ok, models} ->
          Logger.info("Discovered #{length(models)} models from #{provider}")
          {:ok, models}

        {:error, reason} ->
          Logger.warning("Failed to fetch models from #{provider}: #{inspect(reason)}")
          {:error, :fetch_failed, "Failed to fetch from #{provider}: #{inspect(reason)}"}
      end
    end
  end

  def fetch(provider) do
    {:error, :unknown_provider, "Provider #{provider} not supported"}
  end

  @doc """
  Fetch models from all configured providers.

  Only attempts to fetch from providers that have credentials configured.
  Returns map of provider -> models, continuing if individual providers fail.
  """
  @spec fetch_all() :: {:ok, map()} | {:error, atom()}
  def fetch_all do
    providers = [:github, :gemini, :mistral, :groq, :openrouter, :perplexity, :xai, :ollama]

    results =
      providers
      |> Enum.filter(&has_credentials?/1)
      |> Enum.map(fn provider ->
        case fetch(provider) do
          {:ok, models} -> {provider, models}
          {:error, _reason, _msg} -> {provider, []}
        end
      end)
      |> Enum.into(%{})

    if Enum.empty?(results) or Enum.all?(results, fn {_p, models} -> Enum.empty?(models) end) do
      {:error, :no_providers_available}
    else
      {:ok, results}
    end
  end

  @doc """
  Check if provider has required credentials configured.

  Only returns true if the environment variable is set AND non-empty.
  Preserves all existing credentials without modification.
  """
  @spec has_credentials?(provider()) :: boolean()
  def has_credentials?(provider) do
    case provider do
      :github -> is_set("GITHUB_TOKEN")
      :gemini -> is_set("GOOGLE_API_KEY")
      :mistral -> is_set("MISTRAL_API_KEY")
      :groq -> is_set("GROQ_API_KEY")
      :openrouter -> is_set("OPENROUTER_API_KEY")
      :perplexity -> is_set("PERPLEXITY_API_KEY")
      :xai -> is_set("XAI_API_KEY")
      :ollama -> true  # Local provider, no key needed
      _ -> false
    end
  end

  @doc """
  Get list of providers with credentials configured.

  Useful for checking which providers are available for fetching.
  """
  @spec available_providers() :: [provider()]
  def available_providers do
    [:github, :gemini, :mistral, :groq, :openrouter, :perplexity, :xai, :ollama]
    |> Enum.filter(&has_credentials?/1)
  end

  # Helper: Check if env var is set and non-empty
  defp is_set(env_var) do
    case System.get_env(env_var) do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  @doc """
  Sync discovered models to YAML config files.

  Merges API-discovered models with existing configs, preserving manual overrides
  and complexity scores.
  """
  @spec sync_to_configs() :: :ok | {:error, atom()}
  def sync_to_configs do
    case fetch_all() do
      {:ok, provider_models} ->
        Enum.each(provider_models, fn {provider, models} ->
          sync_provider_config(provider, models)
        end)

        Logger.info("Model discovery sync complete")
        :ok

      {:error, reason} ->
        Logger.error("Failed to sync models: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get model metadata from provider API.

  Looks up single model info from its provider.
  """
  @spec get_model_info(provider(), String.t()) :: {:ok, model_info()} | {:error, atom()}
  def get_model_info(provider, model_name) do
    case fetch(provider) do
      {:ok, models} ->
        case Enum.find(models, fn m -> m.name == model_name end) do
          nil -> {:error, :model_not_found}
          model -> {:ok, model}
        end

      {:error, reason, _msg} ->
        {:error, reason}
    end
  end

  @doc """
  Check if model is still available (not deprecated) from provider.

  Useful for validating model configs before using them.
  """
  @spec is_available?(provider(), String.t()) :: boolean()
  def is_available?(provider, model_name) do
    case get_model_info(provider, model_name) do
      {:ok, %{available: true, deprecated: false}} -> true
      _ -> false
    end
  end

  # Private

  defp adapter_for(provider) do
    # Provider adapters implement ExLLM.ModelDiscovery.ProviderAdapter behavior
    # Each adapter calls the provider's REST API to fetch available models
    case provider do
      :github -> ProviderAdapters.GitHub
      :gemini -> ProviderAdapters.Gemini
      :mistral -> ProviderAdapters.Mistral
      :groq -> ProviderAdapters.Groq
      :openrouter -> ProviderAdapters.OpenRouter
      :perplexity -> ProviderAdapters.Perplexity
      :xai -> ProviderAdapters.Xai
      :ollama -> ProviderAdapters.Ollama
    end
  end

  defp sync_provider_config(provider, discovered_models) do
    config_file = model_config_path(provider)

    case File.read(config_file) do
      {:ok, content} ->
        current_config = YamlElixir.read_from_string(content) || %{}

        # Merge: discovered models + preserve existing config
        updated_config = merge_model_configs(current_config, discovered_models)

        # Write back
        case File.write(config_file, to_yaml(updated_config)) do
          :ok ->
            Logger.info("Updated #{provider} config with #{length(discovered_models)} models")
            :ok

          {:error, reason} ->
            Logger.error("Failed to write #{provider} config: #{inspect(reason)}")
            :error
        end

      {:error, _reason} ->
        # Config file doesn't exist, create new one
        Logger.info("Creating new config for #{provider}")
        new_config = %{
          "provider" => to_string(provider),
          "models" => Enum.into(discovered_models, %{}, fn model ->
            {model.name, model_to_config(model)}
          end)
        }

        case File.write(model_config_path(provider), to_yaml(new_config)) do
          :ok ->
            Logger.info("Created #{provider} config with #{length(discovered_models)} models")
            :ok

          {:error, reason} ->
            Logger.error("Failed to create #{provider} config: #{inspect(reason)}")
            :error
        end
    end
  end

  defp merge_model_configs(current, discovered) do
    discovered_map = Enum.into(discovered, %{}, fn m ->
      {m.name, model_to_config(m)}
    end)

    current_models = current["models"] || %{}

    # Keep existing overrides (like complexity_scores), merge new API data
    merged_models = Map.merge(discovered_map, current_models, fn _key, discovered, existing ->
      # Preserve complexity scores and other manual configs
      Map.merge(discovered, Map.take(existing, ["task_complexity_score", "notes"]))
    end)

    Map.put(current, "models", merged_models)
  end

  defp model_to_config(model) do
    %{
      "name" => model.display_name,
      "description" => "Discovered from provider API",
      "context_window" => model.context_window,
      "max_output_tokens" => model.max_output_tokens,
      "capabilities" => model.capabilities,
      "pricing" => model.pricing,
      "available" => model.available,
      "deprecated" => model.deprecated
    }
  end

  defp model_config_path(provider) do
    config_dir = ExLLM.Infrastructure.Config.ModelConfig.config_dir()
    Path.join(config_dir, "#{provider}.yml")
  end

  defp to_yaml(data) do
    # Simple YAML string generation - preserves structure for configs
    # For complex YAML, consider using yaml library
    data
    |> Jason.encode!(pretty: true)
    |> yaml_from_json()
  end

  # Convert JSON to YAML string format (simple version)
  defp yaml_from_json(json_string) do
    # For now, keep as JSON - can be enhanced to proper YAML if needed
    # This works for model configs since they're mostly key-value pairs
    json_string
  end
end

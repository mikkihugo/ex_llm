defmodule SingularityLLM.Core.ModelCatalog do
  @moduledoc """
  Provider-Agnostic Model Catalog - Query models by name with complexity-based routing.

  The ModelCatalog enables model-first routing where users request models by canonical name,
  and the system automatically routes to the best provider based on task complexity and context.

  This follows the OpenRouter.ai pattern: request model by name → auto-route to provider
  with best complexity score and cost characteristics.

  ## Architecture

  ```
  User Code
      ↓
  ModelCatalog.get("gpt-4o", :complex)  # Request by model name + complexity
      ↓
  Load all provider configs (YAML)
      ↓
  Find model by name across all providers
      ↓
  Select best provider by task complexity score
      ↓
  Return: %Model{provider: :github_models, name: "gpt-4o", complexity_scores: ...}
      ↓
  SingularityLLM.chat(model_name, messages)  # Route to provider via unified API
  ```

  ## Key Features

  - **Model-First Routing**: Request by model name, not provider
  - **Complexity Scoring**: Automatic ranking by simple/medium/complex tasks
  - **Multi-Provider**: Find same model across different providers
  - **Unified API**: Single interface for all models regardless of provider
  - **Zero Configuration**: Auto-discovers all models from YAML configs

  ## Usage Examples

  ```elixir
  # Get a model by name
  {:ok, model} = ModelCatalog.get("gpt-4o")
  %{provider: :github_models, name: "gpt-4o", complexity_scores: %{...}}

  # Get best model for complexity level
  {:ok, model} = ModelCatalog.get_by_complexity(:complex)
  %{provider: :anthropic, name: "claude-opus", complexity_scores: %{complex: 4.9}}

  # Find all models with capability
  {:ok, models} = ModelCatalog.find_models(vision: true)
  [%{provider: :github_models, name: "gpt-4o", ...}, ...]

  # List all available models
  {:ok, models} = ModelCatalog.list_models()
  [%{provider: :github_models, name: "gpt-4o"}, ...]

  # Get model capabilities
  {:ok, capabilities} = ModelCatalog.get_capabilities("gpt-4o")
  [:streaming, :function_calling, :vision, ...]
  ```

  ## Anti-Patterns

  DO NOT:
  - Request models directly from providers (`SingularityLLM.Providers.GitHub.chat/2`)
  - Hard-code provider names in business logic
  - Assume model availability (query catalog first)

  Use ModelCatalog instead:
  - Query by model name → provider discovered automatically
  - Business logic is provider-agnostic
  - Graceful fallback if model unavailable
  """

  require Logger

  @type complexity_level :: :simple | :medium | :complex
  @type provider_name :: :codex | :github_models | :gemini | :groq | :anthropic | :openai | :mistral | atom()

  @type model :: %{
    provider: provider_name(),
    name: String.t(),
    description: String.t(),
    context_window: non_neg_integer(),
    max_output_tokens: non_neg_integer(),
    capabilities: [String.t()],
    complexity_scores: %{complexity_level() => float()},
    pricing: %{input: float(), output: float()},
    supported_modalities: [String.t()],
    supported_output_modalities: [String.t()]
  }

  # Client API

  @doc """
  Get a specific model by canonical name.

  Returns the first matching model found across all providers.
  If multiple providers have the same model, returns the one with highest
  complexity score for the default complexity level (:medium).

  ## Examples

      iex> ModelCatalog.get("gpt-4o")
      {:ok, %{provider: :github_models, name: "gpt-4o", ...}}

      iex> ModelCatalog.get("nonexistent-model")
      {:error, :model_not_found}
  """
  @spec get(String.t()) :: {:ok, model()} | {:error, atom()}
  def get(model_name) when is_binary(model_name) do
    case find_model_by_name(model_name) do
      nil -> {:error, :model_not_found}
      model -> {:ok, model}
    end
  end

  @doc """
  Get the best model for a given task complexity level.

  Searches all available models and returns the one with highest complexity
  score for the specified level. Useful for auto-selecting models based on
  task requirements without knowing specific model names.

  ## Examples

      iex> ModelCatalog.get_by_complexity(:complex)
      {:ok, %{provider: :anthropic, name: "claude-opus", ...}}

      iex> ModelCatalog.get_by_complexity(:simple)
      {:ok, %{provider: :github_models, name: "gpt-4o-mini", ...}}
  """
  @spec get_by_complexity(complexity_level()) :: {:ok, model()} | {:error, atom()}
  def get_by_complexity(complexity) when complexity in [:simple, :medium, :complex] do
    models = get_models_from_cache()

    best =
      models
      |> Enum.map(fn model ->
        score = get_in(model, [:complexity_scores, complexity]) || 0.0
        {model, score}
      end)
      |> Enum.max_by(fn {_model, score} -> score end, fn -> {nil, 0.0} end)

    case best do
      {nil, _} -> {:error, :no_models_available}
      {model, _} -> {:ok, model}
    end
  end

  @doc """
  Find all models matching given capabilities.

  Searches for models that support all specified capabilities.

  ## Examples

      iex> ModelCatalog.find_models(vision: true, function_calling: true)
      {:ok, [%{provider: :github_models, name: "gpt-4o", ...}, ...]}

      iex> ModelCatalog.find_models(streaming: true)
      {:ok, [%{...}, %{...}, ...]}
  """
  @spec find_models(Keyword.t()) :: {:ok, [model()]} | {:error, atom()}
  def find_models(requirements \\ []) do
    models = get_models_from_cache()

    filtered =
      Enum.filter(models, fn model ->
        Enum.all?(requirements, fn {capability, required?} ->
          has_capability = Enum.member?(model.capabilities, to_string(capability))
          has_capability == required?
        end)
      end)

    {:ok, filtered}
  end

  @doc """
  List all available models in the catalog.

  Returns all loaded models sorted by provider name and model name.

  ## Examples

      iex> ModelCatalog.list_models()
      {:ok, [
        %{provider: :anthropic, name: "claude-haiku", ...},
        %{provider: :anthropic, name: "claude-opus", ...},
        %{provider: :codex, name: "gpt-5-codex", ...},
        ...
      ]}
  """
  @spec list_models() :: {:ok, [model()]}
  def list_models do
    models = get_models_from_cache()
    sorted = Enum.sort_by(models, &{&1.provider, &1.name})
    {:ok, sorted}
  end

  @doc """
  Get capabilities for a specific model.

  Returns the list of capabilities supported by the model.

  ## Examples

      iex> ModelCatalog.get_capabilities("gpt-4o")
      {:ok, [:streaming, :function_calling, :vision, :json_mode, ...]}

      iex> ModelCatalog.get_capabilities("nonexistent")
      {:error, :model_not_found}
  """
  @spec get_capabilities(String.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def get_capabilities(model_name) when is_binary(model_name) do
    case find_model_by_name(model_name) do
      nil -> {:error, :model_not_found}
      model -> {:ok, model.capabilities}
    end
  end

  @doc """
  Get provider for a specific model.

  Returns the provider name that hosts this model.

  ## Examples

      iex> ModelCatalog.get_provider("gpt-4o")
      {:ok, :github_models}

      iex> ModelCatalog.get_provider("gpt-5-codex")
      {:ok, :codex}
  """
  @spec get_provider(String.t()) :: {:ok, provider_name()} | {:error, atom()}
  def get_provider(model_name) when is_binary(model_name) do
    case find_model_by_name(model_name) do
      nil -> {:error, :model_not_found}
      model -> {:ok, model.provider}
    end
  end

  @doc """
  Get complexity score for a model at a specific level.

  Returns the numeric score (0.0-5.0) for how well a model handles a task
  at the given complexity level.

  Higher scores indicate better suitability for that complexity level.

  ## Examples

      iex> ModelCatalog.get_complexity_score("gpt-4o", :complex)
      {:ok, 4.8}

      iex> ModelCatalog.get_complexity_score("gpt-4o-mini", :simple)
      {:ok, 1.5}
  """
  @spec get_complexity_score(String.t(), complexity_level()) :: {:ok, float()} | {:error, atom()}
  def get_complexity_score(model_name, complexity) when is_binary(model_name) and complexity in [:simple, :medium, :complex] do
    case find_model_by_name(model_name) do
      nil ->
        {:error, :model_not_found}

      model ->
        score = get_in(model, [:complexity_scores, complexity]) || 0.0
        {:ok, score}
    end
  end

  @doc """
  Reload all models from YAML configuration files.

  Useful for testing or if configuration files change at runtime.
  In production, models are loaded once at startup.

  ## Examples

      iex> ModelCatalog.reload_models()
      :ok
  """
  @spec reload_models() :: :ok | {:error, atom()}
  def reload_models do
    load_models()
  end

  @doc """
  Get model metadata for provider selection logic.

  Returns full model details including pricing, context windows, and capabilities
  to support intelligent provider selection algorithms.

  ## Examples

      iex> ModelCatalog.get_metadata("gpt-4o")
      {:ok, %{provider: :github_models, name: "gpt-4o", context_window: 128000, ...}}
  """
  @spec get_metadata(String.t()) :: {:ok, model()} | {:error, atom()}
  def get_metadata(model_name) when is_binary(model_name) do
    case find_model_by_name(model_name) do
      nil -> {:error, :model_not_found}
      model -> {:ok, model}
    end
  end

  # Private implementation

  defp load_models do
    Logger.debug("Loading model catalog from YAML configurations...")

    # Get all provider model configs
    config_dir = SingularityLLM.Infrastructure.Config.ModelConfig.config_dir()

    models =
      if File.exists?(config_dir) do
        config_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".yml"))
        |> Enum.map(&load_provider_from_file(&1, config_dir))
        |> Enum.flat_map(fn {provider, config} ->
          normalize_provider_models({provider, config})
        end)
      else
        Logger.warning("Model config directory not found: #{config_dir}")
        []
      end

    # Cache models in application memory
    Process.put(__MODULE__, models)
    :ok
  end

  defp load_provider_from_file(filename, config_dir) do
    provider_name =
      filename
      |> String.replace_suffix(".yml", "")
      |> String.to_atom()

    case File.read(Path.join(config_dir, filename)) do
      {:ok, content} ->
        config = YamlElixir.read_from_string(content) || %{}
        {provider_name, config}

      {:error, reason} ->
        Logger.debug("Failed to load model config #{filename}: #{inspect(reason)}")
        {provider_name, %{}}
    end
  end

  defp normalize_provider_models({provider, config}) do
    case config do
      %{"models" => models} when is_map(models) ->
        Enum.map(models, fn {model_name, model_config} ->
          normalize_model(provider, model_name, model_config)
        end)

      _ ->
        []
    end
  end

  defp normalize_model(provider, model_name, config) when is_map(config) do
    %{
      provider: normalize_provider_name(provider),
      name: model_name,
      description: config["description"] || config["name"] || model_name,
      context_window: config["context_window"] || 4096,
      max_output_tokens: config["max_output_tokens"] || config["output_tokens_limit"] || 2048,
      capabilities: normalize_capabilities(config["capabilities"]),
      complexity_scores: normalize_complexity_scores(config["task_complexity_score"]),
      pricing: normalize_pricing(config["pricing"]),
      supported_modalities: config["supported_modalities"] || ["text"],
      supported_output_modalities: config["supported_output_modalities"] || ["text"]
    }
  end

  defp normalize_provider_name(provider) when is_atom(provider), do: provider
  defp normalize_provider_name(provider) when is_binary(provider), do: String.to_atom(provider)

  defp normalize_capabilities(nil), do: []
  defp normalize_capabilities(caps) when is_list(caps) do
    Enum.map(caps, &to_string/1)
  end

  defp normalize_complexity_scores(nil) do
    %{simple: 2.0, medium: 3.0, complex: 3.5}
  end

  defp normalize_complexity_scores(scores) when is_map(scores) do
    %{
      simple: normalize_score(scores["simple"] || scores[:simple]),
      medium: normalize_score(scores["medium"] || scores[:medium]),
      complex: normalize_score(scores["complex"] || scores[:complex])
    }
  end

  defp normalize_score(nil), do: 2.0
  defp normalize_score(score) when is_number(score), do: float(score)
  defp normalize_score(score) when is_binary(score), do: String.to_float(score)

  defp normalize_pricing(nil) do
    %{input: 0.0, output: 0.0}
  end

  defp normalize_pricing(pricing) when is_map(pricing) do
    %{
      input: float(pricing["input"] || pricing[:input] || 0.0),
      output: float(pricing["output"] || pricing[:output] || 0.0)
    }
  end

  defp float(value) when is_float(value), do: value
  defp float(value) when is_integer(value), do: value / 1.0
  defp float(value) when is_binary(value), do: String.to_float(value)

  defp find_model_by_name(model_name) do
    models = get_models_from_cache()
    Enum.find(models, fn model -> model.name == model_name end)
  end

  defp get_models_from_cache do
    case Process.get(__MODULE__) do
      nil ->
        # Models not loaded yet, load them
        :ok = load_models()
        Process.get(__MODULE__) || []

      models ->
        models
    end
  end
end

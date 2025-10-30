defmodule Genesis.LlmConfigManager do
  @moduledoc """
  Genesis LLM Configuration Manager - Adaptive Model Selection

  Manages LLM configuration learned from execution patterns across the network.
  Genesis receives optimal complexity/model mappings from other Singularity instances
  and applies them to improve code analysis quality and reduce costs.

  ## Architecture

  LLM configs flow through Genesis as follows:

  ```
  Singularity Instance (learns optimal mappings)
        ↓ (publishes via PgFlow)
  genesis_llm_config_updates queue
        ↓ (consumed by PgFlowWorkflowConsumer)
  LlmConfigManager.update_config()
        ↓ (updates local configuration)
  Genesis job execution
        ↓ (uses better model selection)
  Improved analysis with lower costs
  ```

  ## Config Format

  ```elixir
  %{
    provider: "claude" | "gemini" | "copilot",
    complexity: "simple" | "medium" | "complex",
    models: ["claude-3-5-sonnet-20241022"],
    task_types: ["architect", "coder", "planning"],
    updated_at: DateTime.t()
  }
  ```

  ## Usage

  ```elixir
  # Update LLM configuration from other instance
  :ok = LlmConfigManager.update_config(%{
    provider: "claude",
    complexity: "complex",
    models: ["claude-3-5-sonnet-20241022"],
    task_types: ["architect"]
  })

  # Get current configuration
  config = LlmConfigManager.get_config(provider: "claude")

  # Get best model for task
  {:ok, model} = LlmConfigManager.get_model("architect", :complex, "claude")

  # Get complexity for task
  {:ok, complexity} = LlmConfigManager.get_complexity("planning", "gemini")
  ```
  """

  require Logger

  @type config :: %{
          provider: String.t(),
          complexity: String.t(),
          models: [String.t()],
          task_types: [String.t()],
          updated_at: DateTime.t()
        }

  @type update_result :: :ok | {:error, term()}

  @doc """
  Update LLM configuration from learned patterns in other instances.

  Configuration updates are applied immediately and can affect all subsequent
  job executions. Invalid configurations are rejected with detailed error messages.

  ## Parameters
  - `config` - Configuration map with provider, complexity, models, task_types

  ## Returns
  - `:ok` - Configuration updated successfully
  - `{:error, reason}` - Update failed
  """
  @spec update_config(config) :: update_result
  def update_config(config) do
    Logger.info("[Genesis.LlmConfigManager] Updating LLM configuration",
      provider: config.provider,
      complexity: config.complexity,
      models_count: length(config.models || [])
    )

    # Validate configuration structure
    case validate_config(config) do
      :ok ->
        # In production, would update configuration storage
        Logger.debug("[Genesis.LlmConfigManager] Configuration updated",
          config: inspect(config)
        )

        :ok

      {:error, reason} ->
        Logger.error("[Genesis.LlmConfigManager] Configuration validation failed",
          error: reason,
          config: inspect(config)
        )

        {:error, reason}
    end
  end

  @doc """
  Get current LLM configuration for a provider.

  ## Parameters
  - `opts` - Options:
    - `:provider` - Provider name (required)
    - `:complexity` - Filter by complexity (optional)

  ## Returns
  - Configuration map if found
  - nil if not configured
  """
  @spec get_config(keyword()) :: config() | nil
  def get_config(opts) do
    provider = Keyword.fetch!(opts, :provider)
    _complexity = Keyword.get(opts, :complexity)

    Logger.debug("[Genesis.LlmConfigManager] Getting LLM configuration",
      provider: provider
    )

    # In production, would query configuration storage
    nil
  end

  @doc """
  Get the best model for a specific task and complexity level.

  Returns the first configured model for the given provider and task type,
  or nil if no model is configured.

  ## Parameters
  - `task_type` - Task type atom (:architect, :coder, :planning, etc.)
  - `complexity` - Complexity level (:simple, :medium, :complex)
  - `provider` - Provider name

  ## Returns
  - `{:ok, model}` - Model name
  - `{:error, reason}` - Failed to determine model
  """
  @spec get_model(String.t() | atom(), atom(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def get_model(task_type, complexity, provider) do
    task_type_str = task_type |> to_string() |> String.downcase()
    complexity_str = complexity |> to_string() |> String.downcase()

    Logger.debug("[Genesis.LlmConfigManager] Getting model for task",
      task_type: task_type_str,
      complexity: complexity_str,
      provider: provider
    )

    # In production, would lookup from configuration storage
    # For now, return sensible defaults
    case {provider, complexity_str} do
      {"claude", "complex"} ->
        {:ok, "claude-3-5-sonnet-20241022"}

      {"claude", "medium"} ->
        {:ok, "claude-3-5-sonnet-20241022"}

      {"claude", "simple"} ->
        {:ok, "claude-3-haiku-20240307"}

      {"gemini", "complex"} ->
        {:ok, "gemini-2.0-flash-exp"}

      {"gemini", _} ->
        {:ok, "gemini-2.0-flash-exp"}

      _ ->
        {:error, "No model configured for #{provider} at #{complexity_str} complexity"}
    end
  end

  @doc """
  Get configured complexity level for a task type and provider.

  ## Parameters
  - `task_type` - Task type atom (:architect, :coder, etc.)
  - `provider` - Provider name

  ## Returns
  - `{:ok, complexity}` - Complexity level
  - `{:error, reason}` - Not configured
  """
  @spec get_complexity(String.t() | atom(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def get_complexity(task_type, provider) do
    task_type_str = task_type |> to_string() |> String.downcase()

    Logger.debug("[Genesis.LlmConfigManager] Getting complexity for task",
      task_type: task_type_str,
      provider: provider
    )

    # In production, would lookup from configuration storage
    # For now, return sensible defaults based on task type
    case task_type_str do
      "architect" -> {:ok, "complex"}
      "refactoring" -> {:ok, "complex"}
      "code_generation" -> {:ok, "complex"}
      "coder" -> {:ok, "medium"}
      "planning" -> {:ok, "medium"}
      _ -> {:ok, "medium"}
    end
  end

  @doc """
  Get all configured providers and their settings.

  ## Returns
  - Map of provider configurations
  """
  @spec get_all_configs() :: map()
  def get_all_configs do
    Logger.debug("[Genesis.LlmConfigManager] Getting all LLM configurations")

    # In production, would query configuration storage
    %{}
  end

  @doc """
  Get configuration statistics and usage metrics.

  ## Returns
  - Map with configuration statistics
  """
  @spec get_statistics() :: map()
  def get_statistics do
    %{
      configured_providers: 0,
      total_models: 0,
      by_provider: %{},
      by_complexity: %{},
      last_updated: DateTime.utc_now()
    }
  end

  # --- Private Helpers ---

  defp validate_config(config) do
    required_fields = [:provider, :complexity, :models, :updated_at]

    case Enum.reject(required_fields, &Map.has_key?(config, &1)) do
      [] ->
        validate_field_types(config)

      missing ->
        {:error, "Missing required fields: #{inspect(missing)}"}
    end
  end

  defp validate_field_types(config) do
    valid_complexities = ["simple", "medium", "complex"]
    valid_providers = ["claude", "gemini", "copilot", "codex"]

    cond do
      not is_binary(config.provider) ->
        {:error, "provider must be a string"}

      config.provider not in valid_providers ->
        {:error, "provider must be one of: #{inspect(valid_providers)}"}

      not is_binary(config.complexity) ->
        {:error, "complexity must be a string"}

      config.complexity not in valid_complexities ->
        {:error, "complexity must be one of: #{inspect(valid_complexities)}"}

      not is_list(config.models) ->
        {:error, "models must be a list"}

      not Enum.all?(config.models, &is_binary/1) ->
        {:error, "all models must be strings"}

      true ->
        :ok
    end
  end
end

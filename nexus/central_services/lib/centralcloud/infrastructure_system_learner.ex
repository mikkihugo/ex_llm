defmodule CentralCloud.InfrastructureSystemLearner do
  @moduledoc """
  Infrastructure System Learner Behavior - Contract for infrastructure system discovery strategies.

  Defines the interface that all infrastructure system learners must implement to be used with
  the config-driven `InfrastructureSystemLearningOrchestrator`.

  ## Configuration Example

  ```elixir
  # centralcloud/config/config.exs
  config :centralcloud, :infrastructure_system_learners,
    manual_registry: %{
      module: CentralCloud.InfrastructureSystemLearners.ManualRegistry,
      enabled: true,
      priority: 5,
      description: "Direct database queries for known systems"
    },
    llm_discovery: %{
      module: CentralCloud.InfrastructureSystemLearners.LLMDiscovery,
      enabled: true,
      priority: 20,
      description: "LLM-based discovery for new systems"
    }
  ```

  ## How Learning Works

  1. **Orchestrator tries learners in priority order** (lowest number first)
  2. **Each learner returns one of**:
     - `{:ok, systems_map}` - Learning succeeded, return immediately
     - `:no_match` - This learner can't determine, try next
     - `{:error, reason}` - Hard error, stop and propagate

  ## Search Keywords

  infrastructure learning, system discovery, behavior contract, orchestration, priority-based,
  config-driven, learner strategy
  """

  require Logger

  @doc """
  Learn infrastructure systems matching the request criteria.

  Returns:
  - `{:ok, systems_map}` - Successfully learned systems
  - `:no_match` - Learner cannot handle this request
  - `{:error, reason}` - Hard error occurred
  """
  @callback learn(request :: map()) ::
    {:ok, map()} | :no_match | {:error, term()}

  @doc """
  Returns human-readable description of what this learner does.
  """
  @callback description() :: String.t()

  @doc """
  Called after successful learning to update statistics or cache.
  """
  @callback record_success(request :: map(), systems :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled learners from config, sorted by priority (ascending).

  Returns: `[{learner_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_learners do
    :centralcloud
    |> Application.get_env(:infrastructure_system_learners, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific learner type is enabled.
  """
  def enabled?(learner_type) when is_atom(learner_type) do
    learners = load_enabled_learners()
    Enum.any?(learners, fn {type, _priority, _config} -> type == learner_type end)
  end

  @doc """
  Get the module implementing a specific learner type.
  """
  def get_learner_module(learner_type) when is_atom(learner_type) do
    case Application.get_env(:centralcloud, :infrastructure_system_learners, %{})[learner_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :learner_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific learner type (lower numbers try first).

  Defaults to 100 if not specified, ensuring priority-ordered fallback.
  """
  def get_priority(learner_type) when is_atom(learner_type) do
    case Application.get_env(:centralcloud, :infrastructure_system_learners, %{})[learner_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific learner type.
  """
  def get_description(learner_type) when is_atom(learner_type) do
    case get_learner_module(learner_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown learner"
        end

      {:error, _} ->
        "Unknown learner"
    end
  end
end

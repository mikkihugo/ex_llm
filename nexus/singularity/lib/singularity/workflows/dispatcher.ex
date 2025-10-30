defmodule Singularity.Workflows.Dispatcher do
  @moduledoc """
  Workflow Dispatcher - Config-driven registry for centralized workflow management.

  Consolidates 16+ workflow implementations into a unified, data-driven dispatcher.
  All workflow definitions are stored in config and instantiated dynamically.

  ## Features

  - ✅ Centralized workflow registry
  - ✅ Config-driven workflow definitions
  - ✅ Dynamic workflow instantiation
  - ✅ Backward compatible with existing workflow modules
  - ✅ Support for pgflow and RCA workflows
  - ✅ Lazy loading and caching

  ## Usage

  ```elixir
  # Get workflow module for a type
  {:ok, workflow_module} = Dispatcher.get_workflow(:agent_improvement)

  # List all available workflows
  workflows = Dispatcher.list_workflows()

  # Create a workflow instance with config
  {:ok, workflow_def} = Dispatcher.create_workflow(:code_quality_training, %{
    agent_id: "quality-agent",
    timeout_ms: 30000
  })
  ```

  ## Configuration

  Add to `config/config.exs`:

  ```elixir
  config :singularity, :workflows,
    registry: [
      agent_improvement: Singularity.Workflows.AgentImprovementWorkflow,
      code_quality_training: Singularity.Workflows.CodeQualityTrainingWorkflow,
      # ... more workflows
    ],
    # Optional: map aliases to reduce duplication
    aliases: [
      quality: :code_quality_training,
      architecture: :architecture_learning
    ]
  ```

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Workflows.Dispatcher",
    "purpose": "Config-driven registry for unified workflow management",
    "role": "orchestrator",
    "layer": "domain_services",
    "introduced_in": "Phase B.2 Consolidation",
    "replaces": [
      "Hardcoded module references in application.ex",
      "Scattered workflow instantiation logic across agents"
    ]
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Agent[Agent/System] -->|request workflow| Dispatcher[WorkflowDispatcher]
      Dispatcher -->|lookup config| Registry[Workflow Registry]
      Registry -->|return module| Module[Workflow Module]
      Module -->|execute| Pgflow[PGFlow Executor]

      style Dispatcher fill:#90EE90
      style Registry fill:#FFD700
      style Module fill:#87CEEB
  ```

  ### Call Graph (YAML)

  ```yaml
  provides:
    - get_workflow/1 (lookup workflow module by type)
    - list_workflows/0 (list all registered workflows)
    - create_workflow/2 (instantiate workflow with config)
    - resolve_alias/1 (resolve workflow type aliases)

  called_by:
    - Singularity.Application (supervisor setup)
    - Agents (workflow instantiation)
    - Pipelines (workflow creation)
    - ML systems (workflow discovery)

  depends_on:
    - Application config (:singularity, :workflows)
    - Workflow modules (implementations)
  ```

  ### Anti-Patterns

  - ❌ DO NOT hardcode workflow module names in application.ex
  - ❌ DO NOT create workflows without going through Dispatcher
  - ❌ DO NOT duplicate workflow definitions across codebase
  - ✅ DO use Dispatcher.get_workflow/1 for all lookups
  - ✅ DO add new workflows to config registry
  - ✅ DO use aliases for commonly used workflows

  ### Search Keywords

  workflow dispatcher, workflow registry, config-driven, centralized workflow,
  pgflow integration, workflow instantiation, workflow discovery
  """

  require Logger

  @table :workflow_registry

  def init do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    load_registry_from_config()
    :ok
  rescue
    _ ->
      # Table already exists or other startup issue
      :ok
  end

  @doc """
  Load workflow registry from application config.

  Populates ETS table with workflow definitions from configuration.
  Called automatically during application startup.
  """
  def load_registry_from_config do
    registry = Application.get_env(:singularity, :workflows, %{})
    workflow_map = Map.get(registry, :registry, %{})
    aliases = Map.get(registry, :aliases, %{})

    # Store workflow module mappings
    Enum.each(workflow_map, fn {type, module} ->
      :ets.insert(@table, {{:workflow, type}, module})
    end)

    # Store aliases
    Enum.each(aliases, fn {alias_name, type} ->
      :ets.insert(@table, {{:alias, alias_name}, type})
    end)

    Logger.info("Loaded #{map_size(workflow_map)} workflows into dispatcher registry")
  end

  @doc """
  Get workflow module for a given workflow type.

  Returns {:ok, module} or {:error, :not_found}.

  ## Examples

      {:ok, module} = Dispatcher.get_workflow(:agent_improvement)
      {:ok, module} = Dispatcher.get_workflow(:quality) # resolves alias
  """
  @spec get_workflow(atom() | String.t()) :: {:ok, module()} | {:error, :not_found}
  def get_workflow(type) when is_atom(type) or is_binary(type) do
    init()

    # Resolve alias if applicable
    resolved_type = resolve_alias(type)

    case :ets.lookup(@table, {:workflow, resolved_type}) do
      [{_, module}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Resolve workflow type alias to actual type.

  Returns the resolved type, or the original type if no alias exists.

  ## Examples

      :code_quality_training = Dispatcher.resolve_alias(:quality)
      :code_quality_training = Dispatcher.resolve_alias(:code_quality_training)
  """
  @spec resolve_alias(atom() | String.t()) :: atom() | String.t()
  def resolve_alias(type) do
    case :ets.lookup(@table, {:alias, type}) do
      [{_, resolved}] -> resolved
      [] -> type
    end
  end

  @doc """
  List all registered workflows.

  Returns [{type, module}, ...].
  """
  @spec list_workflows :: [{atom(), module()}]
  def list_workflows do
    init()

    @table
    |> :ets.match_object({{:workflow, :_}, :_})
    |> Enum.map(fn {{:workflow, type}, module} -> {type, module} end)
  end

  @doc """
  Check if a workflow type is registered.

  Returns true if workflow exists, false otherwise.
  """
  @spec workflow_exists?(atom() | String.t()) :: boolean()
  def workflow_exists?(type) when is_atom(type) or is_binary(type) do
    init()
    resolved = resolve_alias(type)
    :ets.member(@table, {:workflow, resolved})
  end

  @doc """
  Create workflow instance with given config.

  Looks up workflow module and calls its workflow_definition/0 function,
  merging in provided config overrides.

  Returns workflow definition map suitable for pgflow execution.
  """
  @spec create_workflow(atom() | String.t(), map()) ::
          {:ok, map()} | {:error, :workflow_not_found | :invalid_config}
  def create_workflow(type, config \\ %{}) when is_map(config) do
    with {:ok, module} <- get_workflow(type),
         {:ok, base_def} <- safe_call_workflow_definition(module),
         :ok <- validate_config(config) do
      merged_def = merge_workflow_config(base_def, config, type)
      {:ok, merged_def}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get workflow definition from a module safely.

  Handles both pgflow.Workflow and BaseWorkflow-style definitions.
  """
  @spec safe_call_workflow_definition(module()) ::
          {:ok, map()} | {:error, :definition_failed}
  defp safe_call_workflow_definition(module) do
    if function_exported?(module, :workflow_definition, 0) do
      {:ok, module.workflow_definition()}
    else
      {:error, :definition_failed}
    end
  rescue
    _e ->
      {:error, :definition_failed}
  end

  @doc """
  Validate workflow config.

  Checks that config is a valid map.
  """
  @spec validate_config(map()) :: :ok | {:error, :invalid_config}
  defp validate_config(config) do
    if is_map(config), do: :ok, else: {:error, :invalid_config}
  end

  @doc """
  Merge provided config overrides into workflow definition.

  Updates workflow-level config with provided overrides.
  """
  @spec merge_workflow_config(map(), map(), atom()) :: map()
  defp merge_workflow_config(base_def, config_overrides, type) do
    # Merge config section with overrides
    current_config = Map.get(base_def, :config, %{})
    merged_config = Map.merge(current_config, config_overrides)

    base_def
    |> Map.put(:config, merged_config)
    |> Map.put(:type, type)
    |> Map.update(:name, Atom.to_string(type), & &1)
  end

  @doc """
  Register a new workflow dynamically.

  Useful for runtime workflow registration or testing.

  ## Examples

      :ok = Dispatcher.register_workflow(:custom_workflow, MyCustomWorkflow)
  """
  @spec register_workflow(atom(), module()) :: :ok
  def register_workflow(type, module) when is_atom(type) and is_atom(module) do
    init()
    :ets.insert(@table, {{:workflow, type}, module})
    Logger.info("Registered workflow #{type} => #{module}")
    :ok
  end

  @doc """
  Create workflow alias for easier access.

  Useful for reducing typing and making configs more readable.

  ## Examples

      :ok = Dispatcher.create_alias(:quality, :code_quality_training)
      # Now Dispatcher.get_workflow(:quality) works
  """
  @spec create_alias(atom(), atom()) :: :ok
  def create_alias(alias_name, target_type) when is_atom(alias_name) and is_atom(target_type) do
    init()
    :ets.insert(@table, {{:alias, alias_name}, target_type})
    Logger.info("Created alias #{alias_name} => #{target_type}")
    :ok
  end

  @doc """
  Record workflow pattern result from GenesisWorkflowLearner feedback.

  Used by Genesis to store proven workflow patterns for future use.
  Allows cross-instance workflow optimization and learning.

  ## Parameters
  - `workflow_type` - Workflow type
  - `pattern` - Workflow pattern result map from GenesisWorkflowLearner

  ## Examples

      :ok = Dispatcher.record_workflow_pattern(:code_quality_training, %{
        config: config,
        success_rate: 0.95,
        confidence: 0.87
      })
  """
  @spec record_workflow_pattern(atom(), map()) :: :ok | {:error, term()}
  def record_workflow_pattern(workflow_type, pattern) when is_atom(workflow_type) and is_map(pattern) do
    init()

    # Store pattern key as reference for future lookup
    pattern_key = {:workflow_pattern, workflow_type, pattern.genesis_id}
    :ets.insert(@table, {pattern_key, pattern})

    Logger.info("Recorded workflow pattern", %{
      workflow_type: workflow_type,
      genesis_id: pattern.genesis_id,
      confidence: pattern.confidence
    })

    :ok
  rescue
    e ->
      Logger.error("Failed to record workflow pattern: #{inspect(e)}")
      {:error, :record_failed}
  end

  @doc """
  Get all proven workflow patterns from Genesis.

  Returns patterns published by other instances or synthesized locally
  and proven through execution.

  ## Examples

      patterns = Dispatcher.get_proven_patterns(:code_quality_training)
  """
  @spec get_proven_patterns(atom()) :: [map()]
  def get_proven_patterns(workflow_type) when is_atom(workflow_type) do
    init()

    @table
    |> :ets.match_object({{:workflow_pattern, workflow_type, :_}, :_})
    |> Enum.map(fn {_, pattern} -> pattern end)
    |> Enum.sort_by(fn p -> p.confidence end)
    |> Enum.reverse()
  end
end

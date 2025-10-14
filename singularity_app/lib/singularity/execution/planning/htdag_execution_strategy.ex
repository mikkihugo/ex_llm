defmodule Singularity.Execution.Planning.HTDAGExecutionStrategy do
  @moduledoc """
  Ecto schema for Lua-powered HTDAG execution strategies.

  Execution strategies define how HTDAG tasks are:
  1. Decomposed into subtasks (decomposition_script)
  2. Assigned to dynamically spawned agents (agent_spawning_script)
  3. Orchestrated across multiple agents (orchestration_script)
  4. Validated for completion (completion_script)

  All logic is defined in Lua scripts stored in the database, enabling hot-reload
  of execution strategies without recompiling Elixir.

  ## Pattern Matching

  Strategies match tasks via regex patterns on task descriptions:

      iex> strategy = %HTDAGExecutionStrategy{
      ...>   name: "secure_feature_development",
      ...>   task_pattern: "(implement|build|create).*(auth|security|payment)"
      ...> }
      iex> matches?("Build user authentication", strategy.task_pattern)
      true

  ## Lua Script Types

  ### 1. Decomposition Script
  - Input: `context.task` (description, complexity, type, etc.)
  - Output: `{subtasks: [...], strategy: "sequential", reasoning: "..."}`
  - Purpose: Break complex tasks into HTDAG subtasks

  ### 2. Agent Spawning Script
  - Input: `context.task`, `context.available_agents`, `context.resources`
  - Output: `{agents: [...], orchestration: {...}, reasoning: "..."}`
  - Purpose: Determine which agents to spawn/reuse for task

  ### 3. Orchestration Script
  - Input: `context.task`, `context.agents`, `context.subtasks`
  - Output: `{execution_plan: [...], coordination: {...}, reasoning: "..."}`
  - Purpose: Define how agents collaborate (parallel, sequential, pipeline)

  ### 4. Completion Script
  - Input: `context.task`, `context.execution_results`, `context.tests`, `context.code_quality`
  - Output: `{status: "completed"|"needs_rework", confidence: 0.0-1.0, reasoning: "..."}`
  - Purpose: Intelligent task completion validation

  ## Usage

      # Create new strategy
      {:ok, strategy} = %HTDAGExecutionStrategy{}
      |> HTDAGExecutionStrategy.changeset(%{
        name: "standard_development",
        description: "Standard feature development with testing",
        task_pattern: "(implement|build|create).*(feature|component)",
        decomposition_script: File.read!("strategies/standard_decomposition.lua"),
        agent_spawning_script: File.read!("strategies/standard_agents.lua"),
        orchestration_script: File.read!("strategies/standard_orchestration.lua"),
        completion_script: File.read!("strategies/standard_completion.lua")
      })
      |> Repo.insert()

      # Find strategy for task
      HTDAGStrategyLoader.get_strategy_for_task("Build user profile feature")
      # => {:ok, %HTDAGExecutionStrategy{name: "standard_development", ...}}

      # Execute decomposition
      HTDAGLuaExecutor.decompose_task(strategy, task, context)
      # => {:ok, [%{description: "...", estimated_complexity: 3.0, ...}, ...]}
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "htdag_execution_strategies" do
    # Identity
    field :name, :string
    field :description, :string
    field :task_pattern, :string

    # Lua scripts for each execution phase
    field :decomposition_script, :string
    field :agent_spawning_script, :string
    field :orchestration_script, :string
    field :completion_script, :string

    # Metadata
    field :status, :string, default: "active"
    field :version, :integer, default: 1
    field :priority, :integer, default: 0

    # Performance tracking
    field :usage_count, :integer, default: 0
    field :success_rate, :float, default: 1.0
    field :avg_execution_time_ms, :float, default: 0.0

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating execution strategies.

  ## Required Fields
  - `:name` - Unique strategy name
  - `:task_pattern` - Regex pattern to match tasks
  - At least one Lua script (decomposition, agent_spawning, orchestration, or completion)

  ## Optional Fields
  - `:description` - Human-readable description
  - `:status` - "active" (default) or "inactive"
  - `:priority` - Higher priority strategies matched first (default: 0)
  - `:version` - Version number for evolution tracking (default: 1)

  ## Examples

      # Minimal strategy (decomposition only)
      changeset(%HTDAGExecutionStrategy{}, %{
        name: "simple_decomposer",
        task_pattern: ".*",
        decomposition_script: "return {subtasks: {...}}"
      })

      # Full strategy (all scripts)
      changeset(%HTDAGExecutionStrategy{}, %{
        name: "complete_strategy",
        task_pattern: "(build|create).*",
        decomposition_script: "...",
        agent_spawning_script: "...",
        orchestration_script: "...",
        completion_script: "...",
        priority: 10
      })
  """
  def changeset(strategy, attrs) do
    strategy
    |> cast(attrs, [
      :name,
      :description,
      :task_pattern,
      :decomposition_script,
      :agent_spawning_script,
      :orchestration_script,
      :completion_script,
      :status,
      :version,
      :priority
    ])
    |> validate_required([:name, :task_pattern])
    |> validate_at_least_one_script()
    |> validate_inclusion(:status, ["active", "inactive"])
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_number(:version, greater_than: 0)
    |> validate_task_pattern()
    |> unique_constraint(:name)
  end

  @doc """
  Changeset for updating performance statistics after execution.
  """
  def update_stats_changeset(strategy, stats) do
    strategy
    |> cast(stats, [:usage_count, :success_rate, :avg_execution_time_ms])
    |> validate_number(:success_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:avg_execution_time_ms, greater_than_or_equal_to: 0.0)
  end

  ## Private Validations

  defp validate_at_least_one_script(changeset) do
    scripts = [
      get_field(changeset, :decomposition_script),
      get_field(changeset, :agent_spawning_script),
      get_field(changeset, :orchestration_script),
      get_field(changeset, :completion_script)
    ]

    if Enum.any?(scripts, &(&1 != nil && String.trim(&1) != "")) do
      changeset
    else
      add_error(changeset, :decomposition_script,
        "at least one Lua script must be provided (decomposition, agent_spawning, orchestration, or completion)"
      )
    end
  end

  defp validate_task_pattern(changeset) do
    case get_field(changeset, :task_pattern) do
      nil ->
        changeset

      pattern ->
        case Regex.compile(pattern) do
          {:ok, _regex} ->
            changeset

          {:error, reason} ->
            add_error(changeset, :task_pattern, "invalid regex: #{inspect(reason)}")
        end
    end
  end
end

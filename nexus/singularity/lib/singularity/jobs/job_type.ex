defmodule Singularity.Jobs.JobType do
  @moduledoc """
  Job Type Behavior - Contract for all background job operations.

  Defines the interface that all Oban background jobs must implement to be managed
  by the config-driven `JobOrchestrator`.

  Consolidates scattered job implementations (MetricsAggregationWorker, PatternMinerJob,
  AgentEvolutionWorker, etc.) into a unified system with consistent configuration and
  orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Jobs.JobType",
    "purpose": "Behavior contract for config-driven job orchestration",
    "type": "behavior/protocol",
    "layer": "infrastructure",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Config["Config: job_types"]
      Orchestrator["JobOrchestrator"]
      Behavior["JobType Behavior"]

      Config -->|enabled: true| Job1["MetricsAggregationJob"]
      Config -->|enabled: true| Job2["PatternMinerJob"]
      Config -->|enabled: true| Job3["AgentEvolutionJob"]
      Config -->|enabled: true| Job4["CacheMaintenanceJob"]

      Orchestrator -->|discover| Behavior
      Behavior -->|implemented by| Job1
      Behavior -->|implemented by| Job2
      Behavior -->|implemented by| Job3
      Behavior -->|implemented by| Job4

      Job1 -->|perform/1| Result1["Metrics Aggregated"]
      Job2 -->|perform/1| Result2["Patterns Mined"]
      Job3 -->|perform/1| Result3["Agent Improved"]
      Job4 -->|perform/1| Result4["Cache Clean"]
  ```

  ## Configuration Example

  ```elixir
  # config/config.exs
  config :singularity, :job_types,
    metrics_aggregation: %{
      module: Singularity.Jobs.MetricsAggregationWorker,
      enabled: true,
      queue: :default,
      max_attempts: 2,
      schedule: "*/5 * * * *",  # Every 5 minutes
      description: "Aggregate agent metrics for feedback loop"
    },
    pattern_miner: %{
      module: Singularity.Jobs.PatternMinerJob,
      enabled: true,
      queue: :pattern_mining,
      max_attempts: 3,
      priority: 2,
      schedule: "0 2 * * *",  # Daily at 2 AM
      description: "Mine code patterns from codebase"
    },
    agent_evolution: %{
      module: Singularity.Jobs.AgentEvolutionWorker,
      enabled: true,
      queue: :default,
      max_attempts: 2,
      schedule: "0 * * * *",  # Every hour
      description: "Apply agent improvements"
    }
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** create hardcoded job lists
  - ❌ **DO NOT** scatter job definitions across config files
  - ❌ **DO NOT** call jobs directly instead of through orchestrator
  - ✅ **DO** always register jobs in config.exs `:job_types`
  - ✅ **DO** implement jobs as `@behaviour JobType` modules
  - ✅ **DO** use `JobOrchestrator.enqueue/2` for job scheduling
  - ✅ **DO** use `JobOrchestrator.get_job_types_info()` to list jobs

  ## Job Keywords

  background job, Oban worker, job scheduling, cron jobs, periodic tasks,
  async processing, job retry, job queue, job coordination, batch processing
  """

  require Logger

  @doc """
  Returns the atom identifier for this job type.

  Examples: `:metrics_aggregation`, `:pattern_miner`, `:agent_evolution`
  """
  @callback job_type() :: atom()

  @doc """
  Returns human-readable description of what this job does.
  """
  @callback description() :: String.t()

  @doc """
  Returns the Oban queue this job should run in.

  Examples: `:default`, `:pattern_mining`, `:training`
  """
  @callback queue() :: atom()

  @doc """
  Returns the Oban module (the actual Oban.Worker implementation).
  """
  @callback oban_module() :: module()

  @doc """
  Returns list of capabilities/features this job provides.

  Examples: `["metrics_aggregation", "telemetry_processing"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Execute the job (called by Oban).

  Delegates to the actual Oban.Worker implementation.
  """
  @callback perform(job :: Oban.Job.t()) :: Oban.Worker.result()

  @doc """
  Learn from job execution results.

  Called after job completion to update heuristics/patterns.
  """
  @callback learn_from_job(result :: map()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled job types from config.

  Returns: `[{job_type, config_map}, ...]`
  """
  def load_enabled_jobs do
    :singularity
    |> Application.get_env(:job_types, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.to_list()
  end

  @doc """
  Check if a specific job type is enabled.
  """
  def enabled?(job_type) when is_atom(job_type) do
    jobs = load_enabled_jobs()
    Enum.any?(jobs, fn {type, _config} -> type == job_type end)
  end

  @doc """
  Get the module implementing a specific job type.
  """
  def get_job_module(job_type) when is_atom(job_type) do
    case Application.get_env(:singularity, :job_types, %{})[job_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :job_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get description for a specific job type.
  """
  def get_description(job_type) when is_atom(job_type) do
    case get_job_module(job_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :description, 0) do
          module.description()
        else
          "Unknown job"
        end

      {:error, _} ->
        "Unknown job"
    end
  end

  @doc """
  Get queue for a specific job type.
  """
  def get_queue(job_type) when is_atom(job_type) do
    case Application.get_env(:singularity, :job_types, %{})[job_type] do
      %{queue: queue} -> {:ok, queue}
      _ -> {:ok, :default}
    end
  end

  @doc """
  Get job configuration.
  """
  def get_config(job_type) when is_atom(job_type) do
    case Application.get_env(:singularity, :job_types, %{})[job_type] do
      config when is_map(config) -> {:ok, config}
      nil -> {:error, :job_not_configured}
      _ -> {:error, :invalid_config}
    end
  end
end

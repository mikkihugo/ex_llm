defmodule Singularity.Jobs.JobOrchestrator do
  @moduledoc """
  Job Orchestrator - Config-driven orchestration of all background jobs.

  Automatically discovers and manages any enabled Oban job (Metrics, Pattern Mining,
  Agent Evolution, Cache Maintenance, etc.). Consolidates scattered job definitions
  into a unified, config-driven system.

  ## Quick Start

  ```elixir
  # Enqueue a job
  {:ok, job} = JobOrchestrator.enqueue(:pattern_miner, %{
    codebase_path: "/path/to/code",
    languages: ["elixir", "rust"]
  })

  # Check job status
  {:ok, status} = JobOrchestrator.get_job_status(:pattern_miner)
  # => %{queued: 1, executing: 0, completed: 5}

  # List all configured jobs
  JobOrchestrator.get_job_types_info()
  ```

  ## Public API

  - `enqueue(job_type, args, opts)` - Enqueue a background job
  - `get_job_status(job_type)` - Get execution statistics
  - `get_job_types_info/0` - List all configured job types
  - `enabled?(job_type)` - Check if job type is enabled

  ## Key Features

  - **Config-driven discovery** - Jobs auto-registered from config
  - **Queue management** - Route jobs to appropriate Oban queues
  - **Status tracking** - Real-time job execution monitoring
  - **Learning capability** - Optional feedback from job results

  ## Error Handling

  Returns `{:ok, job}` on success or `{:error, reason}` on failure:
  - `:job_type_not_configured` - Unknown job type
  - `:invalid_job_result` - Job creation failed
  - `:enqueue_failed` - Oban insertion error

  ---

  ## AI Navigation Metadata

  The sections below provide structured metadata for AI assistants,
  graph databases (Neo4j), and vector databases (pgvector).

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Jobs.JobOrchestrator",
    "purpose": "Config-driven orchestration of all background jobs via Oban",
    "role": "orchestrator",
    "layer": "infrastructure",
    "alternatives": {
      "Oban": "Direct Oban usage - use JobOrchestrator for unified job management",
      "JobType": "Internal behavior contract - use JobOrchestrator as public API",
      "Individual job workers": "Specific job implementations - managed by JobOrchestrator"
    },
    "disambiguation": {
      "vs_oban": "JobOrchestrator provides config-driven abstraction over Oban with job discovery",
      "vs_job_type": "JobType defines behavior contract; JobOrchestrator orchestrates all job types",
      "vs_workers": "Workers implement specific job logic; JobOrchestrator manages their lifecycle"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Request[Job Enqueue Request]
      Orchestrator[JobOrchestrator.enqueue/3]
      Config[Config: job_types]
      JobType[JobType behavior]

      Orchestrator -->|1. loads| Config
      Config -->|enabled: true| Metrics[MetricsAggregation]
      Config -->|enabled: true| PatternMiner[PatternMiner]
      Config -->|enabled: true| Evolution[AgentEvolution]

      Orchestrator -->|2. validates via| JobType
      JobType -->|3. get module| Metrics
      JobType -->|3. get module| PatternMiner
      JobType -->|3. get module| Evolution

      Metrics -->|4. new/1| ObanJob[Oban.Job]
      PatternMiner -->|4. new/1| ObanJob
      Evolution -->|4. new/1| ObanJob

      ObanJob -->|5. insert| Repo[Singularity.Repo]
      Repo -->|6. job queued| DB[(PostgreSQL)]

      Request -->|input| Orchestrator
      Orchestrator -->|7. return| Result[{:ok, job}]

      style Orchestrator fill:#90EE90
      style Config fill:#FFD700
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Jobs.JobType
      function: load_enabled_jobs/0
      purpose: Discover all enabled job types from config
      critical: true

    - module: Singularity.Jobs.JobType
      function: get_job_module/1
      purpose: Get Oban worker module for job type
      critical: true

    - module: "[Job Worker Modules]"
      function: new/1
      purpose: Create Oban.Job struct with args
      critical: true

    - module: Oban
      function: insert/2
      purpose: Insert job into PostgreSQL queue
      critical: true

    - module: Singularity.Repo
      function: aggregate/2
      purpose: Query job status counts
      critical: false

    - module: Logger
      function: "[info|error]/2"
      purpose: Log job lifecycle events
      critical: false

  called_by:
    - module: Singularity.Agents.*
      purpose: Schedule agent tasks as background jobs
      frequency: high

    - module: Singularity.Execution.*
      purpose: Long-running execution as jobs
      frequency: medium

    - module: Singularity.NATS.JobRouter
      purpose: NATS-triggered job scheduling
      frequency: medium

  depends_on:
    - Oban (MUST be started in supervision tree)
    - Singularity.Repo (MUST be available for DB access)
    - Config :job_types (MUST be configured)
    - Job worker modules (MUST implement Oban.Worker)

  supervision:
    supervised: false
    reason: "Stateless module - delegates to Oban for job supervision"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT call Oban.insert directly for Singularity jobs
  **Why:** JobOrchestrator provides unified job management with config-driven discovery.
  **Use instead:**
  ```elixir
  # ❌ WRONG
  %MyJob{args: %{}}
  |> MyJob.new(%{})
  |> Oban.insert()

  # ✅ CORRECT
  JobOrchestrator.enqueue(:my_job, %{})
  ```

  #### ❌ DO NOT hardcode job worker modules
  **Why:** Config-driven discovery enables better job evolution.
  **Use instead:**
  ```elixir
  # ❌ WRONG - hardcoded job dispatch
  case job_type do
    :metrics -> MetricsAggregation.new(args)
    :pattern -> PatternMiner.new(args)
  end

  # ✅ CORRECT - use orchestrator
  JobOrchestrator.enqueue(job_type, args)
  ```

  #### ❌ DO NOT create separate job management modules
  **Why:** JobOrchestrator already exists!
  **Use instead:** Configure new job types in `config/config.exs`:
  ```elixir
  config :singularity, :job_types,
    my_new_job: %{
      module: Singularity.Jobs.MyNewJob,
      enabled: true,
      queue: :default,
      max_attempts: 3
    }
  ```

  ### Search Keywords

  job orchestrator, background jobs, oban, job queue, async tasks,
  job scheduling, job management, config driven jobs, job discovery,
  job status, job tracking, job lifecycle, worker orchestration
  """

  require Logger
  import Ecto.Query
  alias Singularity.Jobs.JobType
  alias Singularity.Repo

  @doc """
  Get all configured job types and their status.
  """
  def get_job_types_info do
    JobType.load_enabled_jobs()
    |> Enum.map(fn {type, config} ->
      description = JobType.get_description(type)
      {:ok, queue} = JobType.get_queue(type)

      %{
        name: type,
        enabled: true,
        description: description,
        module: config[:module],
        queue: queue,
        max_attempts: config[:max_attempts] || 1,
        priority: config[:priority],
        schedule: config[:schedule],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Check if a specific job type is enabled.
  """
  def enabled?(job_type) when is_atom(job_type) do
    JobType.enabled?(job_type)
  end

  @doc """
  Enqueue a job to Oban.

  ## Options

  - `:priority` - Job priority (default: from config or 0)
  - `:scheduled_at` - When to run the job (default: immediately)
  - `:replace_args` - Replace job args if job already queued

  ## Returns

  `{:ok, job}` or `{:error, reason}`
  """
  def enqueue(job_type, args \\ %{}, opts \\ []) when is_atom(job_type) and is_map(args) do
    try do
      case JobType.get_job_module(job_type) do
        {:ok, module} ->
          Logger.info("Enqueuing job",
            job_type: job_type,
            module: module,
            args: inspect(args)
          )

          # Create and insert job via Oban
          job_args = ensure_string_keys(args)

          case module.new(job_args) do
            %Oban.Job{} = job ->
              # Apply options
              job = apply_job_options(job, opts)
              Logger.debug("Enqueueing job", job_type: job_type)
              Oban.insert(Repo, job)

            {:error, reason} ->
              Logger.error("Job creation failed", job_type: job_type, reason: inspect(reason))
              {:error, reason}

            other ->
              Logger.warning("Unexpected job creation result",
                job_type: job_type,
                result: inspect(other)
              )

              {:error, :invalid_job_result}
          end

        {:error, reason} ->
          Logger.error("Job type not configured",
            job_type: job_type,
            reason: inspect(reason)
          )

          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Job enqueue failed",
          job_type: job_type,
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, :enqueue_failed}
    end
  end

  @doc """
  Get status of a job type (count of queued/executing/completed).
  """
  def get_job_status(job_type) when is_atom(job_type) do
    try do
      case JobType.get_job_module(job_type) do
        {:ok, module} ->
          worker_name = to_string(module)

          # Count jobs in database by state
          completed_count =
            Repo.aggregate(
              from(j in Oban.Job,
                where: j.worker == ^worker_name and j.state == "completed"
              ),
              :count
            ) || 0

          queued_count =
            Repo.aggregate(
              from(j in Oban.Job,
                where: j.worker == ^worker_name and j.state == "available"
              ),
              :count
            ) || 0

          executing_count =
            Repo.aggregate(
              from(j in Oban.Job,
                where: j.worker == ^worker_name and j.state == "executing"
              ),
              :count
            ) || 0

          {:ok,
           %{
             job_type: job_type,
             module: module,
             completed: completed_count,
             queued: queued_count,
             executing: executing_count
           }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Job status query failed",
          job_type: job_type,
          error: inspect(e)
        )

        {:error, :status_query_failed}
    end
  end

  @doc """
  Learn from job execution results.
  """
  def learn_from_job(job_type, job_result) when is_atom(job_type) do
    case JobType.get_job_module(job_type) do
      {:ok, module} ->
        Logger.info("Learning from job execution", job_type: job_type)

        if function_exported?(module, :learn_from_job, 1) do
          module.learn_from_job(job_result)
        else
          :ok
        end

      {:error, reason} ->
        Logger.error("Cannot learn from job",
          job_type: job_type,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @doc """
  Get capabilities for a specific job type.
  """
  def get_capabilities(job_type) when is_atom(job_type) do
    case JobType.get_job_module(job_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp apply_job_options(job, opts) do
    job
    |> maybe_set_priority(Keyword.get(opts, :priority))
    |> maybe_set_scheduled_at(Keyword.get(opts, :scheduled_at))
    |> maybe_set_replace_args(Keyword.get(opts, :replace_args))
  end

  defp maybe_set_priority(job, nil), do: job

  defp maybe_set_priority(job, priority) when is_integer(priority) do
    %{job | priority: priority}
  end

  defp maybe_set_scheduled_at(job, nil), do: job

  defp maybe_set_scheduled_at(job, %DateTime{} = scheduled_at) do
    %{job | scheduled_at: scheduled_at}
  end

  defp maybe_set_replace_args(job, nil), do: job

  defp maybe_set_replace_args(job, true) do
    %{job | replace_args: true}
  end

  defp ensure_string_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end

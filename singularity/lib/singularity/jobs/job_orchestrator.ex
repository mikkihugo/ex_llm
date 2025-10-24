defmodule Singularity.Jobs.JobOrchestrator do
  @moduledoc """
  Job Orchestrator - Config-driven orchestration of all background jobs.

  Automatically discovers and manages any enabled Oban job (Metrics, Pattern Mining,
  Agent Evolution, Cache Maintenance, etc.). Consolidates scattered job definitions
  into a unified, config-driven system.

  Provides centralized job management including:
  - Enqueuing jobs to appropriate queues
  - Managing job schedules and priorities
  - Tracking job execution status
  - Handling job dependencies
  - Learning from job results

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Jobs.JobOrchestrator",
    "purpose": "Config-driven orchestration of all background jobs",
    "layer": "infrastructure",
    "status": "production"
  }
  ```

  ## Usage Examples

  ```elixir
  # List all configured jobs
  JobOrchestrator.get_job_types_info()
  # => [
  #   %{name: :metrics_aggregation, enabled: true, queue: :default, ...},
  #   %{name: :pattern_miner, enabled: true, queue: :pattern_mining, ...},
  #   ...
  # ]

  # Check if a job is enabled
  JobOrchestrator.enabled?(:metrics_aggregation)
  # => true

  # Enqueue a specific job
  {:ok, job} = JobOrchestrator.enqueue(:pattern_miner, %{
    codebase_path: "/path/to/code",
    languages: ["elixir", "rust"]
  })

  # Enqueue with options
  {:ok, job} = JobOrchestrator.enqueue(:agent_evolution,
    %{iteration: 42},
    priority: 10,
    scheduled_at: DateTime.utc_now()
  )

  # Get job status
  {:ok, status} = JobOrchestrator.get_job_status(:metrics_aggregation)

  # Disable a job (via config change)
  Application.put_env(:singularity, :job_types, %{
    metrics_aggregation: %{enabled: false, ...}
  })
  ```
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
              Logger.warn("Unexpected job creation result",
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

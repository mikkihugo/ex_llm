defmodule Singularity.Adapters.ObanAdapter do
  @moduledoc """
  Oban Adapter - Background job execution via Oban.

  Implements @behaviour TaskAdapter for queuing and executing tasks as background jobs
  using Oban job processing system.

  ## Features

  - Async background job execution
  - Configurable queues and retries
  - Scheduled job support
  - Job progress tracking

  ## Capabilities

  - `["async", "background_jobs", "retries", "scheduled"]`
  """

  @behaviour Singularity.Execution.TaskAdapter

  require Logger

  @impl Singularity.Execution.TaskAdapter
  def adapter_type, do: :oban_adapter

  @impl Singularity.Execution.TaskAdapter
  def description do
    "Background job execution via Oban"
  end

  @impl Singularity.Execution.TaskAdapter
  def capabilities do
    ["async", "background_jobs", "retries", "scheduled", "distributed"]
  end

  @impl Singularity.Execution.TaskAdapter
  def execute(task, opts \\ []) do
    Logger.debug("Oban adapter: Queuing task", task_type: task[:type])

    # Extract task details
    task_type = task[:type]
    args = task[:args] || %{}
    task_opts = task[:opts] || []

    # Map task type to Oban job module
    job_module = get_job_module(task_type)

    unless job_module do
      Logger.warning("Oban adapter: No job module for task type", task_type: task_type)
      {:error, :not_suitable}
    else
      # Queue job via JobOrchestrator
      case Singularity.Execution.JobOrchestrator.enqueue(task_type, args) do
        {:ok, job} ->
          Logger.debug("Oban adapter: Job queued",
            task_type: task_type,
            job_id: job.id
          )

          {:ok, "oban:#{job.id}"}

        {:error, reason} ->
          Logger.error("Oban adapter: Failed to queue job", reason: inspect(reason))
          {:error, reason}
      end
    end
  end

  defp get_job_module(task_type) when is_atom(task_type) do
    # Map task types to their Oban job modules
    # Example: :pattern_analysis → Singularity.Jobs.PatternAnalysisJob
    module_name =
      task_type
      |> Atom.to_string()
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join("")

    try do
      module = Module.concat([Singularity, Jobs, "#{module_name}Job"])
      if Code.ensure_loaded?(module), do: module, else: nil
    rescue
      _ -> nil
    end
  end
end

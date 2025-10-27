defmodule Singularity.Bootstrap.SetupBootstrap do
  @moduledoc """
  Bootstrap one-time setup tasks on application startup

  Runs all one-time setup jobs (knowledge migration, RAG setup, etc.)
  using Oban with unique constraints to ensure they only run once.

  ## Setup Jobs (Priority Order)

  1. **Knowledge Migration** (Priority 100) - Load JSON artifacts to database
  2. **Templates Data Load** (Priority 95) - Load templates_data/ to JSONB
  3. **Graph Populate** (Priority 80) - Populate dependency arrays (5-100x faster queries)
  4. **Code Ingest** (Priority 85) - Parse codebase for semantic search
  5. **RAG Setup** (Priority 70) - Full RAG system initialization

  Note: **Planning Seed** runs via pg_cron (seed_work_plan stored procedure)

  ## How It Works

  - Runs when application starts
  - Uses Oban with `unique_for: :infinity` to run only once
  - Gracefully handles idempotent operations
  - Logs progress to application logs
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    Logger.info("Scheduling one-time setup jobs...")

    # Schedule all setup jobs with unique constraints
    # They will run in order of queue priority
    schedule_setup_jobs()

    {:ok, %{}}
  end

  defp schedule_setup_jobs do
    jobs = [
      # 1. Load knowledge artifacts from JSON
      %{
        module: Singularity.Jobs.KnowledgeMigrateWorker,
        args: %{},
        unique_key: "setup:knowledge_migrate",
        priority: 100
      },
      # 2. Load templates_data/ into PostgreSQL
      %{
        module: Singularity.Jobs.TemplatesDataLoadWorker,
        args: %{},
        unique_key: "setup:templates_data_load",
        priority: 95
      },
      # NOTE: Planning Seed moved to pg_cron (seed_work_plan stored procedure)
      # - More efficient: Pure SQL, no Elixir overhead
      # - Idempotent: Uses ON CONFLICT DO NOTHING
      # - Scheduled: Runs automatically via pg_cron

      # 3. Populate dependency graph arrays (for 5-100x faster queries)
      %{
        module: Singularity.Jobs.GraphPopulateWorker,
        args: %{},
        unique_key: "setup:graph_populate",
        priority: 80
      },

      # 4. Ingest codebase for semantic search
      %{
        module: Singularity.Jobs.CodeIngestWorker,
        args: %{},
        unique_key: "setup:code_ingest",
        priority: 85
      },
      # 4. Full RAG setup (runs last - depends on templates and code)
      %{
        module: Singularity.Jobs.RagSetupWorker,
        args: %{},
        unique_key: "setup:rag_setup",
        priority: 70
      }
    ]

    Enum.each(jobs, fn job_spec ->
      insert_unique_job(job_spec)
    end)
  end

  defp insert_unique_job(spec) do
    %{
      module: module,
      args: args,
      unique_key: unique_key,
      priority: priority
    } = spec

    case module.new(args, unique_for: :infinity, priority: priority)
         |> Oban.insert() do
      {:ok, job} ->
        Logger.info("Scheduled setup job: #{unique_key} (job_id: #{job.id})")

      {:error, :unique_constraint_violation} ->
        Logger.info("Setup job already exists: #{unique_key}")

      {:error, reason} ->
        Logger.warning("Failed to schedule #{unique_key}: #{inspect(reason)}")
    end
  end
end

defmodule Genesis.Application do
  @moduledoc """
  Genesis Application - Isolated Improvement Sandbox

  Genesis is a separate Elixir application that safely executes improvement
  experiments requested by Singularity instances. It provides a sandboxed
  environment for testing high-risk changes without affecting production.

  ## Architecture

  Genesis runs with complete isolation:
  - Separate PostgreSQL database (genesis)
  - Reads job requests from CentralCloud's shared_queue (pgmq) database
  - Publishes job results back to shared_queue
  - Separate Git history
  - Aggressive hotreload (can safely test breaking changes)
  - Auto-rollback on regression detection

  ## Supervision Strategy

  Uses `:one_for_one` strategy because each service is independent.
  Database failures are logged but don't cascade to other services.

  ## Key Services

  - Genesis.Repo - Isolated database connection (experiments, isolation)
  - Genesis.SharedQueueConsumer - Polls shared_queue for job_requests, publishes job_results
  - Genesis.IsolationManager - Manages sandboxed environments
  - Genesis.RollbackManager - Handles git-based rollback
  - Genesis.MetricsCollector - Tracks experiment outcomes
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Genesis Application (Improvement Sandbox)...")

    children = [
      # Foundation: Database (isolated genesis)
      Genesis.Repo,

      # Infrastructure: Background jobs (Oban handles cron scheduling via plugin)
      {Oban, name: Genesis.Oban, repo: Genesis.Repo},

      # Task supervision for timeout handling
      {Task.Supervisor, name: Genesis.TaskSupervisor},

      # Services: Job execution and isolation
      # SharedQueueConsumer polls pgmq for job_requests and publishes results
      Genesis.SharedQueueConsumer,
      Genesis.IsolationManager,
      Genesis.RollbackManager,
      Genesis.MetricsCollector
    ]

    opts = [strategy: :one_for_one, name: Genesis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

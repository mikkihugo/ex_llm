defmodule Genesis.Application do
  @moduledoc """
  Genesis Application - Isolated Improvement Sandbox

  Genesis is a separate Elixir application that safely executes improvement
  experiments requested by Singularity instances. It provides a sandboxed
  environment for testing high-risk changes without affecting production.

  ## Architecture

  Genesis runs with complete isolation:
  - Separate PostgreSQL database (genesis_db)
  - Separate NATS subscriptions (genesis.* subjects)
  - Separate Git history
  - Aggressive hotreload (can safely test breaking changes)
  - Auto-rollback on regression detection

  ## Supervision Strategy

  Uses `:one_for_one` strategy because each service is independent.
  Database failures are logged but don't cascade to other services.

  ## Key Services

  - Genesis.Repo - Isolated database connection
  - Genesis.NatsClient - NATS messaging subscriber
  - Genesis.ExperimentRunner - Receives and executes experiment requests
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
      # Foundation: Database (isolated genesis_db)
      Genesis.Repo,

      # Infrastructure: Background jobs & messaging
      Oban,
      Genesis.Scheduler,

      # Services: Experiment execution and isolation
      Genesis.NatsClient,
      Genesis.IsolationManager,
      Genesis.RollbackManager,
      Genesis.MetricsCollector,
      Genesis.ExperimentRunner
    ]

    opts = [strategy: :one_for_one, name: Genesis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

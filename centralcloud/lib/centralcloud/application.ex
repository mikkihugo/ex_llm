defmodule Centralcloud.Application do
  @moduledoc """
  Central Cloud Application
  
  The global Elixir service that coordinates all Singularity instances.
  Central Cloud now runs primarily on BEAM processes, with optional Rust
  engines accessed over NATS only when needed for heavy workloads.
  """

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting Central Cloud Application...")

    children = [
      # Foundation: Database
      Centralcloud.Repo,

      # Infrastructure: Background jobs & scheduling
      Oban,                             # Background job queue for aggregation, sync
      Centralcloud.Scheduler,           # Quantum scheduler for periodic global tasks

      # Global services
      Centralcloud.NatsClient,          # NATS messaging (for subscriptions)
      Centralcloud.KnowledgeCache,      # ETS-based cache
      Centralcloud.TemplateService,     # Template management
      Centralcloud.FrameworkLearningAgent,  # Learn from external packages
      Centralcloud.IntelligenceHub,     # Aggregate intelligence from all instances
    ]

    opts = [strategy: :one_for_one, name: Centralcloud.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

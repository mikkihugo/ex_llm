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
      # Database
      Centralcloud.Repo,

      # NATS client
      Centralcloud.NatsClient,

      # Global services
      Centralcloud.KnowledgeCache,             # NEW: ETS-based cache
      Centralcloud.TemplateService,
      Centralcloud.FrameworkLearningAgent,
      Centralcloud.IntelligenceHub,            # NEW: Replaces Rust service (handles own subscriptions)
    ]

    opts = [strategy: :one_for_one, name: Centralcloud.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

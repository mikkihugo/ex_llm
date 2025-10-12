defmodule CentralCloud.Application do
  @moduledoc """
  Central Cloud Application
  
  The global Elixir service that coordinates all Singularity instances.
  Uses Rust services for heavy processing and provides global intelligence.
  """

  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("Starting Central Cloud Application...")

    children = [
      # Database
      CentralCloud.Repo,

      # NATS client
      CentralCloud.NatsClient,

      # Global services
      CentralCloud.KnowledgeCache,             # NEW: ETS-based cache
      CentralCloud.TemplateService,
      CentralCloud.FrameworkLearningAgent,
      CentralCloud.IntelligenceHub,            # NEW: Replaces Rust service
      CentralCloud.IntelligenceHubSubscriber,
    ]

    opts = [strategy: :one_for_one, name: CentralCloud.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
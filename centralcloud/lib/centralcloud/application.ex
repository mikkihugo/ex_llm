defmodule CentralCloud.Application do
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

    children = base_children() ++ optional_children()

    opts = [strategy: :one_for_one, name: CentralCloud.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Base children that start in all environments
  defp base_children do
    [
      # Foundation: Database
      CentralCloud.Repo,

      # Infrastructure: Background jobs (Oban handles cron scheduling via plugin)
      {Oban, oban_config()},

      # Always-on services (don't depend on NATS)
      CentralCloud.KnowledgeCache,      # ETS-based cache
      CentralCloud.TemplateService,     # Template management
      CentralCloud.TemplateLoader,      # Lua template loading and rendering
    ]
  end

  # Optional children that require NATS (skip in test mode)
  defp optional_children do
    if Mix.env() == :test do
      []
    else
      [
        CentralCloud.NatsClient,          # NATS messaging (for subscriptions)
        CentralCloud.FrameworkLearningAgent,  # Learn from external packages
        CentralCloud.IntelligenceHub,     # Aggregate intelligence from all instances
        CentralCloud.TemplateIntelligence,  # Template intelligence (Phase 3: cross-instance learning)
        CentralCloud.NATS.PatternValidatorSubscriber,  # Pattern validation via NATS
      ]
    end
  end

  defp oban_config do
    Application.fetch_env!(:centralcloud, Oban)
    |> Keyword.put_new(:name, CentralCloud.Oban)
  end
end

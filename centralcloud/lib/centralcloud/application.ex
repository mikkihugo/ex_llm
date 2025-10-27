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
      # Foundation: Databases
      CentralCloud.Repo,
      CentralCloud.SharedQueueRepo,

      # Shared Queue Manager: Initialize central message queue (pgmq)
      # Must start after Repos
      {Task, fn -> initialize_shared_queue() end},

      # Infrastructure: Background jobs (Oban handles cron scheduling via plugin)
      {Oban, oban_config()},

      # Always-on services (don't depend on NATS)
      CentralCloud.KnowledgeCache,      # ETS-based cache
      CentralCloud.TemplateService,     # Template management
      CentralCloud.TemplateLoader,      # Lua template loading and rendering

      # pgmq Consumers: Read from distributed queues
      # Pattern Learning: Consumes pattern discoveries and learned patterns from instances
      {CentralCloud.PgmqConsumer,
       queue_name: "pattern_discoveries_published",
       handler_module: CentralCloud.Consumers.PatternLearningConsumer,
       poll_interval_ms: 1000,
       batch_size: 10,
       name: :pattern_consumer_1},

      {CentralCloud.PgmqConsumer,
       queue_name: "patterns_learned_published",
       handler_module: CentralCloud.Consumers.PatternLearningConsumer,
       poll_interval_ms: 1000,
       batch_size: 10,
       name: :pattern_consumer_2},

      # Performance Stats: Consumes execution metrics and job statistics
      {CentralCloud.PgmqConsumer,
       queue_name: "execution_statistics_per_job",
       handler_module: CentralCloud.Consumers.PerformanceStatsConsumer,
       poll_interval_ms: 2000,
       batch_size: 20,
       name: :perf_stats_consumer_1},

      {CentralCloud.PgmqConsumer,
       queue_name: "execution_metrics_aggregated",
       handler_module: CentralCloud.Consumers.PerformanceStatsConsumer,
       poll_interval_ms: 5000,
       batch_size: 5,
       name: :perf_stats_consumer_2},
    ]
  end

  # Initialize shared queue database (called at startup)
  defp initialize_shared_queue do
    if CentralCloud.SharedQueueManager.enabled?() do
      case CentralCloud.SharedQueueManager.initialize() do
        :ok ->
          Logger.info("[App] ✅ Shared Queue initialized by CentralCloud")

        {:error, reason} ->
          Logger.warn("[App] ⚠️  Shared Queue initialization failed: #{inspect(reason)}")
      end
    else
      Logger.info("[App] ℹ️  Shared Queue disabled in configuration")
    end
  end

  # Optional children (skip in test mode)
  defp optional_children do
    if Mix.env() == :test do
      []
    else
      [
        CentralCloud.FrameworkLearningAgent,  # Learn from external packages
        CentralCloud.IntelligenceHub,     # Aggregate intelligence from all instances
        CentralCloud.TemplateIntelligence,  # Template intelligence (Phase 3: cross-instance learning)
        CentralCloud.Infrastructure.IntelligenceEndpoint,  # Phase 8: Infrastructure registry NATS endpoint
      ]
    end
  end

  defp oban_config do
    Application.fetch_env!(:centralcloud, Oban)
    |> Keyword.put_new(:name, CentralCloud.Oban)
  end
end

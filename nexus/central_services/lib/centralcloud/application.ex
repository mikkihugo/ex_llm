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
      # ETS-based cache
      CentralCloud.KnowledgeCache,
      # Template management
      CentralCloud.TemplateService,
      # Lua template loading and rendering
      CentralCloud.TemplateLoader,

      # Task Learning: Aggregates task-specialized routing metrics every 60 seconds
      CentralCloud.ModelLearning.TaskMetricsAggregator,

      # ML Training Pipelines - Broadway-based ML training orchestration
      # Handles: Model complexity training, Pattern learning, Framework intelligence
      # Uses PGMQ for task queuing and Broadway for pipeline orchestration
      CentralCloud.ML.PipelineSupervisor,

      # PGFlow Workflow Supervisors - New workflow orchestration
      # Handles: Complexity training workflows with better observability
      {PGFlow.WorkflowSupervisor,
       workflow: CentralCloud.Workflows.ComplexityTrainingWorkflow,
       name: ComplexityTrainingWorkflowSupervisor,
       enabled:
         Application.get_env(:centralcloud, :complexity_training_pipeline, %{})[:pgflow_enabled] ||
           false},
      {PGFlow.WorkflowSupervisor,
       workflow: CentralCloud.Workflows.LLMTeamWorkflow,
       name: LLMTeamWorkflowSupervisor,
       enabled:
         Application.get_env(:centralcloud, :llm_team_workflow, %{})[:pgflow_enabled] || true},

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

      # Phase 8.3: Infrastructure Registry - Handles requests from Singularity/Genesis
      {CentralCloud.PgmqConsumer,
       queue_name: "infrastructure_registry_requests",
       handler_module: CentralCloud.Consumers.InfrastructureRegistryConsumer,
       poll_interval_ms: 500,
       batch_size: 1,
       name: :infrastructure_registry_consumer}
    ]
  end

  # Initialize shared queue database (called at startup)
  defp initialize_shared_queue do
    if CentralCloud.SharedQueueManager.enabled?() do
      case CentralCloud.SharedQueueManager.initialize() do
        :ok ->
          Logger.info("[App] ✅ Shared Queue initialized by CentralCloud")

        {:error, reason} ->
          Logger.warning("[App] ⚠️  Shared Queue initialization failed: #{inspect(reason)}")
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
        # Learn from external packages
        CentralCloud.FrameworkLearningAgent,
        # Aggregate intelligence from all instances
        CentralCloud.IntelligenceHub,
        # Template intelligence (Phase 3: cross-instance learning)
        CentralCloud.TemplateIntelligence,
        # Phase 8: Infrastructure registry NATS endpoint
        CentralCloud.Infrastructure.IntelligenceEndpoint
      ]
    end
  end

  defp oban_config do
    Application.fetch_env!(:centralcloud, Oban)
    |> Keyword.put_new(:name, CentralCloud.Oban)
  end
end

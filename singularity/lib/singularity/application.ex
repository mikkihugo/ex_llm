defmodule Singularity.Application do
  @moduledoc """
  Application entrypoint for Singularity.

  Manages the main supervision tree with a layered architecture:

  ## Supervision Layers

  1. **Foundation** (Repo, Telemetry) - Database and metrics
  2. **Infrastructure** (Infrastructure.Supervisor, NATS.Supervisor) - Core services
  3. **Domain Services** (LLM, Knowledge, Planning, SPARC, Todos) - Business logic
  4. **Agents & Execution** (Agents.Supervisor, ApplicationSupervisor) - Task execution
  5. **Singletons** (RuleEngine) - Standalone services
  6. **Domain Supervisors** (ArchitectureEngine, Git) - Domain-specific trees

  Each layer depends on the previous layers being started successfully.

  ## Nested Supervisors

  This application uses nested supervisors for better organization and fault isolation.
  See individual supervisor modules for details on what they manage.
  """
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Create ETS table for runner executions
    :ets.new(:runner_executions, [:named_table, :public, :set])

    children = [
      # Layer 1: Foundation - Database and metrics MUST start first
      Singularity.Repo,
      Singularity.Telemetry,
      Singularity.ProcessRegistry,

      # HTTP endpoint for dashboard and health checks
      {Bandit, plug: Singularity.Web.Endpoint, port: 4000},

      # Background Job Queue & Scheduling (before domain services)
      # Background job queue for ML training, pattern mining, cron jobs
      Oban,

      # Layer 2: Infrastructure - Core services required by application layer
      # Moved to ApplicationSupervisor to avoid duplicate startup
      # Singularity.Infrastructure.Supervisor,
      # Manages: NatsServer, NatsClient
      Singularity.NATS.Supervisor,

      # Layer 3: Domain Services - Business logic and domain-specific functionality
      # Manages: LLM.RateLimiter
      Singularity.LLM.Supervisor,
      # Manages: TemplateService, TemplatePerformanceTracker, CodeStore
      Singularity.Knowledge.Supervisor,
      # Code Analyzer Cache - Analysis result caching for performance
      {Singularity.CodeAnalyzer.Cache, [max_size: 1000, ttl: 3600]},
      # Manages: StartupCodeIngestion, SafeWorkPlanner, WorkPlanAPI
      Singularity.Execution.Planning.Supervisor,
      # Manages: SPARC.Orchestrator, TemplateSparcOrchestrator
      Singularity.Execution.SPARC.Supervisor,
      # Manages: TodoSwarmCoordinator
      Singularity.Execution.Todos.Supervisor,
      # Tracks bootstrap progression across evolutionary stages
      Singularity.Bootstrap.EvolutionStageController,

      # Layer 4: Agents & Execution - Dynamic agent management and task execution
      # Manages: RuntimeBootstrapper, AgentSupervisor (DynamicSupervisor)
      Singularity.Agents.Supervisor,
      # Manages: Control, Runner (moved from ApplicationSupervisor in future refactor)
      Singularity.ApplicationSupervisor,

      # Real Workload Feeder - Executes real LLM tasks and measures actual performance metrics
      Singularity.Agents.RealWorkloadFeeder,

      # Documentation System - Multi-language quality enforcement and upgrades
      # Manages: DocumentationUpgrader, QualityEnforcer, DocumentationPipeline
      Singularity.Agents.DocumentationUpgrader,
      Singularity.Agents.QualityEnforcer,
      Singularity.Agents.DocumentationPipeline,

      # Layer 5: Singletons - Standalone services that don't fit in other categories
      Singularity.Execution.Autonomy.RuleEngine,

      # Layer 6: Existing Domain Supervisors - Domain-specific supervision trees
      # Git.Supervisor moved to ApplicationSupervisor to avoid duplication

      # Layer 7: Startup Tasks - One-time tasks that run and exit
      Singularity.Engine.NifStatus
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Singularity.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Run documentation bootstrap AFTER supervision tree starts
        # (not supervised - runs once and exits)
        Task.start(fn ->
          Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
        end)

        {:ok, pid}

      error ->
        error
    end
  end
end

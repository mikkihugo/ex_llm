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

      # Layer 2: Infrastructure - Core services required by application layer
      # Manages: CircuitBreaker, ErrorRateTracker, StartupWarmup, EmbeddingModelLoader
      Singularity.Infrastructure.Supervisor,
      # Manages: NatsServer, NatsClient, NatsExecutionRouter
      Singularity.NATS.Supervisor,

      # Layer 3: Domain Services - Business logic and domain-specific functionality
      # Manages: LLM.RateLimiter
      Singularity.LLM.Supervisor,
      # Manages: TemplateService, TemplatePerformanceTracker, CodeStore
      Singularity.Knowledge.Supervisor,
      # Manages: HTDAGAutoBootstrap, SafeWorkPlanner, WorkPlanAPI
      Singularity.Planning.Supervisor,
      # Manages: SPARC.Orchestrator, TemplateSparcOrchestrator
      Singularity.SPARC.Supervisor,
      # Manages: TodoSwarmCoordinator
      Singularity.Todos.Supervisor,

      # Layer 4: Agents & Execution - Dynamic agent management and task execution
      # Manages: RuntimeBootstrapper, AgentSupervisor (DynamicSupervisor)
      Singularity.Agents.Supervisor,
      # Manages: Control, Runner (moved from ApplicationSupervisor in future refactor)
      Singularity.ApplicationSupervisor,

      # Layer 5: Singletons - Standalone services that don't fit in other categories
      Singularity.Autonomy.RuleEngine,

      # Layer 6: Existing Domain Supervisors - Domain-specific supervision trees
      Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
      Singularity.Git.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Singularity.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

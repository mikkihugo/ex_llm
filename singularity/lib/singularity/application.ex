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

      # Background Job Queue & Scheduling
      # Oban processes background jobs with cron-like scheduling
      # Config consolidated to :oban namespace (fixed dual-config issue)
      Oban,

      # Layer 2: Infrastructure - Core services required by application layer
      # Moved to ApplicationSupervisor to avoid duplicate startup
      # Singularity.Infrastructure.Supervisor,

      # Layer 3: Domain Services - Business logic and domain-specific functionality
      # Unified Metrics - Collection, aggregation, and querying service
      Singularity.Metrics.Supervisor
    ]
    |> Kernel.++(optional_children())

    Logger.info("Starting Singularity supervision tree",
      child_count: length(children),
      environment: Mix.env()
    )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Singularity.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Run documentation bootstrap AFTER supervision tree starts
        # (not supervised - runs once and exits)
        # Skip during tests to avoid sandbox database access issues
        # Check if :ex_unit application is loaded (indicates we're running under ExUnit/mix test)
        is_test = Application.loaded_applications()
                  |> Enum.any?(fn {app, _, _} -> app == :ex_unit end)

        unless is_test do
          Task.start(fn ->
            Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
          end)
        end

        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Optional child processes based on environment and configuration.

  These supervisors are intentionally disabled in test mode to avoid
  NATS connection failures and other environment-specific issues.

  ## Disabled Supervisors (Migration Status)

  The following supervisors were disabled during architectural consolidation
  and are awaiting migration to config-driven pattern or dependency resolution:

  - **Oban** - Background job scheduling (depends on Oban config consolidation)
  - **Infrastructure.Supervisor** - NATS services (depends on test mode handling)
  - **LLM.Supervisor** - LLM rate limiting (depends on NATS/Infrastructure)
  - **Knowledge.Supervisor** - Template and code store (depends on Infrastructure)
  - **Learning.Supervisor** - Genesis integration (depends on Knowledge)
  - **Execution.Planning.Supervisor** - Work planning (depends on Knowledge)
  - **Execution.SPARC.Supervisor** - SPARC orchestration (depends on planning)
  - **Execution.Todos.Supervisor** - Task coordination (depends on SPARC)
  - **Bootstrap.EvolutionStageController** - Bootstrap tracking (depends on others)
  - **Agents.Supervisor** - Agent management (depends on Infrastructure/Knowledge)
  - **ApplicationSupervisor** - Control and runner (should be merged into main tree)
  - **Agents.RealWorkloadFeeder** - Performance measurement (needs configuration)
  - **Documentation system** - Documentation pipelines (needs NATS)
  - **Autonomy.RuleEngine** - Gleam integration (needs Gleam/Elixir bridge)
  - **Engine.NifStatus** - NIF status checking (needs investigation)

  ## Plan for Re-enabling

  These supervisors should be re-enabled once:
  1. NATS is available and properly configured
  2. Config-driven patterns are applied to remaining hardcoded systems
  3. Test mode handling is properly implemented
  4. Dependencies are clearly mapped and validated

  See CLAUDE.md OTP Supervision Patterns section for refactoring guidelines.
  """
  defp optional_children do
    # Only enable infrastructure services in production/dev (not test mode)
    if Mix.env() in [:prod, :dev] do
      [
        # Background Job Queue & Scheduling
        # Oban,
        # Note: Temporarily disabled due to dual config (Oban vs Singularity namespace)
        # See: Fix issue in config/config.exs before re-enabling
      ]
    else
      # Test mode: skip NATS and other infrastructure to avoid connection failures
      []
    end
  end
end

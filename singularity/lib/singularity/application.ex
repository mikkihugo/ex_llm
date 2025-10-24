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
      Singularity.Infrastructure.Supervisor,
      Singularity.NATS.Supervisor,

      # Layer 3: Domain Services - Business logic and domain-specific functionality
      # Unified Metrics - Collection, aggregation, and querying service
      Singularity.Metrics.Supervisor,

      # LLM Services - Rate limiting and provider orchestration
      Singularity.LLM.Supervisor,

      # Knowledge Services - Templates and code storage
      Singularity.Knowledge.Supervisor,

      # Learning Services - Genesis integration and learning loops
      Singularity.Learning.Supervisor,

      # Layer 4: Agents & Execution - Task execution and planning
      # Execution Planning - Work planning and task graphs
      Singularity.Execution.Planning.Supervisor,

      # SPARC Orchestration - Template-driven execution
      Singularity.Execution.SPARC.Supervisor,

      # Task Coordination - Todo/work item management
      Singularity.Execution.Todos.Supervisor,

      # Agents Management - Agent lifecycle and supervision
      Singularity.Agents.Supervisor,

      # Layer 5: Domain Supervisors - Domain-specific supervision trees
      Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
      Singularity.Git.Supervisor
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

  Returns additional supervisors to load based on current environment.
  Most supervisors are now enabled in the main supervision tree.

  ## Re-enabled Supervisors

  As of this update, the following supervisors have been re-enabled in the main
  supervision tree (Application.start/2):

  - **Infrastructure.Supervisor** - Circuit breakers, error tracking, model loading
  - **NATS.Supervisor** - Message infrastructure (Server, Client, Embedding, Tools)
  - **LLM.Supervisor** - LLM rate limiting and provider orchestration
  - **Knowledge.Supervisor** - Template and code store services
  - **Learning.Supervisor** - Genesis integration and learning loops
  - **Execution.Planning.Supervisor** - Work planning and task DAG execution
  - **Execution.SPARC.Supervisor** - SPARC template-driven execution
  - **Execution.Todos.Supervisor** - Todo/work item coordination
  - **Agents.Supervisor** - Agent lifecycle management
  - **ArchitectureEngine.MetaRegistry.Supervisor** - Architecture analysis
  - **Git.Supervisor** - Git integration and repository management

  ## Future Re-enabling (Phase 2)

  The following components still need work before re-enabling:

  - **Bootstrap.EvolutionStageController** - Bootstrap tracking (low priority)
  - **Autonomy.RuleEngine** - Gleam integration (requires Gleam/Elixir bridge)
  - **Engine.NifStatus** - NIF status checking (requires investigation)

  ## Environment-Specific Configuration

  Current environment: #{Mix.env()}

  Notes:
  - Test mode: All supervisors start normally (no NATS connection failures in tests)
  - Development: Full supervision tree enabled
  - Production: Full supervision tree enabled

  See CLAUDE.md OTP Supervision Patterns section for architecture details.
  """
  defp optional_children do
    # Return any additional children based on environment
    # Most supervisors are now in main tree
    case Mix.env() do
      :test ->
        # Test mode: skip any test-specific configuration
        []

      :dev ->
        # Development: full supervision tree enabled
        []

      :prod ->
        # Production: full supervision tree enabled
        []
    end
  end
end

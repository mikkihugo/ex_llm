defmodule Singularity.Application do
  @moduledoc """
  Application entrypoint for Singularity.

  Manages the main supervision tree with a layered architecture:

  ## Supervision Layers

  1. **Foundation** (Repo, Telemetry) - Database and metrics
  2. **Infrastructure** (Infrastructure.Supervisor) - Core services
  3. **Domain Services** (LLM, Knowledge, Planning, SPARC, Todos) - Business logic
  4. **Agents & Execution** (Agents.Supervisor, ApplicationSupervisor) - Task execution
  5. **Singletons** (RuleEngine) - Standalone services
  6. **Domain Supervisors** (ArchitectureEngine, Git) - Domain-specific trees

  Each layer depends on the previous layers being started successfully.

  ## Nested Supervisors

  This application uses nested supervisors for better organization and fault isolation.
  See individual supervisor modules for details on what they manage.

  ---

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Application",
    "purpose": "OTP application entrypoint managing 6-layer supervision tree for autonomous AI development",
    "role": "application",
    "layer": "foundation",
    "alternatives": {
      "Individual Supervisors": "Use this as the single source of truth for supervision tree structure",
      "Manual Process Management": "This handles automated supervision, restart strategies, and fault tolerance"
    },
    "disambiguation": {
      "vs_individual_supervisors": "This is the root - orchestrates ALL supervisors in correct startup order",
      "vs_domain_supervisors": "This starts domain supervisors; they manage their own child processes"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      VM[Erlang VM] -->|1. starts| App[Singularity.Application]
      App -->|2. Layer 1| Repo[Repo + Telemetry + Registry]
      App -->|3. Layer 2| Infra[Infrastructure.Supervisor]
      App -->|4. Layer 3| Domain[Domain Supervisors]
      App -->|5. Layer 4| Agents[Agents.Supervisor]
      App -->|6. Layer 5| Rules[RuleEngine + RuleLoader]

      Domain --> LLM[LLM.Supervisor]
      Domain --> Knowledge[Knowledge.Supervisor]
      Domain --> Planning[Planning.Supervisor]
      Domain --> SPARC[SPARC.Supervisor]

      style App fill:#90EE90
      style Repo fill:#87CEEB
      style Domain fill:#FFD700
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Supervisor
      function: start_link/2
      purpose: Start OTP supervision tree with :one_for_one strategy
      critical: true

    - module: Singularity.Repo
      function: start_link/1
      purpose: Start PostgreSQL connection pool (Layer 1)
      critical: true

    - module: Singularity.Agents.Supervisor
      function: start_link/1
      purpose: Start dynamic agent supervision tree (Layer 4)
      critical: true

  called_by:
    - module: Erlang VM
      purpose: Application startup during beam initialization
      frequency: once

  depends_on:
    - Elixir OTP Platform (MUST exist)
    - PostgreSQL database (MUST be running)

  supervision:
    supervised: false
    reason: "Root application - supervised by Erlang VM itself"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create "Singularity.SupervisorManager" or wrapper modules
  **Why:** This module IS the supervisor manager. All supervision starts here.
  **Use instead:** Modify this file to add new supervisors to the tree.

  #### ❌ DO NOT start supervised processes outside this tree
  ```elixir
  # ❌ WRONG - Starting GenServer outside supervision
  {:ok, _} = MyService.start_link()

  # ✅ CORRECT - Add to children list in this module
  children = [
    MyService,  # Add to appropriate layer
    ...
  ]
  ```

  #### ❌ DO NOT change layer ordering without understanding dependencies
  ```elixir
  # ❌ WRONG - Infrastructure before Repo
  children = [
    Singularity.Infrastructure.Supervisor,  # Needs DB!
    Singularity.Repo
  ]

  # ✅ CORRECT - Repo first (Layer 1 before Layer 2)
  children = [
    Singularity.Repo,
    Singularity.Infrastructure.Supervisor
  ]
  ```

  #### ❌ DO NOT use :one_for_all restart strategy
  **Why:** Independent services should not restart each other. Use :one_for_one for fault isolation.

  ### Search Keywords

  application, supervision tree, otp, elixir application, nested supervisors,
  layered architecture, fault tolerance, process management, autonomous agents,
  startup ordering, dependency management, supervision strategy, one for one
  """
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    # Create ETS table for runner executions
    :ets.new(:runner_executions, [:named_table, :public, :set])

    children =
      [
        # Layer 1: Foundation - Database and metrics MUST start first
        Singularity.Repo,
        Singularity.Infrastructure.Telemetry,
        Singularity.ProcessRegistry
      ]
      # Background Job Queue & Scheduling (optional)
      # Oban processes background jobs with cron-like scheduling
      # Config consolidated to :oban namespace (fixed dual-config issue)
      # Can be disabled with: config :singularity, oban_enabled: false
      |> add_optional_child(:oban_enabled, &oban_child/0)
      |> Kernel.++(
        # Layer 2: Infrastructure - Core services required by application layer
        [
          Singularity.Infrastructure.Supervisor
        ]
      )
      |> Kernel.++([
        # Layer 3: Domain Services - Business logic and domain-specific functionality
        # LLM Services - Rate limiting and provider orchestration
        Singularity.LLM.Supervisor,

        # Infrastructure Registry Cache - Caches infrastructure systems from CentralCloud
        # Phase 8.3: Provides detection patterns for TechnologyDetector
        # Falls back to defaults if CentralCloud unavailable
        Singularity.Architecture.InfrastructureRegistryCache,

        # Knowledge Services - Templates and code storage
        # PGMQ is available - enabling Knowledge.Supervisor
        Singularity.Knowledge.Supervisor,

        # Layer 4: Agents & Execution - Task execution and planning
        # Autonomy Rules - Confidence-based autonomous decision making
        # Used by: CostOptimizedAgent, SafeWorkPlanner
        # Rules stored in PostgreSQL, cached in ETS, hot-reloadable via consensus evolution
        # Note: RuleEngine is a pure module (no OTP process) - used directly by agents
        # Singularity.Execution.Autonomy.RuleEngine,  # Pure module, not supervised
        Singularity.Execution.Autonomy.RuleLoader,

        # ML Training Pipelines - Broadway-based ML training orchestration
        # Handles: Embedding training (Qodo + Jina), Code generation training, Model complexity training
        # Uses PGMQ for task queuing and Broadway for pipeline orchestration
        Singularity.ML.PipelineSupervisor,

        # Execution - Unified planning and todos system
        # PGMQ and Knowledge.Supervisor are now available
        Singularity.Execution.Supervisor,

        # SPARC Orchestration - Template-driven execution
        # PGMQ and Knowledge.Supervisor are now available
        Singularity.Execution.SPARC.Supervisor,

        # Agent Coordination - Task routing and execution coordination
        # Routes tasks to best-fit agents based on capabilities
        Singularity.Agents.Coordination.CoordinationSupervisor,

        # Agents Management - Agent lifecycle and supervision
        Singularity.Agents.Supervisor,

        # Layer 5: Domain Supervisors - Domain-specific supervision trees
        # ArchitectureEngine.MetaRegistry.Supervisor - Requires pgmq (not available in test mode)
        # Singularity.ArchitectureEngine.MetaRegistry.Supervisor,
        Singularity.Git.Supervisor
      ])
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
        is_test =
          Application.loaded_applications()
          |> Enum.any?(fn {app, _, _} -> app == :ex_unit end)

        unless is_test do
          Task.start(fn ->
            Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
          end)

          # Initialize PageRank calculation on startup
          Task.start(fn ->
            Singularity.Bootstrap.PageRankBootstrap.ensure_initialized()
          end)

          # Populate graph dependency arrays for fast queries (10-100x faster)
          Task.start(fn ->
            Singularity.Bootstrap.GraphArraysBootstrap.ensure_initialized()
          end)
        end

        {:ok, pid}

      error ->
        error
    end
  end

  defp optional_children do
    # Return any additional children based on environment
    # Most supervisors are now in main tree
    # Skip bootstrap in test mode (use is_test_mode? for reliable detection)
    if is_test_mode?() do
      []
    else
      # Development and production: run one-time setup jobs
      [Singularity.Bootstrap.SetupBootstrap]
    end
  end

  # Helper function to conditionally add optional children
  # Special handling for Oban: detect test mode by checking database pool configuration
  defp add_optional_child(children, config_key, child_factory) do
    # For Oban, skip if in test mode (detected by SQL.Sandbox pool)
    if config_key == :oban_enabled and is_test_mode?() do
      Logger.info("Skipping #{config_key} - test mode detected (SQL.Sandbox pool)")
      children
    else
      enabled = Application.get_env(:singularity, config_key, true)
      Logger.info("Checking config for #{config_key}: #{inspect(enabled)}")

      case enabled do
        true ->
          Logger.info("Adding child for #{config_key}")
          children ++ [child_factory.()]

        false ->
          Logger.info("Skipping #{config_key} - disabled in config")
          children
      end
    end
  end

  # Detect test mode by checking if ExUnit is loaded
  # This is reliable regardless of environment variable overrides
  defp is_test_mode? do
    Application.loaded_applications()
    |> Enum.any?(fn {app, _, _} -> app == :ex_unit end)
  end

  # Returns Oban child spec if enabled
  # Can be disabled with: config :singularity, oban_enabled: false
  defp oban_child do
    Oban
  end
end

defmodule Singularity.Execution.Orchestrator.ExecutionOrchestrator do
  @moduledoc """
  Execution Orchestrator - Unified strategy-based code execution.

  Consolidates scattered executors (TaskGraphExecutor, SPARC.Orchestrator,
  MethodologyExecutor, etc.) into a single, strategy-based execution system.

  ## Quick Start

  ```elixir
  # Execute with automatic strategy detection
  {:ok, results} = ExecutionOrchestrator.execute(goal)

  # Execute with specific strategy
  {:ok, results} = ExecutionOrchestrator.execute(
    goal,
    strategy: :task_dag,
    timeout: 30000,
    parallel: true
  )
  ```

  ## Supported Execution Patterns

  - **Task DAGs** - Dependency graph execution (parallel + sequential)
  - **SPARC** - Template-driven SPARC methodology
  - **Methodology** - SAFe workflow execution

  ## Error Handling

  Returns `{:ok, results}` on success or `{:error, reason}` on failure:
  - `:invalid_strategy` - Unknown execution strategy
  - `:timeout` - Execution exceeded timeout
  - `:execution_failed` - Strategy execution error

  ---

  ## AI Navigation Metadata

  The sections below provide structured metadata for AI assistants,
  graph databases (Neo4j), and vector databases (pgvector).

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Orchestrator.ExecutionOrchestrator",
    "purpose": "Unified config-driven orchestration of execution strategies",
    "role": "orchestrator",
    "layer": "domain_services",
    "location": "lib/singularity/execution/orchestrator/execution_orchestrator.ex",
    "alternatives": {
      "ExecutionStrategyOrchestrator": "Internal implementation - use ExecutionOrchestrator as public API",
      "TaskGraphExecutor": "Legacy executor - replaced by ExecutionOrchestrator",
      "MethodologyExecutor": "Specific strategy - access via ExecutionOrchestrator"
    },
    "disambiguation": {
      "vs_execution_strategy": "ExecutionOrchestrator is the PUBLIC API that routes to ExecutionStrategyOrchestrator",
      "vs_task_graph": "Orchestrator selects strategy automatically; TaskGraph is one strategy option",
      "vs_methodology": "Orchestrator unifies all methodologies; MethodologyExecutor handles SAFe-specific logic"
    }
  }
  ```

  ### Architecture (Mermaid)

  ```mermaid
  graph TB
      Goal[Goal/Task Input]
      Orchestrator[ExecutionOrchestrator.execute/2]
      StrategyRouter[ExecutionStrategyOrchestrator]
      Config[Config: execution_strategies]

      Orchestrator -->|1. delegates to| StrategyRouter
      StrategyRouter -->|2. loads| Config
      Config -->|enabled: true| TaskDAG[TaskGraphStrategy]
      Config -->|enabled: true| SPARC[SparcStrategy]
      Config -->|enabled: true| Methodology[MethodologyStrategy]

      StrategyRouter -->|3. auto-detect or use specified| TaskDAG
      StrategyRouter -->|3. auto-detect or use specified| SPARC
      StrategyRouter -->|3. auto-detect or use specified| Methodology

      TaskDAG -->|4. results| StrategyRouter
      SPARC -->|4. results| StrategyRouter
      Methodology -->|4. results| StrategyRouter

      StrategyRouter -->|5. return| Orchestrator
      Orchestrator -->|6. return| Result[Execution Results]

      Goal -->|input| Orchestrator

      style Orchestrator fill:#90EE90
      style StrategyRouter fill:#FFD700
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Execution.Orchestrator.ExecutionStrategyOrchestrator
      function: execute/2
      purpose: Delegates to strategy router for config-driven execution
      critical: true

    - module: Singularity.Execution.Orchestrator.ExecutionStrategyOrchestrator
      function: get_strategies_info/0
      purpose: Retrieve available strategies and capabilities
      critical: false

    - module: Logger
      function: info/2
      purpose: Log execution start and strategy selection
      critical: false

  called_by:
    - module: Singularity.Agents.*
      purpose: Agent task execution
      frequency: high

    - module: Singularity.CLI.*
      purpose: CLI command execution
      frequency: medium

    - module: Singularity.pgmq.ExecutionRouter
      purpose: pgmq-based execution requests
      frequency: high

  depends_on:
    - ExecutionStrategyOrchestrator (MUST exist - internal routing logic)
    - Config :execution_strategies (MUST be configured)

  supervision:
    supervised: false
    reason: "Stateless module - no process state to manage"
  ```

  ### Anti-Patterns

  #### ❌ DO NOT call ExecutionStrategyOrchestrator directly
  **Why:** ExecutionOrchestrator is the public API.
  **Use instead:**
  ```elixir
  # ❌ WRONG
  ExecutionStrategyOrchestrator.execute(goal, opts)

  # ✅ CORRECT
  ExecutionOrchestrator.execute(goal, opts)
  ```

  #### ❌ DO NOT create new executor modules (TaskGraphExecutor, SparcExecutor)
  **Why:** ExecutionOrchestrator already provides unified execution!
  **Use instead:** Add new strategies via config in `config/config.exs`:
  ```elixir
  config :singularity, :execution_strategies,
    my_strategy: %{
      module: MyStrategyModule,
      enabled: true
    }
  ```

  #### ❌ DO NOT hardcode strategy selection
  **Why:** Config-driven routing enables better strategy evolution.
  **Use instead:**
  ```elixir
  # ❌ WRONG - hardcoded strategy
  case goal.type do
    :dag -> TaskGraphExecutor.execute(goal)
    :sparc -> SparcExecutor.execute(goal)
  end

  # ✅ CORRECT - let orchestrator decide
  ExecutionOrchestrator.execute(goal)
  ```

  ### Search Keywords

  execution orchestrator, strategy pattern, task execution, code execution,
  config driven orchestration, task dag, sparc execution, methodology execution,
  parallel execution, sequential execution, execution routing, strategy selection
  """

  require Logger
  alias Singularity.Execution.Orchestrator.ExecutionStrategyOrchestrator

  @doc """
  Execute code or tasks using unified orchestration.

  Delegates to ExecutionStrategyOrchestrator for strategy routing based on
  configuration. Automatically detects or uses specified strategy for execution.

  ## Options

  - `:strategy` - Specific execution strategy to use (optional, will auto-detect if not provided)
  - `:timeout` - Execution timeout in milliseconds (default: 60000)
  - `:strategies` - List of strategies to try (default: all enabled strategies in priority order)

  ## Returns

  Returns result from selected strategy or error tuple.

  ## Examples

      ExecutionOrchestrator.execute(%{tasks: [...]})
      # => {:ok, results}

      ExecutionOrchestrator.execute(goal, strategy: :sparc)
      # => {:ok, results}
  """
  def execute(goal, opts \\ []) when is_map(goal) or is_binary(goal) do
    timeout = Keyword.get(opts, :timeout, 60000)

    Logger.info("ExecutionOrchestrator: Routing goal to execution strategy",
      goal: inspect(goal),
      timeout: timeout
    )

    # Delegate to ExecutionStrategyOrchestrator for config-driven routing
    ExecutionStrategyOrchestrator.execute(goal, Keyword.put(opts, :timeout, timeout))
  end

  @doc """
  Get information about all configured execution strategies.

  Returns list of available strategies with their capabilities and priorities.
  """
  def get_strategies_info do
    ExecutionStrategyOrchestrator.get_strategies_info()
  end
end

defmodule Genesis.Application do
  @moduledoc """
  Genesis Application - Autonomous Improvement Agent

  Genesis is a separate Elixir application that autonomously executes code
  improvement experiments via PgFlow. It is a reactive agent that consumes
  workflow messages from three queues and executes them in an isolated sandbox.

  ## Architecture

  Genesis operates with complete isolation:
  - Separate PostgreSQL database (genesis)
  - **NEW:** Reads from three PgFlow queues:
    - `genesis_rule_updates` - Rule evolution from Singularity instances
    - `genesis_llm_config_updates` - LLM configuration changes
    - `code_execution_requests` - Job requests for code analysis
  - Publishes results back via PgFlow with full workflow state tracking
  - Separate Git history and filesystem isolation
  - Aggressive hotreload for safe testing of breaking changes
  - Auto-rollback on regression detection

  ## Workflow State Machine

  ```
  Singularity publishes message
       ↓ (via PgFlow)
  Genesis queue (pending)
       ↓
  PgFlowWorkflowConsumer reads message
       ↓
  Workflow state → running
       ↓
  Execute handler (rule/config/job)
       ↓
  Publish results via PgFlow
       ↓
  Workflow state → completed or failed
       ↓
  Archive message
  ```

  ## Supervision Strategy

  Uses `:one_for_one` strategy because each service is independent:
  - Database failures are logged but don't cascade to other services
  - Consumer restart policy: automatic (GenServer restart on crash)
  - Isolation failures don't affect other Genesis services

  ## Key Services

  **NEW:**
  - **Genesis.PgFlowWorkflowConsumer** - Main consumer for PgFlow queues
    - Reads from three queues with batching
    - Routes messages to appropriate handlers
    - Implements full workflow state management
    - Publishes results and error details

  **Supporting Services:**
  - **Genesis.RuleEngine** - Applies evolved linting/validation rules
  - **Genesis.LlmConfigManager** - Manages LLM configuration updates
  - **Genesis.JobExecutor** - Executes code analysis jobs
  - Genesis.Repo - Isolated database connection
  - Genesis.IsolationManager - Manages sandboxed environments
  - Genesis.RollbackManager - Handles git-based rollback
  - Genesis.MetricsCollector - Tracks experiment outcomes

  **Legacy (can be deprecated):**
  - Genesis.SharedQueueConsumer - Polls shared_queue for job_requests
    (Functionality now covered by PgFlowWorkflowConsumer)

  ## Configuration

  Enable PgFlow consumer in `config/config.exs`:

  ```elixir
  config :genesis, :pgflow_consumer,
    enabled: true,
    poll_interval_ms: 1000,
    batch_size: 10,
    timeout_ms: 30000,
    repo: Genesis.Repo
  ```

  ## Integration with Singularity

  **Singularity publishes to three Genesis queues:**

  1. **Rule Updates** - Via GenesisPublisher.publish_rules()
     ```elixir
     {:ok, %{summary: summary, results: results}} =
       Singularity.Evolution.GenesisPublisher.publish_rules()
     ```

  2. **LLM Config Updates** - Via GenesisPublisher.publish_llm_config_rules()
     ```elixir
     {:ok, summary} =
       Singularity.Evolution.GenesisPublisher.publish_llm_config_rules()
     ```

  3. **Job Requests** - Via existing job submission
     ```elixir
     {:ok, :sent} =
       Singularity.PgFlow.send_with_notify("code_execution_requests", payload)
     ```

  Genesis consumes these and publishes results to corresponding results queues.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting Genesis Application (Improvement Sandbox)...")

    children = [
      # Foundation: Database (isolated genesis)
      Genesis.Repo,

      # Infrastructure: Background jobs (Oban handles cron scheduling via plugin)
      {Oban, name: Genesis.Oban, repo: Genesis.Repo},

      # Task supervision for timeout handling
      {Task.Supervisor, name: Genesis.TaskSupervisor},

      # Services: Job execution and isolation
      # PgFlowWorkflowConsumer - Consumes from three PgFlow queues:
      #   - genesis_rule_updates (rule evolution from Singularity)
      #   - genesis_llm_config_updates (LLM config changes from Singularity)
      #   - code_execution_requests (job requests from Singularity)
      # Implements full workflow state management and publishes results via PgFlow
      Genesis.PgFlowWorkflowConsumer,

      # Legacy: SharedQueueConsumer - Can be disabled when PgFlowWorkflowConsumer is stable
      Genesis.SharedQueueConsumer,

      Genesis.IsolationManager,
      Genesis.RollbackManager,
      Genesis.MetricsCollector
    ]

    opts = [strategy: :one_for_one, name: Genesis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

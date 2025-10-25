# Singularity Workflow System - Multi-BEAM Architecture

**Status:** Design for multiple Singularity instances + CentralCloud coordination
**Date:** 2025-10-25
**Deployment Model:** Distributed BEAM instances with PostgreSQL coordination

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      CentralCloud                               │
│           (Multi-Instance Learning Aggregation)                 │
│                                                                  │
│  ├─ Shared Knowledge Base                                       │
│  ├─ Pattern Library (aggregated from all instances)            │
│  ├─ Model Performance Data                                     │
│  └─ Learning History                                           │
└────────────┬──────────────────┬────────────────┬────────────────┘
             │                  │                │
        DOWN: pgmq          DOWN: pgmq      DOWN: pgmq
        Sync patterns      Sync patterns   Sync patterns
             │                  │                │
             ▼                  ▼                ▼
  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
  │   Singularity    │  │   Singularity    │  │   Singularity    │
  │   Instance A     │  │   Instance B     │  │   Instance C     │
  │   (Server 1)     │  │   (Server 2)     │  │   (Server 3)     │
  │                  │  │                  │  │                  │
  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
  │ │ Oban Queues  │ │  │ │ Oban Queues  │ │  │ │ Oban Queues  │ │
  │ ├─ :default   │ │  │ ├─ :default   │ │  │ ├─ :default   │ │
  │ ├─ :metrics   │ │  │ ├─ :metrics   │ │  │ ├─ :metrics   │ │
  │ └─ :training  │ │  │ └─ :training  │ │  │ └─ :training  │ │
  │                  │  │                  │  │                  │
  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
  │ │WorkflowExec  │ │  │ │WorkflowExec  │ │  │ │WorkflowExec  │ │
  │ ├─ LLMRequest  │ │  │ ├─ LLMRequest  │ │  │ ├─ LLMRequest  │ │
  │ ├─ Embedding   │ │  │ ├─ Embedding   │ │  │ ├─ Embedding   │ │
  │ └─ AgentCoord  │ │  │ └─ AgentCoord  │ │  │ └─ AgentCoord  │ │
  │                  │  │                  │  │                  │
  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
  │ │Services      │ │  │ │Services      │ │  │ │Services      │ │
  │ ├─ LLM.Service │ │  │ ├─ LLM.Service │ │  │ ├─ LLM.Service │ │
  │ ├─ Embedding   │ │  │ ├─ Embedding   │ │  │ ├─ Embedding   │ │
  │ └─ Agents      │ │  │ └─ Agents      │ │  │ └─ Agents      │ │
  └─────────┬────────┘  └─────────┬────────┘  └─────────┬────────┘
            │ UP: pgmq           │ UP: pgmq            │ UP: pgmq
            │ Send results,      │ Send results,       │ Send results,
            │ patterns, costs    │ patterns, costs     │ patterns, costs
            │                    │                    │
            └────────────────────┴────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  PostgreSQL Database    │
                    │  (Shared Job Queue)     │
                    │                         │
                    │ ├─ oban_jobs            │
                    │ │  (distributed queue)  │
                    │ ├─ oban_peers           │
                    │ │  (instance registry)  │
                    │ ├─ pgmq queues          │
                    │ │  (UP/DOWN messages)   │
                    │ └─ job_results          │
                    │    (results log)        │
                    └─────────────────────────┘
```

## Multi-Instance Job Distribution

### How Work Gets Distributed

**Scenario: Three Singularity instances, 10 LLM request jobs**

```
Time: T0
  Job Queue (PostgreSQL oban_jobs):
  ├─ job_1: state=available, instance_id=NULL
  ├─ job_2: state=available, instance_id=NULL
  ├─ job_3: state=available, instance_id=NULL
  ├─ job_4: state=available, instance_id=NULL
  ├─ job_5: state=available, instance_id=NULL
  ├─ job_6: state=available, instance_id=NULL
  ├─ job_7: state=available, instance_id=NULL
  ├─ job_8: state=available, instance_id=NULL
  ├─ job_9: state=available, instance_id=NULL
  └─ job_10: state=available, instance_id=NULL

  Instance A polls Oban queue → Claims job_1, job_2, job_3 (or less if load high)
  Instance B polls Oban queue → Claims job_4, job_5, job_6
  Instance C polls Oban queue → Claims job_7, job_8, job_9, job_10

  Oban updates: claimed_by=instance_A, state=executing

Time: T1
  Instance A executes LlmRequestWorker.perform(job_1)
    ├─ WorkflowExecutor.execute(LlmRequest, input)
    ├─ Steps: receive → select_model → call_llm → publish_result
    ├─ Result stored in database
    └─ Sends result to CentralCloud via pgmq:instance_a_results

  Instance B executes LlmRequestWorker.perform(job_4)
    ├─ (same workflow)
    └─ Sends result to CentralCloud via pgmq:instance_b_results

  Instance C executes LlmRequestWorker.perform(job_7, job_8, job_9, job_10)
    ├─ All in parallel via BEAM processes
    └─ Sends results to CentralCloud

Time: T2
  All instances report to CentralCloud:
    - Cost savings (which models were used)
    - Pattern discoveries (new routing rules)
    - Performance metrics (latency, success rate)

  CentralCloud aggregates:
    - Instance A: 3 jobs, 0 failures, avg cost $0.12
    - Instance B: 3 jobs, 1 failure, avg cost $0.10
    - Instance C: 4 jobs, 0 failures, avg cost $0.11

  CentralCloud publishes learnings DOWN to all instances:
    - "Use Claude Sonnet more (15% cheaper than Opus)"
    - "New pattern: Classifier → Decomposition → Coder pipeline"
    - "Updated model routing: Cost optimization enabled"

Time: T3
  Instance A, B, C all receive updates via pgmq DOWN channel
  Update local knowledge base with new patterns/models
  Next batch of jobs uses improved routing
```

### Oban Configuration for Multiple Instances

```elixir
# config/config.exs
config :singularity, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    default: [limit: 10, paused: false],   # 10 concurrent jobs per instance
    metrics: [limit: 5, paused: false],
    training: [limit: 2, paused: false],
    pattern_mining: [limit: 3, paused: false]
  ],
  repo: Singularity.Repo,
  plugins: [
    Oban.Plugins.Repeater,     # Re-enqueue jobs periodically
    Oban.Plugins.Cron,         # Schedule cron tasks
  ]

# Oban automatically:
# 1. Distributes jobs across multiple instances (via oban_jobs table)
# 2. Tracks which instance is executing which job
# 3. Re-assigns jobs if instance crashes (via stale timeout)
# 4. Balances load across all available instances
```

## Worker Coordination

### Instance Discovery & Registration

```elixir
# lib/singularity/instance/registry.ex (NEW)
defmodule Singularity.Instance.Registry do
  @moduledoc """
  Registers and tracks Singularity instances in the cluster.

  When an instance starts:
  1. Generate unique instance_id (hostname:pid or UUID)
  2. Insert into instance_registry table
  3. Set last_heartbeat timestamp
  4. Periodically update heartbeat

  Oban uses this to:
  - Know which instances are alive
  - Assign jobs to available instances
  - Reassign jobs if instance dies (stale timeout)
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    instance_id = generate_instance_id()
    Logger.info("Registering instance: #{instance_id}")

    # Register in database
    {:ok, _} = Singularity.Repo.insert(%InstanceRegistry{
      instance_id: instance_id,
      hostname: Socket.gethostname!(),
      pid: System.get_pid(),
      last_heartbeat: DateTime.utc_now(),
      status: "online"
    })

    # Heartbeat timer (every 5 seconds)
    Process.send_after(self(), :heartbeat, 5000)

    {:ok, %{instance_id: instance_id}}
  end

  def handle_info(:heartbeat, state) do
    # Update last_heartbeat in database
    Singularity.Repo.update_all(
      InstanceRegistry,
      [set: [last_heartbeat: DateTime.utc_now()]],
      where: [instance_id: state.instance_id]
    )
    Process.send_after(self(), :heartbeat, 5000)
    {:noreply, state}
  end

  defp generate_instance_id do
    hostname = Socket.gethostname!()
    pid = System.get_pid()
    "#{hostname}:#{pid}"
  end
end
```

### Schema: Instance Registry

```elixir
# priv/repo/migrations/20251025_create_instance_registry.exs
defmodule Singularity.Repo.Migrations.CreateInstanceRegistry do
  use Ecto.Migration

  def change do
    create table(:instance_registry, primary_key: false) do
      add :instance_id, :string, primary_key: true
      add :hostname, :string
      add :pid, :string
      add :status, :string  # online, offline, paused
      add :last_heartbeat, :utc_datetime_usec
      add :capabilities, :jsonb  # e.g., {llm: true, embedding: true, agents: true}
      add :load, :integer  # Current number of executing jobs
      add :created_at, :utc_datetime_usec
    end

    create index(:instance_registry, [:status])
    create index(:instance_registry, [:last_heartbeat])
  end
end
```

## Result Aggregation & CentralCloud Sync

### UP Channel: Sending Results to CentralCloud

```elixir
# lib/singularity/jobs/result_aggregator_worker.ex (NEW)
defmodule Singularity.Jobs.ResultAggregatorWorker do
  @moduledoc """
  Aggregates workflow results and sends them to CentralCloud.

  Runs every 30 seconds via Oban cron job.
  Collects results from last execution period:
    - Cost data (which models were used, how much did they cost)
    - Success/failure rates
    - Pattern discoveries
    - Performance metrics
  Publishes via pgmq:centralcloud_updates
  """

  use Oban.Worker, queue: :metrics, max_attempts: 3

  def perform(_job) do
    Logger.info("ResultAggregator: Collecting results for CentralCloud")

    # 1. Fetch results from last 30 seconds
    thirty_seconds_ago = DateTime.add(DateTime.utc_now(), -30, :second)

    results = Singularity.Repo.all(
      from jr in JobResult,
      where: jr.completed_at > ^thirty_seconds_ago,
      select: %{
        job_type: jr.job_type,
        success: jr.success,
        cost_cents: jr.cost_cents,
        tokens_used: jr.tokens_used,
        model_used: jr.model_used,
        duration_ms: jr.duration_ms,
        patterns_discovered: jr.patterns_discovered
      }
    )

    # 2. Aggregate metrics
    aggregated = aggregate_results(results)

    # 3. Send to CentralCloud via pgmq
    send_to_centralcloud(aggregated)

    {:ok, aggregated}
  end

  defp aggregate_results(results) do
    %{
      instance_id: instance_id(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      period_seconds: 30,
      job_count: length(results),
      success_rate: success_rate(results),
      avg_cost_cents: avg_cost(results),
      avg_latency_ms: avg_latency(results),
      models_used: models_used(results),
      patterns_discovered: patterns_discovered(results),
      total_tokens: total_tokens(results)
    }
  end

  defp send_to_centralcloud(aggregated) do
    payload = Jason.encode!(aggregated)

    PgmqClient.send_message(
      "centralcloud_updates",
      payload
    )

    Logger.info("ResultAggregator: Sent aggregated results to CentralCloud",
      instance: instance_id(),
      jobs: aggregated.job_count,
      avg_cost: aggregated.avg_cost_cents
    )
  end

  defp instance_id do
    # Get from registry or environment
    System.get_env("INSTANCE_ID") || "instance_unknown"
  end

  # Helper functions...
  defp success_rate(results) do
    successes = Enum.count(results, & &1.success)
    if Enum.empty?(results), do: 0, else: successes / length(results)
  end

  defp avg_cost(results) do
    if Enum.empty?(results), do: 0, else:
      Enum.sum(results, & &1.cost_cents) / length(results)
  end

  defp avg_latency(results) do
    if Enum.empty?(results), do: 0, else:
      Enum.sum(results, & &1.duration_ms) / length(results)
  end

  defp models_used(results) do
    results
    |> Enum.group_by(& &1.model_used)
    |> Enum.map(fn {model, group} ->
      %{model: model, count: length(group)}
    end)
  end

  defp patterns_discovered(results) do
    results
    |> Enum.flat_map(& &1.patterns_discovered)
    |> Enum.uniq()
  end

  defp total_tokens(results) do
    Enum.sum(results, & &1.tokens_used)
  end
end

# Schedule in config/config.exs
config :singularity, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/30 * * * * *", Singularity.Jobs.ResultAggregatorWorker}  # Every 30 seconds
     ]}
  ]
```

### DOWN Channel: Receiving Learnings from CentralCloud

```elixir
# lib/singularity/jobs/learning_sync_worker.ex (NEW)
defmodule Singularity.Jobs.LearningSyncWorker do
  @moduledoc """
  Polls for learnings from CentralCloud and applies them locally.

  Runs every 10 seconds via Oban cron job.
  Receives via pgmq:instance_learning (DOWN from CentralCloud):
    - Updated model routing rules
    - Newly discovered patterns
    - Performance benchmarks
    - Cost optimization guidance
  """

  use Oban.Worker, queue: :metrics, max_attempts: 3

  def perform(_job) do
    Logger.info("LearningSync: Checking for updates from CentralCloud")

    # 1. Poll pgmq for learning updates
    {:ok, messages} = PgmqClient.read_messages("instance_learning", batch_size: 10)

    # 2. Process each learning
    Enum.each(messages, fn msg ->
      apply_learning(msg)
      PgmqClient.ack_message("instance_learning", msg.msg_id)
    end)

    Logger.info("LearningSync: Processed #{length(messages)} updates from CentralCloud")
    {:ok, %{processed: length(messages)}}
  end

  defp apply_learning(msg) do
    payload = Jason.decode!(msg.message)

    case payload["type"] do
      "model_routing" ->
        apply_model_routing(payload)

      "pattern_discovery" ->
        apply_pattern_discovery(payload)

      "cost_optimization" ->
        apply_cost_optimization(payload)

      "performance_benchmark" ->
        apply_performance_benchmark(payload)

      _ ->
        Logger.warn("LearningSync: Unknown learning type: #{payload["type"]}")
    end
  end

  defp apply_model_routing(payload) do
    Logger.info("LearningSync: Updating model routing rules",
      rules: payload["routing_rules"]
    )

    # Update cached routing rules in memory or ETS
    Singularity.Knowledge.ModelRouting.update_rules(payload["routing_rules"])
  end

  defp apply_pattern_discovery(payload) do
    Logger.info("LearningSync: Registering newly discovered pattern",
      pattern: payload["pattern_name"]
    )

    # Store pattern in local database
    Singularity.Patterns.register_pattern(
      payload["pattern_name"],
      payload["pattern_definition"],
      source: :centralcloud
    )
  end

  defp apply_cost_optimization(payload) do
    Logger.info("LearningSync: Applying cost optimization",
      savings: payload["estimated_savings"]
    )

    # Update cost optimization settings
    Singularity.Cost.Optimizer.update_settings(payload["settings"])
  end

  defp apply_performance_benchmark(payload) do
    Logger.info("LearningSync: Updating performance benchmarks",
      benchmarks: payload["benchmarks"]
    )

    # Store benchmarks for comparison
    Singularity.Performance.Benchmarks.update(payload["benchmarks"])
  end
end

# Schedule in config/config.exs
config :singularity, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"*/10 * * * * *", Singularity.Jobs.LearningSyncWorker}  # Every 10 seconds
     ]}
  ]
```

## Job Result Tracking Schema

```elixir
# lib/singularity/schema/job_result.ex
defmodule Singularity.Schema.JobResult do
  use Ecto.Schema
  import Ecto.Changeset

  schema "job_results" do
    field :job_id, Ecto.UUID
    field :instance_id, :string
    field :job_type, :string  # "llm_request", "embedding", "agent_coordination"
    field :workflow_type, :string  # "LlmRequest", "Embedding", etc.

    field :success, :boolean
    field :error_reason, :string, default: nil

    # Performance metrics
    field :duration_ms, :integer
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    # Cost tracking
    field :cost_cents, :integer
    field :model_used, :string
    field :tokens_used, :integer

    # Learning
    field :patterns_discovered, {:array, :string}, default: []
    field :insights, :map, default: %{}

    # Input/output for debugging
    field :input_summary, :map
    field :result_summary, :map

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(job_result, attrs) do
    job_result
    |> cast(attrs, [
      :job_id, :instance_id, :job_type, :workflow_type,
      :success, :error_reason,
      :duration_ms, :started_at, :completed_at,
      :cost_cents, :model_used, :tokens_used,
      :patterns_discovered, :insights,
      :input_summary, :result_summary
    ])
    |> validate_required([:job_id, :instance_id, :job_type, :success])
  end
end
```

## Failure Handling in Multi-Instance Setup

### Instance Crash Recovery

```
Scenario: Instance B crashes while executing job_4

Time: T0
  Instance B executing job_4
  oban_jobs: job_4 state=executing, reserved_by=instance_b, reserved_at=T0

Time: T1 (after 5 min stale timeout)
  Oban detects Instance B heartbeat is stale (last_heartbeat > 5 min ago)
  Instance B marked as "offline" in instance_registry
  oban_jobs: job_4 state=available again (reserved_by reset)

Time: T2
  Instance A polls Oban → Claims job_4
  Executes job_4 again (may be duplicate work, but guaranteed completion)
  oban_jobs: job_4 state=executing, reserved_by=instance_a

Time: T3
  Job completes, result stored
  CentralCloud receives duplicate results from both attempts
  Can deduplicate by job_id
```

### Duplicate Job Prevention

```elixir
# Idempotent job processing
defmodule Singularity.Jobs.LlmRequestWorker do
  def perform(%Job{args: args} = job) do
    request_id = args["request_id"]

    # Check if we already processed this request
    case Singularity.Repo.get(JobResult, request_id) do
      nil ->
        # First time: execute workflow
        execute_workflow(args)

      result ->
        # Already executed: return cached result
        Logger.info("LlmRequestWorker: Job #{request_id} already completed",
          cost_cents: result.cost_cents
        )
        {:ok, result}
    end
  end

  defp execute_workflow(args) do
    start_time = System.monotonic_time(:millisecond)

    case WorkflowExecutor.execute(Workflows.LlmRequest, args) do
      {:ok, result} ->
        elapsed_ms = System.monotonic_time(:millisecond) - start_time

        # Store result for deduplication
        Singularity.Repo.insert(%JobResult{
          job_id: args["request_id"],
          instance_id: instance_id(),
          job_type: "llm_request",
          workflow_type: "LlmRequest",
          success: true,
          duration_ms: elapsed_ms,
          cost_cents: result["cost_cents"],
          model_used: result["model"],
          tokens_used: result["tokens_used"]
        })

        {:ok, result}

      {:error, reason} ->
        elapsed_ms = System.monotonic_time(:millisecond) - start_time

        Singularity.Repo.insert(%JobResult{
          job_id: args["request_id"],
          instance_id: instance_id(),
          job_type: "llm_request",
          workflow_type: "LlmRequest",
          success: false,
          error_reason: inspect(reason),
          duration_ms: elapsed_ms
        })

        {:error, reason}
    end
  end
end
```

## Summary: Multi-Instance Workflow System

### Data Flow

```
┌─ Instance A ──┐  ┌─ Instance B ──┐  ┌─ Instance C ──┐
│ Enqueue jobs  │  │ Enqueue jobs  │  │ Enqueue jobs  │
│ Execute work  │  │ Execute work  │  │ Execute work  │
│ Send results  │  │ Send results  │  │ Send results  │
└─────────────┬─┘  └─────────────┬─┘  └─────────────┬─┘
              │                  │                  │
              └────────────┬─────┴────────┬─────────┘
                           │              │
                ┌──────────▼──────────────▼──────────┐
                │    PostgreSQL Database             │
                │  (Shared job queue + results)      │
                │                                    │
                │ ├─ oban_jobs (job distribution)   │
                │ ├─ job_results (result tracking)  │
                │ ├─ instance_registry (node health)│
                │ └─ pgmq queues (UP/DOWN sync)     │
                └──────────────┬────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   CentralCloud      │
                    │ (Learning Hub)      │
                    │                     │
                    │ Aggregates:         │
                    │ - Cost patterns     │
                    │ - Model usage       │
                    │ - Success rates     │
                    │ - Discoveries       │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Send learnings DOWN │
                    │ (model routing,     │
                    │  patterns, costs)   │
                    └─────────────────────┘
```

### Advantages of This Architecture

1. **Distributed Execution** ✅
   - Multiple BEAM instances execute in parallel
   - Load balanced automatically by Oban
   - Fault-tolerant (instance crashes don't lose jobs)

2. **Coordinated Learning** ✅
   - All instances contribute results to CentralCloud
   - Aggregate insights distributed back to all instances
   - Collective intelligence improves over time

3. **Cost Optimization** ✅
   - Track which models/paths cost least
   - CentralCloud identifies savings opportunities
   - All instances get better routing rules

4. **Simple Coordination** ✅
   - PostgreSQL is the coordination hub
   - No complex distributed consensus needed
   - Oban handles all job distribution logic

5. **Scalability** ✅
   - Add new Singularity instances by just starting them
   - Oban automatically includes them in job distribution
   - Load spreads across N instances

### Deployment

**Single Instance (Development):**
```bash
nix develop
mix phx.server  # One Singularity instance
# Works perfectly, all jobs process locally
```

**Three Instances (Production):**
```bash
# Terminal 1: Instance A
INSTANCE_ID=instance_a mix phx.server -p 4000

# Terminal 2: Instance B
INSTANCE_ID=instance_b mix phx.server -p 4001

# Terminal 3: Instance C
INSTANCE_ID=instance_c mix phx.server -p 4002

# All three connect to same PostgreSQL
# Jobs automatically distributed
# Results aggregated in CentralCloud
```

### Next Steps

1. ✅ Implement `Instance.Registry` GenServer for instance tracking
2. ✅ Create `ResultAggregatorWorker` for UP channel
3. ✅ Create `LearningSyncWorker` for DOWN channel
4. ✅ Add `JobResult` schema for tracking
5. ⏳ Deploy and test with 2-3 instances
6. ⏳ Monitor load distribution and cost savings


# Task Adapter Orchestrator: Config-Driven Task Execution System

## Overview

This document explains Singularity's unification of **4 distinct task execution systems** (Oban jobs, NATS messaging, GenServer agents, Task Graph) into a **config-driven, unified task adapter system**.

**Old approach:** Multiple task execution mechanisms scattered across codebase with no unified interface

**New approach:** Config-driven adapter orchestration with first-match-wins semantics for flexible task routing

## Architecture

### Core Components

```
┌──────────────────────────────────────────┐
│   TaskAdapter Behavior (~150 LOC)        │
│                                          │
│   Defines contract for all adapters:     │
│   - adapter_type() → :atom             │
│   - description() → String              │
│   - capabilities() → [String]           │
│   - execute(task, opts)                 │
└──────────────────────────────────────────┘
           ▲                    ▲
        implements          implements
           │                    │
           │                    │
┌──────────┴────┐      ┌────────┴──────────┐
│ ObanAdapter    │      │ NatsAdapter       │
│  (~65 LOC)     │      │  (~75 LOC)        │
│                │      │                   │
│ Priority: 10   │      │ Priority: 15      │
│ Background     │      │ Distributed       │
│ jobs, retries  │      │ messaging         │
└────────────────┘      └───────────────────┘
           ▲                    ▲
           │          implements
           │                    │
           │         ┌──────────┘
           │         │
           └─────────┴──────────────────────┐
                                            │
                         ┌──────────────────┴──────────┐
                         │                             │
                    implements              implements
                         │                             │
            ┌────────────┴────────────┐   ┌───────────┴──────────┐
            │ GenServerAdapter        │   │ (Future adapters)    │
            │     (~80 LOC)           │   │                      │
            │                         │   │ Priority: 25+        │
            │ Priority: 20            │   │                      │
            │ Sync, in-process        │   │ Custom execution     │
            └────────────────────────┘   └──────────────────────┘
           ▲
           │
           └─────────────────┬──────────────────────────┐
                             │                          │
                      discovered & loaded              controlled
                             │                          │
                             ▼                          ▼
                ┌─────────────────────────┐  ┌────────────────────┐
                │  Config (config.exs)    │  │ TaskAdapterOrchest.
                │                         │  │ (~250 LOC)
                │ :task_adapters = {      │  │
                │   oban_adapter: %{      │  │ 1. Load adapters
                │     module: ...,        │  │    from config
                │     enabled: true,      │  │
                │     priority: 10        │  │ 2. Try in priority
                │   },                    │  │    order
                │   ...                   │  │
                │ }                       │  │ 3. Return first
                └─────────────────────────┘  │    success
                                             │
                                             │ 4. Or error
                                             └────────────────────┘
```

## Configuration

### Location
`singularity/config/config.exs`

### Format
```elixir
config :singularity, :task_adapters,
  oban_adapter: %{
    module: Singularity.Adapters.ObanAdapter,
    enabled: true,
    priority: 10,
    description: "Background job execution via Oban"
  },
  nats_adapter: %{
    module: Singularity.Adapters.NatsAdapter,
    enabled: true,
    priority: 15,
    description: "Async task execution via NATS messaging"
  },
  genserver_adapter: %{
    module: Singularity.Adapters.GenServerAdapter,
    enabled: true,
    priority: 20,
    description: "Synchronous task execution via GenServer agents"
  }
```

### Configuration Keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `module` | Atom | ✅ | Module implementing `@behaviour TaskAdapter` |
| `enabled` | Boolean | ✅ | Whether adapter is active in this environment |
| `priority` | Integer | ✅ | Execution order (ascending, lower = tries first) |
| `description` | String | ✓ | Human-readable description (optional) |

## How Task Execution Works

### First-Match-Wins Semantics

```
Input: task with type and args
   │
   ▼
Load enabled adapters from config
Sort by priority (ascending)
   │
   ├─→ Try ObanAdapter (priority 10)
   │   │
   │   ├─→ {:ok, task_id} → Return success
   │   │
   │   ├─→ {:error, :not_suitable} → Try next
   │   │
   │   └─→ {:error, reason} → Return error (stop)
   │
   ├─→ Try NatsAdapter (priority 15)
   │   │
   │   ├─→ {:ok, task_id} → Return success
   │   │
   │   ├─→ {:error, :not_suitable} → Try next
   │   │
   │   └─→ {:error, reason} → Return error (stop)
   │
   ├─→ Try GenServerAdapter (priority 20)
   │   │
   │   ├─→ {:ok, task_id} → Return success
   │   │
   │   └─→ {:error, reason} → Return error
   │
   └─→ All adapters tried
       └─→ Return {:error, :no_adapter_found}
```

**Key Difference:**
- ValidationOrchestrator: All-must-pass (collects violations)
- TaskAdapterOrchestrator: First-match-wins (stops on success)
- FrameworkLearningOrchestrator: First-match-wins (stops on success)

## Adapter Implementations

### ObanAdapter

**File:** `lib/singularity/adapters/oban_adapter.ex`

**Purpose:** Background job execution via Oban

**Process:**
1. Map task type to Oban job module
2. Queue job via JobOrchestrator
3. Return task ID for tracking

**Returns:**
- `{:ok, "oban:#{job_id}"}` if job queued
- `{:error, :not_suitable}` if no job module found
- `{:error, reason}` on execution error

**Configuration:**
```elixir
oban_adapter: %{
  module: Singularity.Adapters.ObanAdapter,
  enabled: true,
  priority: 10
}
```

**Capabilities:** `["async", "background_jobs", "retries", "scheduled", "distributed"]`

### NatsAdapter

**File:** `lib/singularity/adapters/nats_adapter.ex`

**Purpose:** Distributed task execution via NATS messaging

**Process:**
1. Generate task ID
2. Build message with task details
3. Publish to NATS topic
4. Return task ID

**Returns:**
- `{:ok, "nats:#{task_id}"}` if message published
- `{:error, reason}` on publication error

**Configuration:**
```elixir
nats_adapter: %{
  module: Singularity.Adapters.NatsAdapter,
  enabled: true,
  priority: 15
}
```

**Capabilities:** `["async", "distributed", "messaging", "cross_instance", "pub_sub"]`

### GenServerAdapter

**File:** `lib/singularity/adapters/genserver_adapter.ex`

**Purpose:** Synchronous task execution via GenServer agents

**Process:**
1. Get or create agent for task type
2. Execute task in agent
3. Return task ID with result

**Returns:**
- `{:ok, "genserver:#{task_id}"}` if executed
- `{:error, reason}` on execution error

**Configuration:**
```elixir
genserver_adapter: %{
  module: Singularity.Adapters.GenServerAdapter,
  enabled: true,
  priority: 20
}
```

**Capabilities:** `["sync", "in_process", "immediate", "low_latency", "agent_based"]`

## Usage Examples

### Basic Execution (Auto-Routing)

```elixir
alias Singularity.Execution.TaskAdapterOrchestrator

# Execute task - orchestrator picks best adapter
TaskAdapterOrchestrator.execute(%{
  type: :pattern_analysis,
  args: %{codebase_id: "my-project"},
  opts: [async: true]
})
# => {:ok, "oban:12345"}
```

### Specific Adapter

```elixir
# Use only NATS for distributed execution
TaskAdapterOrchestrator.execute(task, adapters: [:nats_adapter])
# => {:ok, task_id} or {:error, reason}
```

### Get Adapter Information

```elixir
adapters = TaskAdapterOrchestrator.get_adapters_info()

Enum.each(adapters, fn a ->
  IO.puts("#{a.name}: #{a.description}")
  IO.puts("  Priority: #{a.priority}")
  IO.puts("  Capabilities: #{Enum.join(a.capabilities, ", ")}")
end)
```

## Task Structure

### Input Task Map

```elixir
%{
  type: :pattern_analysis,           # Required: Task type (atom)
  args: %{                           # Required: Task arguments
    codebase_id: "my-project",
    analysis_type: :full
  },
  opts: [                            # Required: Task options
    async: true,
    timeout: 30000,
    priority: :high
  ]
}
```

### Response

All adapters return:
- `{:ok, task_id}` - Task queued/executed (task_id format: "adapter:id")
- `{:error, :not_suitable}` - Adapter can't handle this task
- `{:error, reason}` - Hard error occurred

## Adding New Adapters

### Step-by-Step Guide

#### 1. Create Adapter Module

Create file: `lib/singularity/adapters/my_adapter.ex`

```elixir
defmodule Singularity.Adapters.MyAdapter do
  @moduledoc """
  My Adapter - Custom task execution strategy.
  """

  @behaviour Singularity.Execution.TaskAdapter

  require Logger

  @impl Singularity.Execution.TaskAdapter
  def adapter_type, do: :my_adapter

  @impl Singularity.Execution.TaskAdapter
  def description do
    "Custom task execution using my approach"
  end

  @impl Singularity.Execution.TaskAdapter
  def capabilities do
    ["custom", "specialized"]
  end

  @impl Singularity.Execution.TaskAdapter
  def execute(task, opts) do
    # Your execution logic here

    # Return:
    # - {:ok, task_id} on success
    # - {:error, :not_suitable} if can't handle this task
    # - {:error, reason} on error
    {:ok, "my:task123"}
  end
end
```

#### 2. Update Configuration

Add to `config/config.exs`:

```elixir
config :singularity, :task_adapters,
  my_adapter: %{
    module: Singularity.Adapters.MyAdapter,
    enabled: true,
    priority: 25,  # After existing adapters
    description: "Custom task execution using my approach"
  }
```

#### 3. Test Adapter

```bash
iex> TaskAdapterOrchestrator.execute(task)
{:ok, "my:task123"}
```

Done! The orchestrator automatically discovers and uses your adapter.

## Integration Points

### Current Usage Patterns

The TaskAdapterOrchestrator can be used in:

1. **Agent Systems** - Route agent tasks to appropriate adapter
2. **Goal Decomposition** - Execute decomposed goals
3. **Workflow Orchestration** - Execute workflow steps
4. **Pattern Detection** - Queue pattern analysis jobs
5. **Code Generation** - Execute code generation tasks

### Example Integration

```elixir
# In goal execution
case TaskAdapterOrchestrator.execute(task) do
  {:ok, task_id} ->
    Logger.info("Task queued: #{task_id}")
    track_task(task_id)

  {:error, :no_adapter_found} ->
    Logger.error("No adapter for task type: #{task.type}")

  {:error, reason} ->
    Logger.error("Execution failed: #{reason}")
end
```

## Performance Characteristics

### ObanAdapter
- **Time:** ~50ms (queue insert)
- **Async:** Yes (background execution)
- **Distributed:** Yes (multi-instance)

### NatsAdapter
- **Time:** ~100ms (message publish)
- **Async:** Yes (publish/subscribe)
- **Distributed:** Yes (cross-instance)

### GenServerAdapter
- **Time:** ~10ms (in-process)
- **Async:** No (synchronous)
- **Distributed:** No (in-process only)

## Error Handling

### Not Suitable vs Hard Error

```elixir
# Adapter can't handle this task type → try next
{:error, :not_suitable}

# Hard error (timeout, service down) → stop and return
{:error, reason}
```

Orchestrator only continues on `:not_suitable`, stops on other errors.

## Monitoring

### Logs

Task execution is logged at multiple levels:

```
INFO: "TaskAdapterOrchestrator: Executing task"
  task_type: :pattern_analysis
  adapter_count: 3

DEBUG: "Trying oban_adapter adapter"
INFO: "Task execution succeeded with oban_adapter"
  task_id: "oban:12345"
```

### Task ID Format

Task ID prefixes indicate which adapter executed:
- `oban:12345` - Executed by ObanAdapter
- `nats:abc123` - Executed by NatsAdapter
- `genserver:xyz` - Executed by GenServerAdapter

## Comparison: Old vs New

### Old (Scattered)

```elixir
# Different calls for different execution types
JobOrchestrator.enqueue(:pattern_analysis, args)
NatsClient.publish("task.analysis", message)
Agent.get_and_update(agent, fn -> execute_task() end)

# No unified interface, no routing
```

### New (Config-Driven)

```elixir
# Single unified API
TaskAdapterOrchestrator.execute(task)

# Automatic routing to appropriate adapter
# Can add/remove/reorder adapters via configuration
# Consistent error handling and task tracking
```

## FAQ

### Q: Can I disable an adapter?

**A:** Yes, set `enabled: false` in config.

### Q: Can I change execution order?

**A:** Yes, adjust priority values (lower = tries first).

### Q: What if no adapter matches?

**A:** Returns `{:error, :no_adapter_found}`.

### Q: Can adapters depend on each other?

**A:** No, but priority ordering helps control which tries first.

### Q: How do I handle `:not_suitable` vs errors?

**A:** Orchestrator handles this automatically - continues on `:not_suitable`, stops on errors.

## Related Documentation

- [TaskAdapter Behavior](lib/singularity/execution/task_adapter.ex) - Behavior contract
- [TaskAdapterOrchestrator](lib/singularity/execution/task_adapter_orchestrator.ex) - Orchestrator
- [ObanAdapter](lib/singularity/adapters/oban_adapter.ex) - Background jobs
- [NatsAdapter](lib/singularity/adapters/nats_adapter.ex) - Distributed tasks
- [GenServerAdapter](lib/singularity/adapters/genserver_adapter.ex) - In-process tasks
- [TASK_EXECUTION_INVENTORY.md](TASK_EXECUTION_INVENTORY.md) - Complete task system inventory

## Summary

The config-driven task adapter system provides:

1. **Unified Interface** - All adapters implement same contract
2. **Flexible Routing** - Choose adapter based on task requirements
3. **Configuration** - Enable/disable/reorder via config
4. **Extensibility** - Add new adapters without code changes
5. **Consistency** - Same return types across all adapters
6. **Reliability** - Error handling and task tracking

This follows the proven **Behavior + Orchestrator** pattern used throughout Singularity, completing the 6-phase architectural consolidation:

1. ✅ SearchOrchestrator
2. ✅ JobOrchestrator
3. ✅ Genesis Integration
4. ✅ Metrics Orchestrator
5. ✅ ValidationOrchestrator
6. ✅ **TaskAdapterOrchestrator** (Final Phase)

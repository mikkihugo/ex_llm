# Task Adapter System - Quick Reference

## Status: COMPLETE & PRODUCTION READY

All 3 adapters are fully implemented. No missing implementations.

---

## Files & Locations

| Component | File Path | Status |
|-----------|-----------|--------|
| **Behavior** | `singularity/lib/singularity/execution/task_adapter.ex` | ✅ Complete |
| **Orchestrator** | `singularity/lib/singularity/execution/task_adapter_orchestrator.ex` | ✅ Complete |
| **ObanAdapter** | `singularity/lib/singularity/adapters/oban_adapter.ex` | ✅ Complete |
| **NatsAdapter** | `singularity/lib/singularity/adapters/nats_adapter.ex` | ✅ Complete |
| **GenServerAdapter** | `singularity/lib/singularity/adapters/genserver_adapter.ex` | ✅ Complete |
| **Configuration** | `singularity/config/config.exs` (lines 441-459) | ✅ Complete |
| **Tests** | `singularity/test/singularity/execution/task_adapter_orchestrator_test.exs` | ✅ Complete (35+ tests) |

---

## 3 Adapters Overview

### 1. ObanAdapter (Priority 10)
**Best for:** Background jobs, scheduled tasks, retries

**Capabilities:** `["async", "background_jobs", "retries", "scheduled", "distributed"]`

**How it works:**
1. Queue task as Oban job
2. Integrates with JobOrchestrator
3. Maps task_type → Job module (`:ml_training` → `Singularity.Jobs.MlTrainingJob`)
4. Returns `{:ok, "oban:#{job_id}"}`

**Use when:** Task needs persistence, retries, or scheduling

---

### 2. NatsAdapter (Priority 15)
**Best for:** Distributed execution, cross-instance tasks, async messaging

**Capabilities:** `["async", "distributed", "messaging", "cross_instance", "pub_sub"]`

**How it works:**
1. Publish task via NATS
2. Generate unique task ID
3. Publish to subject: `task.{task_type}`
4. Returns `{:ok, "nats:#{task_id}"}`

**Use when:** Task needs distributed execution or cross-instance routing

---

### 3. GenServerAdapter (Priority 20)
**Best for:** Synchronous execution, immediate results, low latency

**Capabilities:** `["sync", "in_process", "immediate", "low_latency", "agent_based"]`

**How it works:**
1. Create/get Agent for task type
2. Execute task synchronously
3. Return result immediately
4. Returns `{:ok, "genserver:#{task_id}"}`

**Use when:** Task needs immediate execution and results

---

## Usage

### Basic Task Execution

```elixir
alias Singularity.Execution.TaskAdapterOrchestrator

# Execute task (adapter selected automatically by priority)
task = %{
  type: :pattern_analysis,
  args: %{codebase_id: "my-project"},
  opts: [timeout: 5000]
}

{:ok, task_id} = TaskAdapterOrchestrator.execute(task)
# Returns: {:ok, "oban:12345"} or {:ok, "nats:XyZ..."} or {:ok, "genserver:..."}

# Or use specific adapter
{:ok, task_id} = TaskAdapterOrchestrator.execute(task, adapters: [:nats_adapter])
```

### Get Adapter Information

```elixir
# List all adapters
adapters = TaskAdapterOrchestrator.get_adapters_info()
# Returns: [
#   %{name: :oban_adapter, enabled: true, priority: 10, capabilities: [...], ...},
#   %{name: :nats_adapter, enabled: true, priority: 15, capabilities: [...], ...},
#   %{name: :genserver_adapter, enabled: true, priority: 20, capabilities: [...], ...}
# ]

# Get capabilities for specific adapter
capabilities = TaskAdapterOrchestrator.get_capabilities(:oban_adapter)
# Returns: ["async", "background_jobs", "retries", "scheduled", "distributed"]
```

---

## Execution Flow

```
TaskAdapterOrchestrator.execute(task)
    ↓
Load adapters by priority
    ↓
Try ObanAdapter (priority 10)
    ├─ Success? → Return {:ok, "oban:..."}
    ├─ Not suitable? → Try next
    └─ Error? → Stop & return error
    ↓
Try NatsAdapter (priority 15)
    ├─ Success? → Return {:ok, "nats:..."}
    ├─ Not suitable? → Try next
    └─ Error? → Stop & return error
    ↓
Try GenServerAdapter (priority 20)
    ├─ Success? → Return {:ok, "genserver:..."}
    └─ Error? → Stop & return error
    ↓
No adapters matched → Return {:error, :no_adapter_found}
```

---

## Return Values

### Success
```elixir
{:ok, "oban:12345"}           # Oban background job
{:ok, "nats:Abc_Def456"}       # NATS message published
{:ok, "genserver:XyZ789"}      # GenServer executed
```

### Error
```elixir
{:error, :no_adapter_found}    # No adapter could execute task
{:error, :database_error}      # Hard error from adapter
{:error, :job_not_found}       # Task type has no job module
```

---

## Error Categories

1. **Not Suitable** → Try next adapter
   - Adapter can't handle this task type
   - Continue to next adapter

2. **Exception** → Try next adapter
   - Exception during execution
   - Caught by orchestrator, logged

3. **Hard Error** → Stop immediately
   - Adapter returned {:error, reason}
   - No fallback to next adapter

---

## Configuration

Located: `singularity/config/config.exs` (lines 441-459)

```elixir
config :singularity, :task_adapters,
  oban_adapter: %{
    module: Singularity.Adapters.ObanAdapter,
    enabled: true,          # true = enabled, false = disabled
    priority: 10,           # Lower = try first
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

---

## Behavior Contract (What Adapters Must Implement)

Every adapter must implement `@behaviour Singularity.Execution.TaskAdapter`:

```elixir
# Required callbacks:

@callback adapter_type() :: atom()
  # Return unique identifier (e.g., :oban_adapter)

@callback description() :: String.t()
  # Return human-readable description

@callback capabilities() :: [String.t()]
  # Return list of capability strings

@callback execute(task :: map(), opts :: Keyword.t()) ::
            {:ok, String.t()} | {:error, term()}
  # Execute task and return task ID or error
```

---

## Adding a New Adapter

1. **Create file:** `singularity/lib/singularity/adapters/my_adapter.ex`

```elixir
defmodule Singularity.Adapters.MyAdapter do
  @behaviour Singularity.Execution.TaskAdapter

  @impl true
  def adapter_type, do: :my_adapter

  @impl true
  def description, do: "My custom adapter"

  @impl true
  def capabilities, do: ["feature1", "feature2"]

  @impl true
  def execute(task, opts) do
    # Implementation
    {:ok, "my:task_id"} # or {:error, reason}
  end
end
```

2. **Add to config:** `singularity/config/config.exs`

```elixir
config :singularity, :task_adapters,
  my_adapter: %{
    module: Singularity.Adapters.MyAdapter,
    enabled: true,
    priority: 25,  # Try after GenServer (priority 20)
    description: "My custom adapter"
  }
```

3. **Add test** in `task_adapter_orchestrator_test.exs`

---

## Test Coverage

- **35+ test cases** covering:
  - Configuration loading and integrity
  - Adapter discovery and priority ordering
  - Task execution and error handling
  - Callback compliance
  - Routing scenarios
  - Performance and determinism

Run tests:
```bash
cd singularity
mix test test/singularity/execution/task_adapter_orchestrator_test.exs
```

---

## Common Task Type Examples

| Task Type | Best Adapter | Reason |
|-----------|--------------|--------|
| `:ml_training` | Oban | Long-running, needs retries |
| `:code_analysis` | NATS | Distributed, can be processed anywhere |
| `:format_code` | GenServer | Quick, synchronous operation |
| `:metrics_aggregation` | Oban | Periodic, scheduled task |
| `:pattern_detection` | NATS | Can run on other instances |

---

## Integration Points

### Where to use TaskAdapterOrchestrator

1. **ExecutionOrchestrator** - Dispatch execution strategies
2. **Agent Actions** - Execute agent-generated tasks
3. **Work Plans** - Execute work plan items
4. **MCP Tools** - Execute tool tasks
5. **Task Graph** - Execute graph tasks

---

## Performance Notes

- **ObanAdapter** - Persisted, scalable, suitable for large volumes
- **NatsAdapter** - Distributed, low-latency, suitable for async work
- **GenServerAdapter** - In-process, immediate, suitable for sync operations

---

## Troubleshooting

### No Adapter Found
- Check if all adapters are enabled in config
- Verify task type is valid
- Check adapter priorities are set

### Task Not Executing
- Check if adapter module exists
- Verify configuration syntax
- Check logs for errors

### Wrong Adapter Selected
- Check priority ordering
- Verify adapter capabilities
- Consider disabling unwanted adapters

---

## Key Modules

- `Singularity.Execution.TaskAdapter` - Behavior definition
- `Singularity.Execution.TaskAdapterOrchestrator` - Orchestration logic
- `Singularity.Adapters.ObanAdapter` - Oban implementation
- `Singularity.Adapters.NatsAdapter` - NATS implementation
- `Singularity.Adapters.GenServerAdapter` - GenServer implementation


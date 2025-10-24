# Execution Directory Structure Reference

**Last Updated:** 2025-10-25
**Status:** Production

## Quick Reference

```
lib/singularity/execution/
├── orchestrator/          # Config-driven orchestration (NEW)
├── runners/              # Execution engines (NEW)
├── strategies/           # Strategy implementations (NEW, empty)
├── autonomy/             # Autonomous decision making
├── planning/             # SAFe work planning
├── sparc/                # SPARC methodology
├── task_graph/           # Task graph execution
├── todos/                # Todo management
└── feedback/             # Execution feedback
```

---

## Orchestrator Directory

**Path:** `lib/singularity/execution/orchestrator/`

**Purpose:** Config-driven orchestration of execution strategies

**Files:**
- `execution_orchestrator.ex` - Public API for unified execution
- `execution_strategy_orchestrator.ex` - Internal strategy routing
- `execution_strategy.ex` - Behavior contract for strategies

**Namespaces:**
```elixir
Singularity.Execution.Orchestrator.ExecutionOrchestrator
Singularity.Execution.Orchestrator.ExecutionStrategyOrchestrator
Singularity.Execution.Orchestrator.ExecutionStrategy
```

**Usage:**
```elixir
alias Singularity.Execution.Orchestrator.ExecutionOrchestrator

# Execute with auto-detection
ExecutionOrchestrator.execute(goal)

# Execute with specific strategy
ExecutionOrchestrator.execute(goal, strategy: :task_dag)
```

---

## Runners Directory

**Path:** `lib/singularity/execution/runners/`

**Purpose:** High-performance execution engines

**Files:**
- `runner.ex` - Concurrent task execution with backpressure
- `control.ex` - Control plane for agent coordination
- `lua_runner.ex` - Lua script execution engine

**Namespaces:**
```elixir
Singularity.Execution.Runners.Runner
Singularity.Execution.Runners.Control
Singularity.Execution.Runners.LuaRunner
```

**Usage:**
```elixir
alias Singularity.Execution.Runners.Runner

# Execute concurrent tasks
Runner.execute_concurrent(tasks)

# Stream execution with backpressure
Runner.stream_execution(tasks, max_concurrency: 10)
```

---

## Strategies Directory

**Path:** `lib/singularity/execution/strategies/`

**Purpose:** Pluggable execution strategy implementations

**Status:** Empty (ready for future strategy modules)

**Expected Files:**
- `task_dag_strategy.ex` - Task DAG execution
- `sparc_strategy.ex` - SPARC methodology
- `methodology_strategy.ex` - SAFe methodology

**Future Namespaces:**
```elixir
Singularity.Execution.Strategies.TaskDagStrategy
Singularity.Execution.Strategies.SparcStrategy
Singularity.Execution.Strategies.MethodologyStrategy
```

---

## Backward Compatibility

**Delegation Modules (root level):**

These modules provide backward compatibility for code using old paths:

```
lib/singularity/
├── execution/
│   └── execution_orchestrator.ex  # Delegates to orchestrator/execution_orchestrator.ex
├── runner.ex                       # Delegates to execution/runners/runner.ex
├── control.ex                      # Delegates to execution/runners/control.ex
└── lua_runner.ex                   # Delegates to execution/runners/lua_runner.ex
```

**Migration Timeline:**
- **Now (Q4 2025):** Both old and new paths work
- **Q2 2026:** Update to new paths when convenient
- **Q3 2026:** Remove delegation modules (breaking change)

---

## Module Relationships

### ExecutionOrchestrator Flow

```
User Code
    ↓
ExecutionOrchestrator.execute/2
    ↓
ExecutionStrategyOrchestrator.execute/2
    ↓
ExecutionStrategy.load_enabled_strategies/0
    ↓
Strategy Module (TaskDAG, SPARC, Methodology)
    ↓
Runner.execute_concurrent/2
    ↓
Results
```

### Control Flow

```
Agent
    ↓
Control.publish_improvement/2
    ↓
NATS.Client.publish/2
    ↓
Event Bus
    ↓
Other Agents
```

---

## AI Assistant Guidelines

### DO ✅

1. **Use new namespaces:**
   ```elixir
   alias Singularity.Execution.Orchestrator.ExecutionOrchestrator
   alias Singularity.Execution.Runners.Runner
   ```

2. **Add strategies to config:**
   ```elixir
   config :singularity, :execution_strategies,
     my_strategy: %{
       module: MyStrategyModule,
       enabled: true
     }
   ```

3. **Check AI metadata before creating modules:**
   - Look for "Module Identity" in `@moduledoc`
   - Review "Anti-Patterns" section

### DON'T ❌

1. **Create new orchestrators:**
   - ExecutionOrchestrator already exists
   - Use config-driven registration instead

2. **Use old namespaces in new code:**
   ```elixir
   # ❌ WRONG
   alias Singularity.Execution.ExecutionOrchestrator

   # ✅ CORRECT
   alias Singularity.Execution.Orchestrator.ExecutionOrchestrator
   ```

3. **Call strategies directly:**
   ```elixir
   # ❌ WRONG
   TaskDagStrategy.execute(goal)

   # ✅ CORRECT
   ExecutionOrchestrator.execute(goal, strategy: :task_dag)
   ```

---

## Configuration Reference

**File:** `config/config.exs`

```elixir
config :singularity, :execution_strategies,
  task_dag: %{
    module: Singularity.ExecutionStrategies.TaskDagStrategy,
    enabled: true,
    priority: 10,
    description: "Task DAG based execution with dependency tracking"
  },
  sparc: %{
    module: Singularity.ExecutionStrategies.SparcStrategy,
    enabled: true,
    priority: 20,
    description: "SPARC template-driven execution"
  },
  methodology: %{
    module: Singularity.ExecutionStrategies.MethodologyStrategy,
    enabled: true,
    priority: 30,
    description: "Methodology-based execution (SAFe, etc.)"
  }
```

---

## Testing

### Unit Tests

```elixir
# Test orchestrator
test "ExecutionOrchestrator.execute/2 delegates to strategy" do
  assert {:ok, _} = ExecutionOrchestrator.execute(%{tasks: [...]})
end

# Test runner
test "Runner.execute_concurrent/2 runs tasks in parallel" do
  assert {:ok, results} = Runner.execute_concurrent(tasks)
  assert length(results) == length(tasks)
end

# Test control
test "Control.publish_improvement/2 publishes to NATS" do
  assert :ok = Control.publish_improvement("agent-1", %{code: "..."})
end
```

### Integration Tests

```elixir
test "end-to-end execution flow" do
  # Given
  goal = %{type: :code_generation, spec: "..."}

  # When
  {:ok, result} = ExecutionOrchestrator.execute(goal)

  # Then
  assert result.status == :success
  assert result.code != nil
end
```

---

## Troubleshooting

### Compilation Errors

**Error:** `module Singularity.Execution.ExecutionOrchestrator is undefined`

**Solution:**
```elixir
# Update to new namespace
alias Singularity.Execution.Orchestrator.ExecutionOrchestrator
```

---

### Deprecation Warnings

**Warning:** `Singularity.Execution.ExecutionOrchestrator is deprecated`

**Solution:** Update to new namespace (see migration guide above)

---

### Module Not Found

**Error:** `could not find module Singularity.Execution.Strategies.MyStrategy`

**Solution:**
1. Check strategy is registered in `config/config.exs`
2. Verify module exists and is compiled
3. Ensure module implements `ExecutionStrategy` behavior

---

## See Also

- [CODE_ORGANIZATION_PHASE_5_7_SUMMARY.md](CODE_ORGANIZATION_PHASE_5_7_SUMMARY.md) - Complete consolidation summary
- [EXECUTION_ARCHITECTURE.md](../docs/EXECUTION_ARCHITECTURE.md) - Architecture overview
- [CLAUDE.md](../CLAUDE.md) - Project guidelines

---

**Generated:** 2025-10-25
**Maintained By:** Singularity Team
**Next Review:** Q1 2026

# HTDAG Executor: Before vs After

Visual comparison showing the transformation from hardcoded logic to Lua-powered execution.

---

## Before: Hardcoded Execution (OLD)

```elixir
defmodule Singularity.Execution.Planning.HTDAGExecutor do
  defp execute_task(task, state, opts) do
    # HARDCODED: Build operation params
    op_params = build_operation_params(task, opts)

    # Execute via NATS
    case NatsOperation.compile(op_params, ctx) do
      {:ok, compiled} ->
        NatsOperation.run(compiled, inputs, ctx)
    end
  end

  # ❌ HARDCODED: Model selection based on complexity threshold
  defp build_operation_params(task, opts) do
    model_id = select_model_for_task(task)  # Lines 263
    prompt_template = build_task_prompt(task)  # Lines 266-270

    %{
      model_id: model_id,
      prompt_template: prompt_template,
      temperature: 0.7,  # Fixed!
      max_tokens: 4000   # Fixed!
    }
  end

  # ❌ HARDCODED: Complexity thresholds (lines 285-297)
  defp select_model_for_task(task) do
    cond do
      task.estimated_complexity >= 8.0 -> "claude-sonnet-4.5"
      task.estimated_complexity >= 5.0 -> "gemini-2.5-pro"
      true -> "gemini-1.5-flash"
    end
  end

  # ❌ HARDCODED: Fixed prompt template (lines 299-312)
  defp build_task_prompt(task) do
    """
    Complete the following task:
    Task: #{task.description}
    Type: #{task.task_type}
    Complexity: #{task.estimated_complexity}

    Acceptance Criteria:
    #{Enum.map_join(task.acceptance_criteria, "\n", fn c -> "- #{c}" end)}

    Provide a detailed solution.
    """
  end

  # ❌ HARDCODED: RAG integration (lines 314-360)
  defp build_task_prompt_with_rag(task, opts) do
    similar_code = find_similar_code_examples(task)
    base_prompt = build_task_prompt(task)

    if similar_code != [] do
      """
      #{base_prompt}

      ## Similar Code Examples
      #{format_rag_examples(similar_code)}
      """
    else
      base_prompt
    end
  end
end
```

**Problems:**
- 🔴 Model selection: Hardcoded complexity thresholds (8.0, 5.0)
- 🔴 Prompts: Fixed templates, no context awareness
- 🔴 RAG: Always-on or always-off, not adaptive
- 🔴 Configuration: Fixed temperature, max_tokens
- 🔴 Deployment: Requires recompilation to change logic

---

## After: Lua-Powered Execution (NEW)

```elixir
defmodule Singularity.Execution.Planning.HTDAGExecutor do
  defp execute_task(task, state, opts) do
    # ✅ LUA-POWERED: Load strategy for this task
    case HTDAGStrategyLoader.get_strategy_for_task(task.description) do
      {:ok, strategy} ->
        if should_decompose?(task) do
          decompose_and_recurse(task, strategy, state, opts)
        else
          execute_atomic_task(task, strategy, state, opts)
        end

      {:error, :no_strategy_found} ->
        execute_with_default_strategy(task, state, opts)  # Fallback
    end
  end

  defp execute_atomic_task(task, strategy, state, opts) do
    # ✅ LUA DECIDES: Which agents to spawn
    case HTDAGLuaExecutor.spawn_agents(strategy, task, state) do
      {:ok, spawn_config} ->
        agents = Enum.map(spawn_config["agents"], &AgentSpawner.spawn/1)

        # ✅ LUA ORCHESTRATES: How agents collaborate
        case HTDAGLuaExecutor.orchestrate_execution(strategy, task, agents, []) do
          {:ok, orchestration} ->
            results = execute_orchestration(orchestration, agents, task, state)

            # ✅ LUA VALIDATES: Completion quality
            HTDAGLuaExecutor.check_completion(strategy, task, results)
        end
    end
  end

  defp decompose_and_recurse(task, strategy, state, opts) do
    # ✅ LUA DECOMPOSES: Break into subtasks
    case HTDAGLuaExecutor.decompose_task(strategy, task, state) do
      {:ok, subtasks} ->
        # Add to DAG (automatic ordering!)
        dag = Enum.reduce(subtasks, state.dag, fn subtask, acc_dag ->
          HTDAGCore.add_task(acc_dag, subtask)
        end)

        {:ok, %{decomposed: true, subtask_count: length(subtasks)}}
    end
  end
end
```

**Benefits:**
- ✅ Model selection: Lua decides based on full context
- ✅ Prompts: Lua builds context-aware prompts
- ✅ RAG: Lua decides when RAG is needed
- ✅ Configuration: Lua provides per-task config
- ✅ Deployment: Update Lua in database, no recompilation

---

## Lua Strategy Examples

### Agent Spawning (Replaces select_model_for_task)

**Before (Elixir - Hardcoded):**
```elixir
defp select_model_for_task(task) do
  cond do
    task.estimated_complexity >= 8.0 -> "claude-sonnet-4.5"
    task.estimated_complexity >= 5.0 -> "gemini-2.5-pro"
    true -> "gemini-1.5-flash"
  end
end
```

**After (Lua - Context-Aware):**
```lua
-- templates_data/htdag_strategies/standard_agent_spawning.lua
local task = context.task
local complexity = task.estimated_complexity or 5.0
local agents = {}

-- Select role based on SPARC phase (not just complexity!)
local role = "code_developer"  -- default

if task.sparc_phase == "specification" then
  role = "project_manager"      -- PM for specs
  model = "claude-sonnet-4.5"   -- Best reasoning
elseif task.sparc_phase == "architecture" then
  role = "architecture_analyst" -- Architect for design
  model = "claude-sonnet-4.5"   -- Best architecture
elseif task.sparc_phase == "refinement" then
  role = "code_developer"       -- Dev for implementation
  model = complexity > 7.0 and "gemini-2.5-pro" or "gemini-1.5-flash"
end

-- Dynamic: Spawn quality engineer for complex tasks
if complexity > 8.0 then
  table.insert(agents, {
    role = "quality_engineer",
    model = "claude-sonnet-4.5",
    priority = "high"
  })
end

-- Dynamic: Spawn security analyst for auth tasks
if string.match(task.description:lower(), "auth") or
   string.match(task.description:lower(), "security") then
  table.insert(agents, {
    role = "security_analyst",
    model = "claude-sonnet-4.5"
  })
end

return {
  agents = agents,
  orchestration = {
    pattern = #agents == 1 and "solo" or "leader_follower"
  }
}
```

**What changed:**
- 🎯 Context-aware: Considers SPARC phase, not just complexity
- 🎯 Dynamic: Spawns quality engineer only when needed
- 🎯 Specialized: Different roles for different phases
- 🎯 Security: Auto-spawns security analyst for auth tasks
- 🔄 Hot-reload: Update logic via database, no recompilation

---

### Task Decomposition

**Before (Elixir - No decomposition logic):**
```elixir
# No automatic decomposition in old version
# Tasks executed as-is, no subtask generation
```

**After (Lua - Smart Decomposition):**
```lua
-- templates_data/htdag_strategies/standard_decomposition.lua
local task = context.task
local complexity = task.estimated_complexity or 5.0

-- Don't decompose simple tasks
if complexity < 5.0 then
  return {
    subtasks = {},
    strategy = "atomic",
    reasoning = "Task is simple enough to execute atomically"
  }
end

local subtasks = {}

-- Phase 1: Specification
table.insert(subtasks, {
  description = "Design and specify: " .. task.description,
  task_type = "milestone",
  estimated_complexity = complexity * 0.2,
  sparc_phase = "specification",
  dependencies = {}  -- No deps, can start immediately
})

-- Phase 2: Architecture
table.insert(subtasks, {
  description = "Architecture for: " .. task.description,
  task_type = "milestone",
  estimated_complexity = complexity * 0.25,
  sparc_phase = "architecture",
  dependencies = {subtasks[1].id or "spec"}  -- Depends on spec
})

-- Phase 3: Implementation
table.insert(subtasks, {
  description = "Implement: " .. task.description,
  task_type = "implementation",
  estimated_complexity = complexity * 0.4,
  sparc_phase = "refinement",
  dependencies = {subtasks[2].id or "arch"}  -- Depends on arch
})

-- Phase 4: Testing (optional for high complexity)
if complexity > 8.0 then
  table.insert(subtasks, {
    description = "Test: " .. task.description,
    task_type = "milestone",
    estimated_complexity = complexity * 0.15,
    sparc_phase = "completion_phase",
    dependencies = {subtasks[3].id or "impl"}  -- Depends on impl
  })
end

return {
  subtasks = subtasks,
  strategy = "sequential_with_checkpoints",
  reasoning = string.format(
    "Complex task (%.1f) decomposed into %d SPARC phases",
    complexity,
    #subtasks
  )
}
```

**What changed:**
- ✅ Automatic decomposition for complex tasks
- ✅ SPARC phases (Specification → Architecture → Implementation → Testing)
- ✅ Dependency tracking (phases execute in order)
- ✅ Adaptive: Testing phase only for high complexity
- 🔄 Hot-reload: Adjust decomposition strategy via database

---

### Completion Validation

**Before (Elixir - No validation):**
```elixir
# No completion validation in old version
# Tasks marked as completed based on agent response
```

**After (Lua - Quality Gates):**
```lua
-- templates_data/htdag_strategies/standard_completion.lua
local task = context.task
local results = context.execution_results or {}
local tests = context.tests or {}
local quality = context.code_quality or {}

-- Check all subtasks completed
local all_completed = true
local subtask_failures = {}

for _, result in ipairs(results) do
  if result.status ~= "completed" then
    all_completed = false
    table.insert(subtask_failures, result.id)
  end
end

-- Check tests
local test_failures = 0
if tests.unit_tests then
  test_failures = test_failures + (tests.unit_tests.failed or 0)
end
if tests.integration_tests then
  test_failures = test_failures + (tests.integration_tests.failed or 0)
end

-- Check quality gates
local quality_issues = {}

if quality.coverage and quality.coverage < 0.80 then
  table.insert(quality_issues, "Coverage below 80%")
end

if quality.complexity and quality.complexity > 10 then
  table.insert(quality_issues, "Complexity too high")
end

-- Decide completion status
if all_completed and test_failures == 0 and #quality_issues == 0 then
  return {
    status = "completed",
    confidence = 0.95,
    reasoning = "All subtasks completed, tests passed, quality gates met"
  }
else
  local issues = {}
  if not all_completed then
    table.insert(issues, string.format("%d subtasks incomplete", #subtask_failures))
  end
  if test_failures > 0 then
    table.insert(issues, string.format("%d test failures", test_failures))
  end
  if #quality_issues > 0 then
    table.insert(issues, table.concat(quality_issues, ", "))
  end

  return {
    status = "needs_rework",
    confidence = 0.6,
    reasoning = table.concat(issues, "; "),
    required_fixes = issues
  }
end
```

**What changed:**
- ✅ Validates subtask completion
- ✅ Checks test results (unit + integration)
- ✅ Enforces quality gates (coverage, complexity)
- ✅ Provides detailed reasoning for rework
- 🔄 Hot-reload: Adjust quality standards via database

---

## Automatic Task Ordering

**Key insight:** HTDAGCore.select_next_task/1 handles ordering automatically!

```elixir
# HTDAGCore (existing code - unchanged)
def select_next_task(dag) do
  dag
  |> get_ready_tasks()  # Tasks with all dependencies completed
  |> Enum.sort_by(fn task ->
    {task.depth, task.estimated_complexity}  # Priority: depth first
  end)
  |> List.first()
end
```

**How Lua uses this:**

```lua
-- Lua just defines subtasks with dependencies
local subtasks = {
  {
    id = "task-1",
    description = "Design API",
    dependencies = {}  -- No deps, can start immediately
  },
  {
    id = "task-2",
    description = "Implement API",
    dependencies = {"task-1"}  -- Depends on task-1
  },
  {
    id = "task-3",
    description = "Test API",
    dependencies = {"task-2"}  -- Depends on task-2
  }
}

return {subtasks = subtasks}
```

**HTDAGCore automatically executes in order:**
1. task-1 (Design API) - no dependencies
2. task-2 (Implement API) - waits for task-1 completion
3. task-3 (Test API) - waits for task-2 completion

**No manual ordering needed!**

---

## Code Size Comparison

### Before (Hardcoded)
```
htdag_executor.ex:
- execute_task: 60 lines
- build_operation_params: 23 lines
- select_model_for_task: 13 lines
- build_task_prompt: 14 lines
- build_task_prompt_with_rag: 21 lines
- find_similar_code_examples: 13 lines
- format_rag_examples: 12 lines

Total: ~156 lines of hardcoded logic
```

### After (Lua-Powered)
```
htdag_executor.ex:
- execute_task: 20 lines (Lua orchestration)
- decompose_and_recurse: 35 lines
- execute_atomic_task: 45 lines
- execute_orchestration: 20 lines
- execute_with_default_strategy: 50 lines (legacy fallback)

Total: ~170 lines (includes fallback + orchestration)

Lua strategies (hot-reloadable):
- standard_decomposition.lua: 60 lines
- standard_agent_spawning.lua: 50 lines
- standard_orchestration.lua: 40 lines
- standard_completion.lua: 70 lines

Total: ~220 lines (but hot-reloadable!)
```

**Trade-off:**
- 📈 Total lines increased slightly (+34 lines)
- ✅ But all logic is now hot-reloadable
- ✅ Better separation of concerns
- ✅ More context-aware execution
- ✅ Easier to maintain and extend

**Value:** Hot-reload capability >> line count

---

## Deployment Comparison

### Before (Hardcoded)

**Changing model selection logic:**

1. Edit `htdag_executor.ex`
2. Change thresholds
3. `mix compile`
4. Restart application
5. Test in production

**Time:** ~10 minutes (compile + deploy + restart)
**Risk:** 🔴 HIGH (full restart, compile errors, downtime)

### After (Lua-Powered)

**Changing model selection logic:**

1. Update Lua script in database:
   ```sql
   UPDATE htdag_execution_strategies
   SET agent_spawning_script = '
     -- Updated logic
     if complexity > 9.0 then
       model = "claude-opus-4"
     end
   '
   WHERE name = 'standard_strategy';
   ```

2. Wait for auto-refresh (< 5 min) or manual reload:
   ```elixir
   HTDAGStrategyLoader.reload_strategies()
   ```

**Time:** ~1 second (database update)
**Risk:** ✅ LOW (no restart, no compilation, instant rollback)

---

## Summary

| Aspect | Before (Hardcoded) | After (Lua-Powered) |
|--------|-------------------|-------------------|
| **Model Selection** | Fixed thresholds (8.0, 5.0) | Context-aware (phase, complexity, keywords) |
| **Agent Spawning** | Single agent always | Dynamic multi-agent (PM, architect, dev, QA, security) |
| **Decomposition** | None | Automatic SPARC phases with dependencies |
| **Validation** | None | Quality gates (tests, coverage, complexity) |
| **Configuration** | Compile-time | Runtime (database) |
| **Deployment** | Restart required | Hot-reload (< 5 min) |
| **Context** | Task only | Task + phase + history + metrics |
| **Flexibility** | Low | High |
| **Maintenance** | Edit Elixir | Edit Lua (via database) |

**Result:** 🎉 Massively more flexible execution with hot-reload capability!

---

## Migration Path

### Phase 1: ✅ COMPLETE (Current State)
- ✅ Created Lua infrastructure
- ✅ Maintained backward compatibility (legacy fallback)
- ✅ Added example strategies
- ✅ Compiled successfully

### Phase 2: Seed Strategies (Next)
```elixir
# Load example strategies into database
HTDAGStrategyLoader.seed_default_strategies()
```

### Phase 3: Gradual Migration
- Tasks with strategies → Lua execution
- Tasks without strategies → Legacy fallback
- Monitor performance, adjust strategies

### Phase 4: Full Migration
- All tasks use Lua strategies
- Remove legacy fallback (optional)
- 100% hot-reloadable execution

**No big-bang migration required!**

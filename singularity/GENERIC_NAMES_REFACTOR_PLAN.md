# Generic Names → Self-Documenting Refactor Plan

**Replace vague generic names (Manager, Gateway, Orchestrator) with specific, self-documenting names** 📝

---

## 🎯 Problem

Generic suffixes like "Manager", "Gateway", "Handler", "Orchestrator" are vague and require reading docs/code to understand purpose.

**Anti-Patterns:**
- ❌ `Manager` - Manages what?
- ❌ `Gateway` - Gateway to what? For what purpose?
- ❌ `Handler` - Handles what?
- ❌ `Orchestrator` - Orchestrates what?
- ❌ `Helper` - Helps with what?
- ❌ `Utils` - What utilities?

---

## ✅ Solution: Self-Documenting Names

### Rename Plan (Phase 3)

| Old Name (Generic) | New Name (Self-Documenting) | What It Does | Why Better |
|-------------------|----------------------------|--------------|------------|
| `Singularity.SystemStatusMonitor` | `Singularity.SystemStatusMonitor` | Monitors queue depth, agents, memory, uptime | "Monitor" says it observes, not modifies |
| `Singularity.HotReload.SafeCodeChangeDispatcher` | `Singularity.HotReload.SafeCodeChangeDispatcher` | Dispatches code changes through safety checks | "Dispatcher" + "Safe" + "CodeChange" = clear purpose |
| `Singularity.Bootstrap.EvolutionStageController` | `Singularity.Bootstrap.EvolutionStageController` | Controls evolution stage transitions (Embryonic → Adult) | "Controller" + "EvolutionStage" = clear domain |
| `Singularity.ArchitectureEngine.ConfigCache` | `Singularity.ArchitectureEngine.ConfigCache` | Caches architecture config in ETS | "Cache" says it stores, "Config" says what |

**Keep as-is (already specific):**
- ✅ `SPARC.Orchestrator` - "SPARC" is specific methodology, orchestrator fits
- ✅ `TaskGraph.Orchestrator` - "TaskGraph" is specific domain, orchestrator fits
- ✅ `BuildToolOrchestrator` - "BuildTool" is specific, orchestrator fits

---

## 📝 Detailed Analysis

### 1. Manager → SystemStatusMonitor

**File:** `lib/singularity/manager.ex`

**Current:**
```elixir
defmodule Singularity.SystemStatusMonitor do
  @moduledoc """
  System manager for queue and resource management.
  """

  def queue_depth do
    # Get queue depth from execution coordinator
  end

  def status do
    %{
      queue_depth: queue_depth(),
      agents_running: length(...),
      memory_usage: :erlang.memory(:total),
      uptime: :erlang.statistics(:wall_clock)
    }
  end
end
```

**Why rename:**
- ❌ "Manager" is too vague - manages what? how?
- ❌ Doesn't modify state - just reads metrics
- ❌ Confusing with other "managers" (EvolutionStageController, ConfigCache)

**After:**
```elixir
defmodule Singularity.SystemStatusMonitor do
  @moduledoc """
  Monitors system status: queue depth, running agents, memory usage, uptime.

  Read-only monitoring - does not modify system state.
  """

  def queue_depth # Same implementation
  def status      # Same implementation
end
```

**Benefits:**
- ✅ "Monitor" clearly indicates read-only observation
- ✅ "SystemStatus" says exactly what it monitors
- ✅ No confusion with controllers/managers that modify state

---

### 2. SafeCodeChangeDispatcher → SafeCodeChangeDispatcher

**File:** `lib/singularity/hot_reload/safe_code_change_dispatcher.ex`

**Current:**
```elixir
defmodule Singularity.HotReload.SafeCodeChangeDispatcher do
  @moduledoc """
  Thin facade that ensures hot-reload guardrails are used when other systems
  generate code changes outside the dedicated self-improving agent loop.

  The gateway will:
    * Start (or reuse) a self-improving agent for dispatching improvements.
    * Merge contextual metadata to preserve audit trails.
    * Forward the payload through the existing improvement queue.
  """

  def dispatch(payload, opts)
end
```

**Why rename:**
- ❌ "Gateway" is vague - gateway to what? from where?
- ❌ Doesn't say what it does with improvements
- ❌ "Improvement" is vague - code improvements? performance?

**After:**
```elixir
defmodule Singularity.HotReload.SafeCodeChangeDispatcher do
  @moduledoc """
  Dispatches code changes through safety validation pipeline.

  Ensures all code modifications go through:
  - Self-improving agent validation
  - Audit trail preservation
  - Hot-reload guardrails
  - Rollback capabilities

  Prevents unsafe direct code changes.
  """

  def dispatch(code_change, opts)
end
```

**Benefits:**
- ✅ "Dispatcher" says it routes/forwards
- ✅ "Safe" emphasizes validation/guardrails
- ✅ "CodeChange" is explicit about what it handles
- ✅ No confusion with API gateways, network gateways, etc.

---

### 3. EvolutionStageController → EvolutionStageController

**File:** `lib/singularity/bootstrap/evolution_stage_controller.ex`

**Current:**
```elixir
defmodule Singularity.Bootstrap.EvolutionStageController do
  @moduledoc """
  Manages Singularity's evolution stages from minimal self-discovery to full autonomy.

  ## Bootstrap Stages

  1. Embryonic (Self-Discovery)
  2. Larval (Supervised Self-Improvement)
  3. Juvenile (Autonomous Self-Development)
  4. Adult (Multi-Project Development)
  """

  def get_current_stage
  def can_advance?
  def advance_stage!
end
```

**Why rename:**
- ❌ "Manager" is overused (3 managers in codebase)
- ❌ Doesn't say it controls state transitions
- ❌ "Stage" is vague - what kind of stages?

**After:**
```elixir
defmodule Singularity.Bootstrap.EvolutionStageController do
  @moduledoc """
  Controls evolution stage transitions (Embryonic → Larval → Juvenile → Adult).

  Enforces stage requirements:
  - Time in stage (days minimum)
  - Success metrics (bug fixes, approval rate)
  - Safety validation before advancement

  Prevents premature stage transitions.
  """

  def get_current_stage
  def can_advance?
  def advance_stage!
end
```

**Benefits:**
- ✅ "Controller" indicates it manages state transitions
- ✅ "EvolutionStage" is specific to Singularity's growth model
- ✅ Clear distinction from managers that just observe

---

### 4. ConfigCache → ConfigCache

**File:** `lib/singularity/architecture_engine/config_cache.ex`

**Current:**
```elixir
defmodule Singularity.ArchitectureEngine.ConfigCache do
  @moduledoc """
  ETS Manager for ArchitectureEngine configuration

  Manages ETS tables for workspace detection, build tool detection, and other configs.
  """

  def get_workspace_template(id)
  def get_all_workspace_templates
  def get_build_tool_template(name)
end
```

**Why rename:**
- ❌ "Manager" is vague
- ❌ Doesn't say it's a cache
- ❌ "Ets" is implementation detail, not domain concept

**After:**
```elixir
defmodule Singularity.ArchitectureEngine.ConfigCache do
  @moduledoc """
  Caches architecture configuration in ETS for fast lookups.

  Cached configurations:
  - Workspace detection templates
  - Build tool detection rules
  - Package manager patterns
  - Naming conventions

  Data loaded from JSON files on startup, cached in ETS for performance.
  """

  def get_workspace_template(id)
  def get_all_workspace_templates
  def get_build_tool_template(name)
end
```

**Benefits:**
- ✅ "Cache" clearly indicates purpose (fast lookups)
- ✅ "Config" says what it caches
- ✅ Implementation (ETS) hidden, focus on purpose
- ✅ No confusion with other managers

---

## 🔍 Keep As-Is (Already Specific)

### SPARC.Orchestrator ✅

**File:** `lib/singularity/execution/sparc/orchestrator.ex`

```elixir
defmodule Singularity.Execution.SPARC.Orchestrator do
  @moduledoc """
  SPARC Orchestrator - Template-driven SPARC execution with TaskGraph integration.
  """
end
```

**Why keep:**
- ✅ "SPARC" is specific methodology (Specification, Pseudocode, Architecture, Refinement, Completion)
- ✅ "Orchestrator" fits - coordinates multiple DAGs (Template DAG + SPARC TaskGraph)
- ✅ Already self-documenting

### TaskGraph.Orchestrator ✅

**File:** `lib/singularity/execution/task_graph/orchestrator.ex`

**Why keep:**
- ✅ "TaskGraph" is specific domain
- ✅ "Orchestrator" fits - coordinates task execution across graph
- ✅ Consistent with SPARC.Orchestrator pattern

### BuildToolOrchestrator ✅

**File:** `lib/singularity/integration/platforms/build_tool_orchestrator.ex`

**Why keep:**
- ✅ "BuildTool" is specific (mix, cargo, npm, etc.)
- ✅ "Orchestrator" fits - coordinates multiple build tools
- ✅ Already clear purpose

---

## 📊 Summary

### Rename (4 modules):
1. `Manager` → `SystemStatusMonitor`
2. `SafeCodeChangeDispatcher` → `SafeCodeChangeDispatcher`
3. `EvolutionStageController` → `EvolutionStageController`
4. `ConfigCache` → `ConfigCache`

### Keep (3 modules):
1. `SPARC.Orchestrator` ✅
2. `TaskGraph.Orchestrator` ✅
3. `BuildToolOrchestrator` ✅

---

## 🎯 Naming Principles

### When to Use Generic Suffix

**Orchestrator** - OK when prefixed with specific domain:
- ✅ `SPARC.Orchestrator` - SPARC is specific
- ✅ `TaskGraph.Orchestrator` - TaskGraph is specific
- ❌ `Orchestrator` alone - too vague

**Manager** - Generally avoid, use specific verb:
- ✅ `SystemStatusMonitor` - monitors (specific action)
- ✅ `EvolutionStageController` - controls transitions
- ✅ `ConfigCache` - caches data
- ❌ `Manager` - too vague

**Gateway** - Avoid, use specific verb + domain:
- ✅ `SafeCodeChangeDispatcher` - dispatches code changes safely
- ❌ `Gateway` - vague about purpose

### Self-Documenting Patterns

1. **Action + What**: `Monitor` + `SystemStatus`
2. **Safety Qualifier + Action + What**: `Safe` + `Dispatch` + `CodeChange`
3. **Domain + Role**: `EvolutionStage` + `Controller`
4. **What + Purpose**: `Config` + `Cache`

---

## ✅ Next Steps

1. Execute git mv for 4 modules
2. Update references across codebase
3. Verify compilation
4. Create comprehensive documentation (like HTDAG_TASKGRAPH_REFACTOR.md)
5. Look for more generic names to improve

---

**Goal:** Every module name should answer "What does it do?" without reading documentation.

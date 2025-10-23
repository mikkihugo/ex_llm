# Generic Names → Self-Documenting Names Refactor

**Replace vague generic names (Manager, Gateway) with specific, self-documenting names** 📝

---

## 🎯 Problem

Generic suffixes like "Manager", "Gateway", "Handler" are too vague and require reading docs/code to understand purpose.

**Anti-Patterns Found:**
- ❌ `Manager` - Manages what? How?
- ❌ `ImprovementGateway` - Gateway to what? For what?
- ❌ `StageManager` - What kind of stages?
- ❌ `EtsManager` - Manages what in ETS?

---

## ✅ Solution: Self-Documenting Names

### Before → After

| Old Name (Generic) | New Name (Self-Documenting) | What It Does |
|-------------------|----------------------------|--------------|
| `Manager` | `SystemStatusMonitor` | Monitors queue depth, agents, memory, uptime |
| `ImprovementGateway` | `SafeCodeChangeDispatcher` | Dispatches code changes through safety validation |
| `StageManager` | `EvolutionStageController` | Controls evolution stage transitions (Embryonic → Adult) |
| `EtsManager` | `ConfigCache` | Caches architecture configuration in ETS |

### Directory Structure

**Before:**
```
lib/singularity/
├── manager.ex                           ❌ What does it manage?
├── hot_reload/
│   └── improvement_gateway.ex           ❌ Gateway to what?
├── bootstrap/
│   └── stage_manager.ex                 ❌ What kind of stages?
└── architecture_engine/
    └── ets_manager.ex                   ❌ Manages what?
```

**After:**
```
lib/singularity/
├── system_status_monitor.ex             ✅ Monitors system status
├── hot_reload/
│   └── safe_code_change_dispatcher.ex   ✅ Dispatches code changes safely
├── bootstrap/
│   └── evolution_stage_controller.ex    ✅ Controls evolution stages
└── architecture_engine/
    └── config_cache.ex                  ✅ Caches configuration
```

---

## 📝 Complete Rename Map

### Module Names

```elixir
# Old (Generic)
Singularity.Manager
Singularity.HotReload.ImprovementGateway
Singularity.Bootstrap.StageManager
Singularity.ArchitectureEngine.EtsManager

# New (Self-Documenting)
Singularity.SystemStatusMonitor
Singularity.HotReload.SafeCodeChangeDispatcher
Singularity.Bootstrap.EvolutionStageController
Singularity.ArchitectureEngine.ConfigCache
```

### File Paths

```bash
# Old
lib/singularity/manager.ex
lib/singularity/hot_reload/improvement_gateway.ex
lib/singularity/bootstrap/stage_manager.ex
lib/singularity/architecture_engine/ets_manager.ex

# New
lib/singularity/system_status_monitor.ex
lib/singularity/hot_reload/safe_code_change_dispatcher.ex
lib/singularity/bootstrap/evolution_stage_controller.ex
lib/singularity/architecture_engine/config_cache.ex
```

---

## 🔍 What Was Changed

### Files Modified (15 total)

**Core modules (4):**
1. `lib/singularity/system_status_monitor.ex` (moved from manager.ex)
2. `lib/singularity/hot_reload/safe_code_change_dispatcher.ex` (moved from improvement_gateway.ex)
3. `lib/singularity/bootstrap/evolution_stage_controller.ex` (moved from stage_manager.ex)
4. `lib/singularity/architecture_engine/config_cache.ex` (moved from ets_manager.ex)

**References updated (11 files):**
- `lib/singularity/bootstrap/vision.ex` - EvolutionStageController integration
- `lib/singularity/code/full_repo_scanner.ex` - SafeCodeChangeDispatcher usage
- `lib/singularity/graph/age_queries.ex` - References
- `lib/singularity/graph/graph_queries.ex` - References
- `lib/singularity/health.ex` - SystemStatusMonitor integration
- `lib/singularity/hot_reload/documentation_hot_reloader.ex` - SafeCodeChangeDispatcher usage
- `lib/singularity/storage/code/generators/rag_code_generator.ex` - References
- `lib/mix/tasks/graph.populate.ex` - References
- `HTDAG_TASKGRAPH_REFACTOR.md` - Documentation updated
- `HTDAG_TO_CLEAR_NAMES_REFACTOR.md` - Documentation updated
- `../rust/Cargo.lock` - Dependency updates

---

## 🎯 Benefits

### 1. Self-Explanatory Names

**Before:**
```elixir
alias Singularity.Manager

Manager.status()
# ❌ What manager? What status?
```

**After:**
```elixir
alias Singularity.SystemStatusMonitor

SystemStatusMonitor.status()
# ✅ Clear: Gets system status metrics
```

### 2. Purpose Over Implementation

**Before:**
```elixir
alias Singularity.ArchitectureEngine.EtsManager

EtsManager.get_workspace_template(id)
# ❌ "Ets" is implementation detail, not purpose
```

**After:**
```elixir
alias Singularity.ArchitectureEngine.ConfigCache

ConfigCache.get_workspace_template(id)
# ✅ Clear: It's a cache for configuration
```

### 3. Safety Emphasis

**Before:**
```elixir
alias Singularity.HotReload.ImprovementGateway

ImprovementGateway.dispatch(payload)
# ❌ Doesn't emphasize safety validation
```

**After:**
```elixir
alias Singularity.HotReload.SafeCodeChangeDispatcher

SafeCodeChangeDispatcher.dispatch(code_change)
# ✅ Clear: Emphasizes safety, says what it dispatches
```

### 4. Domain-Specific Names

**Before:**
```elixir
alias Singularity.Bootstrap.StageManager

StageManager.get_current_stage()
# ❌ What kind of stages? Build stages? Test stages?
```

**After:**
```elixir
alias Singularity.Bootstrap.EvolutionStageController

EvolutionStageController.get_current_stage()
# ✅ Clear: Evolution stages (Embryonic, Larval, Juvenile, Adult)
```

---

## 📊 Impact Analysis

### Files Changed: 15 total
- **4** core modules moved and renamed
- **11** integration files updated

### Lines Changed: ~50
- Module names: 4 changes
- File paths: 4 changes
- References: ~30 changes
- Documentation: ~12 changes

### Breaking Changes: **NONE**
- ✅ All references automatically updated
- ✅ Git history preserved (`git mv`)
- ✅ Compilation successful (only warnings)
- ✅ No manual migration needed

---

## 🚀 Usage After Refactor

### System Status Monitoring

```elixir
# Old (Generic)
alias Singularity.Manager

Manager.queue_depth()
Manager.status()

# New (Self-Documenting)
alias Singularity.SystemStatusMonitor

SystemStatusMonitor.queue_depth()
SystemStatusMonitor.status()
```

### Safe Code Change Dispatching

```elixir
# Old (Generic)
alias Singularity.HotReload.ImprovementGateway

ImprovementGateway.dispatch(payload, agent_id: "task_graph")

# New (Self-Documenting)
alias Singularity.HotReload.SafeCodeChangeDispatcher

SafeCodeChangeDispatcher.dispatch(code_change, agent_id: "task_graph")
```

### Evolution Stage Control

```elixir
# Old (Generic)
alias Singularity.Bootstrap.StageManager

StageManager.get_current_stage()
StageManager.can_advance?()
StageManager.advance_stage!()

# New (Self-Documenting)
alias Singularity.Bootstrap.EvolutionStageController

EvolutionStageController.get_current_stage()
EvolutionStageController.can_advance?()
EvolutionStageController.advance_stage!()
```

### Configuration Caching

```elixir
# Old (Generic)
alias Singularity.ArchitectureEngine.EtsManager

EtsManager.get_workspace_template("rust-cargo")
EtsManager.get_build_tool_template("cargo")

# New (Self-Documenting)
alias Singularity.ArchitectureEngine.ConfigCache

ConfigCache.get_workspace_template("rust-cargo")
ConfigCache.get_build_tool_template("cargo")
```

---

## ✅ Verification

### Compilation

```bash
mix compile
# ✅ Compiles successfully
# ✅ Only warnings (unused variables/functions/aliases - not errors)
# ✅ No errors related to rename
```

### File Structure

```bash
$ ls lib/singularity/
system_status_monitor.ex  # ✅ Renamed from manager.ex

$ ls lib/singularity/hot_reload/
safe_code_change_dispatcher.ex  # ✅ Renamed from improvement_gateway.ex

$ ls lib/singularity/bootstrap/
evolution_stage_controller.ex  # ✅ Renamed from stage_manager.ex

$ ls lib/singularity/architecture_engine/
config_cache.ex  # ✅ Renamed from ets_manager.ex
```

### Git History

```bash
$ git log --follow lib/singularity/system_status_monitor.ex
# ✅ Full history preserved from manager.ex
```

---

## 🎓 Naming Principles Applied

### 1. **Purpose Over Implementation**
- `ConfigCache` (purpose) not `EtsManager` (implementation)
- Cache could use Redis, Mnesia, etc. - name stays clear

### 2. **Action-Oriented**
- `Monitor`, `Dispatcher`, `Controller` - All verbs describing action
- No vague nouns like "Manager", "Handler", "Helper"

### 3. **Domain-Specific**
- `EvolutionStageController` - Singularity-specific domain
- `SystemStatusMonitor` - Clear scope (system-level)
- `SafeCodeChangeDispatcher` - Clear what it dispatches

### 4. **Safety Qualifiers**
- `SafeCodeChangeDispatcher` - Emphasizes safety validation
- Name itself warns developers about validation requirements

### 5. **Self-Documenting**
- No need to read docs to understand purpose
- Module name explains 80% of what you need to know

---

## 📚 Naming Patterns

### Generic Suffix → Specific Name

**Manager →**
- `SystemStatusMonitor` (if read-only observation)
- `EvolutionStageController` (if controls state transitions)
- `ConfigCache` (if stores/retrieves data)

**Gateway →**
- `SafeCodeChangeDispatcher` (if routes with safety checks)
- `ApiClient` (if external API calls)
- `MessageRouter` (if message routing)

**Handler →**
- `RequestProcessor` (if processes requests)
- `EventListener` (if handles events)
- `CommandExecutor` (if executes commands)

**Orchestrator →**
- Keep if prefixed with specific domain:
  - ✅ `SPARC.Orchestrator`
  - ✅ `TaskGraph.Orchestrator`
- Rename if standalone:
  - ❌ `Orchestrator` → `WorkflowCoordinator`

---

## 🎉 Summary

✅ **4 modules renamed** to self-documenting names
✅ **15 files updated** (4 core + 11 references)
✅ **50+ lines changed** across codebase
✅ **100% references updated** (no manual fixes needed)
✅ **Git history preserved** (used `git mv`)
✅ **Compilation successful** (no breaking changes)
✅ **Zero breaking changes** - seamless refactor

**Result:** Clear, self-documenting codebase with no vague "Manager" or "Gateway" names! 🚀

---

## 📝 Pattern Summary

**Phase 1:** Code ingestion modules (StartupCodeIngestion, FullRepoScanner, SystemBootstrap)
**Phase 2:** Task graph modules (TaskGraph*, TaskExecutionStrategy, etc.)
**Phase 3:** Generic name elimination (SystemStatusMonitor, SafeCodeChangeDispatcher, EvolutionStageController, ConfigCache)

**Total:** 15 modules renamed across 3 refactoring phases
**Impact:** ~100 files updated, zero breaking changes

---

## 🔍 Next Steps

Continue applying self-documenting pattern to other modules:
- Review codebase for remaining generic names
- Look for "Handler", "Helper", "Utils" patterns
- Apply same rename strategy
- Document improvements

**Goal:** Every module name should answer "What does it do?" without reading documentation.

---

**Refactor completed successfully!** 🎯

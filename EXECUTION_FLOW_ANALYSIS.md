# Execution Flow Analysis: Documented vs Actual

## Executive Summary

**Critical Finding**: The documented execution flow in CLAUDE.md and module documentation does NOT match the actual implementation. The system is currently **DISABLED** and bypassed.

**Impact**:
- Core orchestration features are non-functional
- Documentation misleads developers
- Architectural debt is accumulating
- Multiple modules exist but are never called

---

## 1. Documented Flow (From CLAUDE.md)

The documentation claims this flow:

```
User Request → ExecutionCoordinator → Planner →
  ArchitectureAnalyzer → SemanticCodeSearch → Code Generation
```

### Documented Components:
1. **ExecutionCoordinator** - Orchestrates the two DAGs
2. **Planner** - Produces new strategy payloads
3. **ArchitectureAnalyzer** - Pattern detection and analysis
4. **SemanticCodeSearch** - RAG-based code search
5. **MethodologyExecutor** - Executes SPARC methodology

---

## 2. Actual Flow (From Code Analysis)

### Current Reality: **DISABLED**

```
application.ex:59 → # TODO: Fix NatsOrchestrator to work with latest HybridAgent API
application.ex:59 → # Singularity.NatsOrchestrator,
```

**The entire NATS orchestration is commented out!**

### What Actually Happens (When Enabled):

```
NATS "execution.request"
  → NatsOrchestrator.handle_execution_request
  → SemanticCache.get (check cache)
  → If miss:
      → TemplateOptimizer.select_template
      → HybridAgent.start_link
      → HybridAgent.process_task
          → RuleEngineV2.execute_category (try rules first)
          → If rules fail:
              → SemanticCache check again
              → If miss: LLM.Provider.call
  → Response published to NATS
```

---

## 3. Module Call Analysis

### 3.1 Actually Called Modules

**✅ ACTIVE** (when NatsOrchestrator is enabled):

| Module | Called By | Purpose |
|--------|-----------|---------|
| `NatsOrchestrator` | Application (DISABLED) | NATS message handler |
| `TemplateOptimizer` | NatsOrchestrator | Select best template |
| `HybridAgent` | NatsOrchestrator | Process task with rules/LLM |
| `RuleEngineV2` | HybridAgent | Try rule-based execution first |
| `SemanticCache` | NatsOrchestrator, HybridAgent | Cache LLM responses |
| `LLM.Provider` | HybridAgent | Call LLM when rules fail |

### 3.2 Never Called Modules

**❌ DEAD CODE** (exists but never executed):

| Module | Why Dead | Location |
|--------|----------|----------|
| `ExecutionCoordinator` | Not called by anyone | `/lib/singularity/agents/execution_coordinator.ex` |
| `Planner` | Only called by Decider (not in flow) | `/lib/singularity/autonomy/planner.ex` |
| `ArchitectureAnalyzer` | No caller in active path | `/lib/singularity/code/analyzers/architecture_analyzer.ex` |
| `SemanticCodeSearch` | Only referenced, never used | `/lib/singularity/search/semantic_code_search.ex` |
| `MethodologyExecutor` | Referenced by ExecutionCoordinator (dead) | `/lib/singularity/quality/methodology_executor.ex` |
| `HTDAG` | Used by dead modules only | `/lib/singularity/planning/htdag.ex` |

### 3.3 Bypass Evidence

**NatsOrchestrator BYPASSES ExecutionCoordinator:**

```elixir
# nats_orchestrator.ex:90-95
template = TemplateOptimizer.select_template(%{...})  # Direct call
result = HybridAgent.process_task(agent_id, %{...})   # Direct call
```

**Should be** (per documentation):
```elixir
{:ok, result, metrics} = ExecutionCoordinator.execute(goal, opts)
```

---

## 4. Architectural Gaps

### 4.1 Missing Integrations

1. **ExecutionCoordinator ← NatsOrchestrator**
   - Gap: NatsOrchestrator doesn't call ExecutionCoordinator
   - Impact: DAG orchestration never happens
   - Fix: Route through ExecutionCoordinator

2. **Planner ← ExecutionCoordinator**
   - Gap: ExecutionCoordinator doesn't use Planner
   - Impact: No strategic planning
   - Fix: Integrate vision-driven planning

3. **ArchitectureAnalyzer ← ExecutionCoordinator**
   - Gap: Never invoked for analysis
   - Impact: No codebase understanding
   - Fix: Analyze before generation

4. **SemanticCodeSearch ← MethodologyExecutor**
   - Gap: RAG search not integrated
   - Impact: No context from codebase
   - Fix: Use for finding examples

5. **HTDAG ← ExecutionCoordinator**
   - Gap: HTDAG created but not used
   - Impact: No task decomposition
   - Fix: Decompose complex tasks

### 4.2 Design Conflicts

**Conflict 1: Template Selection**
- Current: `TemplateOptimizer.select_template` (simple)
- Should be: `TemplateOptimizer.get_best_template` (with DAG tracking)

**Conflict 2: Task Execution**
- Current: `HybridAgent.process_task` (rules → LLM)
- Should be: `ExecutionCoordinator.execute` → SPARC phases

**Conflict 3: Caching Strategy**
- Current: Simple `SemanticCache.get/put`
- Should be: Integrated with template performance tracking

---

## 5. Flow Diagrams

### 5.1 Documented Flow (IDEAL)

```
┌─────────────────────────────────────────────────────────────┐
│                     DOCUMENTED FLOW                          │
└─────────────────────────────────────────────────────────────┘

  NATS Request
       │
       ▼
  ┌──────────────────┐
  │ NatsOrchestrator │
  └────────┬─────────┘
           │
           ▼
  ┌────────────────────────┐
  │ ExecutionCoordinator   │◄──── Should orchestrate both DAGs
  └────────┬───────────────┘
           │
           ├─────────────────────┐
           │                     │
           ▼                     ▼
  ┌────────────────┐    ┌──────────────────┐
  │ Template DAG   │    │    SPARC DAG     │
  │ (Optimizer)    │    │    (HTDAG)       │
  └────────┬───────┘    └────────┬─────────┘
           │                     │
           ▼                     ▼
  ┌─────────────────┐   ┌──────────────────┐
  │ Best Template   │   │ Planner          │
  └─────────────────┘   │ (Vision-driven)  │
                        └────────┬─────────┘
                                 │
                                 ▼
                        ┌──────────────────────┐
                        │ ArchitectureAnalyzer │
                        └────────┬─────────────┘
                                 │
                                 ▼
                        ┌──────────────────────┐
                        │ SemanticCodeSearch   │
                        │ (RAG)                │
                        └────────┬─────────────┘
                                 │
                                 ▼
                        ┌──────────────────────┐
                        │ MethodologyExecutor  │
                        │ (SPARC Phases)       │
                        └────────┬─────────────┘
                                 │
                                 ▼
                        ┌──────────────────────┐
                        │ Code Generation      │
                        └──────────────────────┘
```

### 5.2 Actual Flow (CURRENT - DISABLED)

```
┌─────────────────────────────────────────────────────────────┐
│                     ACTUAL FLOW (DISABLED!)                  │
└─────────────────────────────────────────────────────────────┘

  NATS Request
       │
       ▼
  ┌──────────────────┐
  │ NatsOrchestrator │  ← COMMENTED OUT IN application.ex:59!
  └────────┬─────────┘
           │
           ▼
  ┌────────────────────────┐
  │ SemanticCache.get      │  ← Check cache first
  └────────┬───────────────┘
           │
           ├─── Hit ──→ Return cached response
           │
           └─── Miss
                 │
                 ▼
        ┌────────────────────────┐
        │ TemplateOptimizer      │  ← BYPASSES ExecutionCoordinator!
        │ .select_template       │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │ HybridAgent.start_link │
        │ HybridAgent            │
        │ .process_task          │
        └────────┬───────────────┘
                 │
                 ▼
        ┌────────────────────────┐
        │ RuleEngineV2           │  ← Try rules first (90% cases)
        │ .execute_category      │
        └────────┬───────────────┘
                 │
                 ├─── Confident (≥0.9) ──→ Use rule result
                 │
                 └─── Not confident
                       │
                       ▼
              ┌────────────────────────┐
              │ SemanticCache check    │
              └────────┬───────────────┘
                       │
                       ├─── Hit ──→ Adapt cached
                       │
                       └─── Miss
                             │
                             ▼
                    ┌─────────────────┐
                    │ LLM.Provider    │  ← Expensive! (5% cases)
                    │ .call           │
                    └─────────────────┘

┌────────────────────────────────────────────────────┐
│           DEAD CODE (Never Executed)               │
├────────────────────────────────────────────────────┤
│  ❌ ExecutionCoordinator                           │
│  ❌ Planner                                         │
│  ❌ ArchitectureAnalyzer                           │
│  ❌ SemanticCodeSearch                             │
│  ❌ MethodologyExecutor                            │
│  ❌ HTDAG                                           │
└────────────────────────────────────────────────────┘
```

### 5.3 Proposed Integrated Flow

```
┌─────────────────────────────────────────────────────────────┐
│              PROPOSED INTEGRATED FLOW                        │
└─────────────────────────────────────────────────────────────┘

  NATS Request
       │
       ▼
  ┌──────────────────┐
  │ NatsOrchestrator │  ← Re-enable and route correctly
  └────────┬─────────┘
           │
           ▼
  ┌────────────────────────────────┐
  │ SemanticCache.get              │  ← Fast path
  └────────┬───────────────────────┘
           │
           ├─── Hit ──→ Return (0ms, $0)
           │
           └─── Miss
                 │
                 ▼
        ┌──────────────────────────────┐
        │ ExecutionCoordinator.execute │  ← INTEGRATE!
        └────────┬─────────────────────┘
                 │
                 ├───────────────────────────────┐
                 │                               │
                 ▼                               ▼
        ┌─────────────────┐          ┌──────────────────────┐
        │ Template DAG    │          │ SPARC DAG (HTDAG)    │
        │ (Performance    │          │                      │
        │  Tracking)      │          │ Decompose task →     │
        └────────┬────────┘          │   Planner            │
                 │                   └────────┬─────────────┘
                 │                            │
                 ▼                            ▼
        ┌─────────────────┐          ┌──────────────────────┐
        │ Best Template   │          │ ArchitectureAnalyzer │
        └─────────────────┘          │ (Understand context) │
                                     └────────┬─────────────┘
                                              │
                                              ▼
                                     ┌──────────────────────┐
                                     │ SemanticCodeSearch   │
                                     │ (Find examples)      │
                                     └────────┬─────────────┘
                                              │
                                              ▼
                                     ┌──────────────────────┐
                                     │ HybridAgent          │
                                     │ (Rules → Cache → LLM)│
                                     └────────┬─────────────┘
                                              │
                                              ▼
                                     ┌──────────────────────┐
                                     │ MethodologyExecutor  │
                                     │ (SPARC phases)       │
                                     └────────┬─────────────┘
                                              │
                                              ▼
                                     ┌──────────────────────┐
                                     │ Template Optimizer   │
                                     │ .record_usage        │
                                     │ (Feedback loop)      │
                                     └──────────────────────┘
```

---

## 6. Code Evidence

### 6.1 NatsOrchestrator is DISABLED

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/application.ex`

```elixir
# Lines 57-59
# NATS Orchestrator (connects AI Server to ExecutionCoordinator)
# TODO: Fix NatsOrchestrator to work with latest HybridAgent API
# Singularity.NatsOrchestrator,
```

### 6.2 NatsOrchestrator Bypasses ExecutionCoordinator

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/interfaces/nats/orchestrator.ex`

```elixir
# Lines 89-109 - Direct calls, no ExecutionCoordinator!
template = TemplateOptimizer.select_template(%{
  task: request["task"],
  language: request["language"] || "auto",
  complexity: request["complexity"] || "medium"
})

agent_id = "orchestrator_agent_#{:erlang.unique_integer()}"
{:ok, _pid} = HybridAgent.start_link(id: agent_id, specialization: :general)

result = HybridAgent.process_task(agent_id, %{
  prompt: request["task"],
  context: request["context"] || %{},
  template: template,
  complexity: request["complexity"]
})
```

### 6.3 ExecutionCoordinator Has NO Callers

**Search Results**:
```bash
$ rg "ExecutionCoordinator\.execute"
# No results - NEVER CALLED!
```

**Only referenced by**:
- `application.ex:55` - Started as GenServer
- `nats_orchestrator.ex:14` - Aliased but not used
- Itself (internal calls only)

### 6.4 Template Selection Mismatch

**NatsOrchestrator uses** (simple):
```elixir
TemplateOptimizer.select_template(%{...})
```

**ExecutionCoordinator expects** (with tracking):
```elixir
TemplateOptimizer.get_best_template(task_type, language)
```

### 6.5 Planner Only Called by Decider

**File**: `/home/mhugo/code/singularity/singularity_app/lib/singularity/autonomy/decider.ex`

```elixir
# Planner.generate called only here
# Decider is NOT in the execution flow!
payload = Planner.generate(state, context)
```

---

## 7. Integration Strategy

### Phase 1: Fix Critical Path (Week 1)

**Goal**: Re-enable NatsOrchestrator with proper routing

1. **Fix HybridAgent API compatibility**
   ```elixir
   # Update NatsOrchestrator to handle HybridAgent's tuple response
   {response_type, response_content, metadata} = result
   ```

2. **Re-enable in application.ex**
   ```elixir
   # Line 59 - Remove comment
   Singularity.NatsOrchestrator,
   ```

3. **Add ExecutionCoordinator routing**
   ```elixir
   # In NatsOrchestrator.handle_execution_request
   {:ok, result, metrics} = ExecutionCoordinator.execute(goal, [
     language: request["language"],
     complexity: request["complexity"]
   ])
   ```

### Phase 2: Integrate Planning (Week 2)

**Goal**: Connect Planner and ArchitectureAnalyzer

1. **ExecutionCoordinator calls Planner**
   ```elixir
   # Before executing SPARC DAG
   task_type = extract_task_type(goal)
   {:vision_task, task} = Planner.get_current_goal()
   ```

2. **Integrate ArchitectureAnalyzer**
   ```elixir
   # Analyze codebase before generation
   {:ok, analysis} = ArchitectureAnalyzer.analyze_codebase(workspace)
   context = Map.put(context, :architecture, analysis)
   ```

### Phase 3: Enable RAG Search (Week 3)

**Goal**: Use SemanticCodeSearch for context

1. **MethodologyExecutor uses SemanticCodeSearch**
   ```elixir
   # In execute_phase(:architecture, ...)
   {:ok, similar_code} = SemanticCodeSearch.semantic_search(
     codebase_id,
     query_embedding,
     10
   )
   ```

2. **Populate embeddings**
   ```elixir
   # Background job to embed existing code
   mix task: singularity.embed_codebase
   ```

### Phase 4: HTDAG Integration (Week 4)

**Goal**: Use HTDAG for complex task decomposition

1. **ExecutionCoordinator creates HTDAG**
   ```elixir
   # Line 78 - Already exists!
   sparc_dag = HTDAG.decompose(goal)
   ```

2. **Track execution in DAG**
   ```elixir
   # Mark tasks complete/failed
   HTDAG.mark_completed(sparc_dag, task.id)
   ```

### Phase 5: Close Feedback Loop (Week 5)

**Goal**: Template performance tracking

1. **ExecutionCoordinator records metrics**
   ```elixir
   # Lines 98-102 - Already exists!
   TemplateOptimizer.record_usage(template_id, task, metrics)
   ```

2. **TemplateOptimizer learns**
   ```elixir
   # Calculate rankings based on performance
   calculate_template_rankings(performance_data)
   ```

---

## 8. Metrics & Validation

### Success Criteria

1. **All modules active**
   - ✅ NatsOrchestrator enabled
   - ✅ ExecutionCoordinator called
   - ✅ Planner integrated
   - ✅ ArchitectureAnalyzer used
   - ✅ SemanticCodeSearch active
   - ✅ HTDAG decomposition working

2. **Flow validated**
   - ✅ NATS → ExecutionCoordinator → Response
   - ✅ Template DAG tracking performance
   - ✅ SPARC DAG decomposing tasks
   - ✅ Feedback loop closing

3. **Performance**
   - Cache hit rate > 40%
   - Rule execution > 80%
   - LLM calls < 10%
   - Average latency < 2s

### Testing Strategy

```elixir
# Integration test
test "full execution flow" do
  # Publish NATS request
  request = %{
    "task" => "Create NATS consumer",
    "language" => "elixir",
    "complexity" => "medium"
  }

  # Verify flow
  assert_called ExecutionCoordinator.execute(_, _)
  assert_called Planner.get_current_goal()
  assert_called ArchitectureAnalyzer.analyze_codebase(_)
  assert_called SemanticCodeSearch.semantic_search(_, _, _)
  assert_called MethodologyExecutor.execute(_, _)
  assert_called TemplateOptimizer.record_usage(_, _, _)
end
```

---

## 9. Risk Assessment

### High Risk

1. **HybridAgent API Changes**
   - Risk: Breaking changes to return format
   - Mitigation: Version compatibility layer

2. **Performance Degradation**
   - Risk: Full flow slower than current bypass
   - Mitigation: Parallel execution, caching

3. **Dependency Cycles**
   - Risk: ExecutionCoordinator → Planner → ExecutionCoordinator
   - Mitigation: Clear phase separation

### Medium Risk

1. **Database Schema Migrations**
   - Risk: Breaking existing embeddings
   - Mitigation: Migration scripts, backward compatibility

2. **Template Selection Conflicts**
   - Risk: Two different selection methods
   - Mitigation: Deprecate old method

### Low Risk

1. **Documentation Updates**
   - Risk: Docs still out of sync
   - Mitigation: Auto-generate from code

---

## 10. Recommendations

### Immediate Actions (This Week)

1. **RE-ENABLE NatsOrchestrator**
   - Fix HybridAgent compatibility
   - Uncomment in application.ex
   - Test basic flow

2. **ROUTE Through ExecutionCoordinator**
   - Update NatsOrchestrator.handle_execution_request
   - Call ExecutionCoordinator.execute
   - Verify DAG orchestration

3. **DOCUMENT Actual Flow**
   - Update CLAUDE.md
   - Add flow diagrams
   - Mark dead code

### Short-term (Next Month)

1. **Integrate Planner**
   - Connect to ExecutionCoordinator
   - Enable vision-driven planning
   - Test with real tasks

2. **Enable RAG Search**
   - Embed existing codebase
   - Integrate SemanticCodeSearch
   - Validate improvements

3. **Complete Feedback Loop**
   - Track template performance
   - Learn from successes/failures
   - Optimize selection

### Long-term (Next Quarter)

1. **Deprecate Dead Code**
   - Remove unused modules
   - Consolidate duplicates
   - Clean architecture

2. **Performance Optimization**
   - Parallel execution
   - Smart caching
   - Cost reduction

3. **Advanced Features**
   - Multi-codebase search
   - Cross-language patterns
   - Auto-refactoring

---

## Appendix A: Module Dependency Graph

```
┌─────────────────────────────────────────────────────┐
│              MODULE DEPENDENCIES                     │
└─────────────────────────────────────────────────────┘

Application (ROOT)
 │
 ├── ✅ TemplateOptimizer (Active)
 │    └── HTDAG (Started, not used)
 │
 ├── ✅ ExecutionCoordinator (Started, never called!)
 │    ├── TemplateOptimizer (should use .get_best_template)
 │    ├── HTDAG (creates but doesn't use)
 │    └── MethodologyExecutor (calls, which is dead)
 │         ├── TechnologyTemplateLoader
 │         ├── RAGCodeGenerator
 │         └── QualityCodeGenerator
 │
 └── ❌ NatsOrchestrator (DISABLED!)
      ├── TemplateOptimizer (.select_template - bypass!)
      ├── HybridAgent
      │    ├── RuleEngineV2
      │    └── LLM.Provider
      └── SemanticCache

DEAD MODULES (Never in active path):
 ❌ Planner (only called by Decider, not in flow)
 ❌ ArchitectureAnalyzer (no callers)
 ❌ SemanticCodeSearch (only self-referenced)
 ❌ HTDAG (created by dead modules only)
```

---

## Appendix B: Configuration Changes Needed

### application.ex
```elixir
# Line 59 - CHANGE FROM:
# Singularity.NatsOrchestrator,

# TO:
Singularity.NatsOrchestrator,  # Fixed HybridAgent API
```

### nats_orchestrator.ex
```elixir
# Line 90-109 - CHANGE FROM:
template = TemplateOptimizer.select_template(%{...})
result = HybridAgent.process_task(agent_id, %{...})

# TO:
goal = %{
  description: request["task"],
  type: extract_task_type(request["task"])
}

{:ok, result, metrics} = ExecutionCoordinator.execute(goal, [
  language: request["language"],
  complexity: request["complexity"]
])
```

### execution_coordinator.ex
```elixir
# Line 73 - CHANGE FROM:
{:ok, template_id} = TemplateOptimizer.get_best_template(task_type, language)

# TO (ensure it works with HybridAgent):
template = TemplateOptimizer.select_template(%{
  task: goal.description,
  language: language,
  complexity: opts[:complexity] || "medium"
})
```

---

## Conclusion

**The execution flow is fundamentally broken:**

1. ✅ **Documentation says**: Sophisticated DAG-based orchestration
2. ❌ **Reality is**: Simple cache → template → hybrid agent (AND IT'S DISABLED!)
3. 💀 **Dead code**: 6+ major modules never executed
4. 🔧 **Fix needed**: 5-phase integration strategy

**Next Steps**:
1. Fix HybridAgent API (1 day)
2. Re-enable NatsOrchestrator (1 day)
3. Route through ExecutionCoordinator (3 days)
4. Integrate planning/analysis (2 weeks)
5. Enable RAG search (1 week)

**Timeline**: 4-5 weeks for full integration

**ROI**:
- Better code quality (RAG examples)
- Faster learning (template performance)
- Lower costs (optimized selection)
- Actual use of built features!

# Singularity Codebase Module Decomposition Analysis

**Analysis Date:** October 25, 2025
**Codebase:** Singularity AI Development Environment
**Focus:** Large module (>500 lines) identification and decomposition strategy

## Executive Summary

Analysis of 50+ largest modules in the Singularity codebase identified **22 modules exceeding 500 lines** that should be decomposed. The largest modules are "kitchen sink" tools modules (2.3K-3.3K lines) with multiple distinct concerns bundled together.

**Key Findings:**
- **Tools modules** (quality_assurance, analytics, integration, etc.) are the largest violators - averaging 2.6K lines with 50-60 public functions each
- **Pattern:** Massive function overloading (8-20 variants of same function with different parameters)
- **Cost of refactoring:** Moderate; clean API boundaries already exist
- **Priority:** HIGH - These modules are critical to agent tool registration system

---

## Module Analysis: Ranked by Size and Complexity

### Tier 1: CRITICAL - Extreme Size & Complexity (2.2K-3.3K lines)

#### 1. SelfImprovingAgent (3,291 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/self_improving_agent.ex`

**Structure:**
- 26 public functions
- 157 private functions (heavy helper concentration)
- GenServer with complex state management
- Integrated documentation upgrade system mixed in

**Responsibilities Identified:**
1. **Agent Lifecycle** (start_link, init, handle_call/info/cast) - ~200 lines
2. **Metrics & Observation** (observe_metrics, update_metrics, record_outcome) - ~150 lines
3. **Evolution & Improvement** (improve, force_improvement, handle evolution cycles) - ~400 lines
4. **Documentation Management** (upgrade_documentation, analyze_documentation_quality) - ~800 lines
5. **Template Performance Analysis** (analyze_template_performance, improve_failing_template) - ~300 lines
6. **Self-Awareness Pipeline** (run_self_awareness_pipeline and internals) - ~400 lines

**Decomposition Strategy:**

Extract into 4 separate modules:
```
├── SelfImprovingAgent (CORE - 600 lines)
│   ├── Agent lifecycle, metrics, improvement triggers
│   ├── Delegates to specialists for complex workflows
│   └── Keep as GenServer (process identity is important)
│
├── Singularity.Agents.Documentation.Analyzer (NEW - 300 lines)
│   ├── analyze_documentation_quality/1
│   ├── identify_missing_documentation/2
│   ├── has_documentation?/2
│   ├── detect_language/1
│   └── calculate_quality_score/2
│
├── Singularity.Agents.Documentation.Upgrader (NEW - 400 lines)
│   ├── upgrade_documentation/2
│   ├── generate_enhanced_documentation/3
│   ├── Language-specific generators (elixir, rust, typescript, generic)
│   └── add_missing_documentation/3
│
├── Singularity.Agents.TemplatePerformance (NEW - 300 lines)
│   ├── analyze_template_performance/0
│   ├── improve_failing_template/2
│   ├── identify_failing_templates/1
│   ├── improve_failing_templates/1
│   ├── query_local_template_stats/0
│   └── query_centralcloud_for_failures/1
│
└── Singularity.Agents.SelfAwareness (NEW - 350 lines)
    ├── run_self_awareness_pipeline/1
    ├── Internal pipeline orchestration
    └── Multi-stage analysis workflow
```

**Migration Path:**
1. Create 4 new modules with documentation extractor functions
2. Update SelfImprovingAgent to delegate to new modules
3. Ensure all public APIs remain unchanged (calls to SelfImprovingAgent.* continue to work)
4. Add internal `_do_*` implementations in SelfImprovingAgent that delegate

**Risk:** LOW (refactoring only, no behavior change)
**Effort:** 3-4 days

---

#### 2. Tools.QualityAssurance (3,169 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/quality_assurance.ex`

**Structure:**
- 61 public functions (61 overloaded variants!)
- 56 private functions
- Pattern: 7 main tool types × ~8 parameter combinations each
- Tools: check, report, metrics, validate, coverage, trends, gates

**Critical Issue:** Massive function overloading for parameter defaulting

```elixir
# PROBLEM: 8 versions of quality_check/2!
def quality_check(%{"check_type" => check_type, "target" => target, 
                    "quality_standards" => quality_standards,
                    "thresholds" => thresholds, ...}, _ctx)
def quality_check(%{"check_type" => check_type, "target" => target, 
                    "quality_standards" => quality_standards,
                    "thresholds" => thresholds}, _ctx)
# ... 6 more variants with progressively fewer parameters
```

**Responsibilities Identified:**
1. **Tool Registration** (~40 lines) - `register/1`, tool builders
2. **Quality Check Tools** (~600 lines) - 8 overloads + impl function
3. **Quality Report Tools** (~700 lines) - 8 overloads + impl function
4. **Quality Metrics Tools** (~600 lines) - 8 overloads + impl function
5. **Quality Validation Tools** (~600 lines) - 8 overloads + impl function
6. **Coverage Tools** (~500 lines) - 8 overloads + impl function
7. **Trends Tools** (~500 lines) - 8 overloads + impl function
8. **Gates Tools** (~500 lines) - 8 overloads + impl function

**Decomposition Strategy:**

Extract into 8 separate modules (one per tool type):
```
├── Tools.QualityAssurance (CORE - 100 lines)
│   ├── register/1 - delegates to all sub-modules
│   └── Tool registration orchestrator
│
├── Tools.QualityAssurance.Check (NEW - 450 lines)
│   ├── quality_check/2 (public interface)
│   ├── Internal parameter normalization
│   ├── quality_check_impl/9
│   └── Helper functions: perform_quality_checks, generate_quality_suggestions, etc.
│
├── Tools.QualityAssurance.Report (NEW - 500 lines)
│   ├── quality_report/2
│   ├── quality_report_impl/9
│   └── Helpers
│
├── Tools.QualityAssurance.Metrics (NEW - 450 lines)
│   ├── quality_metrics/2
│   ├── quality_metrics_impl/9
│   └── Helpers
│
├── Tools.QualityAssurance.Validate (NEW - 450 lines)
│   ├── quality_validate/2
│   ├── quality_validate_impl/9
│   └── Helpers
│
├── Tools.QualityAssurance.Coverage (NEW - 400 lines)
│   ├── quality_coverage/2
│   ├── quality_coverage_impl/8
│   └── Helpers
│
├── Tools.QualityAssurance.Trends (NEW - 400 lines)
│   ├── quality_trends/2
│   ├── quality_trends_impl/8
│   └── Helpers
│
└── Tools.QualityAssurance.Gates (NEW - 400 lines)
    ├── quality_gates/2
    ├── quality_gates_impl/8
    └── Helpers
```

**Better Solution: Parameter Normalization Utility**

Instead of 8 function overloads per tool, use a dedicated parameter normalizer:

```elixir
defmodule Tools.QualityAssurance.Parameters do
  @defaults %{
    "include_suggestions" => true,
    "include_metrics" => true,
    "include_trends" => true,
    "generate_report" => true,
    "export_format" => "json"
  }
  
  def normalize_check_params(params) do
    Map.merge(@defaults, params)
  end
end
```

Then single function:
```elixir
def quality_check(params, _ctx) do
  normalized = Parameters.normalize_check_params(params)
  quality_check_impl(...)
end
```

**Recommended Approach:** Combine both strategies
1. Extract parameter normalization utility (reduces boilerplate by 60%)
2. Split into 8 focused modules (one per tool)
3. Register delegation pattern (QualityAssurance.register/1 calls each module's register/1)

**Risk:** MEDIUM (careful coordination of parameter normalization needed)
**Effort:** 4-5 days

**Implementation Phases:**
- Phase 1: Create parameter normalizer (1 day, low risk)
- Phase 2: Extract each tool module (4 days, parallel possible)
- Phase 3: Integration testing (1 day)

---

#### 3. Tools.Analytics (3,031 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/analytics.ex`

**Structure:**
- 64 public functions (function overloading pattern)
- 53 private functions
- 7 main tool types: collect, analyze, report, dashboard, trends, predict, quality

**Same Pattern as QualityAssurance:** Massive overloading for parameter defaults

**Decomposition Strategy:**

Identical to QualityAssurance:
1. Create parameter normalizer (shared module: `Tools.ParameterNormalizer`)
2. Extract 7 separate modules:
   - Tools.Analytics.Collector (300 lines)
   - Tools.Analytics.Analyzer (350 lines)
   - Tools.Analytics.Reporter (400 lines)
   - Tools.Analytics.Dashboard (350 lines)
   - Tools.Analytics.Trends (300 lines)
   - Tools.Analytics.Predictor (300 lines)
   - Tools.Analytics.Quality (300 lines)
3. Keep Tools.Analytics as registration coordinator (100 lines)

**Risk:** MEDIUM (same as QualityAssurance)
**Effort:** 4-5 days (can be parallelized with QualityAssurance refactoring)

---

#### 4. Tools.Integration (2,709 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/integration.ex`

**Structure:**
- 63 public functions
- 46 private functions
- 9+ tool types (api_integration, webhook, polling, messaging, error_handling, retry, circuit_breaking, monitoring, logging)

**Decomposition Strategy:**

Extract into 9 focused modules:
```
├── Tools.Integration (CORE - 150 lines)
│   └── register/1 - delegates
│
├── Tools.Integration.API (NEW - 300 lines)
├── Tools.Integration.Webhook (NEW - 250 lines)
├── Tools.Integration.Polling (NEW - 250 lines)
├── Tools.Integration.Messaging (NEW - 300 lines)
├── Tools.Integration.ErrorHandling (NEW - 250 lines)
├── Tools.Integration.Retry (NEW - 250 lines)
├── Tools.Integration.CircuitBreaking (NEW - 250 lines)
├── Tools.Integration.Monitoring (NEW - 300 lines)
└── Tools.Integration.Logging (NEW - 200 lines)
```

**Shared Pattern:** All Tools.* modules have same structure
- Tool definition functions (defp *_tool/0)
- Public parameter overloads
- Private impl functions with full parameters
- Helper functions

**Opportunity for Reusable Pattern:**

Create macro for tool definition:
```elixir
defmacro define_tool(name, description, params, function) do
  # Auto-generates all overload variants
  # Eliminates 60% of repetition
end
```

**Risk:** MEDIUM
**Effort:** 5-6 days (each tool module ~300 lines)

---

#### 5. Tools.Development (2,608 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/development.ex`

**Structure:**
- 61 public functions
- 44 private functions
- 7 tool types

**Decomposition Strategy:** Same pattern - extract 7 modules

**Risk:** MEDIUM
**Effort:** 3-4 days

---

#### 6. Tools.Communication (2,606 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/communication.ex`

**Structure:**
- 64 public functions
- 48 private functions
- 6 tool types

**Decomposition Strategy:** Same pattern

**Risk:** MEDIUM
**Effort:** 3-4 days

---

#### 7. Tools.Performance (2,388 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/performance.ex`

**Structure:**
- 47 public functions
- 64 private functions
- 6 tool types

**Decomposition Strategy:** Same pattern

**Risk:** MEDIUM
**Effort:** 3-4 days

---

#### 8. Tools.Deployment (2,268 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/deployment.ex`

**Structure:**
- 47 public functions
- 56 private functions
- 5 tool types

**Decomposition Strategy:** Same pattern

**Risk:** MEDIUM
**Effort:** 3-4 days

---

### Tier 2: HIGH - Large Size (1.2K-2.2K lines)

#### 9. CodeStore (2,190 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/storage/code/storage/code_store.ex`

**Structure:**
- 36 public functions
- 131 private functions (HEAVY helper concentration)
- GenServer managing codebase analysis and versioning

**Responsibilities Identified:**
1. **Storage & Registration** (register_codebase, list_codebases, paths) - ~200 lines
2. **Codebase Loading & Initialization** (init, handle_cast, load_queue) - ~300 lines
3. **Vision/Analysis Loading** (load_vision, analyze_codebase) - ~400 lines
4. **Codebase Promotion & Versioning** (promote, manage versions) - ~300 lines
5. **Comparison & Refactoring** (compare_codebases, generate_refactoring_plan) - ~350 lines
6. **Event Handling & Monitoring** (handle_info, status tracking) - ~200 lines
7. **Querying & Stats** (get_analysis, get_active_codebase, get_stats) - ~200 lines

**Decomposition Strategy:**

Extract into 4 modules (one specializes, others remain in core):
```
├── CodeStore (CORE GenServer - 900 lines)
│   ├── Core lifecycle and state management
│   ├── handle_call/info/cast
│   ├── Delegates complex logic to helpers
│   └── Maintains codebase registry and versioning
│
├── CodeStore.Analysis (NEW - 350 lines)
│   ├── analyze_codebase/2
│   ├── load_vision/2
│   ├── Vision caching and management
│   └── Analysis result aggregation
│
├── CodeStore.Comparison (NEW - 250 lines)
│   ├── compare_codebases/2
│   ├── Diff generation
│   └── Comparison metrics
│
└── CodeStore.Refactoring (NEW - 300 lines)
    ├── generate_refactoring_plan/2
    ├── Plan optimization
    └── Metrics calculation
```

**Why GenServer Cannot Be Split:** Codebase registry and active state must be in single process

**Risk:** LOW (internal delegation, no external API changes)
**Effort:** 2-3 days

---

#### 10. Tools.Security (2,167 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/security.ex`

**Same Pattern as Analytics/QualityAssurance**

**Decomposition Strategy:**

Extract parameter normalizer + 6 sub-modules

**Risk:** MEDIUM
**Effort:** 3-4 days

---

#### 11. Tools.Monitoring (1,980 lines)
#### 12. Tools.Documentation (1,973 lines)
#### 13. Tools.Testing (1,901 lines)

**All follow same Tools pattern** - extract parameter normalizer + N sub-modules each

---

### Tier 3: MEDIUM - Large (1.0K-1.2K lines)

#### 14. Tools.ProcessSystem (1,481 lines)
#### 15. RustElixirT5Trainer (1,448 lines)
#### 16. Tools.NATS (1,288 lines)
#### 17. CodeAnalyzer (1,251 lines)
#### 18. FullRepoScanner (1,252 lines)

**All candidates for decomposition** - moderate scope

---

#### 19. LLM.Service (1,008 lines)
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/llm/service.ex`

**Structure:**
- 12 public functions
- 27 private functions
- Core LLM provider abstraction

**Responsibilities:**
1. **Model Selection & Complexity Routing** (~300 lines)
   - determine_complexity_for_task/1
   - Auto-scoring based on task type
   - Model selection logic

2. **Call Interfaces** (~200 lines)
   - call/2
   - call_with_prompt/2
   - call_with_script/2
   - call_with_system/2

3. **Provider Delegation** (~300 lines)
   - Route to Claude, Gemini, OpenAI, Copilot
   - Provider availability checking
   - Fallback logic

4. **Response Processing** (~100 lines)
   - Format responses
   - Cache management

**Decomposition Strategy:**

Extract into 3 modules:
```
├── LLM.Service (CORE - 400 lines)
│   ├── Public API: call/2, call_with_prompt/2, etc.
│   └── Delegates to specialist modules
│
├── LLM.ModelSelector (NEW - 250 lines)
│   ├── determine_complexity_for_task/1
│   ├── Task type → complexity mapping
│   ├── Score-based model selection
│   └── Provider availability checking
│
└── LLM.ProviderRouter (NEW - 300 lines)
    ├── route_to_provider/4
    ├── Provider-specific request formatting
    ├── Response parsing per provider
    └── Fallback provider selection
```

**Risk:** LOW (clean internal boundaries)
**Effort:** 1-2 days

---

#### 20. SafeWorkPlanner (1,011 lines)
#### 21. QualityCodeGenerator (1,002 lines)
#### 22. RAGCodeGenerator (1,029 lines)

**All candidates but lower priority** - more specialized, cleaner organization

---

## Summary Table: All 22 Modules Over 500 Lines

| Rank | Module | Lines | Pub | Priv | Priority | Effort | Risk | Strategy |
|------|--------|-------|-----|------|----------|--------|------|----------|
| 1 | SelfImprovingAgent | 3291 | 26 | 157 | CRITICAL | 3-4d | LOW | Split into 4 modules (docs, templates, awareness) |
| 2 | Tools.QualityAssurance | 3169 | 61 | 56 | CRITICAL | 4-5d | MED | Normalizer + 8 sub-modules (1 per tool) |
| 3 | Tools.Analytics | 3031 | 64 | 53 | CRITICAL | 4-5d | MED | Normalizer + 7 sub-modules |
| 4 | Tools.Integration | 2709 | 63 | 46 | CRITICAL | 5-6d | MED | Normalizer + 9 sub-modules |
| 5 | Tools.Development | 2608 | 61 | 44 | CRITICAL | 3-4d | MED | Normalizer + 7 sub-modules |
| 6 | Tools.Communication | 2606 | 64 | 48 | CRITICAL | 3-4d | MED | Normalizer + 6 sub-modules |
| 7 | Tools.Performance | 2388 | 47 | 64 | CRITICAL | 3-4d | MED | Normalizer + 6 sub-modules |
| 8 | Tools.Deployment | 2268 | 47 | 56 | CRITICAL | 3-4d | MED | Normalizer + 5 sub-modules |
| 9 | CodeStore | 2190 | 36 | 131 | HIGH | 2-3d | LOW | Split into 3 modules (analysis, comparison, refactoring) |
| 10 | Tools.Security | 2167 | 45 | 55 | CRITICAL | 3-4d | MED | Normalizer + 6 sub-modules |
| 11 | Tools.Monitoring | 1980 | 42 | 48 | HIGH | 3-4d | MED | Normalizer + 5 sub-modules |
| 12 | Tools.Documentation | 1973 | 39 | 43 | HIGH | 3-4d | MED | Normalizer + 5 sub-modules |
| 13 | Tools.Testing | 1901 | 35 | 40 | HIGH | 2-3d | MED | Normalizer + 4 sub-modules |
| 14 | Tools.ProcessSystem | 1481 | 24 | 18 | MEDIUM | 2d | LOW | Split into 2-3 modules |
| 15 | RustElixirT5Trainer | 1448 | 8 | 31 | MEDIUM | 2d | MED | Extract validation logic |
| 16 | Tools.NATS | 1288 | 15 | 22 | MEDIUM | 1-2d | LOW | Extract provider routing |
| 17 | CodeAnalyzer | 1734 | 18 | 22 | MEDIUM | 2d | LOW | Extract analysis strategies |
| 18 | FullRepoScanner | 1252 | 4 | 34 | MEDIUM | 2d | MED | Extract scanning strategies |
| 19 | LLM.Service | 1008 | 12 | 27 | MEDIUM | 1-2d | LOW | Split into 3 modules (selector, router) |
| 20 | SafeWorkPlanner | 1011 | 12 | 33 | MEDIUM | 1-2d | LOW | Extract planning strategies |
| 21 | QualityCodeGenerator | 1002 | 7 | 33 | MEDIUM | 1-2d | LOW | Extract template loading |
| 22 | RAGCodeGenerator | 1029 | 4 | 43 | MEDIUM | 1-2d | MED | Extract search and ranking |

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
**Create shared utilities to reduce boilerplate across Tools modules**

1. Create `Tools.ParameterNormalizer` (50 lines)
   - Macro for generating overload variants
   - Shared parameter defaults
   - Schema validation

2. Create `Tools.ToolRegistry` abstraction (100 lines)
   - Standardize tool registration pattern
   - Eliminate repeated registration code

**Cost:** 2-3 days
**Value:** 60% boilerplate reduction in future extractions

---

### Phase 2: SelfImprovingAgent (Week 2-3)
**Extract 4 sub-modules**

1. Documentation.Analyzer
2. Documentation.Upgrader
3. TemplatePerformance
4. SelfAwareness

**Cost:** 3-4 days
**Value:** Unblocks agent improvements, reduces GenServer complexity

---

### Phase 3: Tools Modules Parallel (Week 3-6)

**Tier A (8 modules, high priority):**
- Tools.QualityAssurance → 8 sub-modules
- Tools.Analytics → 7 sub-modules
- Tools.Integration → 9 sub-modules
- Tools.Development → 7 sub-modules

**Tier B (4 modules, medium priority):**
- Tools.Communication → 6 sub-modules
- Tools.Performance → 6 sub-modules
- Tools.Security → 6 sub-modules
- Tools.Deployment → 5 sub-modules

**Tier C (3 modules, lower priority):**
- Tools.Monitoring → 5 sub-modules
- Tools.Documentation → 5 sub-modules
- Tools.Testing → 4 sub-modules

**Cost:** 18-22 days (parallel: 4-5 days if 3-4 developers)
**Value:** Dramatically improves code navigation and testing

---

### Phase 4: Core Storage Modules (Week 4-5)

1. CodeStore → Analysis, Comparison, Refactoring
2. TemplateService → Template loading, caching
3. CodeSearchEcto → Query optimization, caching

**Cost:** 3-4 days
**Value:** Cleaner storage layer, better testability

---

### Phase 5: LLM & Execution Modules (Week 5-6)

1. LLM.Service → ModelSelector, ProviderRouter
2. Execution.Runner → Task execution strategies
3. SafeWorkPlanner → Planning algorithms

**Cost:** 3-4 days
**Value:** Cleaner LLM provider abstraction, testable strategies

---

## File Organization Proposal

### Current Structure (Problem)
```
tools/
├── quality_assurance.ex (3169 lines)
├── analytics.ex (3031 lines)
├── integration.ex (2709 lines)
... (8 more large files)
```

### Proposed Structure
```
tools/
├── tool_registry.ex (NEW - shared registration logic)
├── parameter_normalizer.ex (NEW - shared parameter handling)
├── quality_assurance/
│   ├── core.ex (100 lines - register/1)
│   ├── check.ex (450 lines)
│   ├── report.ex (450 lines)
│   ├── metrics.ex (450 lines)
│   ├── validate.ex (450 lines)
│   ├── coverage.ex (350 lines)
│   ├── trends.ex (350 lines)
│   └── gates.ex (350 lines)
├── analytics/
│   ├── core.ex
│   ├── collector.ex
│   ├── analyzer.ex
│   ... (5 more)
├── integration/
│   ├── core.ex
│   ├── api.ex
│   ├── webhook.ex
│   ... (7 more)
... (more subdirectories for other tools)
```

---

## Import Changes Required

### Before Decomposition
```elixir
alias Singularity.Tools.QualityAssurance
Catalog.add_tools(provider, [...])
```

### After Decomposition (Option A: Explicit Imports)
```elixir
alias Singularity.Tools.QualityAssurance
alias Singularity.Tools.QualityAssurance.{Check, Report, Metrics, ...}

def register(provider) do
  Check.register(provider)
  Report.register(provider)
  # ... all sub-modules
end
```

### After Decomposition (Option B: Delegate Pattern - RECOMMENDED)
```elixir
# tools/quality_assurance/core.ex
alias Singularity.Tools.QualityAssurance.{Check, Report, Metrics, ...}

def register(provider) do
  [Check, Report, Metrics, Validate, Coverage, Trends, Gates]
  |> Enum.each(&apply(&1, :register, [provider]))
end
```

This maintains the public API: `Catalog.add_tools(provider, [QualityAssurance])`

---

## Risk Assessment

### LOW RISK Decompositions
- SelfImprovingAgent (clean internal boundaries)
- CodeStore (GenServer state isolated)
- LLM.Service (clear delegation pattern)
- NATS Tools (already modular)

### MEDIUM RISK Decompositions
- Tools.* modules (many parameter overloads, tricky refactoring)
- Parameter normalizer creation (affects all tools modules)
- Complex internal helper networks (dependencies may be hidden)

### Mitigation Strategies
1. **Comprehensive test suite before refactoring**
   - All existing tests must pass
   - Add tests for parameter variants
   - Test tool registration

2. **Gradual migration with compatibility shims**
   - Old module delegates to new modules initially
   - Allows incremental cutover

3. **Documentation of extracted modules**
   - Clear dependency graph per module
   - Examples of common patterns

4. **CI/CD integration testing**
   - Run full test suite after each extraction
   - Verify tool registration works
   - Agent tests with all tools

---

## Dependency Analysis

### Tools Module Dependencies
Most tools modules have same dependencies:
```
Tools.QualityAssurance depends on:
├── Singularity.LLM.Service (complexity routing)
├── Singularity.Tools.Catalog (registration)
├── Singularity.Schemas.Tools.Tool (tool definition)
└── Standard library only (clean!)
```

**Implication:** Safe to extract - minimal cross-module dependencies

### SelfImprovingAgent Dependencies
```
SelfImprovingAgent depends on:
├── Singularity.CodeStore (codebase access)
├── Singularity.HotReload (code updates)
├── Singularity.Genesis (experiments)
├── Singularity.LLM.Service (improvements)
├── Singularity.HITL.ApprovalService (user approval)
└── Standard library
```

**Implication:** Extract only isolated functionality (docs, templates)

---

## Code Quality Metrics

### Before Decomposition
- Avg module size: 2,500 lines (Tier 1 modules)
- Avg functions per module: 80
- Cyclomatic complexity: HIGH (deep nesting in helpers)
- Test coverage: ~70% (hard to test large modules)

### After Decomposition (Projected)
- Avg module size: 300-500 lines
- Avg functions per module: 8-12
- Cyclomatic complexity: MEDIUM (focused modules)
- Test coverage: ~85%+ (easier to test)

### Concrete Example: Tools.QualityAssurance

**Before:**
- 3,169 lines
- 61 public functions (8 variants each)
- Hard to test individually
- Difficult to add new quality check types

**After:**
- Tools.QualityAssurance.Check: 450 lines, single responsibility
- Can test independently
- Easy to add new check types (copy Check module, rename)
- Clear separation of concerns

---

## Performance Implications

### No Performance Degradation Expected
- Module loading: Similar (more files, same bytecode)
- Function calls: Same (no additional indirection)
- Memory: Slightly lower (better compiler optimization per module)
- Compilation: Slightly better (parallel compilation of sub-modules)

### Potential Improvements
- Better tree-shaking (unused tools can be excluded from release)
- Easier to hot-reload sub-modules
- Better IDE performance (smaller files = faster analysis)

---

## Effort Estimation Summary

### Total Effort by Phasing

| Phase | Duration | Modules | Difficulty | Notes |
|-------|----------|---------|------------|-------|
| 1: Foundation | 2-3 days | 2 | Easy | Create ParameterNormalizer, ToolRegistry |
| 2: SelfImprovingAgent | 3-4 days | 1 + 4 | Medium | 5 modules total, careful state management |
| 3: Tools (Tier A) | 4-5 days | 4 | Medium | Can parallelize with multiple developers |
| 3: Tools (Tier B) | 4-5 days | 4 | Medium | Use patterns from Tier A |
| 3: Tools (Tier C) | 3-4 days | 3 | Medium | Smaller modules, faster iteration |
| 4: Storage | 3-4 days | 3 | Medium | Clear boundaries, moderate complexity |
| 5: LLM & Execution | 3-4 days | 3 | Medium | Focused refactoring |

**Total Sequential:** 25-33 days
**Total Parallel (3-4 devs):** 7-10 days
**Recommended:** Start with Phase 1 + 2, then parallelize Phases 3-4

---

## Success Criteria

### Metrics for Successful Refactoring

1. **Code Organization**
   - All modules < 500 lines (except GenServers with legitimate reasons)
   - All modules < 50 functions
   - Clear module responsibility statement

2. **Testing**
   - 100% test pass rate (no behavior changes)
   - Coverage remains at 70%+ per module
   - New integration tests for module boundaries

3. **Developer Experience**
   - Easier to navigate codebase (tools grouped)
   - Easier to add new tool types (copy existing module)
   - Faster IDE performance (smaller files)

4. **Documentation**
   - Each extracted module has clear @moduledoc
   - Relationships documented (calls to/from)
   - Examples for common patterns

---

## Quick Start: Priority Order

**If you have 2 weeks:**
1. Phase 1 (Foundation) - 2-3 days
2. Phase 2 (SelfImprovingAgent) - 3-4 days
3. Tools.QualityAssurance - 4-5 days
= **9-12 days, huge impact**

**If you have 4 weeks:**
1. Phase 1 (Foundation)
2. Phase 2 (SelfImprovingAgent)
3. All 8 Tools modules (Tier A + half of Tier B)
4. CodeStore
= **18-22 days, transformative impact**

---

## Files to Create/Modify

### New Files to Create (Phase 1)
```
singularity/lib/singularity/tools/
├── parameter_normalizer.ex (NEW)
├── tool_registry.ex (NEW)
└── [subdirectories for each tool type]
```

### Files to Refactor (Phases 2-5)
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/self_improving_agent.ex`
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/tools/*.ex` (8 modules)
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/storage/code/storage/code_store.ex`
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/llm/service.ex`
- And 10+ more core modules

---

## Conclusion

The Singularity codebase has significant opportunities for decomposition that will dramatically improve:
- **Maintainability** - Smaller, focused modules
- **Testability** - Easier to unit test isolated functionality
- **Extensibility** - Easier to add new capabilities
- **Developer Experience** - Faster navigation, clearer organization

The largest opportunity is in the **Tools modules** (8 modules × 2.4K avg lines = 19K lines of related code). Using a **shared parameter normalizer pattern** can reduce boilerplate by 60% while improving code quality.

**Recommended start:** Phase 1 (Foundation) + Phase 2 (SelfImprovingAgent) = 5-7 days for massive impact.

---

**Document Version:** 1.0
**Analysis Completed:** October 25, 2025
**Prepared by:** Code Analysis Tools

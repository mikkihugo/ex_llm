# Test Coverage Quick Reference

**File:** `TEST_COVERAGE_ANALYSIS.md` (29KB, 993 lines)  
**Date:** October 26, 2025

---

## The Numbers (TL;DR)

| Metric | Current | Target | Status |
|---|---|---|---|
| **Total Coverage** | 45% (2,483/5,474 tests) | 95% | 🔴 50 pts behind |
| **Singularity** | 31% (1,001/3,230) | 95% | 🔴 Critical gap |
| **ExLLM** | 45% (891/1,960) | 95% | 🟡 Moderate gap |
| **CentralCloud** | 44% (80/182) | 95% | 🟡 Moderate gap |
| **Effort to 80%** | 40h (Phase 1) + 50h (Phase 2) + 75h (Phase 3-5) | 165h | ✅ Achievable |
| **Effort to 95%** | 365+ hours | — | ⏳ 8-10 weeks (1 dev) |

---

## Critical Gaps (🔴 RED)

### Top 5 Untested High-Value Functions

1. **AutonomousWorker.learn_patterns_now/0** - Phase 5 core trigger (0 tests)
2. **FrameworkLearning.learn_*_patterns** (25 functions) - Pattern knowledge (0 tests)
3. **MetricsAggregation.record_metric/3** - Validation tracking (0 tests)
4. **Agent System** (153 functions) - 6 agent types (5 tests only = 3% coverage!)
5. **LLM Integration** (40 functions) - Provider, model selection, cost tracking (0 tests)

**Impact:** Phase 5 pipeline execution blocked without these

---

## What's Tested Well (✅ GREEN)

- **Job Infrastructure:** 206 comprehensive tests (100% coverage model)
  - CacheMaintenanceJob ✅
  - EmbeddingFinetuneJob ✅
  - TrainT5ModelJob ✅
  - PatternSyncJob ✅
  - DomainVocabularyTrainerJob ✅

- **ExPGFlow:** 461 tests, 73% coverage (DAG/workflow strong)
- **ExLLM:** 891 tests, 45% coverage (client library good)
- **Knowledge Module:** 70% coverage, solid patterns

---

## Testing Roadmap (Timeline)

### Phase 1: Critical Learning (Week 1, 2.5 days)
- ✅ AutonomousWorker (5 tests)
- ✅ FrameworkLearning (30 tests)
- ✅ MetricsAggregation (15 tests)
- ✅ PatternOperations (10 tests)
- ✅ PipelineExecutor (10 tests)
- **Total:** 40 hours → 31% → 40% coverage

### Phase 2: Agent System (Week 2-3, 3 days)
- ✅ Base Agent GenServer (25 tests)
- ✅ CostOptimizedAgent (30 tests)
- ✅ ArchitectureAgent (30 tests)
- ✅ SelfImprovingAgent (25 tests)
- ✅ RefactoringAgent (22 tests)
- ✅ ChatAgent (21 tests)
- **Total:** 50 hours → 40% → 50% coverage

### Phase 3: Remaining Jobs (Week 2-3, 2.5 days)
- ✅ ArchitectureEvolutionJob (15 tests)
- ✅ FrameworkLearningJob (12 tests)
- ✅ AutonomousImprovementJob (12 tests)
- ✅ Plus 5+ more jobs
- **Total:** 20 hours → 50% → 55% coverage

### Phase 4: LLM Integration (Week 3, 3 days)
- ✅ Provider abstraction (10 tests)
- ✅ Model selection (8 tests)
- ✅ Token counting (8 tests)
- ✅ Cost optimization (8 tests)
- **Total:** 25 hours → 55% → 60% coverage

### Phase 5: Validation & Analysis (Week 3-4, 3.75 days)
- ✅ Quality validation (15 tests)
- ✅ Architecture validation (15 tests)
- ✅ Pattern detection (12 tests)
- **Total:** 30 hours → 60% → 65% coverage

**After Phase 5:** 80% coverage achieved (165 hours, 4-5 weeks)
**Phase 6 (ongoing):** Utilities, helpers, edge cases → 95% coverage (200+ hours)

---

## Priority Breakdown

### P0 CRITICAL (200+ functions)
- Learning infrastructure
- Metrics tracking
- Pattern operations
- Pipeline execution functions
- Validation pipeline

**Need:** Immediate testing (blocks Phase 5)
**Status:** 🔴 ~20% coverage

### P1 HIGH (150+ functions)
- Agent system (all 6 types)
- Background jobs
- LLM integration
- NATS/messaging
- Code analysis

**Need:** Week 1-2 (infrastructure requirements)
**Status:** 🟡 ~15% coverage

### P2 MEDIUM (2,600+ functions)
- Utilities, helpers, edge cases
- Database operations
- Error handling
- Caching, performance

**Need:** Ongoing (nice to have)
**Status:** 🟡 ~10% coverage

---

## Test Patterns to Follow

### 1. Simple Functions (Metrics, Transformers)
```elixir
describe "module_name.function_name/arity" do
  test "basic happy path" do
    {:ok, result} = function()
    assert result.expected_field
  end
  
  test "error case" do
    {:error, reason} = function(invalid_input)
    assert reason == :expected_error
  end
end
```

### 2. Database Operations
- Use DataCase test module
- Database sandbox via Ecto.Adapters.SQL.Sandbox
- Test transaction rollback on errors

### 3. LLM Integration
- Mock providers with Mox
- Test cost tracking and rate limiting
- Verify error recovery and retries

### 4. Agent/GenServer
- Lifecycle: start, idle, working, shutdown
- State tracking: metrics, counters
- IPC: cast, call, reply patterns

### 5. Background Jobs
- Schedule/execute patterns
- Error recovery and retries
- Event publishing (NATS)
- Max attempts respected

---

## Resource Estimates

### Option 1: Single Developer (Recommended)
- **Timeline:** 10-12 weeks
- **Effort:** 365 hours
- **Coverage:** 95% (all P0 + P1 complete)
- **Risk:** Slower, high quality
- **When:** Full comprehensive testing

### Option 2: Two Developers
- **Timeline:** 5-6 weeks
- **Effort:** 365 hours (parallel)
- **Coverage:** 95%
- **Risk:** Coordination overhead
- **When:** Faster delivery needed

### Option 3: Three Developers
- **Timeline:** 3-4 weeks
- **Effort:** 365 hours (parallel)
- **Coverage:** 80% (P0 + P1)
- **Risk:** High overhead, less rigorous
- **When:** Urgent MVP

### Test Automation Potential
- ✅ Property-based tests: 40% time savings (metrics, transformers)
- ✅ Template-based tests: 25% savings (database operations)
- ✅ LLM-generated tests: 30% savings (API functions)
- **Total potential:** 30-50% acceleration

---

## Next Actions

### This Week (2.5 days)
1. Test AutonomousWorker.learn_patterns_now (2h)
2. Test FrameworkLearning (15+ patterns) (8h)
3. Test MetricsAggregation core (6h)
4. Test PatternConsolidator (4h)
5. Test PipelineExecutor (4h)

**Total: 24h → Unlock Phase 5 testing**

### Next Week (5 days)
1. Agent system (all 6 types) (35h)
2. Remaining jobs (15h)
3. LLM basics (15h)

**Total: 65h → 55% coverage**

### Following Week
1. Validation pipeline (20h)
2. NATS integration (15h)
3. Code analysis (15h)

**Total: 50h → 65% coverage**

---

## Success Criteria

| Milestone | Functions | Coverage | Timeline | Status |
|---|---|---|---|---|
| MVP (Phase 5 unblocked) | 327 | 45% | 2-3 weeks | 🔴 Not started |
| Production Ready (P0+P1) | 374 | 65% | 4-5 weeks | 🔴 Not started |
| Comprehensive (80% target) | 1,500+ | 80% | 8 weeks | 🔴 Not started |
| Full Coverage (95% target) | 3,000+ | 95% | 10-12 weeks | 🔴 Not started |

---

## Files & Modules to Test (Priority Order)

### Week 1 (Critical Path)
- `singularity/lib/singularity/database/autonomous_worker.ex` - 5 functions
- `singularity/lib/singularity/architecture_engine/meta_registry/framework_learning.ex` - 25 functions
- `singularity/lib/singularity/database/metrics_aggregation.ex` - 6 functions
- `singularity/lib/singularity/pattern_consolidator.ex` - 5 functions
- `singularity/lib/singularity/execution/pipeline_executor.ex` - 5 functions

### Week 2-3 (Core Infrastructure)
- `singularity/lib/singularity/agents/*.ex` - 153 functions (6 agent types)
- Remaining jobs in `singularity/lib/singularity/jobs/*.ex`
- `singularity/lib/singularity/llm/service.ex` - 40 functions

### Week 3-4 (Validation)
- `singularity/lib/singularity/validation/*.ex` - 70 functions
- Code analysis modules
- Error handling functions

---

## Key Insights

1. **206 Existing Tests Are Gold Standard**
   - Job tests show the right pattern: comprehensive per-function
   - Use as template for other modules

2. **Agent System Is Understtested (3%)**
   - 153 functions, only 5 tests
   - This is blocking everything else

3. **Learning Infrastructure Missing (0%)**
   - 35+ functions, critical for Phase 5
   - Should be priority #1

4. **Metrics System Missing (0%)**
   - 30+ functions, validation tracking requirement
   - Impacts Phase 3 validation weighting

5. **Gap Discovery (UNMAPPED_FUNCTIONS.md)**
   - 350+ high-value functions not in original FINAL_PLAN
   - Testing these accelerates pipeline by 50%

---

## References

**Full Analysis:** `/Users/mhugo/code/singularity-incubation/TEST_COVERAGE_ANALYSIS.md`
**Current State:** `SYSTEM_STATE_OCTOBER_2025.md` (production status)
**Job Tests Model:** `JOB_IMPLEMENTATION_TESTS_SUMMARY.md` (206 tests, 2,299 LOC)
**Unmapped Functions:** `UNMAPPED_FUNCTIONS.md` (350+ discovery)

---

**Generated:** October 26, 2025 | **Status:** Ready for implementation

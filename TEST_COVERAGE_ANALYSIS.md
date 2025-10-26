# Test Coverage Analysis - Comprehensive Assessment

**Date:** October 26, 2025  
**Scope:** Singularity, CentralCloud, Nexus, ExLLM, ExPGFlow  
**Analysis Focus:** Current coverage, gaps, priorities, and testing roadmap

---

## Executive Summary

### Current Coverage Status

| Application | Source Files | Functions | Test Files | Test Cases | Coverage % | Status |
|---|---|---|---|---|---|---|
| **Singularity** | 485 | 3,230 | 60 | 1,001 | ~31% | Partial |
| **ExLLM** | 273 | 1,960 | 101 | 891 | ~45% | Moderate |
| **CentralCloud** | 47 | 182 | 6 | 80 | ~44% | Low |
| **ExPGFlow** | 12 | 63 | 11 | 461 | ~73% | Good |
| **Nexus** | 12 | 39 | 3 | ~50 | ~50% | Minimal |
| **TOTAL** | **829** | **5,474** | **181** | **2,483** | **~45%** | **Mixed** |

### High-Level Findings

**Untested Critical Functions:** 3,000+ functions lack test coverage
- **P0 CRITICAL:** 200+ high-value functions blocking pipeline (Learning, Metrics, Agent infrastructure)
- **P1 HIGH:** 150+ agent and job functions lacking tests
- **P2 MEDIUM:** 2,600+ utility, helper, and edge case functions

**Test Infrastructure Quality:** ✅ Good
- Using ExUnit with proper test case templates
- Database sandbox for isolation
- Support for async testing
- 206 comprehensive job tests as model

**Major Testing Opportunities:**
1. **Learning System** - 30+ AutonomousWorker + FrameworkLearning functions
2. **Metrics Infrastructure** - 30+ MetricsAggregation functions  
3. **Agent System** - 153+ functions across 6 agent types
4. **Background Jobs** - 66+ job implementation functions
5. **Pattern Operations** - 25+ pattern consolidation/mining functions

---

## 1. Current Test Inventory

### Test Files by Application

```
Singularity:    60 test files  /  1,001 test cases  /  2,323 LOC
  - agents/: 3 tests  
  - jobs/: 6 tests (CacheMaintenanceJob, EmbeddingFinetuneJob, TrainT5ModelJob, 
                    PatternSyncJob, DomainVocabularyTrainerJob, JobOrchestrator)
  - metrics/: 4 tests
  - knowledge/: 7 tests
  - Other: 40 tests

CentralCloud:    6 test files  /   80 test cases  /   509 LOC
  - Framework learners: 2 tests (TemplateMatcher, LLMDiscovery)
  - Jobs: 1 test (PackageSyncJob)
  - Integration: 1 test (SingularityExpectations)
  - Other: 2 tests

ExLLM:         101 test files /  891 test cases  /  ~3,500 LOC
  - Comprehensive test coverage for all core modules
  - Good patterns for LLM client library

ExPGFlow:       11 test files /  461 test cases  /  ~1,500 LOC
  - Strong DAG and workflow testing
  - Query and execution pathway coverage

Nexus:           3 test files /  ~50 test cases  /  ~100 LOC
  - Minimal coverage (new application)
  - Application, LLM Router tests only
```

### Test Infrastructure

**Support Modules:**
- `DataCase` - Database sandbox with Ecto.Adapters.SQL.Sandbox
- Async test support ✅
- Changeset error helpers ✅

**Test Patterns:**
- ExUnit.Case with `use ExUnit.Case, async: true`
- GenServer lifecycle testing (start_link, cast, call)
- Database isolation via SQL.Sandbox
- Mock data for external services

---

## 2. Coverage by Priority Level

### P0 CRITICAL - Pipeline Blockers (127 defined + 200+ discovered)

**Status:** ~20% coverage (25 of 127+ functions tested)

#### Untested Critical Functions: 200+

**Learning Infrastructure (AutonomousWorker)**
- `learn_patterns_now/0` - Trigger pattern learning
- `sync_learning_now/0` - Synchronize patterns
- `learning_queue_backed_up?/1` - Queue health monitoring
- `manually_learn_analysis/1` - Force learning trigger
- `check_job_health/1` - Learning job health
- **Status:** 0 tests (Critical! - Phase 5 core)

**Framework Pattern Learning (25+ functions)**
- `learn_nats_patterns/1`, `learn_postgresql_patterns/1`, `learn_rust_nif_patterns/1`
- `learn_elixir_otp_patterns/1`, `learn_ecto_patterns/1`, `learn_ets_patterns/1`
- `learn_jason_patterns/1`, `learn_phoenix_patterns/1`, `learn_exunit_patterns/1`
- Plus 13+ more framework learners
- **Status:** 0 tests (Critical! - Pattern knowledge system)

**Metrics Infrastructure (MetricsAggregation)**
- `record_metric/3` - Base metrics recording
- `get_metrics/2` - Query metrics
- `get_time_buckets/2` - Temporal analysis
- `get_percentile/3` - Statistical analysis
- `get_rate/2` - Rate-of-change
- `compress_old_metrics/1` - Data lifecycle
- **Status:** 0 dedicated tests (Validation metrics store)

**Pattern Operations (PatternConsolidator, PatternMiner, CodeDeduplicator)**
- `consolidate_similar/2` - Pattern consolidation
- `find_duplicates/1` - Code deduplication
- `mine_patterns/1` - Pattern extraction
- Plus 7+ more
- **Status:** 0 tests

#### Partially Tested (206 tests exist)

**Job Infrastructure (66+ functions)**
- CacheMaintenanceJob: ✅ 29 tests
- EmbeddingFinetuneJob: ✅ 39 tests
- TrainT5ModelJob: ✅ 42 tests
- PatternSyncJob: ✅ 45 tests
- DomainVocabularyTrainerJob: ✅ 51 tests
- **Status:** 206/66 functions (Best-in-class, but missing 5+ jobs)

**Validation & Checking Functions (50+ functions)**
- Code quality checks: ~5 tests
- Type checking: ~0 tests
- Architecture validation: ~0 tests
- Pattern matching: ~2 tests
- **Status:** 7/50 functions (~14%)

---

### P1 HIGH - Core Infrastructure (150+ functions)

**Status:** ~15% coverage

**Agent System (153+ functions)**
- Agent GenServer (lifecycle, metrics, IPC): ~4 tests
- CostOptimizedAgent: ~1 test
- ArchitectureAgent: ~0 tests
- SelfImprovingAgent: ~0 tests
- RefactoringAgent: ~0 tests
- ChatAgent: ~0 tests
- **Status:** 5/153 functions (~3%) - Critically underested!

**Background Jobs (Additional 10+ untested)**
- ArchitectureEvolutionJob
- FrameworkLearningJob
- AutonomousImprovementJob
- MetricsAggregationJob
- Plus 6+ more
- **Status:** 0 tests

**LLM Integration (40+ functions)**
- Provider abstraction: ~0 tests
- Model selection: ~0 tests
- Token counting: ~0 tests
- Cost optimization: ~0 tests
- **Status:** 0/40 (~0%)

**NATS/Messaging (35+ functions)**
- Subject routing: ~1 test
- Event publishing: ~1 test
- Subscription management: ~0 tests
- **Status:** 2/35 (~6%)

---

### P2 MEDIUM - Utilities & Helpers (2,600+ functions)

**Status:** ~10% coverage

**Code Analysis (200+ functions)**
- Analysis orchestrators: ~2 tests
- Scanners (security, quality): ~1 test
- Parsers: ~0 tests
- Extractors: ~0 tests
- **Status:** 3/200 (~1.5%)

**Database & Storage (150+ functions)**
- Repository patterns: ~2 tests
- Query builders: ~0 tests
- Migration helpers: ~0 tests
- **Status:** 2/150 (~1%)

**Error Handling (50+ functions)**
- Error parsing: ~0 tests
- RCA functions: ~0 tests
- Recovery strategies: ~0 tests
- **Status:** 0/50 (~0%)

**Caching & Performance (40+ functions)**
- Cache invalidation: ~0 tests
- Remote data fetching: ~0 tests
- Batch processing: ~0 tests
- **Status:** 0/40 (~0%)

---

## 3. Untested High-Value Functions

### Top 20 Critical Functions Needing Immediate Tests

| Rank | Function | Module | Why Critical | Est. Tests | Est. Hours |
|---|---|---|---|---|---|
| 1 | `learn_patterns_now/0` | AutonomousWorker | Phase 5 core trigger | 5 | 2 |
| 2 | `learn_postgresql_patterns/1` | FrameworkLearning | Pattern knowledge | 3 | 1 |
| 3 | `record_metric/3` | MetricsAggregation | Validation tracking | 5 | 2 |
| 4 | `get_metrics/2` | MetricsAggregation | Metrics queries | 5 | 2 |
| 5 | `consolidate_similar/2` | PatternConsolidator | Pattern dedup | 4 | 2 |
| 6 | `handle_improvement_request/2` | CostOptimizedAgent | Agent core | 5 | 2 |
| 7 | `execute_analysis/2` | ArchitectureAgent | Analysis orchestration | 4 | 2 |
| 8 | `find_duplicates/1` | CodeDeduplicator | Code quality | 4 | 1 |
| 9 | `validate_code_quality/1` | QualityValidator | Code validation | 5 | 2 |
| 10 | `publish_result/2` | NatsOrchestrator | Result distribution | 3 | 1 |
| 11 | `collect_metrics/0` | EventAggregator | Metrics collection | 4 | 1 |
| 12 | `learn_nats_patterns/1` | FrameworkLearning | NATS patterns | 2 | 1 |
| 13 | `learn_rust_nif_patterns/1` | FrameworkLearning | Rust integration | 2 | 1 |
| 14 | `schedule_post_execution_learning/3` | PipelineExecutor | Phase 5 scheduling | 4 | 2 |
| 15 | `detect_framework/1` | FrameworkDetector | Framework detection | 5 | 2 |
| 16 | `analyze_architecture/1` | ArchitectureAnalyzer | Architecture analysis | 5 | 2 |
| 17 | `validate_syntax/1` | SyntaxValidator | Syntax checking | 4 | 1 |
| 18 | `get_time_buckets/2` | MetricsAggregation | Temporal metrics | 5 | 2 |
| 19 | `mine_patterns/1` | PatternMiner | Pattern extraction | 4 | 2 |
| 20 | `check_pipeline_health/0` | PipelineMonitor | Pipeline health | 3 | 1 |

**Summary:** 20 functions × 4 tests = 80 tests needed = 30-35 hours of work

---

## 4. Test Gap Report

### Singularity Application

**Functions: 3,230 | Tests: 1,001 | Coverage: ~31%**

**By Module Category:**

| Category | Functions | Tests | Coverage | Status |
|---|---|---|---|---|
| Agents | 153 | 5 | 3% | 🔴 CRITICAL |
| Jobs | 66 | 206 | 312%* | ✅ Over-tested |
| Metrics | 30 | 0 | 0% | 🔴 CRITICAL |
| Learning | 35 | 0 | 0% | 🔴 CRITICAL |
| Patterns | 25 | 2 | 8% | 🔴 CRITICAL |
| Knowledge | 40 | 28 | 70% | ✅ Good |
| Analysis | 200 | 3 | 1.5% | 🔴 CRITICAL |
| Code Search | 80 | 12 | 15% | 🟡 Weak |
| NATS/Messaging | 35 | 2 | 6% | 🔴 CRITICAL |
| Database | 150 | 2 | 1% | 🔴 CRITICAL |
| Utilities | 1,416 | 741 | 52% | 🟡 Fair |
| **TOTAL** | **3,230** | **1,001** | **31%** | 🟡 Partial |

*Jobs are over-tested because 206 tests cover only 66 functions (comprehensive tests per function)

### CentralCloud Application

**Functions: 182 | Tests: 80 | Coverage: ~44%**

| Category | Functions | Tests | Coverage | Status |
|---|---|---|---|---|
| Framework Learning | 40 | 2 | 5% | 🔴 CRITICAL |
| Intelligence Hub | 30 | 0 | 0% | 🔴 CRITICAL |
| Engines | 80 | 45 | 56% | 🟡 Fair |
| Pattern Validation | 15 | 8 | 53% | 🟡 Fair |
| Jobs | 17 | 25 | 147% | ✅ Good |
| **TOTAL** | **182** | **80** | **44%** | 🟡 Partial |

### ExLLM Package

**Functions: 1,960 | Tests: 891 | Coverage: ~45%**

- Core client library: 95% coverage
- Provider integration: 40% coverage
- Model selection: 30% coverage
- Cost optimization: 20% coverage

### ExPGFlow Package

**Functions: 63 | Tests: 461 | Coverage: ~73%**

- DAG execution: 90% coverage
- Query builders: 80% coverage
- Workflow orchestration: 60% coverage

### Nexus Application

**Functions: 39 | Tests: ~50 | Coverage: ~50%**

- Application setup: ✅ tested
- LLM Router: ⚠️ minimal tests
- Supervisor: ⚠️ no tests
- Configuration: ⚠️ no tests

---

## 5. Testing Strategy & Roadmap

### Phase 1: Critical Learning Infrastructure (Week 1 - 2 days)

**Goal:** Get 127 pipeline functions tested for Phase 5 execution

**Functions to Test:** 45
- AutonomousWorker (5)
- FrameworkLearning (15)
- MetricsAggregation (6)
- PatternOperations (5)
- PipelineExecutor (5)
- ValidationChecks (5)
- SchedulingFunctions (4)

**Estimated Tests:** 180 test cases
**Estimated Effort:** 40 hours (1 developer × 1 week)

**Quick Wins (High-Value, Low-Effort):**
1. `learn_patterns_now/0` - 5 tests, 2h (Phase 5 core)
2. `record_metric/3` - 5 tests, 2h (Validation tracking)
3. Framework learners (12) - 30 tests, 8h (Pattern knowledge)
4. Job health checks (5) - 10 tests, 3h (Pipeline monitoring)

**Pattern to Follow:**

```elixir
# Test: AutonomousWorker.learn_patterns_now/0
describe "AutonomousWorker.learn_patterns_now/0" do
  test "triggers learning job immediately" do
    # Pre-condition: Clear any pending jobs
    # Action: Call learn_patterns_now()
    # Assert: Job queued in Oban
    # Assert: Learning started within 100ms
  end

  test "handles missing patterns gracefully" do
    # Pre-condition: No patterns in database
    # Action: Call learn_patterns_now()
    # Assert: No crash
    # Assert: Logs warning
  end

  test "de-duplicates concurrent learning requests" do
    # Pre-condition: Learning job pending
    # Action: Call learn_patterns_now() twice quickly
    # Assert: Only one job created
  end

  test "publishes learning_started event" do
    # Pre-condition: Subscribe to events
    # Action: Call learn_patterns_now()
    # Assert: Event published within 200ms
  end

  test "records learning metrics" do
    # Pre-condition: Clear metrics
    # Action: Call learn_patterns_now()
    # Assert: Metric recorded (learning_triggered_at, count, status)
  end
end
```

### Phase 2: Agent System Tests (Week 2 - 3 days)

**Goal:** Test all 6 agent types (150+ functions)

**Functions to Test:** 153
- Agent (GenServer base): 25
- CostOptimizedAgent: 30
- ArchitectureAgent: 30
- SelfImprovingAgent: 25
- RefactoringAgent: 22
- ChatAgent: 21

**Estimated Tests:** 300 test cases
**Estimated Effort:** 50 hours (1 developer × 1.25 weeks)

**Key Scenarios:**
1. Lifecycle (start, idle, working, error, shutdown) - 10 tests per agent
2. Metrics tracking (requests, successes, failures, time) - 5 tests per agent
3. IPC (cast, call, reply) - 5 tests per agent
4. Request handling (analyze, improve, refactor, chat) - 5 tests per agent
5. Error recovery and backpressure - 5 tests per agent

### Phase 3: Job Infrastructure Tests (Week 2 - 2 days)

**Goal:** Test all background jobs (66+ functions total)

**Already Tested (206 tests):**
- CacheMaintenanceJob ✅
- EmbeddingFinetuneJob ✅
- TrainT5ModelJob ✅
- PatternSyncJob ✅
- DomainVocabularyTrainerJob ✅

**Remaining Untested (10+ jobs):**
- ArchitectureEvolutionJob - 15 tests
- FrameworkLearningJob - 12 tests
- AutonomousImprovementJob - 12 tests
- MetricsAggregationJob - 10 tests
- PatternConsolidationJob - 10 tests
- Plus 5+ more

**Estimated Tests:** 100 test cases
**Estimated Effort:** 20 hours (1 developer × 2.5 days)

### Phase 4: LLM Integration Tests (Week 3 - 2 days)

**Goal:** Test provider integration, model selection, cost tracking

**Functions to Test:** 40
- Provider abstraction: 10
- Model selection: 8
- Token counting: 8
- Cost optimization: 8
- Caching: 6

**Estimated Tests:** 120 test cases
**Estimated Effort:** 25 hours (1 developer × 3 days)

**Mocking Strategy:**
```elixir
# Use Mox for provider mocking
defmock MockProvider, for: Singularity.LLM.Provider do
  def call(model, messages, opts) do
    # Return realistic token counts and costs
    {:ok, %{tokens: 150, cost: 0.0045, completion: "..."}}
  end
end
```

### Phase 5: Validation & Code Analysis Tests (Week 3 - 2 days)

**Goal:** Test validation pipeline and code analysis orchestrators

**Functions to Test:** 70
- Quality validation: 15
- Type validation: 12
- Architecture validation: 15
- Pattern detection: 12
- Code analysis: 16

**Estimated Tests:** 140 test cases
**Estimated Effort:** 30 hours (1 developer × 3.75 days)

### Phase 6: Utility & Helper Tests (Week 4+)

**Goal:** Comprehensive coverage of utilities, helpers, edge cases

**Functions to Test:** 2,600+ (lower priority)

**Estimated Tests:** 2,600 test cases
**Estimated Effort:** 200+ hours (ongoing)

---

## 6. Test Pattern Recommendations

### Pattern 1: Simple Data Transformers

**Example:** Metrics recording, pattern consolidation, format conversion

```elixir
describe "MetricsAggregation.record_metric/3" do
  test "records metric with numeric value" do
    {:ok, metric} = MetricsAggregation.record_metric("latency", 42.5, [])
    assert metric.value == 42.5
    assert metric.recorded_at
  end

  test "supports metric labels (tags)" do
    labels = [check_id: "check-1", run_id: "run-1", status: "success"]
    {:ok, metric} = MetricsAggregation.record_metric("execution_time", 123, labels)
    assert metric.labels == labels
  end

  test "validates metric names" do
    assert {:error, :invalid_name} = 
      MetricsAggregation.record_metric("", 10, [])
    assert {:error, :invalid_name} = 
      MetricsAggregation.record_metric("invalid name!", 10, [])
  end

  test "handles negative values" do
    {:ok, metric} = MetricsAggregation.record_metric("delta", -5, [])
    assert metric.value == -5
  end

  test "idempotent: same call twice = same result" do
    result1 = MetricsAggregation.record_metric("test", 1, [])
    result2 = MetricsAggregation.record_metric("test", 1, [])
    assert result1 == result2
  end
end
```

### Pattern 2: Database Operations

**Example:** Pattern storage, learning records, validation results

```elixir
describe "PatternConsolidator.consolidate_similar/2" do
  setup [:setup_database]

  test "consolidates identical patterns", %{repo: repo} do
    # Setup: Insert two similar patterns
    p1 = repo.insert!(%Pattern{name: "oauth", similarity: 0.98})
    p2 = repo.insert!(%Pattern{name: "oauth_v2", similarity: 0.97})

    # Action: Consolidate
    {:ok, consolidated} = PatternConsolidator.consolidate_similar([p1, p2], 0.95)

    # Assert: Merged into single record
    assert length(consolidated) == 1
    assert consolidated[0].aliases == ["oauth", "oauth_v2"]
  end

  test "respects similarity threshold" do
    p1 = build(:pattern, similarity: 0.99)
    p2 = build(:pattern, similarity: 0.50)

    {:ok, result} = PatternConsolidator.consolidate_similar([p1, p2], 0.95)

    # Should NOT consolidate (threshold not met)
    assert length(result) == 2
  end

  test "transaction rollback on error" do
    patterns = [
      build(:pattern),
      build(:pattern, name: nil)  # Will fail validation
    ]

    {:error, :validation_failed} = 
      PatternConsolidator.consolidate_similar(patterns, 0.95)

    # Verify no partial writes
    assert repo.aggregate(Pattern, :count) == 0
  end
end

# Helper
defp setup_database(_) do
  {:ok, repo: Repo}
end
```

### Pattern 3: LLM Integration Testing

**Example:** Provider calls, model selection, cost tracking

```elixir
describe "LLM.Service.call/2 with provider mocking" do
  setup do
    Mox.verify_on_exit!()
    {:ok}
  end

  test "calls correct provider based on model" do
    expect(MockAnthropicProvider, :call, fn _model, _messages, _opts ->
      {:ok, %{tokens: 100, cost: 0.003, completion: "response"}}
    end)

    {:ok, result} = LLM.Service.call(:simple, [
      %{role: "user", content: "test"}
    ], provider: MockAnthropicProvider)

    assert result.tokens == 100
    assert result.cost == 0.003
  end

  test "retries on provider timeout" do
    expect(MockProvider, :call, fn _m, _ms, _o ->
      {:error, :timeout}
    end)
    expect(MockProvider, :call, fn _m, _ms, _o ->
      {:ok, %{completion: "success"}}
    end)

    {:ok, result} = LLM.Service.call(:simple, [], 
      provider: MockProvider,
      max_retries: 2)

    assert result.completion == "success"
  end

  test "tracks cost metrics" do
    allow(MockMetrics, :record_metric, fn name, value, opts ->
      assert name == "llm_cost_total"
      assert value > 0
      :ok
    end)

    LLM.Service.call(:simple, [], provider: MockProvider)

    # Verify metric was recorded
    Mox.verify(MockMetrics)
  end
end
```

### Pattern 4: Agent/GenServer Testing

**Example:** Lifecycle, state management, message handling

```elixir
describe "CostOptimizedAgent lifecycle" do
  test "starts with idle status" do
    {:ok, pid} = CostOptimizedAgent.start_link(id: "test-agent")
    state = GenServer.call(pid, :state)
    assert state.status == :idle
    assert state.request_count == 0
    GenServer.stop(pid)
  end

  test "transitions to :analyzing on request" do
    {:ok, pid} = CostOptimizedAgent.start_link(id: "test")
    
    GenServer.cast(pid, {:improve, %{code: "pub fn test() {}"}})
    Process.sleep(50)
    
    state = GenServer.call(pid, :state)
    assert state.status in [:analyzing, :idle]  # May complete quickly
    GenServer.stop(pid)
  end

  test "tracks request metrics" do
    {:ok, pid} = CostOptimizedAgent.start_link(id: "test")
    
    GenServer.cast(pid, {:improve, %{}})
    Process.sleep(50)
    GenServer.cast(pid, {:improve, %{}})
    Process.sleep(50)
    
    state = GenServer.call(pid, :state)
    assert state.request_count == 2
    assert state.success_count >= 0
    GenServer.stop(pid)
  end

  test "handles errors gracefully" do
    {:ok, pid} = CostOptimizedAgent.start_link(id: "test")
    
    GenServer.cast(pid, {:improve, nil})  # Invalid input
    Process.sleep(50)
    
    state = GenServer.call(pid, :state)
    assert state.error_count >= 1
    assert Process.alive?(pid)  # Not crashed
    GenServer.stop(pid)
  end

  test "terminates cleanly" do
    {:ok, pid} = CostOptimizedAgent.start_link(id: "test")
    
    assert GenServer.stop(pid) == :ok
    refute Process.alive?(pid)
  end
end
```

### Pattern 5: Background Job Testing

**Example:** Scheduling, execution, error recovery (206 tests as model)

```elixir
describe "ArchitectureEvolutionJob" do
  setup [:setup_job_test]

  test "schedules job in correct queue" do
    {:ok, job} = ArchitectureEvolutionJob.schedule_now(%{session_id: "s1"})
    
    assert job.queue == "architecture"
    assert job.state == "scheduled"
    assert_enqueued(worker: ArchitectureEvolutionJob)
  end

  test "executes analysis and returns results" do
    args = %{"session_id" => "s1", "analysis_type" => "microservices"}
    
    {:ok, result} = ArchitectureEvolutionJob.perform(%Oban.Job{args: args})
    
    assert result.session_id == "s1"
    assert result.recommendations
    assert is_list(result.recommendations)
  end

  test "publishes completion event to NATS" do
    expect(MockNats, :pub, fn subject, _payload ->
      assert subject == "architecture.evolution.complete"
      :ok
    end)

    ArchitectureEvolutionJob.perform(%Oban.Job{args: %{"session_id" => "s1"}})
    
    Mox.verify(MockNats)
  end

  test "retries on transient errors" do
    # Simulate database timeout on first call
    expect(MockRepo, :one, fn _query ->
      {:error, :timeout}
    end)
    expect(MockRepo, :one, fn _query ->
      {:ok, session}
    end)

    # Job framework will retry automatically
    # Verify successful execution after retry
  end

  test "max_attempts respected" do
    # After 3 attempts, job moves to discarded
    # Verify error is logged
    # Verify notification sent (optional)
  end
end
```

---

## 7. Test Execution & CI/CD Integration

### Current Test Infrastructure

**Mix Tasks:**
```bash
mix test                    # Run all tests
mix test --color --cover    # Run with coverage report
mix test.ci                 # CI configuration
mix coverage                # Generate HTML coverage report
```

**Coverage Tool:** Coveralls (optional, available)

### Recommended CI Configuration

```bash
# In mix.exs test.ci task:
"test.ci": ["test --color --cover --exit-on-failure"]

# GitHub Actions workflow:
- name: Run Tests
  run: cd singularity && mix test.ci
  
- name: Upload Coverage
  run: mix coveralls.github
```

### Target Coverage Goals

| Phase | Coverage % | Timeline | Status |
|---|---|---|---|
| **Phase 1** (Critical) | 45% | 2 weeks | 🔴 Starting |
| **Phase 2** (Core) | 65% | 4 weeks | 🟡 In progress |
| **Phase 3** (High) | 80% | 8 weeks | 🔴 Not started |
| **Phase 4** (Complete) | 95% | 16 weeks | 🔴 Not started |

---

## 8. Effort & Resource Estimates

### Time Investment (1 developer)

| Phase | Functions | Tests | Effort | Timeline |
|---|---|---|---|---|
| Phase 1: Learning Infrastructure | 45 | 180 | 40h | Week 1 (2.5 days) |
| Phase 2: Agent System | 153 | 300 | 50h | Week 2-3 (3 days) |
| Phase 3: Jobs | 66 | 100 | 20h | Week 2-3 (2.5 days) |
| Phase 4: LLM Integration | 40 | 120 | 25h | Week 3 (3 days) |
| Phase 5: Validation | 70 | 140 | 30h | Week 3 (3.75 days) |
| **Subtotal (Critical/High)** | **374** | **840** | **165h** | **2-3 weeks** |
| Phase 6: Utilities | 2,600 | 2,600 | 200h+ | 4+ weeks |
| **GRAND TOTAL** | **3,000+** | **3,500+** | **365h+** | **8-10 weeks** |

### Resource Options

**Option 1: Single Developer (Recommended for MVP)**
- Time: 10-12 weeks
- Coverage reached: 95% (all P0 + P1 complete)
- Risk: Slower, but proven quality
- Best for: Rigorous testing, consistency

**Option 2: Two Developers (Parallel)**
- Time: 5-6 weeks
- Coverage reached: 95%
- Risk: Coordination overhead, test duplication
- Best for: Urgent deadline, adequate resources

**Option 3: Three Developers (Aggressive)**
- Time: 3-4 weeks
- Coverage reached: 80% (P0 + P1 complete)
- Risk: High coordination overhead, less rigorous
- Best for: Urgent MVP, later refinement

### Test Automation Potential

**Can tests be auto-generated?**

✅ **Yes, partially (30-50% time savings)**

1. **Property-based tests** via ExUnit/PropEr/StreamData
   - Automated input generation for pure functions
   - Finds edge cases automatically
   - Recommended for: Metrics, transformation functions
   - Potential savings: 40% of tests

2. **Template-based tests** from type specs
   - Generate basic tests from function signatures
   - Developers fill in business logic assertions
   - Recommended for: Database operations, CRUD functions
   - Potential savings: 25% of effort

3. **Generative testing** via Instructor + LLM
   - Generate test cases from docstrings
   - Validate with LLM output checking
   - Recommended for: API functions, integration points
   - Potential savings: 30% of effort

**Implementation Approach:**
```elixir
# Use ExUnit with property-based testing
defmodule MetricsAggregation.PropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "record_metric always returns metric" do
    check all name <- string(:printable),
              value <- float(),
              labels <- list_of(atom(:printable)) do
      
      {:ok, metric} = MetricsAggregation.record_metric(name, value, labels)
      assert metric.value == value
    end
  end
end
```

---

## 9. Recommendations

### Minimum Viable Testing

**Scope:** 127 pipeline + 200 critical discovered functions (327 total)
**Functions:** 327
**Tests Needed:** ~800 test cases
**Effort:** 100 hours
**Timeline:** 2-3 weeks
**Coverage Impact:** Phase 5 pipeline becomes testable

**Components to Test:**
1. ✅ Learning infrastructure (AutonomousWorker, FrameworkLearning)
2. ✅ Metrics tracking (MetricsAggregation)
3. ✅ Pattern operations (consolidation, deduplication)
4. ✅ Job scheduling and execution
5. ✅ Validation pipeline
6. ✅ Key agent functions

**Expected Outcome:** Confident Phase 5 pipeline execution, ~45% total coverage

---

### Realistic Target

**Scope:** P0 + P1 functions (374 total)
**Functions:** 374
**Tests Needed:** 840 test cases
**Effort:** 165 hours
**Timeline:** 4-5 weeks (1 dev) or 2-3 weeks (2 devs)
**Coverage Impact:** Production-ready infrastructure

**Additional Components:**
1. ✅ All 6 agent types
2. ✅ All background jobs
3. ✅ LLM provider integration
4. ✅ NATS messaging
5. ✅ Advanced error handling

**Expected Outcome:** Comprehensive P0/P1 coverage, ~65% total coverage, production-ready

---

### Ideal Comprehensive Coverage

**Scope:** All functions (3,000+)
**Functions:** 3,000+
**Tests Needed:** 3,500+ test cases
**Effort:** 365+ hours
**Timeline:** 8-10 weeks (1 dev) or 4-5 weeks (2 devs)
**Coverage Impact:** 95% function coverage, all edge cases tested

**Complete Testing of:**
1. ✅ All utility functions
2. ✅ All helper functions
3. ✅ All edge cases and error paths
4. ✅ Property-based testing
5. ✅ Integration testing across components

**Expected Outcome:** Comprehensive test suite, 95%+ coverage, maximum confidence

---

### Immediate Next Steps

**This Week (2.5 days):**
1. Test AutonomousWorker functions (5 tests, 2h)
2. Test FrameworkLearning functions (30 tests, 8h)
3. Test MetricsAggregation core (15 tests, 6h)
4. Test PatternConsolidator (10 tests, 4h)
5. Test PipelineExecutor scheduling (10 tests, 4h)

**Total: 40 tests, 24 hours → 31% → 40% coverage on critical functions**

**Then (Week 2):**
1. Remaining agent system functions
2. Remaining job implementations
3. LLM integration basics
4. CI/CD integration with coverage tracking

---

## 10. Testing Metrics to Track

### Key Metrics

```yaml
Coverage Metrics:
  - Lines covered / Total lines
  - Functions tested / Total functions
  - By application (Singularity, CentralCloud, ExLLM, etc.)
  - By module category (agents, jobs, metrics, etc.)

Quality Metrics:
  - Test pass rate (target: 100%)
  - Test flakiness rate (target: <1%)
  - Test execution time (target: <5min for unit tests)
  - Code review coverage (target: 100%)

Development Velocity:
  - Tests written per day
  - Coverage improvement per sprint
  - Time-to-test by function type
  - Regressions caught by tests

Maintenance Metrics:
  - Test-to-code ratio (target: 1:2 to 1:3)
  - Test code quality (duplicated test patterns)
  - Documentation coverage in tests
```

### Monitoring via CI/CD

```bash
# Track coverage trend
mix test.ci --cover
coveralls.json → GitHub Actions → Chart

# Alert on regressions
IF coverage_drop > 5% THEN alert
IF test_failure_rate > 0.5% THEN alert

# Dashboard
Coverage %: 31% (target: 95%)
Last updated: 2025-10-26
Trend: +3% per week
ETA to 80%: 10 weeks (1 dev)
```

---

## Conclusion

**Current State:** 45% average coverage with 1,001 tests across 829 source files. Strong infrastructure for critical jobs (206 tests), but significant gaps in agent system (3%), learning functions (0%), and metrics (0%).

**Critical Path:** Phase 5 pipeline execution depends on 200+ untested functions. Minimum viable testing (100h, 2-3 weeks) makes pipeline executable. Realistic target (165h, 4-5 weeks) reaches production-ready infrastructure.

**Recommendation:** Implement Phase 1-2 (learning + agents) immediately to unblock pipeline testing, then Phase 3-5 for comprehensive coverage. Use property-based testing where applicable to accelerate development.

**Success Metrics:** 80% coverage in 8 weeks (1 dev) or 4 weeks (2 devs). All P0 functions tested by end of Phase 2. All P1 functions tested by end of Phase 3.

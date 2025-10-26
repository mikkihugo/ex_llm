# Test Implementation Plan - Phase 5 Critical Functions

**Date:** October 26, 2025
**Priority:** P0 CRITICAL - Unblock Phase 5 implementation
**Scope:** AutonomousWorker, FrameworkLearning, MetricsAggregation, PatternConsolidator, PipelineExecutor
**Effort:** 70 hours to reach Phase 5 readiness

---

## Overview

This document provides **detailed, actionable test specifications** for all P0 CRITICAL functions blocking Phase 5 implementation. Each function includes:

1. **Test File Location** - Where to write tests
2. **Test Cases** - Specific test names and scenarios
3. **Assertions** - Exact checks needed
4. **Mock Strategy** - How to handle dependencies
5. **Effort Estimate** - Time per test
6. **Success Criteria** - When test is complete

---

## 1. AutonomousWorker Tests (5 tests, 2 hours)

**File:** `singularity/test/singularity/database/autonomous_worker_test.exs`

**Purpose:** Test core learning triggers for Phase 5

### Test 1.1: `test_learn_patterns_now_succeeds`

**Function Under Test:** `AutonomousWorker.learn_patterns_now/0`

**Test Specification:**

```elixir
test "learn_patterns_now/0 triggers pattern learning and returns :ok" do
  # Setup: Create test failure patterns in database
  {:ok, failure} = create_test_failure(%{
    signature: "CompileError",
    context: "build",
    mode: "apply_fix"
  })

  # Mock: Replace background job submission with counter
  {:ok, job_pid} = mock_background_job_submission()

  # Execute
  result = AutonomousWorker.learn_patterns_now()

  # Assert
  assert result == :ok
  assert job_submitted?(job_pid)
end
```

**Setup Requirements:**
- Database with sample failure patterns
- Mock Oban job submission
- Clear metrics state before test

**Mock Strategy:**
- Mock `Oban.insert/1` to prevent actual job submission
- Use in-memory counter to track calls
- Return success atom

**Assertions:**
- Return value is `:ok`
- Background job was submitted
- Failure count > 0 (patterns exist to learn)

**Effort:** 20 minutes

---

### Test 1.2: `test_learn_patterns_now_with_no_failures`

**Function Under Test:** `AutonomousWorker.learn_patterns_now/0`

**Test Specification:**

```elixir
test "learn_patterns_now/0 returns :ok even when no failures exist" do
  # Setup: Empty database
  clear_failures_table()

  # Execute
  result = AutonomousWorker.learn_patterns_now()

  # Assert
  assert result == :ok
  assert no_jobs_submitted()
end
```

**Setup Requirements:**
- Clean database (no failures)
- Mock job submission

**Mock Strategy:**
- Mock `Oban.insert/1` to fail safely if called
- Track that no calls were made

**Assertions:**
- Return `:ok` (idempotent)
- No background jobs submitted
- No errors raised

**Effort:** 15 minutes

---

### Test 1.3: `test_sync_learning_now_succeeds`

**Function Under Test:** `AutonomousWorker.sync_learning_now/0`

**Test Specification:**

```elixir
test "sync_learning_now/0 synchronizes learned patterns" do
  # Setup: Create learned pattern in local cache
  {:ok, pattern} = create_learned_pattern(%{
    name: "retry_exponential_backoff",
    framework: "elixir_otp",
    success_rate: 0.95
  })

  # Mock: Replace remote sync with counter
  mock_remote_sync()

  # Execute
  result = AutonomousWorker.sync_learning_now()

  # Assert
  assert result == :ok
  assert remote_sync_called?()
end
```

**Setup Requirements:**
- Database with learned patterns
- Mock remote sync API
- Metrics setup

**Mock Strategy:**
- Mock HTTP calls to remote learning database
- Use in-memory tracking for verification
- Simulate success response

**Assertions:**
- Returns `:ok`
- Remote sync was called
- Pattern metadata updated with sync timestamp

**Effort:** 20 minutes

---

### Test 1.4: `test_learning_queue_backed_up_returns_boolean`

**Function Under Test:** `AutonomousWorker.learning_queue_backed_up?/1`

**Test Specification:**

```elixir
test "learning_queue_backed_up?(threshold) returns true when queue size exceeds threshold" do
  # Setup: Create many queued jobs
  create_queued_jobs(count: 100)

  # Execute
  result_below = AutonomousWorker.learning_queue_backed_up?(50)
  result_above = AutonomousWorker.learning_queue_backed_up?(200)

  # Assert
  assert result_below == true
  assert result_above == false
end
```

**Setup Requirements:**
- Oban job queue setup
- Multiple queued jobs
- Job count tracking

**Mock Strategy:**
- Create real Oban jobs (or mock job count retrieval)
- Clear queue before/after test

**Assertions:**
- Returns boolean (true/false)
- Correctly compares queue size to threshold
- Handles edge cases (empty queue, equal count)

**Effort:** 15 minutes

---

### Test 1.5: `test_check_job_health_returns_status`

**Function Under Test:** `AutonomousWorker.check_job_health/1`

**Test Specification:**

```elixir
test "check_job_health(job_type) returns health status" do
  # Setup: Create jobs with known success/failure rates
  create_jobs([
    {learning_job, 95},   # 95% success rate
    {sync_job, 80},       # 80% success rate
    {failed_job, 20}      # 20% success rate (unhealthy)
  ])

  # Execute
  health_good = AutonomousWorker.check_job_health(:learning)
  health_ok = AutonomousWorker.check_job_health(:sync)
  health_bad = AutonomousWorker.check_job_health(:failed)

  # Assert
  assert health_good == :healthy
  assert health_ok == :degraded
  assert health_bad == :unhealthy
end
```

**Setup Requirements:**
- Multiple jobs with different success rates
- Historical job execution data
- Status threshold definitions

**Mock Strategy:**
- Create test jobs with known outcomes
- Mock job history queries
- Return status based on percentages

**Assertions:**
- Returns atom status (:healthy, :degraded, :unhealthy)
- Correctly calculates success rate
- Handles missing jobs gracefully

**Effort:** 20 minutes

---

## 2. FrameworkLearning Tests (30 tests, 8 hours)

**File:** `singularity/test/singularity/architecture_engine/meta_registry/framework_learning_test.exs`

**Purpose:** Test all 9 framework-specific learner functions

**Note:** There are actually 9 core learner functions plus 13+ suggestion getter functions. We'll test core learners thoroughly.

### Test 2.1-2.9: Core Framework Learner Tests (27 tests, 7 hours)

**Pattern for Each Learner:**

For each of the 9 learners (NATS, PostgreSQL, ETS, Rust NIF, OTP, Ecto, Jason, Phoenix, ExUnit), create 3 tests:

#### Test 2.X.A: Happy Path - Learn Framework Patterns

```elixir
test "learn_nats_patterns/1 extracts and stores NATS patterns" do
  # Setup: Code with NATS patterns
  code = """
  def handle_message(subject, message) do
    case subject do
      "pubsub.*" -> broadcast(message)
      "rpc.*" -> respond(message)
    end
  end
  """

  # Mock: Pattern extraction and storage
  mock_pattern_extraction()
  mock_pattern_storage()

  # Execute
  {:ok, patterns} = FrameworkLearning.learn_nats_patterns(code)

  # Assert
  assert length(patterns) >= 1
  assert Enum.any?(patterns, &match?(%{pattern_type: "pubsub"}, &1))
  assert Enum.any?(patterns, &match?(%{pattern_type: "rpc"}, &1))
end
```

**Tests:** (9 learners × 3 scenarios = 27 tests)
1. `learn_nats_patterns/1` - NATS messaging patterns
2. `learn_postgresql_patterns/1` - Database query patterns
3. `learn_ets_patterns/1` - ETS caching patterns
4. `learn_rust_nif_patterns/1` - Rust NIF binding patterns
5. `learn_elixir_otp_patterns/1` - OTP supervision patterns
6. `learn_ecto_patterns/1` - ORM query patterns
7. `learn_jason_patterns/1` - JSON encoding patterns
8. `learn_phoenix_patterns/1` - Web framework patterns
9. `learn_exunit_patterns/1` - Test framework patterns

**For Each Learner, Test 3 Scenarios:**

**Scenario A: Happy Path (3 hours total, 20 min per test)**
```
- Learner extracts patterns successfully
- Returns list of patterns
- Each pattern has required fields (name, type, example, confidence)
- Patterns are stored in database
```

**Scenario B: No Patterns Found (1.5 hours total, 10 min per test)**
```
- Code doesn't contain framework-specific patterns
- Returns empty list []
- No errors raised
- Function is idempotent
```

**Scenario C: Error Handling (2.5 hours total, 15 min per test)**
```
- Invalid code (syntax errors)
- Database connection failure
- Returns {:error, reason}
- Reason is descriptive
- Original state unchanged
```

**Setup Requirements Per Test:**
- Sample code files with framework patterns
- Mock pattern extraction (if using external tool)
- Mock database storage
- Clear state before/after

**Mock Strategy:**
- Mock `CodeAnalyzer.extract_patterns/2` to return patterns
- Mock `PatternStore.save/1` to return {:ok, pattern}
- Mock `Logger.info/1` to avoid noise

**Assertions Per Test:**
- Correct return type (list or error tuple)
- Correct pattern structure
- Database calls made correctly
- No side effects (idempotent)

**Effort:** 27 tests × 15-20 min = 450-540 minutes = 7.5-9 hours total

---

### Test 2.10: Suggestion Getter Tests (3 tests, 1 hour)

**Test Pattern:** Test the suggestion getter functions that query learned patterns

```elixir
test "get_nats_suggestions(context, depth) returns relevant suggestions" do
  # Setup: Store learned NATS patterns
  patterns = [
    %{name: "pubsub_handler", confidence: 0.95},
    %{name: "rpc_responder", confidence: 0.88},
    %{name: "queue_consumer", confidence: 0.92}
  ]
  store_learned_patterns(patterns)

  # Execute
  suggestions = FrameworkLearning.get_nats_suggestions("message_handler", depth: 2)

  # Assert
  assert length(suggestions) >= 1
  assert Enum.all?(suggestions, &(Map.has_key?(&1, :name)))
  assert Enum.all?(suggestions, &(Map.has_key?(&1, :confidence)))
  assert hd(suggestions).confidence >= 0.8  # High confidence threshold
end
```

**Tests:**
1. `get_nats_suggestions/2` - NATS pattern suggestions
2. `get_postgresql_suggestions/2` - Database pattern suggestions
3. `get_framework_suggestions/2` (if exists) - General framework suggestions

**Effort:** 3 tests × 20 min = 60 minutes = 1 hour

---

## 3. MetricsAggregation Tests (15 tests, 6 hours)

**File:** `singularity/test/singularity/database/metrics_aggregation_test.exs`

**Purpose:** Test complete validation metrics infrastructure

### Test 3.1: `test_record_metric_stores_and_retrieves`

```elixir
test "record_metric/3 stores metric and can be retrieved" do
  # Setup
  check_id = "quality_check_1"
  metric_name = "execution_time_ms"
  value = 125

  # Execute: Record metric
  {:ok, metric} = MetricsAggregation.record_metric(check_id, metric_name, value)

  # Execute: Retrieve metric
  {:ok, retrieved} = MetricsAggregation.get_metric(check_id, metric_name)

  # Assert
  assert retrieved.value == value
  assert retrieved.check_id == check_id
  assert retrieved.metric_name == metric_name
  assert metric.created_at is not nil
end
```

**Effort:** 20 minutes

---

### Test 3.2: `test_record_metric_with_tags`

```elixir
test "record_metric/3 stores tags for filtering" do
  # Setup
  metric = %{
    check_id: "security_check_1",
    name: "issues_found",
    value: 3,
    tags: %{"severity" => "high", "type" => "sql_injection"}
  }

  # Execute
  {:ok, stored} = MetricsAggregation.record_metric(metric.check_id, metric.name, metric.value, metric.tags)

  # Execute: Query by tag
  {:ok, results} = MetricsAggregation.query_by_tag("severity", "high")

  # Assert
  assert length(results) >= 1
  assert Enum.any?(results, &(&1.check_id == metric.check_id))
end
```

**Effort:** 20 minutes

---

### Test 3.3: `test_get_metrics_returns_all_metrics_for_check`

```elixir
test "get_metrics/2 returns all metrics for a check" do
  # Setup: Record multiple metrics
  check_id = "validation_check_5"
  metrics = [
    {"confidence", 0.92},
    {"execution_time", 245},
    {"validation_passes", 15},
    {"validation_failures", 2}
  ]

  Enum.each(metrics, fn {name, value} ->
    MetricsAggregation.record_metric(check_id, name, value)
  end)

  # Execute
  {:ok, results} = MetricsAggregation.get_metrics(check_id, limit: 100)

  # Assert
  assert length(results) == 4
  assert Enum.all?(results, &(&1.check_id == check_id))
  names = Enum.map(results, &(&1.metric_name))
  assert names == ["confidence", "execution_time", "validation_passes", "validation_failures"]
end
```

**Effort:** 20 minutes

---

### Test 3.4: `test_get_metrics_with_time_range`

```elixir
test "get_metrics/2 filters by time range" do
  # Setup: Record metrics at different times
  check_id = "time_test_check"

  past_time = DateTime.add(DateTime.utc_now(), -1, :day)
  recent_time = DateTime.utc_now()

  # Record old metric
  MetricsAggregation.record_metric(check_id, "old_metric", 100, %{}, past_time)

  # Record recent metric
  MetricsAggregation.record_metric(check_id, "new_metric", 200, %{}, recent_time)

  # Execute: Get recent metrics
  {:ok, results} = MetricsAggregation.get_metrics(check_id,
    since: DateTime.add(recent_time, -1, :hour)
  )

  # Assert
  assert length(results) == 1
  assert hd(results).metric_name == "new_metric"
end
```

**Effort:** 20 minutes

---

### Test 3.5: `test_get_percentile_calculates_correctly`

```elixir
test "get_percentile/3 calculates percentile correctly" do
  # Setup: Record execution times for percentile calculation
  check_id = "percentile_test"
  times = [100, 150, 200, 250, 300, 350, 400, 450, 500]

  Enum.each(times, fn time ->
    MetricsAggregation.record_metric(check_id, "latency_ms", time)
  end)

  # Execute
  p50 = MetricsAggregation.get_percentile(check_id, "latency_ms", 50)
  p95 = MetricsAggregation.get_percentile(check_id, "latency_ms", 95)

  # Assert
  assert p50 >= 200 and p50 <= 300  # Middle value around 250
  assert p95 >= 400 and p95 <= 500  # High percentile near top
end
```

**Effort:** 25 minutes

---

### Test 3.6: `test_get_rate_calculates_per_second`

```elixir
test "get_rate/2 calculates metrics per second correctly" do
  # Setup: Record metrics over time window
  check_id = "rate_test"

  # Record 10 events over 10 seconds
  start_time = DateTime.utc_now()
  Enum.each(1..10, fn i ->
    time = DateTime.add(start_time, i, :second)
    MetricsAggregation.record_metric(check_id, "requests", i, %{}, time)
  end)

  # Execute: Get rate (events per second)
  rate = MetricsAggregation.get_rate(check_id, "requests",
    from: start_time,
    to: DateTime.add(start_time, 10, :second)
  )

  # Assert
  assert rate >= 0.9 and rate <= 1.1  # ~1 event per second
end
```

**Effort:** 25 minutes

---

### Test 3.7-3.10: Edge Cases and Error Handling (4 tests, 1.5 hours)

**Test 3.7: Empty Metrics**
```elixir
test "get_metrics/2 returns empty list when no metrics exist" do
  {:ok, results} = MetricsAggregation.get_metrics("nonexistent_check")
  assert results == []
end
```

**Test 3.8: Invalid Input**
```elixir
test "record_metric/3 returns error for invalid inputs" do
  {:error, reason} = MetricsAggregation.record_metric("", "metric", "not_a_number")
  assert reason != nil
end
```

**Test 3.9: Concurrent Writes**
```elixir
test "record_metric/3 handles concurrent writes correctly" do
  check_id = "concurrent_test"

  tasks = Enum.map(1..10, fn i ->
    Task.async(fn ->
      MetricsAggregation.record_metric(check_id, "count", i)
    end)
  end)

  Task.await_many(tasks)

  {:ok, results} = MetricsAggregation.get_metrics(check_id)
  assert length(results) == 10
end
```

**Test 3.10: Data Compression**
```elixir
test "compress_old_metrics/1 archives old data correctly" do
  # Setup: Record metrics older than retention period
  old_time = DateTime.add(DateTime.utc_now(), -90, :day)
  MetricsAggregation.record_metric("old_check", "metric", 100, %{}, old_time)

  # Execute: Compress
  {:ok, compressed_count} = MetricsAggregation.compress_old_metrics(days: 30)

  # Assert
  assert compressed_count >= 1
end
```

**Effort:** 4 tests × 22 min = 88 minutes = 1.5 hours

---

### Test 3.11-3.15: Integration Tests (5 tests, 1.5 hours)

**Test 3.11: Validation Metrics Flow**
```elixir
test "complete validation metrics flow works end-to-end" do
  # Record: Validation started
  MetricsAggregation.record_metric("validation_1", "started", 1)

  # Record: Each check execution
  MetricsAggregation.record_metric("validation_1", "check_1_time", 125)
  MetricsAggregation.record_metric("validation_1", "check_1_passed", 1)

  MetricsAggregation.record_metric("validation_1", "check_2_time", 234)
  MetricsAggregation.record_metric("validation_1", "check_2_passed", 1)

  # Query: Get all metrics
  {:ok, all_metrics} = MetricsAggregation.get_metrics("validation_1", limit: 100)

  # Assert: Can reconstruct validation execution
  assert length(all_metrics) >= 5
  times = Enum.filter(all_metrics, &String.contains?(&1.metric_name, "time"))
  assert length(times) == 2
end
```

**Effort:** 5 tests × 18 min = 90 minutes = 1.5 hours

---

## 4. PatternConsolidator Tests (10 tests, 4 hours)

**File:** `singularity/test/singularity/storage/code/patterns/pattern_consolidator_test.exs`

### Test 4.1: `test_consolidate_patterns_merges_similar_patterns`

```elixir
test "consolidate_patterns/1 merges similar failure patterns" do
  # Setup: Similar failure patterns with slight variations
  patterns = [
    %{
      signature: "CompileError",
      context: "build_lib",
      mode: "apply_fix",
      confidence: 0.92
    },
    %{
      signature: "CompileError",
      context: "build_test",
      mode: "apply_fix",
      confidence: 0.89
    },
    %{
      signature: "CompileError",
      context: "build_bench",
      mode: "apply_fix",
      confidence: 0.85
    }
  ]

  # Execute
  {:ok, consolidated} = PatternConsolidator.consolidate_patterns(patterns)

  # Assert: Merged into single pattern
  assert length(consolidated) == 1
  assert hd(consolidated).signature == "CompileError"
  assert hd(consolidated).confidence > 0.85
end
```

**Effort:** 20 minutes

---

### Test 4.2: `test_consolidate_patterns_removes_duplicates`

```elixir
test "consolidate_patterns/1 removes exact duplicates" do
  # Setup: Exact duplicate patterns
  pattern = %{signature: "RuntimeError", context: "execute", mode: "retry"}

  # Execute
  {:ok, result} = PatternConsolidator.consolidate_patterns([pattern, pattern, pattern])

  # Assert
  assert length(result) == 1
  assert hd(result) == pattern
end
```

**Effort:** 15 minutes

---

### Test 4.3: `test_deduplicate_similar_identifies_code_duplicates`

```elixir
test "deduplicate_similar/1 identifies similar code patterns" do
  # Setup: Similar code blocks
  code_blocks = [
    "def handle_error(error) do
       Logger.error(\"Error: #{error}\")
       {:error, error}
     end",

    "def handle_exception(ex) do
       Logger.error(\"Exception: #{ex}\")
       {:error, ex}
     end"
  ]

  # Execute
  {:ok, duplicates} = PatternConsolidator.deduplicate_similar(code_blocks)

  # Assert: Recognizes similarity
  assert length(duplicates) >= 1
end
```

**Effort:** 20 minutes

---

### Test 4.4: `test_generalize_pattern_creates_abstract_pattern`

```elixir
test "generalize_pattern/2 creates abstract pattern" do
  # Setup: Specific pattern instances
  pattern = %{
    signature: "TypeError",
    fix: "cast value: Integer.to_string(value)",
    context: "data_transformation"
  }

  # Execute
  {:ok, generalized} = PatternConsolidator.generalize_pattern(pattern, abstract: true)

  # Assert: Pattern is generalized
  assert generalized.signature == "TypeError"
  assert String.contains?(generalized.fix, "cast value")
  assert generalized.is_abstract == true
end
```

**Effort:** 20 minutes

---

### Test 4.5: `test_analyze_pattern_quality_scores_correctly`

```elixir
test "analyze_pattern_quality/1 scores pattern quality" do
  # Setup: High-quality pattern
  high_quality = %{
    signature: "ExUnit.AssertionError",
    success_count: 95,
    total_count: 100,
    last_applied: DateTime.utc_now(),
    context: "test_validation"
  }

  # Execute
  {:ok, score} = PatternConsolidator.analyze_pattern_quality(high_quality)

  # Assert: High quality score
  assert score.overall_score >= 0.90
  assert score.success_rate == 0.95
end
```

**Effort:** 20 minutes

---

### Test 4.6-4.10: Pattern Operations Edge Cases (5 tests, 2 hours)

**Test 4.6: Empty Pattern List**
```elixir
test "consolidate_patterns/1 handles empty list" do
  {:ok, result} = PatternConsolidator.consolidate_patterns([])
  assert result == []
end
```

**Test 4.7: Conflicting Patterns**
```elixir
test "consolidate_patterns/1 handles conflicting patterns correctly" do
  patterns = [
    %{signature: "Error", fix: "retry"},
    %{signature: "Error", fix: "skip"}  # Conflicting fix
  ]

  {:ok, result} = PatternConsolidator.consolidate_patterns(patterns)
  # Should keep high-confidence or prompt resolution
end
```

**Test 4.8: Pattern Evolution**
```elixir
test "analyze_pattern_quality/1 tracks pattern evolution over time" do
  # Pattern improves over time
  old = %{success_count: 10, total_count: 20, last_applied: 90.days.ago}
  new = %{success_count: 95, total_count: 100, last_applied: DateTime.utc_now()}

  {:ok, score} = PatternConsolidator.analyze_pattern_quality(new)
  assert score.trend == :improving
end
```

**Test 4.9: Confidence Threshold**
```elixir
test "consolidate_patterns/1 filters by confidence threshold" do
  patterns = [
    %{signature: "Error", confidence: 0.95},
    %{signature: "Error", confidence: 0.45},  # Low confidence
    %{signature: "Error", confidence: 0.89}
  ]

  {:ok, result} = PatternConsolidator.consolidate_patterns(patterns, min_confidence: 0.80)
  assert length(result) <= 2
end
```

**Test 4.10: Batch Consolidation**
```elixir
test "auto_consolidate/0 consolidates all pending patterns" do
  # Setup: Create pending patterns
  create_pending_patterns(count: 50)

  # Execute
  {:ok, consolidated_count} = PatternConsolidator.auto_consolidate()

  # Assert
  assert consolidated_count >= 1
end
```

**Effort:** 5 tests × 24 min = 120 minutes = 2 hours

---

## 5. PipelineExecutor Integration Tests (5 tests, 1 hour)

**File:** `singularity/test/singularity/pipeline/pipeline_executor_test.exs`

### Test 5.1: `test_pipeline_executor_runs_phase_1_context_gathering`

```elixir
test "execute_phase_1/1 gathers context successfully" do
  # Setup: Test story
  story = %{
    title: "Add logging to API handler",
    current_code: "def handle_request(conn) do ... end",
    context_size: :medium
  }

  # Mock: NATS calls, LLM responses
  mock_nats_calls()

  # Execute
  {:ok, result} = PipelineExecutor.execute_phase_1(story)

  # Assert
  assert result.phase == 1
  assert result.context_gathered == true
  assert Map.has_key?(result, :code_patterns)
  assert Map.has_key?(result, :failure_history)
end
```

**Effort:** 20 minutes

---

### Test 5.2: `test_pipeline_executor_validates_generated_code`

```elixir
test "execute_phase_3/2 validates generated code with metrics" do
  # Setup: Generated code from Phase 2
  generated = %{
    code: "def handle_request(conn) do Logger.info(conn.method) ... end",
    phase: 2
  }

  story = %{title: "Add logging"}

  # Mock: Validation checks, metrics recording
  mock_validation_checks()
  mock_metrics_recording()

  # Execute
  {:ok, result} = PipelineExecutor.execute_phase_3(story, generated)

  # Assert
  assert result.phase == 3
  assert result.validations_passed >= 1
  assert result.metrics_recorded == true
end
```

**Effort:** 20 minutes

---

### Test 5.3: `test_pipeline_executor_triggers_learning_phase_5`

```elixir
test "execute_phase_5/2 triggers pattern learning" do
  # Setup: Execution result
  result = %{
    phase: 4,
    code: "# final code",
    success: true
  }

  story = %{title: "Test story"}

  # Mock: Learning triggers
  mock_autonomous_worker()

  # Execute
  {:ok, learning_result} = PipelineExecutor.execute_phase_5(story, result)

  # Assert
  assert learning_result.phase == 5
  assert learning_result.patterns_learned >= 0
  assert learning_result.learning_triggered == true
end
```

**Effort:** 20 minutes

---

### Test 5.4: `test_pipeline_executor_handles_errors_gracefully`

```elixir
test "execute/1 handles phase errors and continues" do
  # Setup: Story that will trigger error in Phase 2
  story = %{
    title: "Invalid story",
    current_code: nil  # Will cause error
  }

  # Execute
  {:ok, result} = PipelineExecutor.execute(story)

  # Assert: Error handling and logging
  assert result.phase >= 1
  assert Map.has_key?(result, :errors)
  assert result.errors != nil or result.success == true
end
```

**Effort:** 15 minutes

---

### Test 5.5: `test_pipeline_executor_end_to_end_success`

```elixir
test "execute/1 completes full pipeline successfully" do
  # Setup: Complete story with all required fields
  story = %{
    title: "Add validation to form handler",
    current_code: "def handle_form(data) do ... end",
    complexity: :medium,
    context_size: :medium,
    desired_outcome: "Add form validation with error messages"
  }

  # Mock: All phases
  mock_all_phases()

  # Execute
  {:ok, result} = PipelineExecutor.execute(story, timeout: 30000)

  # Assert: Full execution
  assert result.success == true
  assert result.phase == 5
  assert Map.has_key?(result, :generated_code)
  assert Map.has_key?(result, :validation_results)
  assert Map.has_key?(result, :learning_results)
end
```

**Effort:** 25 minutes

---

## 6. Testing Infrastructure Requirements

### 6.1 Mock/Stub Modules Needed

**Create:** `singularity/test/support/mocks/`

```elixir
# Mocks/autonomous_worker_mock.ex
defmodule Mocks.AutonomousWorkerMock do
  def mock_background_job_submission, do: {:ok, spawn(fn -> :ok end)}
  def job_submitted?(pid), do: is_pid(pid)
end

# Mocks/metrics_mock.ex
defmodule Mocks.MetricsMock do
  def mock_metric_storage, do: :ok
  def record_metric_mock(id, name, value), do: {:ok, %{id: id, name: name, value: value}}
end

# Mocks/pattern_mock.ex
defmodule Mocks.PatternMock do
  def mock_pattern_extraction, do: :ok
  def extract_mock(code), do: {:ok, [%{type: "test", confidence: 0.95}]}
end

# Mocks/nats_mock.ex
defmodule Mocks.NatsMock do
  def mock_nats_call(subject, request) do
    {:ok, %{"result" => "success"}}
  end
end
```

---

### 6.2 Database Fixtures

**Create:** `singularity/test/support/fixtures/`

```elixir
# Fixtures/autonomous_worker_fixtures.ex
defmodule Fixtures.AutonomousWorkerFixtures do
  def create_test_failure(attrs \\ %{}) do
    defaults = %{
      signature: "TestError",
      context: "test",
      mode: "apply_fix",
      timestamp: DateTime.utc_now()
    }

    Map.merge(defaults, attrs)
    |> Singularity.Database.insert_failure()
  end

  def create_learned_pattern(attrs \\ %{}) do
    defaults = %{
      name: "test_pattern",
      framework: "elixir",
      success_rate: 0.90
    }

    Map.merge(defaults, attrs)
    |> Singularity.Storage.insert_pattern()
  end
end

# Fixtures/metrics_fixtures.ex
defmodule Fixtures.MetricsFixtures do
  def create_test_metrics(count \\ 10) do
    Enum.map(1..count, fn i ->
      Singularity.Database.MetricsAggregation.record_metric(
        "test_check",
        "metric_#{i}",
        i * 10
      )
    end)
  end
end
```

---

### 6.3 Test Helpers

**Update:** `singularity/test/support/data_case.ex`

```elixir
defmodule Singularity.DataCase do
  using do
    quote do
      alias Singularity.Repo

      import Ecto
      import Ecto.Query
      import Singularity.DataCase
      import Fixtures.AutonomousWorkerFixtures
      import Fixtures.MetricsFixtures
      import Fixtures.PatternFixtures
      import Mocks.AutonomousWorkerMock
      import Mocks.MetricsMock
      import Mocks.PatternMock
      import Mocks.NatsMock

      # Common assertions
      def assert_metric_recorded(check_id, metric_name) do
        {:ok, metric} = Singularity.Database.MetricsAggregation.get_metric(check_id, metric_name)
        assert metric != nil
      end

      def clear_metrics(check_id) do
        Repo.delete_all(from m in "metrics" where m.check_id == ^check_id)
      end

      def clear_patterns do
        Repo.delete_all(from p in "patterns")
      end
    end
  end

  def setup_sandbox(config) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Singularity.Repo, shared: not config[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

---

## 7. Test Execution Plan

### Phase 1: Immediate (This Week - 24 hours)

**Day 1 (8 hours):**
- Set up test infrastructure (mocks, fixtures, helpers)
- Write and test AutonomousWorker tests (5 tests, 2h)
- Write and test MetricsAggregation tests 1-5 (5 tests, 2h)
- Verify all Phase 5 core triggers work

**Day 2 (8 hours):**
- Write FrameworkLearning tests (9 tests, 3h)
- Write PatternConsolidator tests (5 tests, 2h)
- Integration testing (3h)

**Day 3 (8 hours):**
- Complete remaining tests (10 tests, 4h)
- Fix failures and refine mocks (2h)
- Achieve 70%+ coverage on Phase 5 functions (2h)

### Phase 2: Week 1 (40 hours)
- Complete all FrameworkLearning tests
- Complete all MetricsAggregation tests
- Write PipelineExecutor integration tests
- Fix any failing tests

### Phase 3: Week 2 (50 hours)
- Agent system tests (60+ tests)
- Background job tests (40+ tests)
- LLM integration tests (20+ tests)

---

## 8. Success Criteria

### Coverage Targets

- **AutonomousWorker:** 100% (5/5 functions tested)
- **FrameworkLearning:** 95%+ (9/9 learners, all 3 scenarios each)
- **MetricsAggregation:** 90%+ (6/6 core functions with edge cases)
- **PatternConsolidator:** 85%+ (5/5 core operations)
- **FailurePatternStore:** 100% (7/7 core workflows tested)

### FailurePatternStore Coverage (Added 2025-10-26)

- **File:** `singularity/test/singularity/storage/failure_pattern_store_test.exs`
- **Scope:** Persistence + query helpers for failure pattern intelligence
- **Implemented Tests (7 total):**
  1. `creates a new failure pattern record` — verifies base insert path, defaults, timestamps
  2. `increments frequency and merges metadata for existing patterns` — exercises increment + merge logic
  3. `returns records filtered by failure mode` — ensures query filter accuracy
  4. `supports minimum frequency filter` — validates aggregation threshold handling
  5. `aggregates failure modes by total frequency` — covers `find_patterns/1` summarisation
  6. `matches entries with similar story signatures` — tests `find_similar/2` similarity scoring
  7. `returns unique successful fixes across matching records` — confirms deduped fix retrieval
- **Assertions Added:** Frequency bumping, map/list merges, timestamp updates, similarity thresholds, unique fix aggregation
- **Next Tests (if needed):**
  - Error handling for invalid payloads (malformed validation_errors / successful_fixes)
  - CentralCloud sync behaviour once integration endpoint is available
- **Execution Command:** `mix test singularity/test/singularity/storage/failure_pattern_store_test.exs`
- **Effort Logged:** ~2 hours (schema/store verification + data fixtures)
- **PipelineExecutor:** 80%+ (end-to-end coverage)

### Test Quality

- ✅ All tests pass locally
- ✅ No flaky tests (runs 3x consistently)
- ✅ Clear test names describing behavior
- ✅ Proper mocking (no external API calls)
- ✅ Database isolation (no test pollution)
- ✅ Good error messages on failures

### Phase 5 Readiness

- ✅ All core learning functions tested
- ✅ Metrics recording verified
- ✅ Pattern consolidation working
- ✅ Framework learners functional
- ✅ Integration tests passing
- ✅ Pipeline execution E2E verified

---

## 9. Estimated Effort by Function Group

| Function Group | Tests | Hours | Person-Days | Priority |
|---|---|---|---|---|
| AutonomousWorker | 5 | 2.0 | 0.25 | P0 |
| FrameworkLearning | 30 | 8.0 | 1.0 | P0 |
| MetricsAggregation | 15 | 6.0 | 0.75 | P0 |
| PatternConsolidator | 10 | 4.0 | 0.5 | P0 |
| PipelineExecutor | 5 | 1.0 | 0.125 | P0 |
| FailurePatternStore | 7 | 2.0 | 0.25 | P0 |
| **TOTAL PHASE 5** | **72** | **23.0** | **2.88 days** | **P0** |

---

## 10. Next Steps

1. **Create test support files** (mocks, fixtures, helpers) - 1 hour
2. **Implement AutonomousWorker tests** - 2 hours
3. **Implement FrameworkLearning tests** - 8 hours
4. **Implement MetricsAggregation tests** - 6 hours
5. **Implement PatternConsolidator tests** - 4 hours
6. **Implement PipelineExecutor tests** - 1 hour
7. **Integration testing and fixes** - 5 hours
8. **Coverage verification** - 1 hour
9. *(Completed 2025-10-26)* **FailurePatternStore tests** - 2 hours (`singularity/test/singularity/storage/failure_pattern_store_test.exs`)

**Total: 30 hours to Phase 5 readiness (includes FailurePatternStore coverage)**

---

**Ready to begin implementation!**

This plan is actionable and specific enough that any developer can follow it step-by-step to achieve Phase 5 test coverage and unblock the self-evolving pipeline implementation.

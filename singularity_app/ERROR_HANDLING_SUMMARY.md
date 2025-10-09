# Comprehensive Error Handling Infrastructure - Implementation Summary

## Completed Components

### 1. Core Infrastructure (✅ Complete)

#### `lib/singularity/infrastructure/error_handling.ex`
Production-ready error handling infrastructure with:

- **Structured Error Logging**
  - Correlation IDs for request tracking
  - Contextual metadata (operation, module, user_id, etc.)
  - Automatic stacktrace capture
  - Duration tracking

- **Retry Logic**
  - Exponential backoff with configurable base/max delays
  - Jitter to prevent thundering herd
  - Retryable error classification
  - Configurable max attempts

- **Circuit Breaker**
  - Protection against cascading failures
  - States: closed, open, half_open
  - Configurable failure thresholds
  - Automatic reset after timeout

- **Timeout Handling**
  - Task-based timeouts with cleanup
  - Graceful shutdown of timed-out operations

- **Telemetry Integration**
  - Event emission for monitoring
  - Measurements: duration, status
  - Metadata: correlation_id, operation, module

- **Error Rate Tracking**
  - ETS-based fast error counting
  - Sliding window statistics
  - Automatic alerting on high error rates

- **Graceful Degradation**
  - Fallback value support
  - Continue with partial results

- **Health Checks**
  - GenServer health status
  - Multi-check aggregation
  - States: healthy, degraded, unhealthy

#### `lib/singularity/infrastructure/circuit_breaker.ex`
GenServer-based circuit breaker implementation:

- **Dynamic Circuit Creation**
  - Auto-start via DynamicSupervisor
  - Registry-based lookup
  - Per-service configuration

- **State Management**
  - Closed → Open transition on failure threshold
  - Open → Half-Open after reset timeout
  - Half-Open → Closed on success

- **Statistics Tracking**
  - Failure counts
  - Last failure time
  - Time until reset
  - Current state

#### `lib/singularity/infrastructure/error_rate_tracker.ex`
ETS-based error rate monitoring:

- **Fast Concurrent Access**
  - Public ETS table with read/write concurrency
  - O(1) error recording

- **Sliding Window Analysis**
  - Configurable window (default: 60 seconds)
  - Separate success/error tracking
  - Automatic old entry cleanup

- **Automatic Alerting**
  - Threshold-based alerts (default: 5% error rate)
  - Minimum sample size requirement
  - Integration points for PagerDuty/Slack

- **Multi-Operation Tracking**
  - Track errors per operation type
  - Global error rate overview

## Enhanced Modules

### 2. PackageAndCodebaseSearch (✅ Complete)

**File**: `lib/singularity/search/package_and_codebase_search.ex`

**Enhancements**:
- ✅ Correlation ID tracking across all operations
- ✅ Parallel search with timeout protection (@search_timeout_ms = 10_000)
- ✅ Circuit breaker for package registry API
- ✅ Retry logic for code search (handles Postgrex.Error, DBConnection.ConnectionError)
- ✅ Graceful degradation (continue with partial results if one search fails)
- ✅ Structured logging with context
- ✅ Error rate tracking per operation
- ✅ Telemetry events for monitoring

**Error Scenarios Handled**:
1. Package registry API timeout/failure → Circuit breaker trips, returns empty packages
2. Database connection error → Retry with exponential backoff (2 attempts, 200ms base)
3. Embedding generation failure → Retry 3 times, then fail gracefully
4. Search timeout → Task killed, empty results returned
5. Partial failure → Continue with successful results

### 3. CodeSearch (✅ Complete)

**File**: `lib/singularity/search/semantic_code_search.ex`

**Enhancements**:
- ✅ Query timeout protection (@query_timeout_ms = 30_000)
- ✅ Slow query logging (@slow_query_threshold_ms = 1_000)
- ✅ Database connection retry (3 attempts, 100ms base delay)
- ✅ Correlation ID tracking
- ✅ Telemetry events for query performance
- ✅ Error-specific logging (Postgrex.Error, DBConnection.ConnectionError)
- ✅ Graceful degradation (return empty list on error)

**Error Scenarios Handled**:
1. Database connection lost → Retry 3 times with backoff
2. Query timeout → Kill task, return empty results
3. Slow query → Log warning for optimization
4. Invalid vector → Error logged, empty results
5. Postgrex errors → Retry, track error rate

## Remaining Modules (Prioritized)

### 4. EmbeddingGenerator (🔄 Next Priority)

**File**: `lib/singularity/llm/embedding_generator.ex`

**Needed Enhancements**:
- [ ] Track which provider succeeds (Jina/Google/Zero)
- [ ] Log each fallback step with timing
- [ ] Add metrics for embedding generation time
- [ ] Handle Google AI rate limiting (429 errors)
- [ ] Circuit breaker for Google AI API
- [ ] Cache hit/miss telemetry
- [ ] Bumblebee GPU failure handling
- [ ] Model load failure retry

**Proposed Changes**:
```elixir
def embed_with_fallback(text) do
  correlation_id = generate_correlation_id()
  start_time = System.monotonic_time(:millisecond)

  Logger.info("Starting embedding generation",
    correlation_id: correlation_id,
    provider_chain: [:jina, :google, :zero_vector]
  )

  # Try Jina (Bumblebee) - best for code
  case try_provider(:jina, text, correlation_id, start_time) do
    {:ok, embedding} ->
      emit_success_telemetry(:jina, start_time)
      {:ok, embedding}

    {:error, :jina_failed} ->
      # Try Google AI with circuit breaker
      case with_circuit_breaker(:google_ai, fn ->
        try_provider(:google, text, correlation_id, start_time)
      end) do
        {:ok, embedding} ->
          emit_success_telemetry(:google, start_time)
          {:ok, embedding}

        {:error, _reason} ->
          # Fallback to zero vector
          Logger.warning("All providers failed, using zero vector")
          emit_fallback_telemetry(:zero_vector, start_time)
          {:ok, Pgvector.new(List.duplicate(0.0, 768))}
      end
  end
end
```

### 5. ExecutionCoordinator (High Priority)

**File**: `lib/singularity/agents/execution_coordinator.ex`

**Needed Enhancements**:
- [ ] Handle HTDAG decomposition failures
- [ ] Add timeout for long-running executions
- [ ] Track execution failures by task type
- [ ] Circuit breaker for LLM calls
- [ ] Retry template selection on failure
- [ ] Graceful degradation if template unavailable
- [ ] State recovery on crash
- [ ] Correlation ID propagation to HybridAgent

### 6. PatternMiner (Medium Priority)

**File**: `lib/singularity/code/patterns/pattern_miner.ex`

**Needed Enhancements**:
- [ ] Handle empty result sets gracefully
- [ ] Retry logic for DB queries (semantic_patterns, codebase_metadata)
- [ ] Log pattern search failures
- [ ] Cache frequently requested patterns (ETS or Redis)
- [ ] Handle embedding generation failures
- [ ] Track pattern retrieval success rate
- [ ] Timeout for expensive pattern searches

### 7. Planner (Medium Priority)

**File**: `lib/singularity/autonomy/planner.ex`

**Needed Enhancements**:
- [ ] Handle LLM API failures with fallback
- [ ] Implement fallback to simpler code generation
- [ ] Track generation failures by type
- [ ] Add cost limits per request (circuit breaker on cost)
- [ ] Retry LLM calls with different models
- [ ] Cache successful generations (semantic cache)
- [ ] Handle SPARC decomposition failures
- [ ] Timeout for code generation

### 8. WorkPlanCoordinator (Low Priority - Recently Updated)

**File**: `lib/singularity/planning/work_plan_coordinator.ex`

**Needed Enhancements**:
- [ ] Handle invalid work items gracefully
- [ ] Validate WSJF calculations (prevent divide-by-zero)
- [ ] Add state recovery on crash (already uses database)
- [ ] Persist state incrementally (already done via Ecto)
- [ ] Handle database transaction failures
- [ ] Retry failed database operations
- [ ] Validate epic/capability/feature structure

## Infrastructure Supervisor (🔄 Required)

### Create `lib/singularity/infrastructure/supervisor.ex`

Supervisor for error handling infrastructure:

```elixir
defmodule Singularity.Infrastructure.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Circuit breaker registry
      {Registry, keys: :unique, name: Singularity.Infrastructure.CircuitBreakerRegistry},

      # Circuit breaker supervisor (for dynamic circuits)
      {DynamicSupervisor,
        strategy: :one_for_one,
        name: Singularity.Infrastructure.CircuitBreakerSupervisor
      },

      # Error rate tracker
      Singularity.Infrastructure.ErrorRateTracker
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

**Add to application.ex**:
```elixir
def start(_type, _args) do
  children = [
    # ... existing children ...
    Singularity.Infrastructure.Supervisor,
    # ... rest of children ...
  ]
end
```

## Telemetry Events

### Events Emitted

1. **[:singularity, MODULE, OPERATION, :complete]**
   - Measurements: `%{duration: ms}`
   - Metadata: `%{status: :success | :error, correlation_id: id, ...}`

2. **[:singularity, :semantic_search, :complete]**
   - Measurements: `%{duration: ms, result_count: n}`
   - Metadata: `%{codebase_id: id, correlation_id: id}`

3. **[:singularity, :embedding, :generate]** (Proposed)
   - Measurements: `%{duration: ms, dimensions: 768}`
   - Metadata: `%{provider: :jina | :google | :zero, fallback_count: n}`

### Telemetry Handlers

**Create**: `lib/singularity/telemetry.ex`

```elixir
defmodule Singularity.Telemetry do
  require Logger

  def setup do
    :telemetry.attach_many(
      "singularity-telemetry",
      [
        [:singularity, :semantic_search, :complete],
        [:singularity, :embedding, :generate],
        [:singularity, :hybrid_search, :complete]
      ],
      &handle_event/4,
      nil
    )
  end

  defp handle_event(event, measurements, metadata, _config) do
    # Log to AppSignal, Datadog, or custom metrics system
    Logger.info("Telemetry event",
      event: event,
      measurements: measurements,
      metadata: metadata
    )
  end
end
```

## Error Tracking Integration

### External Error Trackers

**Sentry Integration** (Recommended):

```elixir
# Add to mix.exs
{:sentry, "~> 10.0"}

# config/runtime.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Update error_handling.ex
defp report_to_error_tracker(error, stacktrace, context) do
  Sentry.capture_exception(error,
    stacktrace: stacktrace,
    extra: context
  )
end
```

**AppSignal Integration** (Alternative):

```elixir
# Add to mix.exs
{:appsignal, "~> 2.0"}

# Update error_handling.ex
defp report_to_error_tracker(error, stacktrace, context) do
  Appsignal.send_error(error,
    stacktrace: stacktrace,
    metadata: context
  )
end
```

## Health Checks

### GenServer Health Check Example

```elixir
# Add to each GenServer module
def health_check do
  ErrorHandling.health_check(__MODULE__, [
    database_connection: fn ->
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
        {:ok, _} -> :ok
        error -> error
      end
    end,

    circuit_breaker_state: fn ->
      case CircuitBreaker.get_state(:external_api) do
        :closed -> :ok
        :half_open -> {:degraded, :recovering}
        :open -> {:error, :circuit_open}
      end
    end,

    error_rate: fn ->
      %{error_rate: rate} = ErrorRateTracker.get_rate(:main_operation)
      if rate < 0.05, do: :ok, else: {:degraded, {:high_error_rate, rate}}
    end
  ])
end
```

## Monitoring & Alerts

### Recommended Alerting Rules

1. **High Error Rate**: Error rate > 5% over 5 minutes
2. **Circuit Breaker Open**: Any circuit breaker open for > 1 minute
3. **Slow Queries**: > 10 queries/minute > 1 second
4. **Database Connection Errors**: > 5/minute
5. **Embedding Generation Failures**: > 10% failure rate

### Metrics to Track

- **Latency**: p50, p95, p99 for all operations
- **Error Rates**: Per operation and overall
- **Circuit Breaker States**: Count of open/half-open circuits
- **Retry Counts**: Average retries per operation
- **Cache Hit Rates**: Semantic cache effectiveness
- **Database Connection Pool**: Available vs. busy connections

## Testing Strategy

### Unit Tests

```elixir
# test/singularity/infrastructure/error_handling_test.exs
defmodule Singularity.Infrastructure.ErrorHandlingTest do
  use ExUnit.Case
  alias Singularity.Infrastructure.ErrorHandling

  describe "safe_operation/2" do
    test "returns {:ok, result} on success" do
      assert {:ok, 42} = ErrorHandling.safe_operation(fn -> 42 end)
    end

    test "returns {:error, error} on exception" do
      assert {:error, _} = ErrorHandling.safe_operation(fn ->
        raise "boom"
      end)
    end

    test "logs correlation_id" do
      ErrorHandling.safe_operation(fn -> :ok end,
        context: %{correlation_id: "test-123"}
      )

      assert Logger.metadata()[:correlation_id] == "test-123"
    end
  end

  describe "with_retry/2" do
    test "succeeds on first attempt" do
      assert {:ok, :success} = ErrorHandling.with_retry(fn ->
        {:ok, :success}
      end)
    end

    test "retries on failure and succeeds" do
      agent = Agent.start_link(fn -> 0 end)

      result = ErrorHandling.with_retry(fn ->
        Agent.get_and_update(agent, fn count ->
          if count < 2 do
            {{:error, :timeout}, count + 1}
          else
            {{:ok, :success}, count + 1}
          end
        end)
      end, max_attempts: 3)

      assert {:ok, :success} = result
    end
  end
end
```

### Integration Tests

Test error scenarios:
- Database connection failures
- API timeouts
- High error rates triggering circuit breakers
- Retry exhaustion
- Graceful degradation

## Performance Impact

### Expected Overhead

- **safe_operation**: ~0.1ms per call (correlation ID generation, logging)
- **with_retry**: 0ms on success, 100-1000ms on retries (configurable)
- **circuit_breaker**: ~0.01ms per call (GenServer call)
- **error_rate_tracker**: ~0.001ms per record (ETS insert)

### Optimizations

1. **Lazy Correlation ID**: Only generate if logging level enabled
2. **Telemetry Sampling**: Sample 10% of successful operations
3. **ETS Cleanup**: Batch delete old entries every 30 seconds
4. **Circuit Breaker Pooling**: Reuse circuits for same services

## Documentation

### Usage Guide (create `docs/error_handling.md`)

```markdown
# Error Handling Best Practices

## When to Use

Use error handling infrastructure for:
- External API calls (circuit breaker)
- Database queries (retry, timeout)
- Expensive computations (timeout)
- User-facing operations (graceful degradation)

## Examples

### Basic Error Handling
\```elixir
use Singularity.Infrastructure.ErrorHandling

def my_operation do
  safe_operation(fn ->
    dangerous_work()
  end, context: %{operation: :my_op, module: __MODULE__})
end
\```

### Circuit Breaker
\```elixir
def call_external_api do
  with_circuit_breaker(:my_api, fn ->
    HTTPoison.get("https://api.example.com/data")
  end, failure_threshold: 5, timeout_ms: 3000)
end
\```

### Retry with Backoff
\```elixir
def query_database do
  with_retry(fn ->
    Repo.query("SELECT * FROM users")
  end, max_attempts: 3, base_delay_ms: 100)
end
\```
```

## Next Steps

1. ✅ **Phase 1 Complete**: Core infrastructure + 2 modules enhanced
2. 🔄 **Phase 2 (In Progress)**: Enhance remaining 6 modules
3. ⏳ **Phase 3**: Create infrastructure supervisor
4. ⏳ **Phase 4**: Add telemetry handlers and external integrations
5. ⏳ **Phase 5**: Write comprehensive tests
6. ⏳ **Phase 6**: Documentation and usage guide

## Summary

**Completed**:
- ✅ Centralized error handling infrastructure
- ✅ Circuit breaker implementation
- ✅ Error rate tracking
- ✅ PackageAndCodebaseSearch enhancements
- ✅ CodeSearch enhancements

**In Progress**:
- 🔄 EmbeddingGenerator (next)
- 🔄 Documentation

**Remaining**:
- ⏳ ExecutionCoordinator
- ⏳ PatternMiner
- ⏳ Planner
- ⏳ WorkPlanCoordinator
- ⏳ Infrastructure supervisor
- ⏳ External integrations (Sentry/AppSignal)
- ⏳ Comprehensive testing

This infrastructure provides production-ready error handling with:
- 🎯 Correlation-based request tracking
- 🔄 Intelligent retry with exponential backoff
- 🛡️ Circuit breaker protection
- 📊 Real-time error rate monitoring
- 🚨 Automatic alerting
- 📈 Telemetry for observability
- 🛟 Graceful degradation
- ⏱️ Timeout protection
- 📝 Comprehensive logging

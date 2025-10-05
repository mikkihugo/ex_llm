# Error Handling Guide for Singularity

## Overview

Singularity implements a comprehensive, production-ready error handling infrastructure that provides:

- **Structured Error Logging** with correlation IDs
- **Automatic Retry** with exponential backoff
- **Circuit Breaker** protection against cascading failures
- **Timeout Handling** for long-running operations
- **Error Rate Tracking** with automatic alerting
- **Telemetry Integration** for monitoring
- **Graceful Degradation** strategies

## Quick Start

### Basic Usage

```elixir
defmodule MyModule do
  use Singularity.Infrastructure.ErrorHandling

  def my_operation(data) do
    safe_operation(fn ->
      # Your potentially failing operation
      dangerous_work(data)
    end, context: %{
      operation: :my_operation,
      module: __MODULE__,
      user_id: data.user_id
    })
  end
end
```

### With Retry

```elixir
def query_database(query) do
  with_retry(fn ->
    Repo.query(query)
  end,
    max_attempts: 3,
    base_delay_ms: 100,
    retryable_errors: [Postgrex.Error, DBConnection.ConnectionError]
  )
end
```

### With Circuit Breaker

```elixir
def call_external_api(params) do
  with_circuit_breaker(:external_api, fn ->
    HTTPoison.post("https://api.example.com/endpoint", params)
  end,
    failure_threshold: 5,
    timeout_ms: 5_000,
    reset_timeout_ms: 60_000
  )
end
```

### With Timeout

```elixir
def expensive_computation(input) do
  with_timeout(fn ->
    compute_result(input)
  end, timeout_ms: 10_000)
end
```

## Core Concepts

### 1. Correlation IDs

Every operation gets a unique correlation ID for request tracing:

```elixir
correlation_id = generate_correlation_id()
Logger.metadata(correlation_id: correlation_id)
```

All logs and telemetry events will include this ID, making it easy to trace a request through the system.

### 2. Structured Logging

Errors are logged with rich context:

```elixir
Logger.error("Operation failed",
  correlation_id: correlation_id,
  operation: :search,
  module: __MODULE__,
  error: inspect(error),
  stacktrace: __STACKTRACE__,
  duration_ms: duration
)
```

### 3. Telemetry Events

Operations emit telemetry events for monitoring:

```elixir
:telemetry.execute(
  [:singularity, :search, :complete],
  %{duration: duration_ms},
  %{status: :success, correlation_id: correlation_id}
)
```

### 4. Error Rate Tracking

Automatically tracks error rates and alerts when thresholds are exceeded:

```elixir
ErrorRateTracker.record_error(:database_query, error)
ErrorRateTracker.get_rate(:database_query)
# => %{error_count: 5, total_count: 100, error_rate: 0.05}
```

### 5. Circuit Breaker States

Protects against cascading failures with three states:

- **Closed**: Normal operation, all requests pass through
- **Open**: Failure threshold exceeded, fast-fail all requests
- **Half-Open**: Testing if service recovered

```elixir
CircuitBreaker.get_state(:external_api)
# => :closed | :open | :half_open
```

## Integration Points

### Application Startup

The error handling infrastructure is automatically started via `Singularity.Infrastructure.Supervisor`:

```elixir
# In application.ex (already configured)
children = [
  Singularity.Infrastructure.Supervisor,  # Starts circuit breakers and error tracking
  # ... other children
]
```

### Telemetry Handlers

Telemetry events are automatically attached during startup:

```elixir
# In Singularity.Telemetry.init/1 (already configured)
attach_error_handling_events()
```

## Best Practices

### 1. Always Use Correlation IDs

```elixir
def my_function(params) do
  correlation_id = generate_correlation_id()

  Logger.metadata(correlation_id: correlation_id)
  Logger.info("Operation starting", params: params)

  # ... operation logic

  Logger.info("Operation complete")
end
```

### 2. Retry Transient Errors Only

```elixir
# Good - retries connection errors
with_retry(fn -> Repo.query(sql) end,
  retryable_errors: [Postgrex.Error, DBConnection.ConnectionError]
)

# Bad - retries validation errors (not transient)
with_retry(fn -> create_user(invalid_data) end)
```

### 3. Circuit Breakers for External Services

```elixir
# Good - protects against external API failures
with_circuit_breaker(:payment_gateway, fn ->
  PaymentGateway.charge(amount)
end)

# Bad - circuit breaker for local database (use retry instead)
with_circuit_breaker(:database, fn -> Repo.query(sql) end)
```

### 4. Graceful Degradation

```elixir
def search_with_fallback(query) do
  case search_packages(query) do
    {:ok, results} -> results
    {:error, _reason} ->
      Logger.warning("Package search failed, using cached results")
      get_cached_results(query)
  end
end
```

### 5. Log Context, Not Just Errors

```elixir
# Good - includes context
Logger.error("Failed to process payment",
  user_id: user.id,
  amount: payment.amount,
  error: inspect(error)
)

# Bad - just the error message
Logger.error("Error: #{inspect(error)}")
```

## Configuration

### Circuit Breaker Settings

```elixir
with_circuit_breaker(:my_service, fn ->
  call_service()
end,
  failure_threshold: 5,      # Open after 5 failures
  timeout_ms: 5_000,         # 5 second operation timeout
  reset_timeout_ms: 60_000   # Try to reset after 60 seconds
)
```

### Retry Settings

```elixir
with_retry(fn -> operation() end,
  max_attempts: 3,           # Try up to 3 times
  base_delay_ms: 100,        # Start with 100ms delay
  max_delay_ms: 10_000,      # Cap at 10 seconds
  exponential_base: 2,       # Double delay each time
  jitter: true,              # Add random jitter (±25%)
  retryable_errors: [:timeout, Postgrex.Error]
)
```

### Error Rate Thresholds

```elixir
# In error_rate_tracker.ex
@alert_threshold 0.05  # Alert at 5% error rate
@window_seconds 60     # Over 60 second window
```

## Monitoring & Alerting

### Metrics to Monitor

1. **Error Rates**:
   - `ErrorRateTracker.get_all_rates()`
   - Alert if any operation > 5% error rate

2. **Circuit Breaker States**:
   - `CircuitBreaker.get_state(circuit_name)`
   - Alert if circuit open for > 1 minute

3. **Slow Operations**:
   - Check telemetry events for `duration > threshold`
   - Alert if p99 latency exceeds SLA

4. **Retry Counts**:
   - Track average retries per operation
   - Alert if retries suddenly spike

### Example Monitoring Integration

```elixir
# With AppSignal
defp report_to_appsignal(event, measurements, metadata) do
  Appsignal.send_metric(
    "singularity.#{format_event_name(event)}",
    measurements.duration,
    tags: metadata
  )
end

# With Datadog (via Statix)
defp report_to_datadog(event, measurements, metadata) do
  Statix.histogram(
    "singularity.#{format_event_name(event)}.duration",
    measurements.duration,
    tags: metadata_to_tags(metadata)
  )
end
```

## Troubleshooting

### High Error Rates

1. Check error rate tracker:
   ```elixir
   ErrorRateTracker.get_rate(:problematic_operation)
   ```

2. Review logs for correlation IDs:
   ```bash
   grep "correlation_id: abc123" logs/singularity.log
   ```

3. Check circuit breaker states:
   ```elixir
   CircuitBreaker.get_stats(:external_service)
   ```

### Circuit Breaker Open

1. Check why it opened:
   ```elixir
   CircuitBreaker.get_stats(:service_name)
   # => %{failure_count: 5, failure_threshold: 5, last_failure_time: ...}
   ```

2. Manually reset if service recovered:
   ```elixir
   CircuitBreaker.reset(:service_name)
   ```

3. Investigate underlying service issues

### Slow Queries

1. Check telemetry events for slow operations
2. Review database query plans
3. Add indexes if needed
4. Consider caching frequently accessed data

## Testing

### Unit Tests

```elixir
defmodule MyModuleTest do
  use ExUnit.Case
  alias Singularity.Infrastructure.ErrorHandling

  test "handles errors gracefully" do
    result = ErrorHandling.safe_operation(fn ->
      raise "boom"
    end)

    assert {:error, _} = result
  end

  test "retries on transient errors" do
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
```

### Integration Tests

```elixir
test "circuit breaker opens after failures" do
  # Simulate 5 failures
  Enum.each(1..5, fn _ ->
    ErrorHandling.with_circuit_breaker(:test_service, fn ->
      raise "error"
    end)
  end)

  # Circuit should be open
  assert :open = CircuitBreaker.get_state(:test_service)

  # Further calls should fast-fail
  result = ErrorHandling.with_circuit_breaker(:test_service, fn ->
    :ok
  end)

  assert {:error, :circuit_open} = result
end
```

## Performance Considerations

### Overhead

- **safe_operation**: ~0.1ms (correlation ID + logging)
- **with_retry**: 0ms on success, 100-1000ms on retries
- **circuit_breaker**: ~0.01ms (GenServer call)
- **error_rate_tracker**: ~0.001ms (ETS insert)

### Optimizations

1. **Lazy Correlation IDs**: Only generate if needed
2. **Telemetry Sampling**: Sample 10% of successful operations
3. **ETS Cleanup**: Batch delete old entries every 30 seconds
4. **Circuit Pooling**: Reuse circuits for same services

## External Integrations

### Sentry

```elixir
# config/runtime.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: config_env()

# In error_handling.ex
defp report_to_error_tracker(error, stacktrace, context) do
  Sentry.capture_exception(error,
    stacktrace: stacktrace,
    extra: context
  )
end
```

### AppSignal

```elixir
# config/runtime.exs
config :appsignal,
  name: "Singularity",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY")

# In telemetry.ex
defp forward_to_appsignal(event, measurements, metadata) do
  Appsignal.send_metric(
    format_event_name(event),
    measurements.duration,
    tags: metadata
  )
end
```

## Examples from Codebase

### PackageAndCodebaseSearch

```elixir
def hybrid_search(query, opts \\ []) do
  correlation_id = generate_correlation_id()

  ErrorHandling.safe_operation(fn ->
    # Run searches in parallel with timeouts
    tasks = [
      Task.async(fn ->
        ErrorHandling.with_timeout(
          fn -> search_packages(query, ecosystem, limit, correlation_id) end,
          timeout_ms: @search_timeout_ms
        )
      end),
      Task.async(fn ->
        ErrorHandling.with_timeout(
          fn -> search_your_code(query, codebase_id, limit, correlation_id) end,
          timeout_ms: @search_timeout_ms
        )
      end)
    ]

    [packages_result, code_result] = Task.await_many(tasks, @search_timeout_ms + 1_000)

    # Graceful degradation - continue with partial results
    packages = case packages_result do
      {:ok, results} -> results
      {:error, _} -> []
    end

    your_code = case code_result do
      {:ok, results} -> results
      {:error, _} -> []
    end

    %{packages: packages, your_code: your_code}
  end, context: %{operation: :hybrid_search, module: __MODULE__})
end
```

### SemanticCodeSearch

```elixir
def semantic_search(repo, codebase_id, query_vector, limit \\ 10) do
  result = ErrorHandling.with_retry(fn ->
    ErrorHandling.with_timeout(fn ->
      Ecto.Adapters.SQL.query(repo, query, params)
    end, timeout_ms: @query_timeout_ms)
  end,
    max_attempts: 3,
    retryable_errors: [Postgrex.Error, DBConnection.ConnectionError]
  )

  case result do
    {:ok, results} -> results
    {:error, _reason} -> []  # Graceful degradation
  end
end
```

## Summary

The error handling infrastructure provides:

- ✅ Production-ready error handling
- ✅ Automatic retry with intelligent backoff
- ✅ Circuit breaker protection
- ✅ Comprehensive logging and tracing
- ✅ Real-time monitoring and alerting
- ✅ Graceful degradation strategies
- ✅ Easy integration with external services

Follow the patterns in this guide to ensure robust, observable, and maintainable code.

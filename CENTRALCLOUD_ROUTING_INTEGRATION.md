# CentralCloud Integration: ModelRouter Routing Events

## Overview

ExLLM's ModelRouter automatically publishes all routing decisions to PostgreSQL pgmq queue `model_routing_decisions`. CentralCloud consumes these events to build cross-instance intelligence about which models work best for different task complexity levels.

## Architecture

```
Singularity Instance 1          Singularity Instance 2          Singularity Instance N
    ↓                               ↓                                  ↓
ModelRouter.route_model()      ModelRouter.route_model()        ModelRouter.route_model()
    ↓                               ↓                                  ↓
Publish to pgmq                Publish to pgmq                  Publish to pgmq
    ↓                               ↓                                  ↓
PostgreSQL pgmq: model_routing_decisions queue
    ↓
CentralCloud RoutingConsumer
    ├─ Track usage per model/complexity
    ├─ Aggregate performance metrics
    ├─ Learn optimal complexity scores
    ├─ Update shared model rankings
    └─ Publish learnings back to all instances
```

## Event Schema

Each routing decision published to `model_routing_decisions` queue:

```json
{
  "timestamp": "2025-10-27T06:55:00Z",
  "instance_id": "singularity-1",
  "routing_decision": {
    "complexity": "complex",
    "selected_model": "gpt-4o",
    "selected_provider": "github_models",
    "complexity_score": 4.8,
    "outcome": "routed",
    "response_time_ms": null,
    "capabilities_required": [],
    "prefer": null,
    "user_model_request": null
  }
}
```

### Event Fields

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO8601 | When routing decision was made |
| `instance_id` | string | Which Singularity instance made decision (from INSTANCE_ID env var) |
| `complexity` | string | Task complexity: "simple", "medium", "complex" |
| `selected_model` | string | Model name selected (e.g., "gpt-4o") |
| `selected_provider` | string | Provider name (e.g., "github_models") |
| `complexity_score` | float | Score (0.0-5.0) used for selection |
| `outcome` | string | Status: "routed" (initial), "success", "failure" |
| `response_time_ms` | number? | Response time if reported |
| `capabilities_required` | array | Filters applied: ["vision", "function_calling"] |
| `prefer` | string? | Preference: "speed" or "cost" |
| `user_model_request` | string? | If user explicitly requested a model |

## CentralCloud Consumer Implementation

### 1. Create RoutingEventConsumer GenServer

```elixir
defmodule CentralCloud.ModelLearning.RoutingEventConsumer do
  @moduledoc """
  Consumes routing decisions from Singularity instances via pgmq.
  Aggregates usage and learns optimal model rankings.
  """

  use GenServer
  require Logger

  @queue_name "model_routing_decisions"
  @poll_interval_ms 5000  # Check every 5 seconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Ensure queue exists
    Singularity.Workflow.Notifications.create_queue(@queue_name)

    # Start polling
    schedule_poll()

    {:ok, %{processed_count: 0}}
  end

  def handle_info(:poll, state) do
    case Singularity.Workflow.Notifications.receive_message(@queue_name) do
      {:ok, {msg_id, event}} ->
        process_routing_event(event)
        # Mark as processed
        Singularity.Workflow.Notifications.delete_message(@queue_name, msg_id)
        schedule_poll()
        {:noreply, %{state | processed_count: state.processed_count + 1}}

      :empty ->
        schedule_poll()
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to receive routing event: #{inspect(reason)}")
        schedule_poll()
        {:noreply, state}
    end
  end

  defp process_routing_event(event) do
    %{
      "timestamp" => timestamp,
      "instance_id" => instance_id,
      "routing_decision" => decision
    } = event

    # Record the routing event
    CentralCloud.ModelLearning.RoutingRecord.create(%{
      timestamp: timestamp,
      instance_id: instance_id,
      complexity: decision["complexity"],
      model: decision["selected_model"],
      provider: decision["selected_provider"],
      score: decision["complexity_score"],
      outcome: decision["outcome"],
      response_time_ms: decision["response_time_ms"],
      capabilities_required: decision["capabilities_required"],
      preference: decision["prefer"]
    })

    # Update aggregated metrics
    update_model_metrics(decision)
  end

  defp update_model_metrics(decision) do
    model = decision["selected_model"]
    complexity = decision["complexity"]

    # Update usage counter
    CentralCloud.ModelLearning.ModelMetrics.increment_usage(model, complexity)

    # Update success rate if available
    if decision["outcome"] == "success" do
      CentralCloud.ModelLearning.ModelMetrics.increment_success(model, complexity)
    end

    # Track response time
    if decision["response_time_ms"] do
      CentralCloud.ModelLearning.ModelMetrics.record_response_time(
        model,
        complexity,
        decision["response_time_ms"]
      )
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end
end
```

### 2. Track Model Performance

```elixir
defmodule CentralCloud.ModelLearning.ModelMetrics do
  @moduledoc """
  Aggregates model performance metrics from routing events.
  """

  require Logger
  alias CentralCloud.Repo

  def increment_usage(model, complexity) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET usage_count = usage_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model, complexity])
  end

  def increment_success(model, complexity) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET success_count = success_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model, complexity])
  end

  def record_response_time(model, complexity, time_ms) do
    Repo.query("""
      UPDATE model_routing_metrics
      SET response_times = array_append(response_times, $3),
          avg_response_time = (
            COALESCE(avg_response_time, 0) * response_time_count + $3
          ) / (response_time_count + 1),
          response_time_count = response_time_count + 1,
          updated_at = NOW()
      WHERE model_name = $1 AND complexity_level = $2
    """, [model, complexity, time_ms])
  end

  def get_success_rate(model, complexity) do
    Repo.query("""
      SELECT
        CASE
          WHEN usage_count = 0 THEN 0
          ELSE success_count::float / usage_count
        END as success_rate
      FROM model_routing_metrics
      WHERE model_name = $1 AND complexity_level = $2
    """, [model, complexity])
  end
end
```

### 3. Learn & Update Complexity Scores

```elixir
defmodule CentralCloud.ModelLearning.ComplexityScoreLearner do
  @moduledoc """
  Learns optimal complexity scores from real-world routing outcomes.
  """

  require Logger

  @min_samples_for_learning 100  # Need at least 100 uses to learn
  @success_threshold 0.95        # 95% success rate to boost score
  @slowness_threshold 2000       # Response time > 2 seconds = slow

  def learn_from_metrics do
    # Get all models with sufficient usage
    metrics = fetch_high_usage_metrics()

    Enum.each(metrics, fn metric ->
      optimize_model_scores(metric)
    end)
  end

  defp optimize_model_scores(%{
    model: model,
    complexity: complexity,
    usage_count: usage_count,
    success_rate: success_rate,
    avg_response_time: avg_time
  } = metric) do
    if usage_count < @min_samples_for_learning do
      Logger.debug("Insufficient data for #{model} at #{complexity} (#{usage_count} samples)")
      return
    end

    current_score = get_current_complexity_score(model, complexity)
    new_score = calculate_optimal_score(current_score, metric)

    if new_score != current_score do
      Logger.info(
        "Updating #{model} complexity #{complexity}: #{current_score} → #{new_score} " <>
        "(success: #{success_rate}, time: #{avg_time}ms)"
      )

      update_complexity_score(model, complexity, new_score)

      # Publish learning back to instances
      publish_learning_event(model, complexity, current_score, new_score)
    end
  end

  defp calculate_optimal_score(current_score, metric) do
    success_boost = if metric.success_rate > @success_threshold do
      0.2  # Boost by 0.2 if very successful
    else
      -0.2  # Reduce by 0.2 if struggling
    end

    speed_penalty = if metric.avg_response_time > @slowness_threshold do
      -0.1  # Penalty for slow responses
    else
      0.1   # Boost for fast responses
    end

    # Clamp to [0.0, 5.0]
    (current_score + success_boost + speed_penalty)
    |> max(0.0)
    |> min(5.0)
  end

  defp update_complexity_score(model, complexity, new_score) do
    # Update in YAML config via git
    # Or push update to ModelCatalog cache
    CentralCloud.ModelLearning.ModelCatalogUpdater.update_score(
      model,
      complexity,
      new_score
    )
  end

  defp publish_learning_event(model, complexity, old_score, new_score) do
    # Publish back to instances so they can update local cache
    event = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      event_type: "model_score_update",
      model: model,
      complexity: complexity,
      old_score: old_score,
      new_score: new_score,
      reason: "Learned from real-world outcomes"
    }

    # Publish to a broadcast queue that all instances listen to
    Singularity.Workflow.Notifications.send("model_score_updates", event)
  end
end
```

### 4. Database Schema for Metrics

```sql
-- Store routing events for audit trail
CREATE TABLE IF NOT EXISTS routing_records (
  id BIGSERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ NOT NULL,
  instance_id VARCHAR NOT NULL,
  complexity VARCHAR NOT NULL,
  model VARCHAR NOT NULL,
  provider VARCHAR NOT NULL,
  score FLOAT NOT NULL,
  outcome VARCHAR NOT NULL,
  response_time_ms INTEGER,
  capabilities_required TEXT[],
  preference VARCHAR,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Aggregate metrics for learning
CREATE TABLE IF NOT EXISTS model_routing_metrics (
  id BIGSERIAL PRIMARY KEY,
  model_name VARCHAR NOT NULL,
  complexity_level VARCHAR NOT NULL,
  usage_count BIGINT DEFAULT 0,
  success_count BIGINT DEFAULT 0,
  response_times INTEGER[] DEFAULT '{}',
  avg_response_time FLOAT,
  response_time_count BIGINT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(model_name, complexity_level)
);

-- Index for quick queries
CREATE INDEX idx_routing_records_model_complexity
  ON routing_records(model, complexity);

CREATE INDEX idx_routing_records_timestamp
  ON routing_records(timestamp DESC);
```

## Singularity Instance Updates

### 1. Enable Routing Event Publishing

ModelRouter automatically publishes all routing decisions. No additional configuration needed - just ensure:

```elixir
# In your Singularity config
config :ex_llm, pgmq_enabled: true

# Set instance ID for tracking
System.put_env("INSTANCE_ID", "singularity-#{node()}")
```

### 2. Subscribe to Model Score Updates

```elixir
defmodule Singularity.ModelRouter.ScoreUpdater do
  @moduledoc """
  Subscribes to model score updates from CentralCloud.
  Updates local ModelCatalog with learned scores.
  """

  use GenServer
  require Logger

  @queue_name "model_score_updates"
  @poll_interval_ms 10_000  # Check every 10 seconds

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Create queue if needed
    Singularity.Workflow.Notifications.create_queue(@queue_name)
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    case Singularity.Workflow.Notifications.receive_message(@queue_name) do
      {:ok, {_msg_id, event}} ->
        apply_score_update(event)
        schedule_poll()
        {:noreply, state}

      :empty ->
        schedule_poll()
        {:noreply, state}

      {:error, _reason} ->
        schedule_poll()
        {:noreply, state}
    end
  end

  defp apply_score_update(%{
    "model" => model,
    "complexity" => complexity,
    "new_score" => new_score
  }) do
    Logger.info("Applying learned score: #{model} (#{complexity}) = #{new_score}")

    # Update local ModelCatalog cache
    ExLLM.Core.ModelCatalog.update_complexity_score(model, complexity, new_score)
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end
end
```

## Monitoring

### CentralCloud Dashboard Metrics

```sql
-- Models used per instance
SELECT instance_id, model, COUNT(*) as usage_count
FROM routing_records
WHERE timestamp > NOW() - INTERVAL '1 day'
GROUP BY instance_id, model
ORDER BY usage_count DESC;

-- Success rates
SELECT model, complexity_level,
  ROUND(success_count::float / NULLIF(usage_count, 0) * 100, 2) as success_rate,
  usage_count
FROM model_routing_metrics
ORDER BY success_rate DESC;

-- Response time trends
SELECT model, complexity_level,
  ROUND(AVG(avg_response_time)::numeric, 0) as avg_ms,
  MAX(avg_response_time) as max_ms
FROM model_routing_metrics
WHERE avg_response_time IS NOT NULL
GROUP BY model, complexity_level
ORDER BY avg_ms DESC;
```

## Benefits

✅ **Cross-Instance Learning**: All instances benefit from aggregated usage data
✅ **Automatic Optimization**: Complexity scores improve over time
✅ **Performance Tracking**: Detect slow/unreliable models
✅ **Cost Optimization**: Learn which models work best vs. cost trade-off
✅ **Failure Detection**: Identify providers/models with high failure rates
✅ **Distributed Intelligence**: Centralized learning with distributed execution

## Configuration

Set in environment for custom instance tracking:

```bash
# Which instance is running this ModelRouter
INSTANCE_ID=singularity-us-west-1

# Enable pgmq integration (auto-enabled if pgmq available)
EX_LLM_PGMQ_ENABLED=true
```

## Migration Path

1. **Phase 1**: ModelRouter publishes events (✅ done)
2. **Phase 2**: CentralCloud consumes events and tracks metrics
3. **Phase 3**: Auto-learn and update complexity scores
4. **Phase 4**: Multi-instance optimization using consensus
5. **Phase 5**: Predictive routing based on learned patterns

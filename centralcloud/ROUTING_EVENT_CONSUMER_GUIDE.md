# CentralCloud Routing Event Consumer Guide

## Overview

The CentralCloud Routing Event Consumer is the central learning engine that aggregates routing decisions from all Singularity instances and learns optimal model complexity scores.

## Architecture

```
Singularity Instances (Multiple)
    ↓ (publish routing decisions)
PostgreSQL pgmq: model_routing_decisions queue
    ↓
RoutingEventConsumer (polls every 5 seconds)
    ├─ Create audit record (routing_records table)
    ├─ Update metrics (model_routing_metrics table)
    └─ Analyze for anomalies
    ↓
ComplexityScoreLearner (runs every 60 seconds)
    ├─ Analyze high-usage models
    ├─ Calculate optimal scores
    └─ Publish updates to instances
    ↓
ModelScoreUpdater
    └─ Publish to model_score_updates queue
    ↓
Singularity Instances (receive updates)
    └─ Update local ModelCatalog cache
```

## Components

### 1. RoutingEventConsumer

**File**: `lib/central_cloud/model_learning/routing_event_consumer.ex`

**Responsibilities**:
- Polls `model_routing_decisions` queue from pgmq
- Processes up to 1 message per poll (configurable)
- Creates audit records in `routing_records` table
- Updates aggregated metrics in `model_routing_metrics` table
- Triggers anomaly detection

**Configuration**:
```elixir
@queue_name "model_routing_decisions"
@poll_interval_ms 5000  # Check every 5 seconds
@max_consecutive_errors 5
```

**State**:
- `processed_count` - Total events processed
- `error_count` - Consecutive errors (resets on success)
- `last_error` - Last error encountered
- `started_at` - When consumer started

### 2. RoutingRecord Schema

**File**: `lib/central_cloud/model_learning/routing_record.ex`

Stores every routing decision for audit trail and historical analysis.

**Attributes**:
- `timestamp` - When decision was made
- `instance_id` - Which instance made the decision
- `complexity` - Task complexity ("simple", "medium", "complex")
- `model` - Model name selected
- `provider` - Provider name
- `score` - Complexity score used for selection
- `outcome` - Status ("routed", "success", "failure")
- `response_time_ms` - Response time in ms (optional)
- `capabilities_required` - Filters applied
- `preference` - User preference ("speed" or "cost")

**Indexes**:
- `[model, complexity]` - For learning queries
- `[timestamp, instance_id]` - For time-series analysis
- `[outcome]` - For failure analysis

### 3. ModelMetrics Schema

**File**: `lib/central_cloud/model_learning/model_metrics.ex`

Aggregated performance metrics per model-complexity combo.

**Attributes**:
- `model_name` - Model identifier
- `complexity_level` - Task complexity
- `usage_count` - How many times routed
- `success_count` - How many succeeded
- `response_times` - Array of all response times
- `avg_response_time` - Running average
- `response_time_count` - Number of samples

**Unique Constraint**: One row per (model_name, complexity_level)

**Methods**:
```elixir
ModelMetrics.update_or_create(model, complexity)
ModelMetrics.increment_usage(model, complexity)
ModelMetrics.increment_success(model, complexity)
ModelMetrics.record_response_time(model, complexity, ms)
ModelMetrics.get_success_rate(model, complexity)
ModelMetrics.get_by_complexity(complexity)
ModelMetrics.get_high_usage_models(min_samples)
```

### 4. ComplexityScoreLearner

**File**: `lib/central_cloud/model_learning/complexity_score_learner.ex`

Learns optimal complexity scores from real outcomes.

**Behavior**:
- Runs every 60 seconds
- Analyzes models with >= 100 uses
- Calculates success rate and response time
- Computes score adjustments:
  - Success > 95% → +0.2 boost
  - Success < 85% → -0.2 reduction
  - Response time > 2s → -0.1 penalty
  - Response time < 500ms → +0.1 boost
- Clamps to [0.0, 5.0]
- Only publishes if change > 0.1

**Example Output**:
```
Updating gpt-4o complexity complex: 4.8 → 4.9
(success: 0.98, time: 450ms)
```

### 5. ModelScoreUpdater

**File**: `lib/central_cloud/model_learning/model_score_updater.ex`

Publishes learned scores back to instances.

**Event Format**:
```json
{
  "timestamp": "2025-10-27T07:00:00Z",
  "model": "gpt-4o",
  "complexity": "complex",
  "old_score": 4.8,
  "new_score": 4.9,
  "reason": "Learned from 250 real uses",
  "confidence": 0.98,
  "based_on_samples": 250
}
```

**Queue**: Publishes to `model_score_updates` queue

### 6. ModelPerformanceAnalyzer

**File**: `lib/central_cloud/model_learning/model_performance_analyzer.ex`

Detects anomalies:
- Low success rates (< 85%)
- Slow responses (> 5 seconds)
- Unusual patterns

Publishes warnings for investigation.

### 7. Monitoring Queries

**File**: `lib/central_cloud/model_learning/monitoring.ex`

Dashboard queries for observability:

```elixir
# View usage by instance
Monitoring.models_by_instance()

# Success rates per model
Monitoring.success_rates_by_model_complexity()

# Response time statistics
Monitoring.response_time_stats()

# Top performing models
Monitoring.top_performing_models(10)

# Problem models
Monitoring.bottom_performing_models(10)

# System health
Monitoring.health_summary()
```

## Database Setup

### Migration

**File**: `priv/repo/migrations/001_create_model_learning_tables.exs`

Creates:
- `routing_records` table (audit log)
- `model_routing_metrics` table (aggregated metrics)
- Proper indexes for performance

### Running Migrations

```bash
cd centralcloud
mix ecto.migrate
```

## Supervision

**File**: `lib/central_cloud/model_learning/supervisor.ex`

Starts:
1. RoutingEventConsumer
2. ComplexityScoreLearner (with 60s interval)
3. ModelScoreUpdater

Add to CentralCloud application supervisor:
```elixir
children = [
  CentralCloud.Repo,
  # ... other services
  CentralCloud.ModelLearning.Supervisor
]
```

## Singularity Integration

### 1. Receiving Score Updates

Singularity should implement a model score subscriber in its application:

```elixir
# lib/singularity/model_learning/score_update_subscriber.ex
defmodule Singularity.ModelLearning.ScoreUpdateSubscriber do
  use GenServer
  require Logger
  alias Singularity.Database.MessageQueue
  alias ExLLM.Core.ModelCatalog

  @queue_name "model_score_updates"
  @poll_interval_ms 10_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    MessageQueue.create_queue(@queue_name)
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    case MessageQueue.receive_message(@queue_name) do
      {:ok, {msg_id, event}} ->
        apply_score_update(event)
        MessageQueue.delete_message(@queue_name, msg_id)
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
    "new_score" => new_score,
    "based_on_samples" => samples
  }) do
    Logger.info(
      "Applying learned score: #{model} (#{complexity}) = #{new_score} " <>
      "(from #{samples} samples)"
    )

    # Update local cache
    ModelCatalog.update_complexity_score(model, String.to_atom(complexity), new_score)

    # Optional: Write to YAML for persistence
    # UpdateModelYaml.update_score(model, complexity, new_score)
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end
end
```

### 2. Add to Singularity Supervisor

```elixir
# singularity/lib/singularity/application.ex
children = [
  # ... existing services
  Singularity.ModelLearning.ScoreUpdateSubscriber
]
```

## Monitoring Dashboard Queries

### View All Models and Success Rates

```sql
SELECT
  model_name,
  complexity_level,
  usage_count,
  ROUND(
    success_count::float / NULLIF(usage_count, 0) * 100, 2
  ) as success_rate,
  ROUND(avg_response_time::numeric, 0) as avg_ms
FROM model_routing_metrics
ORDER BY complexity_level, success_rate DESC;
```

### Models Used Per Instance (Last 24h)

```sql
SELECT
  instance_id,
  model,
  COUNT(*) as usage_count,
  COUNT(CASE WHEN outcome = 'success' THEN 1 END) as success_count
FROM routing_records
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY instance_id, model
ORDER BY instance_id, usage_count DESC;
```

### Recent Learning Updates

```sql
SELECT
  model_name,
  complexity_level,
  usage_count,
  ROUND(
    success_count::float / NULLIF(usage_count, 0) * 100, 2
  ) as success_rate,
  updated_at
FROM model_routing_metrics
ORDER BY updated_at DESC
LIMIT 20;
```

## Performance Considerations

### Queue Processing

- Polls every 5 seconds (configurable)
- Processes one message per poll
- Can increase throughput by batching more messages

### Learning Frequency

- Runs every 60 seconds (configurable)
- Only updates scores if change > 0.1
- Reduces noise from random variations

### Storage

- `routing_records` grows unbounded (audit trail)
- Consider archiving after 30-90 days
- `model_routing_metrics` stays small (one row per model-complexity)

### Scaling

For high-volume instance environments:

1. **Batch Processing**: Change RoutingEventConsumer to process multiple messages
2. **Sharding**: Shard metrics by model name for parallel processing
3. **Archiving**: Move old routing_records to cold storage
4. **Aggregation**: Pre-compute hourly summaries to reduce query load

## Troubleshooting

### Consumer Not Processing Events

1. Check if queue exists:
```sql
SELECT * FROM pgmq.q;
```

2. Check for stuck messages:
```sql
SELECT * FROM pgmq.model_routing_decisions_queue
WHERE vt < NOW();
```

3. Clear poison pill messages:
```sql
DELETE FROM pgmq.model_routing_decisions_queue
WHERE body LIKE '%error%';
```

### Score Updates Not Reaching Instances

1. Check model_score_updates queue:
```sql
SELECT msg_id, body FROM pgmq.read('model_score_updates', limit := 5);
```

2. Verify Singularity subscriber is running
3. Check logs for errors in ScoreUpdateSubscriber

### Learning Not Improving Scores

1. Check if models have > 100 uses:
```sql
SELECT model_name, complexity_level, usage_count
FROM model_routing_metrics
WHERE usage_count < 100
ORDER BY usage_count DESC;
```

2. Check success rates:
```sql
SELECT model_name, complexity_level,
  success_count, usage_count,
  ROUND(success_count::float / usage_count * 100, 2) as success_rate
FROM model_routing_metrics
WHERE usage_count > 50
ORDER BY success_rate;
```

## Next Steps

1. ✅ Deploy CentralCloud consumer
2. Deploy Singularity score update subscriber
3. Monitor dashboard queries for patterns
4. Adjust learning parameters if needed
5. Archive old routing_records periodically
6. Consider adding score persistence to YAML configs

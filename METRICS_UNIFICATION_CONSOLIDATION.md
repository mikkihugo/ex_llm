# Metrics Unification - Consolidation Roadmap

**Phase**: 4 (Days 13-15)
**Approach**: Unified centralized service (not orchestrator pattern)
**Architecture**: Collector → Aggregator → Query API

## Module Naming Convention

Following self-documenting names pattern: `<What><WhatItDoes>` or `<What><How>`

**Proposed Modules**:
```
Singularity.Metrics.EventCollector      # What: Metrics, What it does: Collect events
Singularity.Metrics.EventAggregator     # What: Metrics, What it does: Aggregate events
Singularity.Metrics.Query               # What: Metrics, What it does: Query
Singularity.Metrics.Event               # Schema: What it is: An event
Singularity.Metrics.AggregatedData      # Schema: What it is: Aggregated data
Singularity.Metrics.Supervisor          # Manages aggregator job
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Metrics Unification Service                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  INPUT LAYER (Recording)                                        │
│  ├── Telemetry.execute() events → EventCollector.from_telemetry │
│  ├── RateLimiter costs → EventCollector.record_cost_spent       │
│  ├── Agent execution → EventCollector.record_agent_metrics      │
│  └── Tool execution → EventCollector.record_tool_metrics        │
│                      ↓                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ metrics_events TABLE (Raw measurements)                 │   │
│  │ - event_name, measurement, unit, tags, recorded_at     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                      ↓                                           │
│  AGGREGATION LAYER (Processing)                                │
│  ├── EventAggregator.aggregate_by_period(:hour, time_range)   │
│  └── EventAggregator.aggregate_by_period(:day, time_range)    │
│                      ↓                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ metrics_aggregated TABLE (Time-series rollups)          │   │
│  │ - event_name, period, count, sum, avg, min, max, ...   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                      ↓                                           │
│  QUERY LAYER (Consumption)                                     │
│  ├── Query.get_agent_metrics_over_time()                      │
│  ├── Query.get_operation_costs_summary()                      │
│  ├── Query.get_health_metrics_current()                       │
│  ├── Query.find_metrics_by_pattern() (pgvector)              │
│  └── Query.get_learning_insights()                            │
│                      ↓                                           │
│  OUTPUT USAGE                                                   │
│  ├── FeedbackAnalyzer reads via Query                         │
│  ├── TemplatePerformanceTracker reads via Query              │
│  ├── Health systems read via Query                           │
│  └── Dashboards/Monitoring read via Query                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Module Specifications

### 1. Metrics.EventCollector (Recording Layer)

**File**: `singularity/lib/singularity/metrics/event_collector.ex`

**Responsibility**: Capture measurements from various sources and store in metrics_events

**Self-Documenting API**:
```elixir
defmodule Singularity.Metrics.EventCollector do
  # Record raw measurement event
  def record_measurement(event_name :: String.t, measurement :: number, unit :: String.t, tags :: map)
    :: {:ok, Event.t} | {:error, term}

  # Record cost-specific measurement (convenience)
  def record_cost_spent(operation :: atom, cost_usd :: float, tags :: map)
    :: {:ok, Event.t} | {:error, term}

  # Record latency-specific measurement (convenience)
  def record_latency_ms(operation :: atom, elapsed_ms :: integer, tags :: map)
    :: {:ok, Event.t} | {:error, term}

  # Record agent execution metrics (convenience)
  def record_agent_success(agent_id :: String.t, successful :: boolean, latency_ms :: integer)
    :: {:ok, Event.t} | {:error, term}

  # Record search metrics (convenience)
  def record_search_completed(query :: String.t, results_count :: integer, elapsed_ms :: integer)
    :: {:ok, Event.t} | {:error, term}

  # Capture Telemetry event (handler)
  def handle_telemetry_event(event_name, measurements, metadata)
    :: :ok | {:error, term}
end
```

**Implementation Notes**:
- Async writes via Task to avoid blocking callers
- Batch inserts for high-volume metrics
- Validates event_name, measurement type, unit
- Enriches tags with automatic context (timestamp, node, environment)

### 2. Metrics.EventAggregator (Processing Layer)

**File**: `singurilor/lib/singularity/metrics/event_aggregator.ex`

**Responsibility**: Summarize raw events into time-bucketed statistics

**Self-Documenting API**:
```elixir
defmodule Singularity.Metrics.EventAggregator do
  # Aggregate all events within time bucket
  def aggregate_by_period(period :: :hour | :day, time_range :: {DateTime.t, DateTime.t})
    :: {:ok, [AggregatedData.t]} | {:error, term}

  # Aggregate specific event type
  def aggregate_events_by_name(event_name :: String.t, period :: :hour | :day, time_range :: {DateTime.t, DateTime.t})
    :: {:ok, [AggregatedData.t]} | {:error, term}

  # Aggregate events with specific tag filter
  def aggregate_events_with_tags(tag_filters :: map, period :: :hour | :day, time_range :: {DateTime.t, DateTime.t})
    :: {:ok, [AggregatedData.t]} | {:error, term}

  # Calculate statistics from raw measurements
  def calculate_statistics(measurements :: [float])
    :: %{count: integer, sum: float, avg: float, min: float, max: float, stddev: float}
end
```

**Implementation Notes**:
- Reads from metrics_events (raw)
- Calculates: count, sum, avg, min, max, stddev per event per period
- Writes to metrics_aggregated for persistence and fast queries
- Idempotent - can re-run without creating duplicates
- Oban job runs hourly to aggregate past hour

### 3. Metrics.Query (Query Layer)

**File**: `singularity/lib/singularity/metrics/query.ex`

**Responsibility**: Expose unified API for querying metrics

**Self-Documenting API**:
```elixir
defmodule Singularity.Metrics.Query do
  # Get all metrics for specific agent over time
  def get_agent_metrics_over_time(agent_id :: String.t, time_range :: {DateTime.t, DateTime.t})
    :: {:ok, %{success_rate: float, avg_latency_ms: float, total_cost_usd: float, request_count: integer}} | {:error, term}

  # Get cost breakdown by operation
  def get_operation_costs_summary(time_range :: {DateTime.t, DateTime.t})
    :: {:ok, %{operations: [%{operation: atom, total_cost_usd: float, request_count: integer}]}} | {:error, term}

  # Get current system health metrics
  def get_health_metrics_current()
    :: {:ok, %{memory_usage_pct: float, queue_depth: integer, error_rate: float}} | {:error, term}

  # Get metrics matching search pattern (pgvector)
  def find_metrics_by_pattern(search_pattern :: String.t, limit :: integer)
    :: {:ok, [%{event_name: String.t, relevance: float, recent_values: [float]}]} | {:error, term}

  # Get insights for learning system
  def get_learning_insights(operation :: atom)
    :: {:ok, %{success_rate: float, avg_latency_ms: float, trend: :improving | :stable | :degrading}} | {:error, term}

  # Get metrics for specific time period and event
  def get_metrics_for_event(event_name :: String.t, period :: :hour | :day, time_range :: {DateTime.t, DateTime.t})
    :: {:ok, [AggregatedData.t]} | {:error, term}
end
```

**Implementation Notes**:
- Primary read interface for all metrics consumers
- Caches results in-memory (ETS) with TTL
- Supports pgvector semantic search via embedding
- Returns pre-computed summaries, not raw data

### 4. Metrics.Event (Schema)

**File**: `singularity/lib/singularity/metrics/event.ex`

**Responsibility**: Ecto schema for metrics_events table

```elixir
defmodule Singularity.Metrics.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "metrics_events" do
    field :event_name, :string        # "agent.success", "llm.cost", "search.latency"
    field :measurement, :float        # The actual value
    field :unit, :string              # "count", "ms", "usd", "%", etc.
    field :tags, :map                 # {agent_id, model, operation, environment, ...}
    field :recorded_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :measurement, :unit, :tags, :recorded_at])
    |> validate_required([:event_name, :measurement, :unit, :recorded_at])
    |> validate_measurement_type(:measurement)
  end

  defp validate_measurement_type(changeset, field) do
    # Ensure measurement is valid number
    validate_change(changeset, field, fn ^field, value ->
      if is_number(value) and not is_nan(value) and not is_infinite(value) do
        []
      else
        [{field, "must be a valid number"}]
      end
    end)
  end
end
```

### 5. Metrics.AggregatedData (Schema)

**File**: `singularity/lib/singularity/metrics/aggregated_data.ex`

**Responsibility**: Ecto schema for metrics_aggregated table

```elixir
defmodule Singularity.Metrics.AggregatedData do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "metrics_aggregated" do
    field :event_name, :string        # "agent.success", "llm.cost", etc.
    field :period, :string            # "hour", "day"
    field :period_start, :utc_datetime_usec

    # Statistics over period
    field :count, :integer
    field :sum, :float
    field :avg, :float
    field :min, :float
    field :max, :float
    field :stddev, :float

    field :tags, :map                 # Tag filters used for this aggregation

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(data, attrs) do
    data
    |> cast(attrs, [:event_name, :period, :period_start, :count, :sum, :avg, :min, :max, :stddev, :tags])
    |> validate_required([:event_name, :period, :period_start, :count])
    |> unique_constraint(:event_name_period_start_tags, name: "metrics_aggregated_unique_idx")
  end
end
```

### 6. Metrics.Supervisor (OTP Supervisor)

**File**: `singularity/lib/singularity/metrics/supervisor.ex`

**Responsibility**: Manage metric aggregation job

```elixir
defmodule Singularity.Metrics.Supervisor do
  use Supervisor
  require Logger

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting Metrics Supervisor...")

    children = [
      # GenServer for caching query results
      {Singularity.Metrics.QueryCache, []},
      # Oban job for hourly aggregation
      Singularity.Metrics.AggregationJob
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### 7. Metrics.AggregationJob (Oban Job)

**File**: `singularity/lib/singularity/metrics/aggregation_job.ex`

**Responsibility**: Periodic aggregation of raw events

```elixir
defmodule Singularity.Metrics.AggregationJob do
  use Oban.Worker, queue: :metrics, max_attempts: 2

  @impl Oban.Worker
  def perform(_job) do
    # Calculate one hour ago
    now = DateTime.utc_now()
    one_hour_ago = DateTime.add(now, -3600, :second)

    case Metrics.EventAggregator.aggregate_by_period(:hour, {one_hour_ago, now}) do
      {:ok, _results} ->
        Logger.info("Aggregated metrics for past hour")
        :ok

      {:error, reason} ->
        Logger.error("Failed to aggregate metrics", reason: inspect(reason))
        {:error, reason}
    end
  end

  def schedule_hourly do
    # Schedule via Oban
    __MODULE__.new() |> Oban.insert()
  end
end
```

## Database Migrations

### Migration 1: Create metrics_events Table

**File**: `singularity/priv/repo/migrations/20251024060000_create_metrics_events.exs`

```elixir
defmodule Singularity.Repo.Migrations.CreateMetricsEvents do
  use Ecto.Migration

  def change do
    create table(:metrics_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :measurement, :float, null: false
      add :unit, :string, null: false
      add :tags, :jsonb, null: false, default: "{}"
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:metrics_events, [:event_name, :recorded_at])
    create index(:metrics_events, [:recorded_at])
    create index(:metrics_events, ["tags->>'agent_id'"])
    create index(:metrics_events, ["tags->>'operation'"])
    create index(:metrics_events, ["tags->>'model'"])
    create index(:metrics_events, ["(tags)"], using: :gin)

    # Create hourly partitions for performance
    # (optional: implement if metrics volume becomes large)
  end
end
```

### Migration 2: Create metrics_aggregated Table

**File**: `singularity/priv/repo/migrations/20251024060001_create_metrics_aggregated.exs`

```elixir
defmodule Singularity.Repo.Migrations.CreateMetricsAggregated do
  use Ecto.Migration

  def change do
    create table(:metrics_aggregated, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_name, :string, null: false
      add :period, :string, null: false
      add :period_start, :utc_datetime_usec, null: false
      add :count, :bigint, null: false
      add :sum, :float, null: false
      add :avg, :float, null: false
      add :min, :float, null: false
      add :max, :float, null: false
      add :stddev, :float
      add :tags, :jsonb, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint: prevent duplicate aggregations
    create unique_index(:metrics_aggregated,
      [:event_name, :period, :period_start, :tags],
      name: "metrics_aggregated_unique_idx")

    # Query indexes
    create index(:metrics_aggregated, [:event_name, :period_start])
    create index(:metrics_aggregated, [:period, :period_start])
    create index(:metrics_aggregated, [:period_start])
  end
end
```

## Integration Points

### Integration 1: Telemetry Handler

**Where**: `singularity/lib/singularity/telemetry.ex`

```elixir
# Add handler to existing telemetry setup
defp attach_handlers do
  :telemetry.attach_many(
    "singularity-metrics",
    [
      [:singularity, :llm, :request, :stop],
      [:singularity, :agent, :execution, :stop],
      [:singularity, :search, :completed],
      [:singularity, :tool, :execution, :stop]
    ],
    &Metrics.EventCollector.handle_telemetry_event/4,
    nil
  )
end
```

### Integration 2: RateLimiter Cost Recording

**Where**: `singularity/lib/singularity/llm/rate_limiter.ex`

```elixir
# Record cost when released
def release(cost_usd) do
  # ... existing logic ...

  # NEW: Record in unified metrics
  Metrics.EventCollector.record_cost_spent(
    :llm_api_call,
    cost_usd,
    %{model: @model, operation: "llm.release"}
  )
end
```

### Integration 3: Error Rate Tracker

**Where**: `singularity/lib/singularity/infrastructure/error_rate_tracker.ex`

```elixir
# Record errors via unified metrics
def record_error(operation, error) do
  # ... existing logic ...

  # NEW: Also record in unified metrics
  Metrics.EventCollector.record_measurement(
    "error.#{operation}",
    1,
    "count",
    %{operation: operation, error_type: error_type(error)}
  )
end
```

## Implementation Phases

### Phase 1: Foundation (Day 1)
- Create Metrics.Event schema
- Create Metrics.AggregatedData schema
- Create migrations
- Execute migrations

### Phase 2: Core Service (Day 1-2)
- Implement Metrics.EventCollector
- Implement Metrics.EventAggregator
- Implement Metrics.Query
- Create Metrics.Supervisor
- Create Metrics.AggregationJob

### Phase 3: Integration (Day 2)
- Wire Telemetry handler
- Wire RateLimiter cost recording
- Wire ErrorRateTracker
- Update Application.ex with Metrics.Supervisor

### Phase 4: Testing & Cleanup (Day 3)
- Unit tests for Collector, Aggregator, Query
- Integration tests for end-to-end flow
- Archive/remove old code:
  - MetricsFeeder (synthetic data)
  - Tools.Monitoring (simulation)
  - Tools.Performance (simulation)
  - CodeStore metrics facts
- Update dependent systems

## Success Checklist

- [ ] metrics_events table created and indexed
- [ ] metrics_aggregated table created and indexed
- [ ] Metrics.EventCollector records events from all sources
- [ ] Metrics.EventAggregator aggregates hourly and daily
- [ ] Metrics.Query API complete and tested
- [ ] Telemetry events flow to EventCollector
- [ ] RateLimiter records costs via EventCollector
- [ ] ErrorRateTracker records errors via EventCollector
- [ ] Aggregation job runs successfully every hour
- [ ] All tests passing
- [ ] Simulation code archived
- [ ] Learning loop connected to Query results
- [ ] Zero breaking changes to existing code

---

**Ready for implementation phase.**

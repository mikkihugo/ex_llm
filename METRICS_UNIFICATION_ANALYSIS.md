# Metrics Unification - Consolidation Analysis

**Phase**: 4 (Days 13-15)
**Scope**: 16+ modules, 8,598 LOC, 4 storage backends
**Status**: Analysis Complete - Ready for Implementation

## Executive Summary

Singularity's metrics infrastructure is **highly scattered and fragmented**:

- **16+ modules** with **8,598 LOC** of metrics-related code
- **4 different storage backends**: ETS (ErrorRateTracker), PostgreSQL (AgentMetric, SearchMetric), in-memory DAG (TemplatePerformance), CodeStore (ad-hoc)
- **2,388 LOC of simulation code** (Tools.Performance) that doesn't connect to real operations
- **Missing core module** - Referenced `Metrics.Aggregator` doesn't exist
- **No unified API** - callers must know about 10+ different modules
- **Broken feedback loop** - metrics collected but learning incomplete

### Impact

- **Data Quality**: Hard to find "single source of truth" for any metric
- **Cost Tracking**: Same data tracked 4 different ways (Telemetry, RateLimiter, AgentMetric, CodeStore)
- **Aggregation**: MetricsAggregationWorker references missing module, aggregation logic unclear
- **Learning**: Experiment results exist but not connected to agent metrics
- **Debugging**: Metrics scattered, making system behavior analysis difficult

## Scattered Systems Inventory

### Core Telemetry (Foundation - Working)
```
Singularity.Telemetry (307 LOC) - Event definitions + measurement collection
├── Agent telemetry - request_count, success_rate, latency, cost
├── LLM telemetry - request_count, success_rate, latency, cost, complexity, model
├── NATS telemetry - message_count, latency
├── Tool telemetry - execution_count, latency, success_rate
└── VM telemetry - memory, processes, scheduled_words
```

**Status**: Foundation only - events defined but not collected/persisted

### Infrastructure Metrics (Isolated)
```
ErrorRateTracker (281 LOC)
├── Storage: ETS table (in-memory only)
├── Metrics: error_count, success_rate (sliding window)
├── Features: Alerting to Google Chat
└── Issue: No persistence, isolated from main Telemetry system

RateLimiter (100+ LOC)
├── Tracks: LLM budget, cost, request count
├── Issues: Separate cost tracking from agent metrics
```

**Status**: Working but disconnected from main metrics system

### Database-Persisted Metrics (Schemas Only)
```
AgentMetric (67 LOC schema)
├── Fields: agent_id, success_rate, avg_cost_cents, avg_latency_ms, patterns_used
├── Current status: Schema exists, no actual data flow
└── Issue: Never populated by agent execution

SearchMetric (73 LOC schema)
├── Fields: query, elapsed_ms, results_count, cache_hit, user_satisfaction
├── Issue: No query interface, data never recorded
```

**Status**: Schemas defined but unused

### Collection & Aggregation (Broken)
```
MetricsFeeder (146 LOC)
├── Purpose: Synthetic metric generation
├── Issue: Generates FAKE data, not connected to real operations

MetricsAggregationWorker (59 LOC)
├── References: Metrics.Aggregator (MISSING!)
├── Frequency: Every 5 minutes
├── Issue: Unclear where input data comes from
```

**Status**: Aggregation logic broken/missing

### Template Performance Analysis (Complex)
```
TemplatePerformanceTracker (431 LOC)
├── Storage: In-memory state + CodeStore facts
├── Features: DAG-based ranking, multi-factor weighting
├── Ranking factors: success_rate(0.3), quality(0.3), speed(0.2), recency(0.1), usage(0.1)
├── Data source: Query database for historical data
└── Issue: Massive file, complex logic, not integrated with main metrics
```

**Status**: Sophisticated but isolated

### Tool-Based Metrics (Simulation Only)
```
Tools.Monitoring (1,980 LOC)
├── Purpose: Agent monitoring and log analysis
├── Problem: Pure simulation, no connection to real data
├── Features: Simulated metrics collection, alert checking, trend analysis, dashboards

Tools.Performance (2,388 LOC)
├── Purpose: Performance profiling and optimization
├── Problem: Simulated profiling data, hardcoded test values
├── Features: CPU, memory, bottleneck detection, optimization suggestions
```

**Status**: Highly detailed but 100% simulation

### Health & Monitoring (Fragmented)
```
Health (64 LOC)
├── Checks: queue_depth, memory, database connectivity
├── Issue: References missing SystemStatusMonitor

AgentHealth (? LOC)
├── Agent-specific health tracking
├── Issue: Unclear relationship to Health module

CodebaseHealthTracker (? LOC)
├── Codebase-specific metrics
├── Issue: Isolated from main health system

DeadCodeMonitor (? LOC)
├── Dead code tracking
├── Issue: Purpose unclear, isolated
```

**Status**: Multiple partial implementations, no coordination

### Learning & Feedback (Incomplete)
```
ExperimentResult (? LOC)
├── Stores: Genesis experiment outcomes
├── Issue: Not connected to agent metrics

ExperimentResultConsumer (? LOC)
├── Receives: Genesis results via NATS
├── Issue: No feedback to agent metrics

FeedbackAnalyzer (? LOC)
├── Purpose: Generate improvement feedback from metrics
├── Issue: Input/output unclear
```

**Status**: Components exist but feedback loop incomplete

## Data Flow Gaps

### Current Broken Flow
```
Agent Execution
    ↓
NATS Messages
    ↓
❌ NO COLLECTOR
    ↓
Telemetry.execute() fires event (but not stored)
    ↓
MetricsAggregationWorker.perform()
    ↓
❌ References missing Aggregator module
    ↓
❌ AgentMetric table never updated
    ↓
❌ FeedbackAnalyzer has no input
    ↓
❌ Learning loop stalled
```

### What Should Happen
```
Agent Execution
    ↓
Metrics.Collector.record_event(event_name, measurements, tags)
    ↓
metrics_events table (raw events)
    ↓
Metrics.Aggregator.aggregate(time_range, granularity)
    ↓
metrics_aggregated table (hourly/daily rollups)
    ↓
FeedbackAnalyzer.analyze(metrics)
    ↓
Learning loop → improve future operations
```

## Cost Tracking - 4 Different Systems

### System 1: Telemetry Events
```elixir
:telemetry.execute([:singularity, :llm, :request, :stop],
  %{cost_usd: cost_usd},
  metadata)
```

### System 2: RateLimiter Budget
```elixir
RateLimiter.acquire(estimated_cost)
RateLimiter.release(actual_cost)
```

### System 3: AgentMetric Time-Series
```elixir
AgentMetric
├── avg_cost_cents (but never updated)
```

### System 4: CodeStore Ad-hoc Facts
```elixir
CodeStore.insert_fact(%{
  type: "template_performance",
  cost: ...,
  ...
})
```

**Issue**: Same data (LLM cost) tracked 4 ways with no sync. Which is source of truth?

## Consolidation Strategy

### Approach: Create Unified Metrics Service

Instead of orchestrator pattern (like Search/Job), metrics needs a centralized service because:

1. **Not multiple implementations** - one unified collector/aggregator
2. **Not config-driven dispatch** - deterministic flow from collection → aggregation → queries
3. **Requires database schema** - persistent storage + query interface

### Three-Tier Architecture

```
Tier 1: Metrics.Collector
├── record_event(event_name, measurements, tags)
├── record_cost(operation, cost_usd, tags)
├── record_latency(operation, elapsed_ms, tags)
└── Stores in: metrics_events table

Tier 2: Metrics.Aggregator
├── aggregate_by_hour(metric_name, time_range)
├── aggregate_by_day(metric_name, time_range)
├── aggregate_by_operation(operation, time_range, granularity)
└── Stores in: metrics_aggregated table

Tier 3: Metrics.Query
├── get_agent_metrics(agent_id, time_range)
├── get_cost_metrics(operation, time_range)
├── get_health_metrics(component, time_range)
├── search_metrics(pattern, time_range, filters)
└── Reads from: both tables + pgvector search
```

### Integration Points

| System | Consolidation | Status |
|--------|---------------|--------|
| **Telemetry** | Collector captures events from telemetry.execute() | Direct integration |
| **ErrorRateTracker** | Migrate ETS data to metrics_events | Schema migration |
| **RateLimiter** | Record cost via Metrics.Collector | API integration |
| **AgentMetric** | Populate from aggregated metrics | Automatic via Aggregator |
| **SearchMetric** | Store via Metrics.Collector | New integration |
| **Tools.Monitoring** | Remove simulation, use real metrics via Metrics.Query | Archive old code |
| **Tools.Performance** | Remove simulation, implement with real metrics | Archive old code |
| **TemplatePerformanceTracker** | Query via Metrics.Query | API change |
| **FeedbackAnalyzer** | Input from Metrics.Query output | New integration |
| **ExperimentResult** | Store metrics via Metrics.Collector | Cross-system |

## Database Schema

### metrics_events (Raw Events)
```sql
CREATE TABLE metrics_events (
  id BINARY_ID PRIMARY KEY,
  event_name STRING NOT NULL,           -- "agent.request", "llm.call", etc.
  measurement FLOAT,                    -- value: latency_ms, cost_usd, etc.
  unit STRING,                          -- "ms", "usd", "count", etc.
  tags JSONB,                           -- {agent_id, model, complexity, ...}
  recorded_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ,

  INDEX (event_name, recorded_at),
  INDEX (tags → 'agent_id'),
  INDEX (recorded_at)
);

-- Examples:
-- {event_name: "agent.request.success", measurement: 2500, unit: "ms", tags: {agent_id: "123", ...}}
-- {event_name: "llm.call.cost", measurement: 0.025, unit: "usd", tags: {model: "claude-opus", ...}}
```

### metrics_aggregated (Time-Series Rollups)
```sql
CREATE TABLE metrics_aggregated (
  id BINARY_ID PRIMARY KEY,
  event_name STRING NOT NULL,
  period STRING NOT NULL,               -- "hour", "day", "week"
  period_start TIMESTAMPTZ NOT NULL,

  count BIGINT,
  sum FLOAT,
  avg FLOAT,
  min FLOAT,
  max FLOAT,
  stddev FLOAT,

  tags JSONB,

  UNIQUE (event_name, period, period_start, tags),
  INDEX (event_name, period_start),
  INDEX (period, period_start)
);

-- Examples:
-- {event_name: "agent.request.success", period: "hour", count: 124, avg: 2350, sum: 291400, ...}
-- {event_name: "llm.call.cost", period: "hour", count: 42, sum: 1.25, avg: 0.0298, ...}
```

### metrics_search (Vector Search - pgvector)
```sql
CREATE TABLE metrics_search (
  id BINARY_ID PRIMARY KEY,
  query_pattern STRING NOT NULL,        -- "Find slow LLM calls"
  embedding VECTOR(1536),               -- pgvector embedding
  metrics_ids BINARY_ID[],              -- Related metric event IDs
  results_summary JSONB,
  cached_at TIMESTAMPTZ,

  USING GIN (embedding vector_cosine_ops),
  INDEX (cached_at)
);
```

## Implementation Plan

### Step 1: Create Core Schema & Migrations
- `Metrics.Event` Ecto schema (metrics_events table)
- `Metrics.Aggregated` Ecto schema (metrics_aggregated table)
- Migration: `create_metrics_events.exs`
- Migration: `create_metrics_aggregated.exs`

### Step 2: Create Metrics Service (3 modules)
- `Metrics.Collector` - record_event(), record_cost(), record_latency()
- `Metrics.Aggregator` - aggregate_by_hour(), aggregate_by_day(), etc.
- `Metrics.Query` - get_*_metrics(), search_metrics()

### Step 3: Integrate Collection Points
- Telemetry handler integration
- ErrorRateTracker → Metrics.Collector bridge
- RateLimiter cost recording
- Agent execution metrics capture

### Step 4: Create Aggregation Job
- Replace broken MetricsAggregationWorker
- Oban job: run hourly, aggregate past hour's events
- Store results in metrics_aggregated

### Step 5: Update Dependent Systems
- TemplatePerformanceTracker → Query via Metrics.Query
- FeedbackAnalyzer → Input from Metrics.Query
- Health checks → Use aggregated metrics
- Archive Tools.Monitoring/Performance simulation code

### Step 6: Documentation & Testing
- Unit tests for Collector, Aggregator, Query
- Integration tests for end-to-end flow
- API documentation
- Migration guide for existing systems

## Effort Estimate

| Task | LOC | Days | Notes |
|------|-----|------|-------|
| Schemas (Event, Aggregated) | 100 | 0.5 | Straightforward Ecto schemas |
| Migrations | 50 | 0.5 | Standard Postgres migrations |
| Metrics.Collector | 150 | 1 | Telemetry handler + event recording |
| Metrics.Aggregator | 200 | 1.5 | Time bucketing + aggregation logic |
| Metrics.Query | 100 | 1 | Query API for other systems |
| Integration (5 points) | 150 | 1.5 | Hook up existing systems |
| Tests & Docs | 100 | 1.5 | Comprehensive test coverage |
| **TOTAL** | **850** | **7.5** | **Well within 3-day budget** |

## Success Criteria

✅ **Single source of truth** for all metrics
✅ **Real data** - no more simulation, all actual measurements
✅ **Unified API** - one way to record, aggregate, query metrics
✅ **Persistence** - metrics survive application restarts
✅ **Learning loop** - metrics flow to FeedbackAnalyzer → ExperimentRequest
✅ **Zero downtime** - Telemetry and RateLimiter keep working during migration
✅ **Backward compatible** - existing code continues working (just records to unified system)

## What Gets Archived

1. **MetricsFeeder** (146 LOC) - Synthetic data not needed
2. **Tools.Monitoring** (1,980 LOC) - Simulation replaced by real metrics
3. **Tools.Performance** (2,388 LOC) - Simulation replaced by real metrics
4. **CodeStore facts** (metrics storage) - Use metrics_events table instead
5. **TemplatePerformanceTracker DAG** - Still use ranking logic, but feed from Metrics.Query

**Total cleanup**: ~4,514 LOC of simulation/duplicate code

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Breaking existing systems during migration | Implement Metrics.Collector alongside existing systems, run both for verification |
| Performance overhead from recording all events | Batch writes, use async inserts, archive old events to separate table |
| Missing events during transition | Use canary migration - collect to both systems, compare results |
| Database storage volume | Implement retention policy - keep raw events 7 days, aggregates 90 days |

## Next Phase (Optional)

After Metrics Unification complete, consider:

1. **Prometheus export** - Expose metrics_aggregated via Prometheus endpoint
2. **Grafana dashboards** - Replace Tools.Monitoring simulation with real dashboards
3. **Alerting integration** - Move ErrorRateTracker alerts to unified system
4. **Machine learning** - Train models on historical metrics for prediction
5. **Cost optimization** - Real cost tracking enables cost optimization algorithms

---

## Related Documents

- `METRICS_UNIFICATION_CONSOLIDATION.md` - Detailed consolidation roadmap
- `METRICS_UNIFICATION_QUICK_START.md` - Step-by-step implementation guide
- Phase 1-3 Completion Reports (SearchOrchestrator, JobOrchestrator, Genesis)

---

**Ready to proceed with implementation.**

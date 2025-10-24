# Metrics Unification - Quick Start Implementation Guide

**Timeline**: Days 13-15 (3 days estimated)
**Files to Create**: 8 modules + 2 migrations
**Integration Points**: 3 (Telemetry, RateLimiter, ErrorRateTracker)

## Implementation Checklist

### Day 1: Foundation & Core Service

#### Task 1.1: Create Metrics.Event Schema
**File**: `singularity/lib/singularity/metrics/event.ex` (50 LOC)

- Ecto schema for metrics_events table
- Fields: event_name, measurement, unit, tags, recorded_at
- Validation: measurement must be valid float (no NaN/Inf)

#### Task 1.2: Create Metrics.AggregatedData Schema
**File**: `singularity/lib/singularity/metrics/aggregated_data.ex` (50 LOC)

- Ecto schema for metrics_aggregated table
- Fields: event_name, period, period_start, count, sum, avg, min, max, stddev, tags
- Unique constraint: (event_name, period, period_start, tags)

#### Task 1.3: Create Migrations
**Files**:
- `20251024060000_create_metrics_events.exs` (30 LOC)
- `20251024060001_create_metrics_aggregated.exs` (35 LOC)

#### Task 1.4: Create Metrics.EventCollector
**File**: `singularity/lib/singularity/metrics/event_collector.ex` (150 LOC)

Self-documenting API:
- `record_measurement(event_name, measurement, unit, tags)` - Main function
- `record_cost_spent(operation, cost_usd, tags)` - Convenience
- `record_latency_ms(operation, elapsed_ms, tags)` - Convenience
- `record_agent_success(agent_id, successful, latency_ms)` - Convenience
- `record_search_completed(query, results_count, elapsed_ms)` - Convenience
- `handle_telemetry_event(event_name, measurements, metadata, config)` - Handler

#### Task 1.5: Create Metrics.EventAggregator
**File**: `singularity/lib/singularity/metrics/event_aggregator.ex` (200 LOC)

Self-documenting API:
- `aggregate_by_period(period, time_range)` - All events
- `aggregate_events_by_name(event_name, period, time_range)` - Specific event
- `aggregate_events_with_tags(tag_filters, period, time_range)` - With filters
- `calculate_statistics(measurements)` - Helper

#### Task 1.6: Create Metrics.Query
**File**: `singularity/lib/singularity/metrics/query.ex` (100 LOC)

Self-documenting API:
- `get_agent_metrics_over_time(agent_id, time_range)` - Agent metrics
- `get_operation_costs_summary(time_range)` - Cost breakdown
- `get_health_metrics_current()` - Current health
- `find_metrics_by_pattern(search_pattern, limit)` - Pattern search
- `get_learning_insights(operation)` - Learning data
- `get_metrics_for_event(event_name, period, time_range)` - Generic query

#### Task 1.7: Create Metrics.Supervisor
**File**: `singularity/lib/singularity/metrics/supervisor.ex` (40 LOC)

Manages: QueryCache, AggregationJob

### Day 2: Integration & Jobs

#### Task 2.1: Create Metrics.AggregationJob
**File**: `singularity/lib/singularity/metrics/aggregation_job.ex` (50 LOC)

Oban worker: Hourly aggregation of raw events

#### Task 2.2: Create Metrics.QueryCache
**File**: `singularity/lib/singularity/metrics/query_cache.ex` (80 LOC)

ETS-backed cache with TTL for query results

#### Task 2.3: Integration - Telemetry
**File**: `singularity/lib/singularity/telemetry.ex` (modify)

Add handler attachment for EventCollector

#### Task 2.4: Integration - RateLimiter
**File**: `singularity/lib/singularity/llm/rate_limiter.ex` (modify)

Call EventCollector.record_cost_spent() when releasing

#### Task 2.5: Integration - ErrorRateTracker
**File**: `singularity/lib/singularity/infrastructure/error_rate_tracker.ex` (modify)

Call EventCollector.record_measurement() when recording error

#### Task 2.6: Update Application.ex
**File**: `singularity/lib/singularity/application.ex` (modify)

Add Metrics.Supervisor to Layer 3 (Domain Services)

### Day 3: Testing & Documentation

#### Task 3.1: Tests - EventCollector
**File**: `singularity/test/singularity/metrics/event_collector_test.exs` (100 LOC)

- Valid data recording
- Convenience functions
- Validation (NaN, Inf)
- Tag enrichment
- Error handling

#### Task 3.2: Tests - EventAggregator
**File**: `singularity/test/singularity/metrics/event_aggregator_test.exs` (120 LOC)

- Hourly/daily aggregation
- Statistics (count, sum, avg, min, max, stddev)
- Idempotency
- Filtering by event_name
- Filtering by tags

#### Task 3.3: Tests - Query
**File**: `singularity/test/singularity/metrics/query_test.exs` (80 LOC)

- Agent metrics queries
- Cost summaries
- Health metrics
- Learning insights
- Cache behavior
- Error handling

#### Task 3.4: Integration Test - End-to-End
**File**: `singularity/test/singularity/metrics/metrics_integration_test.exs` (150 LOC)

- Record → Aggregate → Query flow
- Telemetry integration
- All data types

#### Task 3.5: Cleanup & Archive
Archive old code (move to docs/archived/):
- `lib/singularity/agents/metrics_feeder.ex` (146 LOC)
- `lib/singularity/tools/monitoring.ex` (1,980 LOC)
- `lib/singularity/tools/performance.ex` (2,388 LOC)

Total cleanup: 4,514 LOC

#### Task 3.6: Documentation
Create `METRICS_UNIFICATION_COMPLETION.md` with:
- Implementation summary
- Architecture diagram
- API examples
- Integration points verified
- Performance characteristics

## Timeline Summary

- **Day 1 (8h)**: Schemas, migrations, core services (Collector, Aggregator, Query)
- **Day 2 (6h)**: Supervisor, Job, Cache, integrations, Application update
- **Day 3 (6h)**: Tests, cleanup, documentation, verification

## Success Metrics

- ✅ All metrics collected in unified event table
- ✅ Hourly aggregation working (Oban job)
- ✅ Query API provides data to all consumers
- ✅ Learning loop connected
- ✅ Zero downtime during migration
- ✅ All tests passing
- ✅ 4,514 LOC of simulation code archived

---

**See METRICS_UNIFICATION_CONSOLIDATION.md for detailed specifications.**

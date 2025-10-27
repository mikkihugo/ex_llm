# NATS to pgmq Migration Roadmap

**Status:** In Progress (Phase 1 - Infrastructure Prep)
**Last Updated:** October 27, 2025
**Priority:** High - Unblocks full test suite

## Executive Summary

This document outlines the migration from NATS (JetStream) messaging to pgmq (PostgreSQL Message Queue) for all event publishing and task coordination. NATS has been removed from the codebase, but several test files and infrastructure components still reference NATS functionality that needs to be replaced with pgmq-based equivalents.

**Current Status:**
- ✅ NATS code removed from codebase
- ✅ pgmq infrastructure deployed (in packages/ex_pgflow)
- ✅ LLM request/response pipeline migrated to pgmq
- ⏳ 7 test suites awaiting pgmq integration (see Phase breakdown below)

## Why This Migration?

**Benefits of pgmq over NATS:**
1. **Zero External Dependencies** - Message queue lives in PostgreSQL, already required
2. **ACID Transactions** - All messages persisted with full transaction guarantees
3. **Simpler Operations** - No separate NATS server to manage
4. **Cost Reduction** - One less service to run and monitor
5. **Consistency** - Single source of truth (database) for all state

**Challenges:**
1. **Lower Throughput** - ~10-50K msg/sec vs NATS 100K+ msg/sec
   - Mitigation: Batch message processing, connection pooling
2. **Higher Latency** - 10-30ms p50 vs NATS <5ms
   - Mitigation: Async processing, not a blocker for most use cases
3. **Polling-Based** - No native push notifications
   - Mitigation: Scheduled polling workers, acceptable for background jobs

## Architecture Overview

### Message Flow (Old → New)

```
OLD: Module → NATS.publish() → JetStream → NATS.subscribe() → Consumer
NEW: Module → pgmq.send() → PostgreSQL → pgmq.read_with_poll() → Consumer
```

### Three Message Patterns

**1. One-Way Events** (e.g., template usage tracking)
```
Publisher → pgmq:events → Database → (optional) Consumer checks database
No guaranteed consumer needed
```

**2. Request-Response** (e.g., LLM service)
```
Request → pgmq:requests → Database
Consumer processes → pgmq:responses → Database
Original caller reads from responses queue
```

**3. Work Queue** (e.g., background jobs)
```
Job submitted → pgmq:jobs → Database
Worker reads with visibility timeout
Worker processes → Update database with result
Job marked complete
```

## Phase Breakdown

### Phase 1: Foundation (COMPLETED)
- [x] Remove NATS from codebase
- [x] Verify pgmq infrastructure in ex_pgflow
- [x] Document test dependencies
- [x] Create test exclusion strategy

**Deliverables:**
- ✅ `.ci_test_excludes` - Configuration file listing all excluded tests
- ✅ `mix test.ci` - Mix task for CI pipeline
- ✅ `pgflow` package with complete pgmq implementation

### Phase 2: Template Usage Events (HIGH PRIORITY)
**Impact:** Core template system - affects template discovery and learning
**Tests:** 3 files, ~1000 lines of code
**Effort:** 2-3 days
**Timeline:** Week 1

**Files to Migrate:**
1. `test/singularity/knowledge/template_usage_tracking_test.exs`
2. `test/singularity/knowledge/template_service_solid_test.exs`
3. `test/singularity/agents/cost_optimized_agent_templates_test.exs`

**What Needs to Change:**

```elixir
# OLD: Direct NATS publishing
defmodule TemplateUsagePublisher do
  def publish_success(template_id, instance_id) do
    Singularity.NatsClient.publish(
      "template.usage.#{template_id}",
      %{status: "success", instance_id: instance_id, timestamp: DateTime.utc_now()}
    )
  end
end

# NEW: pgmq queue insertion
defmodule TemplateUsagePublisher do
  def publish_success(template_id, instance_id) do
    Pgmq.Client.send(
      :template_usage_events,
      %{
        template_id: template_id,
        status: "success",
        instance_id: instance_id,
        timestamp: DateTime.utc_now()
      }
    )
  end
end
```

**Database Schema Required:**

```sql
-- Migration: priv/repo/migrations/YYYYMMDDHHMMSS_create_template_usage_events.exs
defmodule Singularity.Repo.Migrations.CreateTemplateUsageEvents do
  use Ecto.Migration

  def up do
    # Create audit table (for all usage events)
    create table(:template_usage_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :template_id, :string, null: false
      add :status, :string, null: false  # success, failure
      add :instance_id, :string, null: false
      add :timestamp, :utc_datetime, null: false, default: fragment("NOW()")
      add :metadata, :jsonb
      timestamps()
    end

    create index(:template_usage_events, [:template_id])
    create index(:template_usage_events, [:inserted_at])

    # Create pgmq queue for events (optional - can use notification pattern instead)
    # SELECT pgmq.create('template_usage_events');
  end

  def down do
    drop table(:template_usage_events)
    # DROP QUEUE IF pgmq.create used
  end
end
```

**Ecto Schema:**

```elixir
# lib/singularity/knowledge/template_usage_event.ex
defmodule Singularity.Knowledge.TemplateUsageEvent do
  use Ecto.Schema

  schema "template_usage_events" do
    field :template_id, :string
    field :status, Ecto.Enum, values: [:success, :failure]
    field :instance_id, :string
    field :timestamp, :utc_datetime
    field :metadata, :map

    timestamps()
  end
end
```

**Test Migration Example:**

```elixir
# OLD TEST:
test "publishes usage event to NATS" do
  {:ok, sub} = NatsClient.subscribe("template.usage.test_template")

  TemplateUsagePublisher.publish_success("test_template", "instance-1")

  # Wait for event
  assert_receive {:message, event}, 1000
  assert event.status == "success"
end

# NEW TEST:
test "records usage event in database" do
  TemplateUsagePublisher.publish_success("test_template", "instance-1")

  # Query database
  event = Repo.get_by(TemplateUsageEvent, template_id: "test_template")
  assert event.status == :success
  assert event.instance_id == "instance-1"
end
```

**Reference Implementation:**
See `singularity/test/singularity/llm/service_pgmq_integration_test.exs` for complete pgmq integration pattern.

### Phase 3: Job Event Publishing (MEDIUM PRIORITY)
**Impact:** Background job tracking and monitoring
**Tests:** 1 file, ~200 lines
**Effort:** 1-2 days
**Timeline:** Week 1-2

**Files to Migrate:**
1. `test/singularity/jobs/train_t5_model_job_test.exs`

**What Needs to Change:**

```sql
-- Create job_events table
CREATE TABLE job_events (
  id BIGSERIAL PRIMARY KEY,
  job_id UUID NOT NULL,
  job_type VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,  -- started, completed, failed
  status VARCHAR,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  FOREIGN KEY (job_id) REFERENCES oban_jobs(id) ON DELETE CASCADE
);

CREATE INDEX idx_job_events_job_id ON job_events(job_id);
CREATE INDEX idx_job_events_created_at ON job_events(created_at);
```

**Consumer Pattern:**

```elixir
defmodule Singularity.Jobs.JobEventWorker do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    # Poll job events every 5 seconds
    schedule_poll()
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    # Read completed job events from last_seen_id
    events = Repo.all(
      from e in JobEvent,
      where: e.id > ^state.last_seen_id,
      order_by: [asc: :id],
      limit: 100
    )

    # Process each event (update dashboards, notifications, etc)
    Enum.each(events, &process_event/1)

    schedule_poll()
    {:ok, %{state | last_seen_id: last_event_id(events)}}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, 5000)
  end
end
```

### Phase 4: Task Execution Coordination (MEDIUM PRIORITY)
**Impact:** Work planning and task orchestration
**Tests:** 2 files, ~400 lines
**Effort:** 2-3 days
**Timeline:** Week 2

**Files to Migrate:**
1. `test/singularity/execution/task_adapter_orchestrator_test.exs`
2. `test/singularity/execution_coordinator_integration_test.exs`

**What Needs to Change:**
- Remove NatsAdapter references
- Add PgmqAdapter for task queueing
- Update ExecutionCoordinator message dispatch
- Migrate TaskExecutor to read from pgmq instead of NATS

### Phase 5: Runner Integration (MEDIUM PRIORITY)
**Impact:** Runtime task execution tracking
**Tests:** 1 file, ~200 lines
**Effort:** 1-2 days
**Timeline:** Week 2

**Files to Migrate:**
1. `test/singularity/runner_test.exs`

**What Needs to Change:**
- Replace `Runner.publish_event(event_name, data)` with pgmq insertion
- Update health checks to monitor pgmq instead of NATS connection
- Migrate event history from NATS subscription to database queries

## Implementation Guidelines

### 1. Use Pgmq for Persistent Message Storage

```elixir
# For temporary events (can be discarded after processing):
Pgmq.Client.send(:event_queue, %{type: "usage", data: "..."})

# For audit trails (must be kept forever):
Repo.insert!(%TemplateUsageEvent{...})
```

### 2. Polling Pattern for Event Consumption

```elixir
defmodule EventConsumer do
  def consume_events(queue_name, last_id \\ 0) do
    events = Pgmq.Client.read(queue_name, vt: 30, qty: 10)

    Enum.each(events, fn event ->
      handle_event(event)
      Pgmq.Client.delete(queue_name, event.msg_id)
    end)
  end
end
```

### 3. Batching for Performance

```elixir
# Process messages in batches for 10x throughput improvement
events = Pgmq.Client.read(:job_events, qty: 100)
  |> Enum.chunk_every(10)
  |> Enum.each(&process_batch/1)
```

### 4. Error Handling with Visibility Timeout

```elixir
# pgmq automatically manages visibility timeout
# Failed messages become visible again after timeout (default 30s)
# Manual extend if needed:
Pgmq.Client.set_vt(queue_name, [msg_id], vt: 60)
```

## Testing Strategy

### 1. Unit Tests (no infrastructure needed)

```elixir
test "formats event correctly" do
  event = TemplateUsageEvent.new(template_id: "test", status: :success)
  assert event.template_id == "test"
  assert event.status == :success
end
```

### 2. Integration Tests (with database)

```elixir
test "persists usage event to database" do
  TemplateUsagePublisher.publish_success("test_id", "instance-1")

  event = Repo.get_by(TemplateUsageEvent, template_id: "test_id")
  assert event.status == :success
end
```

### 3. End-to-End Tests (full pipeline)

```elixir
test "complete template usage tracking workflow" do
  # 1. Render template
  {:ok, result} = TemplateService.render("my_template", %{name: "John"})

  # 2. Verify event published
  Process.sleep(100)  # Allow async publishing
  event = Repo.get_by(TemplateUsageEvent, template_id: "my_template")
  assert event.status == :success

  # 3. Verify learning loop captures event
  insights = TemplatePerformanceTracker.get_insights("my_template")
  assert insights.success_count >= 1
end
```

## Risk Mitigation

### Risk 1: Message Loss During Migration

**Mitigation:**
- Keep pgmq queues separate from old NATS subscriptions during transition
- No messages lost - database persistence guarantees data safety
- Old NATS messages can be drained to database if needed

### Risk 2: Performance Degradation

**Mitigation:**
- pgmq handles 5-50K msg/sec (adequate for our workload)
- Use batching to achieve 10x throughput improvement
- Implement connection pooling for better concurrency

### Risk 3: Consumers Missing Events

**Mitigation:**
- Use polling workers with scheduled tasks
- Maintain `last_seen_id` to track processed messages
- Dead-letter queues for failed processing

## Rollback Plan

If issues arise, we can temporarily:

1. Keep NATS and pgmq running in parallel
2. Dual-write events to both systems
3. Gradually shift consumer traffic
4. Monitor metrics for any degradation

## Success Criteria

✅ All 7 test files migrated and passing
✅ No external NATS dependency
✅ All event publishing uses pgmq
✅ Full test suite passes with `mix test.ci`
✅ Documentation updated
✅ No performance regression for critical paths

## Timeline

| Phase | Duration | Effort | Status |
|-------|----------|--------|--------|
| Phase 1: Foundation | 1 day | 4 hours | ✅ DONE |
| Phase 2: Templates | 3 days | 16 hours | ⏳ IN PROGRESS |
| Phase 3: Jobs | 2 days | 8 hours | 📋 PLANNED |
| Phase 4: Tasks | 3 days | 16 hours | 📋 PLANNED |
| Phase 5: Runner | 2 days | 8 hours | 📋 PLANNED |
| **Total** | **11 days** | **52 hours** | 9% complete |

## Next Steps

1. **Immediate (Today):**
   - Review this roadmap
   - Approve migration approach
   - Create database migration for template_usage_events

2. **This Week:**
   - Implement Phase 2 (Templates)
   - Verify tests pass locally
   - Create PR with template changes

3. **Next Week:**
   - Complete Phases 3-5
   - Full integration testing
   - Documentation finalization

## Reference Material

**Pgmq Documentation:**
- [pgmq GitHub](https://github.com/tembo-io/pgmq)
- [pgmq Elixir Client](https://github.com/zcm/pgmq-elixir)
- [Examples in codebase](packages/ex_pgflow)

**Similar Implementations:**
- `singularity/test/singularity/llm/service_pgmq_integration_test.exs`
- `singularity/lib/singularity/jobs/llm_result_poller.ex`

**NATS Removal History:**
- Previous session: Removed NATS code, replaced with pgmq in LLM pipeline
- This document: Planning migration for remaining test suites

---

**Questions?** See `.ci_test_excludes` for quick reference or reach out to the team.

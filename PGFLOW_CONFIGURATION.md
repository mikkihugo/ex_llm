# PgFlow Configuration Guide

## Setup Instructions

### 1. Add Dependencies to mix.exs

**File:** `nexus/singularity/mix.exs` and `nexus/central_services/mix.exs`

```elixir
defp deps do
  [
    # ... existing deps ...

    # PgFlow for durable message queues
    {:ex_pgflow, "~> 0.1"},  # Add this line
  ]
end
```

### 2. Create Configuration Files

#### Singularity Configuration

**File:** `nexus/singularity/config/config.exs`

Add at the end of the file:

```elixir
# PgFlow Message Queues Configuration
# ============================================================================
# Asynchronous, durable messaging to CentralCloud

config :singularity, :pgflow_queues,
  database_url: System.get_env("PGFLOW_DATABASE_URL") || "postgresql://localhost/singularity",
  producers: [
    # Queue for sending proposals to CentralCloud consensus
    {
      :proposals_for_consensus,
      %{
        queue_name: "proposals_for_consensus_queue",
        workers: System.get_env("PGFLOW_PROPOSALS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending metrics to Guardian
    {
      :metrics_to_guardian,
      %{
        queue_name: "metrics_to_guardian_queue",
        workers: System.get_env("PGFLOW_METRICS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending patterns to Aggregator
    {
      :patterns_for_aggregator,
      %{
        queue_name: "patterns_for_aggregator_queue",
        workers: System.get_env("PGFLOW_PATTERNS_WORKERS", "1") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ],
  consumers: [
    # Consumer for consensus results
    {
      :consensus_results,
      %{
        queue_name: "consensus_results_queue",
        workers: System.get_env("PGFLOW_CONSENSUS_WORKERS", "2") |> String.to_integer(),
        handler: Singularity.Evolution.Pgflow.Consumers,
        handler_method: :handle_consensus_result,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Consumer for rollback triggers
    {
      :rollback_triggers,
      %{
        queue_name: "rollback_triggers_queue",
        workers: System.get_env("PGFLOW_ROLLBACK_WORKERS", "1") |> String.to_integer(),
        handler: Singularity.Evolution.Pgflow.Consumers,
        handler_method: :handle_rollback_trigger,
        max_retries: 3,
        retry_delay_ms: 1000,
        priority: :high
      }
    },
    # Consumer for safety profile updates
    {
      :safety_profiles,
      %{
        queue_name: "guardian_safety_profiles_queue",
        workers: System.get_env("PGFLOW_SAFETY_WORKERS", "1") |> String.to_integer(),
        handler: Singularity.Evolution.Pgflow.Consumers,
        handler_method: :handle_safety_profile_update,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ]

# Telemetry for PgFlow events
config :telemetry, :events,
  [
    [:evolution, :pgflow, :proposal_published],
    [:evolution, :pgflow, :metrics_published],
    [:evolution, :pgflow, :pattern_published],
    [:evolution, :pgflow, :publish_failed],
    [:evolution, :pgflow, :consensus_approved],
    [:evolution, :pgflow, :consensus_rejected],
    [:evolution, :pgflow, :rollback_completed],
    [:evolution, :pgflow, :profile_updated]
  ]
```

#### CentralCloud Configuration

**File:** `nexus/central_services/config/config.exs`

Add at the end:

```elixir
# PgFlow Message Queues Configuration
# ============================================================================
# Asynchronous, durable messaging from Singularity instances

config :centralcloud, :pgflow_queues,
  database_url: System.get_env("PGFLOW_DATABASE_URL") || "postgresql://localhost/central_services",
  producers: [
    # Queue for sending consensus results to instances
    {
      :consensus_results,
      %{
        queue_name: "consensus_results_queue",
        workers: System.get_env("PGFLOW_CONSENSUS_RESULTS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending rollback triggers (high priority)
    {
      :rollback_triggers,
      %{
        queue_name: "rollback_triggers_queue",
        workers: System.get_env("PGFLOW_ROLLBACK_WORKERS", "1") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000,
        priority: :high
      }
    },
    # Queue for sending safety profile updates
    {
      :safety_profiles,
      %{
        queue_name: "guardian_safety_profiles_queue",
        workers: System.get_env("PGFLOW_PROFILE_WORKERS", "1") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ],
  consumers: [
    # Consumer for proposals from instances
    {
      :proposals,
      %{
        queue_name: "proposals_for_consensus_queue",
        workers: System.get_env("PGFLOW_PROPOSALS_WORKERS", "3") |> String.to_integer(),
        handler: CentralCloud.Evolution.Pgflow.Consumers,
        handler_method: :handle_proposal_for_consensus,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Consumer for metrics from instances
    {
      :metrics,
      %{
        queue_name: "metrics_to_guardian_queue",
        workers: System.get_env("PGFLOW_METRICS_WORKERS", "2") |> String.to_integer(),
        handler: CentralCloud.Evolution.Pgflow.Consumers,
        handler_method: :handle_execution_metrics,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Consumer for patterns from instances
    {
      :patterns,
      %{
        queue_name: "patterns_for_aggregator_queue",
        workers: System.get_env("PGFLOW_PATTERNS_WORKERS", "1") |> String.to_integer(),
        handler: CentralCloud.Evolution.Pgflow.Consumers,
        handler_method: :handle_pattern_discovered,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ]

# Telemetry for PgFlow events
config :telemetry, :events,
  [
    [:evolution, :pgflow, :proposal_received],
    [:evolution, :pgflow, :metrics_received],
    [:evolution, :pgflow, :pattern_received],
    [:evolution, :pgflow, :consensus_result_published],
    [:evolution, :pgflow, :rollback_trigger_published],
    [:evolution, :pgflow, :profile_update_published]
  ]
```

### 3. Environment Variables

**File:** `.env` or export commands

```bash
# Database for PgFlow queues (shared or separate from app DB)
export PGFLOW_DATABASE_URL=postgresql://user:pass@localhost/singularity

# Queue worker counts (adjust for scale)
export PGFLOW_PROPOSALS_WORKERS=2
export PGFLOW_METRICS_WORKERS=2
export PGFLOW_PATTERNS_WORKERS=1
export PGFLOW_CONSENSUS_WORKERS=2
export PGFLOW_ROLLBACK_WORKERS=1
export PGFLOW_SAFETY_WORKERS=1

# Retry configuration
export PGFLOW_MAX_RETRIES=3
export PGFLOW_RETRY_DELAY_MS=1000
```

### 4. Database Setup

Create PgFlow tables in your PostgreSQL database:

```bash
cd nexus/singularity
mix pgflow.init  # Create pgflow tables in database

cd ../central_services
mix pgflow.init  # Same for CentralCloud
```

This creates:
- `pgflow_queues` - Queue definitions
- `pgflow_messages` - Message storage
- `pgflow_dlq` - Dead-letter queue for failed messages

### 5. Supervision Tree Integration

**File:** `nexus/singularity/lib/singularity/application.ex`

```elixir
def start(_type, _args) do
  children = [
    # ... existing services ...

    # PgFlow consumers for incoming messages from CentralCloud
    {ExPgflow.Consumer, Application.get_env(:singularity, :pgflow_consumers)},

    # ... rest of supervision tree ...
  ]

  opts = [strategy: :one_for_one, name: Singularity.Supervisor]
  Supervisor.start_link(children, opts)
end
```

**File:** `nexus/central_services/lib/centralcloud/application.ex`

```elixir
def start(_type, _args) do
  children = [
    # ... existing services ...

    # PgFlow consumers for incoming messages from instances
    {ExPgflow.Consumer, Application.get_env(:centralcloud, :pgflow_consumers)},

    # ... rest of supervision tree ...
  ]

  opts = [strategy: :one_for_one, name: CentralCloud.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Queue Configuration Details

### Queue Names & Purposes

| Queue | Direction | Purpose | Workers | Priority |
|-------|-----------|---------|---------|----------|
| `proposals_for_consensus_queue` | Singularity → CentralCloud | Send proposals for voting | 2-3 | Normal |
| `consensus_results_queue` | CentralCloud → Singularity | Send voting results | 2 | Normal |
| `metrics_to_guardian_queue` | Singularity → CentralCloud | Send execution metrics | 2 | Normal |
| `patterns_for_aggregator_queue` | Singularity → CentralCloud | Send discovered patterns | 1 | Normal |
| `rollback_triggers_queue` | CentralCloud → Singularity | Send rollback signals | 1 | **High** |
| `guardian_safety_profiles_queue` | CentralCloud → Singularity | Send safety updates | 1 | Normal |

### Scaling Guidelines

**Small Scale (1-5 instances):**
```bash
export PGFLOW_PROPOSALS_WORKERS=1
export PGFLOW_METRICS_WORKERS=1
export PGFLOW_PATTERNS_WORKERS=1
export PGFLOW_CONSENSUS_WORKERS=1
export PGFLOW_ROLLBACK_WORKERS=1
```

**Medium Scale (5-20 instances):**
```bash
export PGFLOW_PROPOSALS_WORKERS=3
export PGFLOW_METRICS_WORKERS=2
export PGFLOW_PATTERNS_WORKERS=2
export PGFLOW_CONSENSUS_WORKERS=2
export PGFLOW_ROLLBACK_WORKERS=1
```

**Large Scale (20+ instances):**
```bash
export PGFLOW_PROPOSALS_WORKERS=5
export PGFLOW_METRICS_WORKERS=4
export PGFLOW_PATTERNS_WORKERS=3
export PGFLOW_CONSENSUS_WORKERS=4
export PGFLOW_ROLLBACK_WORKERS=2
```

## Monitoring PgFlow

### Check Queue Status

```elixir
# In iex console
alias ExPgflow

# List all queues
ExPgflow.list_queues()

# Get queue stats
ExPgflow.get_queue_stats("proposals_for_consensus_queue")

# Check pending messages
ExPgflow.list_pending_messages("proposals_for_consensus_queue")

# Check dead-letter queue
ExPgflow.list_dlq_messages()
```

### Telemetry Monitoring

```elixir
# Listen to PgFlow events
:telemetry.attach(
  "pgflow_monitor",
  [:evolution, :pgflow, :*],
  &log_pgflow_event/4,
  nil
)

defp log_pgflow_event(event, measurements, metadata, _) do
  IO.inspect({event, measurements, metadata}, label: "PgFlow Event")
end

# Events emitted:
# - [:evolution, :pgflow, :proposal_published]
# - [:evolution, :pgflow, :consensus_approved]
# - [:evolution, :pgflow, :rollback_completed]
# - ... and more
```

### Database Queries

```sql
-- View pending messages
SELECT id, queue_name, payload, created_at, retry_count
FROM pgflow_messages
WHERE status = 'pending'
ORDER BY priority DESC, created_at ASC;

-- View failed messages
SELECT id, queue_name, error, created_at
FROM pgflow_dlq
ORDER BY created_at DESC;

-- Queue stats
SELECT queue_name, COUNT(*) as pending_count, MAX(created_at) as oldest
FROM pgflow_messages
WHERE status = 'pending'
GROUP BY queue_name;
```

## Troubleshooting

### Messages Not Being Processed

```elixir
# Check if consumers are running
Supervisor.which_children(Singularity.Supervisor)

# Check pending messages
ExPgflow.list_pending_messages("consensus_results_queue")

# Check for errors in consumer
ExPgflow.list_dlq_messages()
```

### High Latency

- Increase worker count for bottleneck queues
- Check database performance
- Monitor slow queries in PostgreSQL

### Messages in Dead-Letter Queue

```elixir
# List DLQ messages
dlq_messages = ExPgflow.list_dlq_messages()

# Inspect error
Enum.each(dlq_messages, &IO.inspect(&1))

# Retry a message
ExPgflow.retry_dlq_message(message_id)

# Clear DLQ (after fixing issue)
ExPgflow.purge_dlq()
```

## Performance Tips

1. **Database:** Use a dedicated PostgreSQL instance for pgflow (can share with app DB)
2. **Workers:** Start with 2 per queue, scale based on latency
3. **Batching:** Messages are processed in batches automatically
4. **Retry:** Exponential backoff prevents queue storms
5. **Monitoring:** Track pending message count and DLQ size

## Production Checklist

- [ ] PgFlow database configured and migrated
- [ ] Environment variables set
- [ ] Supervision tree updated
- [ ] Configuration tested locally
- [ ] Monitoring dashboard set up
- [ ] Alerting configured (DLQ > 100 messages)
- [ ] Backup strategy for pgflow tables
- [ ] Performance tested with expected load

## See Also

- **EVOLUTION_PGFLOW_INTEGRATION_GUIDE.md** - Implementation guide
- **ProposalQueue usage** - See updated proposal_queue.ex
- **ExecutionFlow usage** - See updated execution_flow.ex

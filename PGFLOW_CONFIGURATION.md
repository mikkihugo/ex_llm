# QuantumFlow Configuration Guide

## Setup Instructions

### 1. Add Dependencies to mix.exs

**File:** `nexus/singularity/mix.exs` and `nexus/central_services/mix.exs`

```elixir
defp deps do
  [
    # ... existing deps ...

    # QuantumFlow for durable message queues
    {:quantum_flow, "~> 0.1"},  # Add this line
  ]
end
```

### 2. Create Configuration Files

#### Singularity Configuration

**File:** `nexus/singularity/config/config.exs`

Add at the end of the file:

```elixir
# QuantumFlow Message Queues Configuration
# ============================================================================
# Asynchronous, durable messaging to CentralCloud

config :singularity, :quantum_flow_queues,
  database_url: System.get_env("QUANTUM_FLOW_DATABASE_URL") || "postgresql://localhost/singularity",
  producers: [
    # Queue for sending proposals to CentralCloud consensus
    {
      :proposals_for_consensus,
      %{
        queue_name: "proposals_for_consensus_queue",
        workers: System.get_env("QUANTUM_FLOW_PROPOSALS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending metrics to Guardian
    {
      :metrics_to_guardian,
      %{
        queue_name: "metrics_to_guardian_queue",
        workers: System.get_env("QUANTUM_FLOW_METRICS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending patterns to Aggregator
    {
      :patterns_for_aggregator,
      %{
        queue_name: "patterns_for_aggregator_queue",
        workers: System.get_env("QUANTUM_FLOW_PATTERNS_WORKERS", "1") |> String.to_integer(),
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
        workers: System.get_env("QUANTUM_FLOW_CONSENSUS_WORKERS", "2") |> String.to_integer(),
        handler: Singularity.Evolution.QuantumFlow.Consumers,
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
        workers: System.get_env("QUANTUM_FLOW_ROLLBACK_WORKERS", "1") |> String.to_integer(),
        handler: Singularity.Evolution.QuantumFlow.Consumers,
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
        workers: System.get_env("QUANTUM_FLOW_SAFETY_WORKERS", "1") |> String.to_integer(),
        handler: Singularity.Evolution.QuantumFlow.Consumers,
        handler_method: :handle_safety_profile_update,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ]

# Telemetry for QuantumFlow events
config :telemetry, :events,
  [
    [:evolution, :QuantumFlow, :proposal_published],
    [:evolution, :QuantumFlow, :metrics_published],
    [:evolution, :QuantumFlow, :pattern_published],
    [:evolution, :QuantumFlow, :publish_failed],
    [:evolution, :QuantumFlow, :consensus_approved],
    [:evolution, :QuantumFlow, :consensus_rejected],
    [:evolution, :QuantumFlow, :rollback_completed],
    [:evolution, :QuantumFlow, :profile_updated]
  ]
```

#### CentralCloud Configuration

**File:** `nexus/central_services/config/config.exs`

Add at the end:

```elixir
# QuantumFlow Message Queues Configuration
# ============================================================================
# Asynchronous, durable messaging from Singularity instances

config :centralcloud, :quantum_flow_queues,
  database_url: System.get_env("QUANTUM_FLOW_DATABASE_URL") || "postgresql://localhost/central_services",
  producers: [
    # Queue for sending consensus results to instances
    {
      :consensus_results,
      %{
        queue_name: "consensus_results_queue",
        workers: System.get_env("QUANTUM_FLOW_CONSENSUS_RESULTS_WORKERS", "2") |> String.to_integer(),
        max_retries: 3,
        retry_delay_ms: 1000
      }
    },
    # Queue for sending rollback triggers (high priority)
    {
      :rollback_triggers,
      %{
        queue_name: "rollback_triggers_queue",
        workers: System.get_env("QUANTUM_FLOW_ROLLBACK_WORKERS", "1") |> String.to_integer(),
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
        workers: System.get_env("QUANTUM_FLOW_PROFILE_WORKERS", "1") |> String.to_integer(),
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
        workers: System.get_env("QUANTUM_FLOW_PROPOSALS_WORKERS", "3") |> String.to_integer(),
        handler: CentralCloud.Evolution.QuantumFlow.Consumers,
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
        workers: System.get_env("QUANTUM_FLOW_METRICS_WORKERS", "2") |> String.to_integer(),
        handler: CentralCloud.Evolution.QuantumFlow.Consumers,
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
        workers: System.get_env("QUANTUM_FLOW_PATTERNS_WORKERS", "1") |> String.to_integer(),
        handler: CentralCloud.Evolution.QuantumFlow.Consumers,
        handler_method: :handle_pattern_discovered,
        max_retries: 3,
        retry_delay_ms: 1000
      }
    }
  ]

# Telemetry for QuantumFlow events
config :telemetry, :events,
  [
    [:evolution, :QuantumFlow, :proposal_received],
    [:evolution, :QuantumFlow, :metrics_received],
    [:evolution, :QuantumFlow, :pattern_received],
    [:evolution, :QuantumFlow, :consensus_result_published],
    [:evolution, :QuantumFlow, :rollback_trigger_published],
    [:evolution, :QuantumFlow, :profile_update_published]
  ]
```

### 3. Environment Variables

**File:** `.env` or export commands

```bash
# Database for QuantumFlow queues (shared or separate from app DB)
export QUANTUM_FLOW_DATABASE_URL=postgresql://user:pass@localhost/singularity

# Queue worker counts (adjust for scale)
export QUANTUM_FLOW_PROPOSALS_WORKERS=2
export QUANTUM_FLOW_METRICS_WORKERS=2
export QUANTUM_FLOW_PATTERNS_WORKERS=1
export QUANTUM_FLOW_CONSENSUS_WORKERS=2
export QUANTUM_FLOW_ROLLBACK_WORKERS=1
export QUANTUM_FLOW_SAFETY_WORKERS=1

# Retry configuration
export QUANTUM_FLOW_MAX_RETRIES=3
export QUANTUM_FLOW_RETRY_DELAY_MS=1000
```

### 4. Database Setup

Create QuantumFlow tables in your PostgreSQL database:

```bash
cd nexus/singularity
mix QuantumFlow.init  # Create QuantumFlow tables in database

cd ../central_services
mix QuantumFlow.init  # Same for CentralCloud
```

This creates:
- `quantum_flow_queues` - Queue definitions
- `quantum_flow_messages` - Message storage
- `quantum_flow_dlq` - Dead-letter queue for failed messages

### 5. Supervision Tree Integration

**File:** `nexus/singularity/lib/singularity/application.ex`

```elixir
def start(_type, _args) do
  children = [
    # ... existing services ...

    # QuantumFlow consumers for incoming messages from CentralCloud
    {QuantumFlow.Consumer, Application.get_env(:singularity, :quantum_flow_consumers)},

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

    # QuantumFlow consumers for incoming messages from instances
    {QuantumFlow.Consumer, Application.get_env(:centralcloud, :quantum_flow_consumers)},

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
export QUANTUM_FLOW_PROPOSALS_WORKERS=1
export QUANTUM_FLOW_METRICS_WORKERS=1
export QUANTUM_FLOW_PATTERNS_WORKERS=1
export QUANTUM_FLOW_CONSENSUS_WORKERS=1
export QUANTUM_FLOW_ROLLBACK_WORKERS=1
```

**Medium Scale (5-20 instances):**
```bash
export QUANTUM_FLOW_PROPOSALS_WORKERS=3
export QUANTUM_FLOW_METRICS_WORKERS=2
export QUANTUM_FLOW_PATTERNS_WORKERS=2
export QUANTUM_FLOW_CONSENSUS_WORKERS=2
export QUANTUM_FLOW_ROLLBACK_WORKERS=1
```

**Large Scale (20+ instances):**
```bash
export QUANTUM_FLOW_PROPOSALS_WORKERS=5
export QUANTUM_FLOW_METRICS_WORKERS=4
export QUANTUM_FLOW_PATTERNS_WORKERS=3
export QUANTUM_FLOW_CONSENSUS_WORKERS=4
export QUANTUM_FLOW_ROLLBACK_WORKERS=2
```

## Monitoring QuantumFlow

### Check Queue Status

```elixir
# In iex console
alias QuantumFlow

# List all queues
QuantumFlow.list_queues()

# Get queue stats
QuantumFlow.get_queue_stats("proposals_for_consensus_queue")

# Check pending messages
QuantumFlow.list_pending_messages("proposals_for_consensus_queue")

# Check dead-letter queue
QuantumFlow.list_dlq_messages()
```

### Telemetry Monitoring

```elixir
# Listen to QuantumFlow events
:telemetry.attach(
  "quantum_flow_monitor",
  [:evolution, :QuantumFlow, :*],
  &log_quantum_flow_event/4,
  nil
)

defp log_quantum_flow_event(event, measurements, metadata, _) do
  IO.inspect({event, measurements, metadata}, label: "QuantumFlow Event")
end

# Events emitted:
# - [:evolution, :QuantumFlow, :proposal_published]
# - [:evolution, :QuantumFlow, :consensus_approved]
# - [:evolution, :QuantumFlow, :rollback_completed]
# - ... and more
```

### Database Queries

```sql
-- View pending messages
SELECT id, queue_name, payload, created_at, retry_count
FROM quantum_flow_messages
WHERE status = 'pending'
ORDER BY priority DESC, created_at ASC;

-- View failed messages
SELECT id, queue_name, error, created_at
FROM quantum_flow_dlq
ORDER BY created_at DESC;

-- Queue stats
SELECT queue_name, COUNT(*) as pending_count, MAX(created_at) as oldest
FROM quantum_flow_messages
WHERE status = 'pending'
GROUP BY queue_name;
```

## Troubleshooting

### Messages Not Being Processed

```elixir
# Check if consumers are running
Supervisor.which_children(Singularity.Supervisor)

# Check pending messages
QuantumFlow.list_pending_messages("consensus_results_queue")

# Check for errors in consumer
QuantumFlow.list_dlq_messages()
```

### High Latency

- Increase worker count for bottleneck queues
- Check database performance
- Monitor slow queries in PostgreSQL

### Messages in Dead-Letter Queue

```elixir
# List DLQ messages
dlq_messages = QuantumFlow.list_dlq_messages()

# Inspect error
Enum.each(dlq_messages, &IO.inspect(&1))

# Retry a message
QuantumFlow.retry_dlq_message(message_id)

# Clear DLQ (after fixing issue)
QuantumFlow.purge_dlq()
```

## Performance Tips

1. **Database:** Use a dedicated PostgreSQL instance for QuantumFlow (can share with app DB)
2. **Workers:** Start with 2 per queue, scale based on latency
3. **Batching:** Messages are processed in batches automatically
4. **Retry:** Exponential backoff prevents queue storms
5. **Monitoring:** Track pending message count and DLQ size

## Production Checklist

- [ ] QuantumFlow database configured and migrated
- [ ] Environment variables set
- [ ] Supervision tree updated
- [ ] Configuration tested locally
- [ ] Monitoring dashboard set up
- [ ] Alerting configured (DLQ > 100 messages)
- [ ] Backup strategy for QuantumFlow tables
- [ ] Performance tested with expected load

## See Also

- **EVOLUTION_QUANTUM_FLOW_INTEGRATION_GUIDE.md** - Implementation guide
- **ProposalQueue usage** - See updated proposal_queue.ex
- **ExecutionFlow usage** - See updated execution_flow.ex

# Multi-BEAM Deployment Guide

**Quick reference for deploying Singularity across multiple instances with CentralCloud sync**

## Quick Start: Local Development (Single BEAM)

```bash
# No special configuration needed
nix develop
mix phx.server

# All jobs process on this single BEAM instance
# WorkflowExecutor runs directly without Oban overhead
```

## Production: Multi-BEAM Deployment

### Prerequisites

- PostgreSQL 14+ (single shared instance)
- CentralCloud running (for learning aggregation)
- 2+ BEAM instances (same or different servers)

### Step 1: Database Setup

```bash
# Run migrations on shared PostgreSQL
cd singularity
mix ecto.migrate

# This creates:
# - oban_jobs (Oban's job queue)
# - oban_peers (instance registry)
# - instance_registry (heartbeat tracking)
# - job_results (execution tracking)
# - pgmq queues (for UP/DOWN channels)
```

### Step 2: Configure Instances

```bash
# Ensure each instance has unique ID
export INSTANCE_ID="instance_a"  # Instance A
export INSTANCE_ID="instance_b"  # Instance B
export INSTANCE_ID="instance_c"  # Instance C

# Or in config/prod.exs:
config :singularity,
  instance_id: System.get_env("INSTANCE_ID") || "instance_#{Node.self()}"
```

### Step 3: Deploy Instances

**Terminal 1: Instance A**
```bash
export INSTANCE_ID=instance_a
export MIX_ENV=prod
mix phx.server -p 4000
```

**Terminal 2: Instance B**
```bash
export INSTANCE_ID=instance_b
export MIX_ENV=prod
mix phx.server -p 4001
```

**Terminal 3: Instance C**
```bash
export INSTANCE_ID=instance_c
export MIX_ENV=prod
mix phx.server -p 4002
```

All three connect to the **same PostgreSQL database** and coordinate automatically.

### Step 4: Verify Distribution

```bash
# Check instance registry
psql $DATABASE_URL

singularity=> SELECT instance_id, status, load, last_heartbeat
             FROM instance_registry
             ORDER BY last_heartbeat DESC;

 instance_id | status | load | last_heartbeat
-------------+--------+------+-----------------------------
 instance_a  | online |    3 | 2025-10-25 12:00:05.123456
 instance_b  | online |    4 | 2025-10-25 12:00:04.987654
 instance_c  | online |    2 | 2025-10-25 12:00:04.765432
(3 rows)

# Check job distribution
singularity=> SELECT reserved_by, COUNT(*) as job_count
             FROM oban_jobs
             WHERE state = 'executing'
             GROUP BY reserved_by;

 reserved_by | job_count
-------------+-----------
 instance_a  |         3
 instance_b  |         4
 instance_c  |         2
(3 rows)
```

## Architecture Components

### Per-Instance Components

Each Singularity instance includes:

```elixir
# Auto-started in application supervision tree
Singularity.Instance.Registry          # Register and heartbeat
Singularity.Oban                        # Job distribution
Singularity.Jobs.ResultAggregatorWorker # Send results UP to CentralCloud
Singularity.Jobs.LearningSyncWorker     # Receive learnings DOWN from CentralCloud
```

### Data Flow

```
Instance A ──┐
Instance B ──┼─→ PostgreSQL ──→ CentralCloud
Instance C ──┘    (coordination)

Oban automatically:
  1. Polls oban_jobs table for available jobs
  2. Claims jobs (reserved_by = instance_id)
  3. Executes workflows in parallel
  4. Stores results in job_results table
  5. Reassigns jobs if instance crashes

ResultAggregator (every 30 seconds):
  1. Collects results from job_results
  2. Aggregates metrics (cost, latency, success)
  3. Sends to pgmq:instance_*_results

LearningSyncWorker (every 10 seconds):
  1. Polls pgmq:instance_learning
  2. Receives learnings from CentralCloud
  3. Updates local model routing and patterns
```

## Monitoring

### Check Instance Health

```bash
# See which instances are online
psql $DATABASE_URL -c "
  SELECT instance_id, status, load,
         EXTRACT(EPOCH FROM (NOW() - last_heartbeat)) as seconds_since_heartbeat
  FROM instance_registry
  ORDER BY last_heartbeat DESC;
"

# Expected output:
# instance_id | status | load | seconds_since_heartbeat
#             | online |    5 |                       2
# instance_b  | online |    3 |                       1
# instance_c  | online |    4 |                       3
```

### Check Job Distribution

```bash
# Jobs in progress by instance
psql $DATABASE_URL -c "
  SELECT reserved_by, state, COUNT(*) as count
  FROM oban_jobs
  GROUP BY reserved_by, state
  ORDER BY reserved_by, state;
"
```

### Check Results/Learnings

```bash
# Recent job results
psql $DATABASE_URL -c "
  SELECT instance_id, job_type, success, AVG(cost_cents) as avg_cost
  FROM job_results
  WHERE completed_at > NOW() - '1 hour'::interval
  GROUP BY instance_id, job_type, success
  ORDER BY instance_id, job_type;
"

# Results sent to CentralCloud
psql $DATABASE_URL -c "
  SELECT msg_id, queue_name, enqueued_at, message->'instance_id' as source
  FROM pgmq.q_centralcloud_updates
  ORDER BY enqueued_at DESC LIMIT 10;
"

# Learnings received from CentralCloud
psql $DATABASE_URL -c "
  SELECT msg_id, enqueued_at, message->'type' as learning_type
  FROM pgmq.q_instance_learning
  ORDER BY enqueued_at DESC LIMIT 10;
"
```

## Troubleshooting

### Instance Not Registered

```bash
# Check application startup logs
grep "Registering instance" /var/log/singularity/instance_a.log

# If not found: Instance.Registry didn't start
# Check supervision tree in application.ex
```

### Jobs Not Distributing

```bash
# Verify all instances can reach PostgreSQL
mix run -e "Singularity.Repo.query!(\"SELECT 1\")"

# Check Oban is running
mix run -e "IO.inspect(Oban.Engine.running?())"

# Verify oban_jobs table exists
psql $DATABASE_URL -c "\dt oban_*"
```

### Instance Crash Recovery

```bash
# If instance crashes:
# 1. Jobs automatically marked as available (reserved_by = NULL)
# 2. Other instances will claim them
# 3. Check stale timeout setting (default 5 minutes)

# Verify in config/prod.exs:
config :singularity, Oban,
  engine: Oban.Engines.Basic,
  queues: [...],
  repo: Singularity.Repo,
  plugins: [
    Oban.Plugins.Cron,
    Oban.Plugins.Repeater  # Handles stale jobs
  ]
```

## Configuration Reference

### Oban Configuration

```elixir
# config/prod.exs
config :singularity, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    default: [limit: 10, paused: false],      # 10 concurrent per instance
    metrics: [limit: 5, paused: false],       # Results aggregation
    training: [limit: 2, paused: false],      # Model training
    pattern_mining: [limit: 3, paused: false] # Pattern discovery
  ],
  repo: Singularity.Repo,
  plugins: [
    Oban.Plugins.Cron,      # Schedule periodic tasks
    Oban.Plugins.Repeater   # Re-enqueue on crash
  ]
```

### Instance Configuration

```elixir
# config/prod.exs
config :singularity,
  instance_id: System.get_env("INSTANCE_ID") || "instance_#{Node.self()}",

  # Heartbeat interval (how often to update last_heartbeat)
  instance_heartbeat_interval: 5000,

  # Stale timeout (mark offline if no heartbeat for this many seconds)
  instance_stale_timeout: 300,

  # Result aggregation
  result_aggregation_interval: 30000,  # Send results every 30 seconds
  learning_sync_interval: 10000        # Check for learnings every 10 seconds
```

## Scaling Considerations

### When to Add More Instances

- Current instance CPU at >70%
- Current instance memory at >80%
- Job queue (oban_jobs.state='available') growing faster than processing
- Want redundancy/fault-tolerance

### When to Add CentralCloud

- Running 3+ instances
- Want to aggregate learnings across instances
- Need cost optimization across instances
- Want collective intelligence (patterns, models)

### When PostgreSQL Becomes Bottleneck

If PostgreSQL CPU/connections hit limits:
1. Add read replicas (for monitoring/reporting)
2. Scale Oban to fewer concurrent jobs per instance
3. Increase batch sizes to reduce polling frequency
4. At extreme scale: Consider pgflow's DAG system

But for typical use (2-10 instances), PostgreSQL is sufficient.

## Example: Progressive Deployment

```
Day 1: Development
  1 Singularity instance
  Sub-millisecond latencies
  Single developer

Day 7: Initial Production
  2 Singularity instances
  Load distributed
  Cost halved per instance
  Fault-tolerant

Day 30: Scaled Production
  5 Singularity instances
  CentralCloud learning aggregation
  Model routing optimized
  Cost savings: 20-30%

Day 90: Distributed Learning
  10+ Singularity instances
  CentralCloud insights shared
  Autonomous optimization
  Cost savings: 40-50%
```

## Next Steps

1. ✅ Implement Instance.Registry GenServer
2. ✅ Create ResultAggregatorWorker (UP channel)
3. ✅ Create LearningSyncWorker (DOWN channel)
4. ✅ Add migrations for instance_registry + job_results
5. ⏳ Deploy with 2 instances
6. ⏳ Verify job distribution and learning sync
7. ⏳ Scale to 3-5 instances
8. ⏳ Monitor costs and optimize routing

---

**Questions?** See:
- `ELIXIR_WORKFLOW_MULTI_BEAM_ARCHITECTURE.md` - Complete architecture
- `PGFLOW_vs_ELIXIR_WORKFLOW_COMPARISON.md` - Comparison with pgflow
- `ELIXIR_WORKFLOW_SYSTEM.md` - Workflow DSL documentation

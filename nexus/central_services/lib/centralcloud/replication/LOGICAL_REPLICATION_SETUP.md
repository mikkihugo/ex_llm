# PostgreSQL Logical Replication Setup

## Overview

CentralCloud publishes approved patterns and metrics via PostgreSQL Logical Replication.

Singularity and Genesis subscribe to these publications to maintain read-only local copies for fast access.

## Architecture

```
CentralCloud (central_services DB)
    ↓ PUBLICATION (native PostgreSQL)
    ├→ Singularity (singularity DB) - SUBSCRIPTION
    └→ Genesis (genesis DB) - SUBSCRIPTION
```

**Key benefits:**
- ✅ Native PostgreSQL (no external tools)
- ✅ Streaming replication (real-time)
- ✅ Automatic lag tracking
- ✅ Built-in error handling
- ✅ No application code needed
- ✅ ACID-compliant

---

## Step 1: Create Replication User (CentralCloud)

CentralCloud must allow replications from Singularity/Genesis.

```bash
# Connect to CentralCloud PostgreSQL
psql -h centralcloud_host -U postgres -d central_services

# Create replication user
CREATE ROLE replication_user WITH LOGIN REPLICATION PASSWORD 'your_secure_password';

# Grant USAGE on public schema
GRANT USAGE ON SCHEMA public TO replication_user;

# Grant SELECT on publication tables
GRANT SELECT ON approved_patterns TO replication_user;
GRANT SELECT ON job_statistics TO replication_user;
GRANT SELECT ON execution_metrics TO replication_user;
GRANT SELECT ON sync_log TO replication_user;

# Verify
\du replication_user
```

**Update pg_hba.conf to allow replication from Singularity/Genesis:**

```bash
# In /etc/postgresql/17/main/pg_hba.conf

# Singularity replication
host  central_services  replication_user  <singularity_ip>/32  md5

# Genesis replication
host  central_services  replication_user  <genesis_ip>/32  md5
```

Then reload PostgreSQL:
```bash
systemctl reload postgresql
```

---

## Step 2: Singularity - Create Target Tables

Singularity needs to create the target tables that will receive replicated data.

**File:** `singularity/priv/repo/migrations/YYYYMMDDXXXXXX_create_approved_patterns_replica.exs`

```elixir
defmodule Singularity.Repo.Migrations.CreateApprovedPatternsReplica do
  use Ecto.Migration

  def change do
    create table(:approved_patterns, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :name, :string, null: false
      add :ecosystem, :string, null: false
      add :frequency, :integer, default: 0
      add :confidence, :float, null: false, default: 0.0
      add :description, :text
      add :examples, :jsonb
      add :best_practices, {:array, :string}
      add :approved_at, :utc_datetime_usec
      add :last_synced_at, :utc_datetime_usec
      add :instances_count, :integer, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    # Unique constraint on pattern identity
    create unique_index(:approved_patterns, [:name, :ecosystem])

    # Search indexes
    create index(:approved_patterns, [:ecosystem])
    create index(:approved_patterns, [:confidence])
    create index(:approved_patterns, [:last_synced_at])
  end

  def down do
    drop table(:approved_patterns)
  end
end
```

---

## Step 3: Singularity - Create Subscription

**File:** `singularity/priv/repo/migrations/YYYYMMDDXXXXXX_subscribe_to_centralcloud_patterns.exs`

```elixir
defmodule Singularity.Repo.Migrations.SubscribeToCentralcloudPatterns do
  use Ecto.Migration

  def up do
    execute("""
      CREATE SUBSCRIPTION patterns_sub
      CONNECTION 'host=centralcloud_host port=5432 user=replication_user password=your_password dbname=central_services'
      PUBLICATION approved_patterns_pub
      WITH (create_slot = true, enabled = true);
    """)
  end

  def down do
    execute("DROP SUBSCRIPTION IF EXISTS patterns_sub;")
  end
end
```

**Environment Variables (Singularity):**

Add to `.env` or configuration:
```bash
# Replication credentials
CENTRALCLOUD_REPLICATION_HOST=centralcloud_host
CENTRALCLOUD_REPLICATION_PORT=5432
CENTRALCLOUD_REPLICATION_USER=replication_user
CENTRALCLOUD_REPLICATION_PASSWORD=your_secure_password
CENTRALCLOUD_REPLICATION_DB=central_services
```

**Or use Ecto configuration:**

```elixir
# config/config.exs
config :singularity, :replication,
  centralcloud_host: System.get_env("CENTRALCLOUD_REPLICATION_HOST", "127.0.0.1"),
  centralcloud_port: String.to_integer(System.get_env("CENTRALCLOUD_REPLICATION_PORT", "5432")),
  centralcloud_user: System.get_env("CENTRALCLOUD_REPLICATION_USER", "replication_user"),
  centralcloud_password: System.get_env("CENTRALCLOUD_REPLICATION_PASSWORD", ""),
  centralcloud_db: System.get_env("CENTRALCLOUD_REPLICATION_DB", "central_services")
```

---

## Step 4: Genesis - Create Target Tables

**File:** `genesis/priv/repo/migrations/YYYYMMDDXXXXXX_create_execution_metrics_replica.exs`

```elixir
defmodule Genesis.Repo.Migrations.CreateExecutionMetricsReplica do
  use Ecto.Migration

  def change do
    # Job-level statistics
    create table(:job_statistics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :job_id, :uuid, null: false
      add :language, :string, null: false
      add :status, :string, null: false  # running, completed, failed
      add :execution_time_ms, :integer
      add :memory_used_mb, :integer
      add :lines_analyzed, :integer
      add :instance_id, :string, null: false
      add :recorded_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:job_statistics, [:job_id])
    create index(:job_statistics, [:instance_id])
    create index(:job_statistics, [:status])
    create index(:job_statistics, [:recorded_at])

    # Aggregated metrics (5-minute windows)
    create table(:execution_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :period_start, :utc_datetime_usec, null: false
      add :period_end, :utc_datetime_usec, null: false
      add :jobs_completed, :integer, default: 0
      add :jobs_failed, :integer, default: 0
      add :success_rate, :float, default: 1.0
      add :avg_execution_time_ms, :integer
      add :total_memory_used_mb, :integer
      add :p50_execution_time_ms, :integer
      add :p95_execution_time_ms, :integer
      add :p99_execution_time_ms, :integer
      add :instance_id, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:execution_metrics, [:period_start, :period_end, :instance_id])
    create index(:execution_metrics, [:period_start])
    create index(:execution_metrics, [:instance_id])
  end

  def down do
    drop table(:execution_metrics)
    drop table(:job_statistics)
  end
end
```

---

## Step 5: Genesis - Create Subscriptions

**File:** `genesis/priv/repo/migrations/YYYYMMDDXXXXXX_subscribe_to_centralcloud_metrics.exs`

```elixir
defmodule Genesis.Repo.Migrations.SubscribeToCentralcloudMetrics do
  use Ecto.Migration

  def up do
    # Subscribe to job statistics
    execute("""
      CREATE SUBSCRIPTION job_stats_sub
      CONNECTION 'host=centralcloud_host port=5432 user=replication_user password=your_password dbname=central_services'
      PUBLICATION job_statistics_pub
      WITH (create_slot = true, enabled = true);
    """)

    # Subscribe to aggregated metrics
    execute("""
      CREATE SUBSCRIPTION metrics_sub
      CONNECTION 'host=centralcloud_host port=5432 user=replication_user password=your_password dbname=central_services'
      PUBLICATION execution_metrics_pub
      WITH (create_slot = true, enabled = true);
    """)
  end

  def down do
    execute("DROP SUBSCRIPTION IF EXISTS metrics_sub;")
    execute("DROP SUBSCRIPTION IF EXISTS job_stats_sub;")
  end
end
```

---

## Step 6: Monitoring Replication

### From CentralCloud (Publisher)

```elixir
alias CentralCloud.Replication.LogicalReplicationMonitor

# List all publications
{:ok, pubs} = LogicalReplicationMonitor.list_publications()
IO.inspect(pubs)

# List replication slots (one per subscriber)
{:ok, slots} = LogicalReplicationMonitor.list_replication_slots()
IO.inspect(slots)

# List active replication connections
{:ok, reps} = LogicalReplicationMonitor.list_active_replications()
IO.inspect(reps)

# Get replication health summary
{:ok, health} = LogicalReplicationMonitor.get_replication_health()
IO.inspect(health)
# %{
#   "publications_count" => 4,
#   "subscriptions_total" => 2,
#   "subscriptions_active" => 2,
#   "subscriptions_inactive" => 0,
#   "replication_lag" => 1024,  # bytes
#   "status" => "healthy",
#   "timestamp" => ~U[2025-01-10 10:15:30Z]
# }
```

**SQL queries (from CentralCloud):**

```sql
-- Check publications
SELECT pubname, pubinsert, pubupdate, pubdelete
FROM pg_publication
ORDER BY pubname;

-- Check replication slots
SELECT slot_name, slot_type, active, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots
ORDER BY slot_name;

-- Check active connections and lag
SELECT application_name, client_addr, state, write_lsn, flush_lsn, replay_lsn, replay_lag
FROM pg_stat_replication
ORDER BY application_name;
```

### From Singularity/Genesis (Subscriber)

```sql
-- Check subscriptions
SELECT subname, subpublications, subenabled
FROM pg_subscription;

-- Check subscription status
SELECT subname, pid, relid::regclass, srcsortby, srvname
FROM pg_stat_subscription
WHERE subname = 'patterns_sub';

-- Check per-table replication status
SELECT srsubid::pg_subscription.subname, srelname, sstate, received_lsn, decoded_lsn, flushed_lsn, applied_lsn
FROM pg_stat_subscription_rel;

-- Monitor progress
SELECT slot_name, restart_lsn, confirmed_flush_lsn
FROM pg_replication_slots
WHERE slot_name LIKE '%patterns%';
```

---

## Step 7: Troubleshooting

### Subscription Won't Connect

```sql
-- Check for errors
SELECT subname, suberror FROM pg_subscription;

-- View detailed error
SELECT * FROM pg_stat_subscription;

-- Manually refresh subscription (after fixing issue)
ALTER SUBSCRIPTION patterns_sub REFRESH PUBLICATION;
```

### Replication Lagging

```sql
-- Check lag in bytes
SELECT application_name, write_lsn, flush_lsn, replay_lsn,
       write_lsn - replay_lsn as lag_bytes
FROM pg_stat_replication;

-- Check for blocking queries on subscriber
SELECT * FROM pg_stat_activity
WHERE application_name = 'walreceiver';
```

### Slot Not Progressing

```sql
-- Check if subscription is enabled
SELECT subname, subenabled FROM pg_subscription WHERE subname = 'patterns_sub';

-- Enable if disabled
ALTER SUBSCRIPTION patterns_sub ENABLE;

-- Check for logical decoding errors
SELECT * FROM pg_stat_replication
WHERE application_name = 'patterns_sub';
```

### Disable/Enable Replication (Maintenance)

```sql
-- Disable subscription (stops replication)
ALTER SUBSCRIPTION patterns_sub DISABLE;

-- Do maintenance on subscriber...

-- Re-enable subscription
ALTER SUBSCRIPTION patterns_sub ENABLE;

-- Refresh publication list
ALTER SUBSCRIPTION patterns_sub REFRESH PUBLICATION;
```

---

## Step 8: Network Configuration (Production)

### Firewall Rules

**CentralCloud (PostgreSQL) must allow:**
- Singularity IP:5432 (replication)
- Genesis IP:5432 (replication)

```bash
# On CentralCloud host (ufw example)
ufw allow from <singularity_ip> to any port 5432
ufw allow from <genesis_ip> to any port 5432
```

### SSL/TLS (Production)

For production, use SSL for replication connections:

```elixir
# Migration example with SSL
execute("""
  CREATE SUBSCRIPTION patterns_sub
  CONNECTION 'host=centralcloud_host port=5432 user=replication_user password=pwd dbname=central_services sslmode=require'
  PUBLICATION approved_patterns_pub
  WITH (create_slot = true, enabled = true);
""")
```

---

## Step 9: Verify Replication Working

**On CentralCloud:**

```elixir
# Insert test pattern
Singularity.Repo.query!("""
  INSERT INTO approved_patterns (
    id, name, ecosystem, frequency, confidence, description, approved_at, last_synced_at,
    inserted_at, updated_at
  ) VALUES (
    uuid_generate_v7(), 'test_pattern', 'elixir', 1, 0.95, 'Test', NOW(), NOW(), NOW(), NOW()
  )
""")
```

**On Singularity:**

```elixir
# Verify pattern replicated
Singularity.Repo.query!("SELECT COUNT(*) FROM approved_patterns WHERE name = 'test_pattern'")
# Should return [1] within seconds
```

**Check replication lag:**

```elixir
# From CentralCloud
{:ok, health} = CentralCloud.Replication.LogicalReplicationMonitor.get_replication_health()
IO.inspect(health["replication_lag"])  # Should be 0 or very small
```

---

## Step 10: Production Deployment Checklist

- ✅ Replication user created with minimal privileges
- ✅ pg_hba.conf updated for replication access
- ✅ Firewall allows PostgreSQL ports
- ✅ SSL enabled for replication (sslmode=require)
- ✅ Target tables created on subscribers
- ✅ Subscriptions enabled and active
- ✅ Replication lag < 1 second
- ✅ Monitoring queries set up
- ✅ Backup strategy includes replication slots
- ✅ Disaster recovery tested

---

## Performance Characteristics

| Metric | Value | Note |
|--------|-------|------|
| Replication Latency | < 100ms | Real-time streaming |
| Max Throughput | ~10k inserts/sec | Per table |
| Slot Storage | Minimal | Only WAL retention |
| CPU Impact | < 5% | On both publisher/subscriber |
| Network Bandwidth | ~100 bytes/insert | Compressed |

---

## Comparison: Logical Replication vs Alternatives

| Feature | Logical Rep | pg_net HTTP | postgres_fdw |
|---------|------------|-------------|-------------|
| Real-time | ✅ Yes | ✅ Yes | ❌ Scheduled |
| ACID Compliance | ✅ Yes | ❌ Eventual | ✅ Yes |
| Built-in | ✅ Yes | ❌ Extension | ✅ Yes |
| Streaming | ✅ Yes | ❌ Polling | ❌ No |
| Lag Monitoring | ✅ Native | ✅ Custom | ❌ Limited |
| Network Traffic | ✅ Minimal | ❌ High | ✅ Minimal |
| Setup Complexity | ✅ Simple | ❌ Complex | ✅ Moderate |

**Chosen: Logical Replication** ✅

---

## References

- [PostgreSQL Logical Replication](https://www.postgresql.org/docs/17/logical-replication.html)
- [CREATE PUBLICATION](https://www.postgresql.org/docs/17/sql-createpublication.html)
- [CREATE SUBSCRIPTION](https://www.postgresql.org/docs/17/sql-createsubscription.html)
- [pg_replication_slots View](https://www.postgresql.org/docs/17/view-pg-replication-slots.html)
- [pg_stat_replication View](https://www.postgresql.org/docs/17/view-pg-stat-replication.html)

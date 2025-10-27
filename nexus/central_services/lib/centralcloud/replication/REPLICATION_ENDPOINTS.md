# Replication Endpoints - CentralCloud → Singularity/Genesis

## Overview

CentralCloud uses PostgreSQL `pg_net` extension + `pg_cron` to push approved patterns and metrics to Singularity instances in **real-time** (every 5 seconds).

Each Singularity instance must expose HTTP endpoints to receive these replications.

## Endpoint 1: Pattern Sync (Singularity)

**URL:** `POST /sync/patterns`
**Authentication:** Optional (internal network)
**Frequency:** Every 5 seconds (async via pg_net)
**Timeout:** 5 seconds

### Request Headers
```
Content-Type: application/json
X-Sync-Event-Type: INSERT | UPDATE
X-Sync-Table: approved_patterns
X-Sync-Record-Id: <uuid>
```

### Request Body (approved_patterns record)
```json
{
  "id": "uuid-v7",
  "name": "gen_server_pattern",
  "ecosystem": "elixir",
  "frequency": 156,
  "confidence": 0.94,
  "description": "Pattern for GenServer state management",
  "examples": {
    "code_snippet": "...",
    "usage_context": "..."
  },
  "best_practices": ["..."],
  "approved_at": "2025-01-10T...",
  "last_synced_at": "2025-01-10T...",
  "instances_count": 3,
  "inserted_at": "2025-01-10T...",
  "updated_at": "2025-01-10T..."
}
```

### Response (Success)
```
HTTP 200 OK

{
  "status": "ok",
  "pattern_id": "uuid",
  "pattern_name": "gen_server_pattern",
  "synced_at": "2025-01-10T...",
  "local_record_count": 42
}
```

### Response (Error)
```
HTTP 400 Bad Request

{
  "status": "error",
  "error": "invalid_pattern",
  "message": "Pattern validation failed"
}
```

### Implementation (Singularity - Elixir)

```elixir
# In Singularity.API.SyncController

def sync_patterns(conn, params) do
  case Singularity.Replication.PatternSync.upsert_pattern(params) do
    {:ok, result} ->
      json(conn, %{
        status: "ok",
        pattern_id: result.id,
        pattern_name: result.name,
        synced_at: DateTime.utc_now(),
        local_record_count: count_approved_patterns()
      })

    {:error, reason} ->
      conn
      |> put_status(400)
      |> json(%{
        status: "error",
        error: "sync_failed",
        message: inspect(reason)
      })
  end
end
```

### Handler Module (Singularity)

```elixir
# lib/singularity/replication/pattern_sync.ex

defmodule Singularity.Replication.PatternSync do
  def upsert_pattern(pattern_data) do
    case Repo.insert_or_update(%ApprovedPattern{}, pattern_data) do
      {:ok, pattern} ->
        Logger.info("[PatternSync] ✓ Synced pattern #{pattern.name}")
        {:ok, pattern}

      {:error, changeset} ->
        Logger.error("[PatternSync] ✗ Failed: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
end
```

---

## Endpoint 2: Metrics Sync (Genesis)

**URL:** `POST /sync/metrics`
**Authentication:** Optional (internal network)
**Frequency:** Every 5 seconds (async via pg_net)
**Timeout:** 5 seconds

### Request Headers
```
Content-Type: application/json
X-Sync-Event-Type: INSERT
X-Sync-Table: execution_metrics
X-Sync-Record-Id: <uuid>
```

### Request Body (execution_metrics record)
```json
{
  "id": "uuid-v7",
  "period_start": "2025-01-10T10:00:00Z",
  "period_end": "2025-01-10T10:05:00Z",
  "jobs_completed": 156,
  "jobs_failed": 3,
  "success_rate": 0.98,
  "avg_execution_time_ms": 892,
  "total_memory_used_mb": 2450,
  "p50_execution_time_ms": 750,
  "p95_execution_time_ms": 2100,
  "p99_execution_time_ms": 3500,
  "instance_id": "singularity-1",
  "inserted_at": "2025-01-10T...",
  "updated_at": "2025-01-10T..."
}
```

### Response (Success)
```
HTTP 200 OK

{
  "status": "ok",
  "metrics_id": "uuid",
  "success_rate": 0.98,
  "synced_at": "2025-01-10T...",
  "local_metrics_count": 1234
}
```

### Implementation (Genesis - Elixir)

```elixir
# In Genesis.API.SyncController

def sync_metrics(conn, params) do
  case Genesis.Replication.MetricsSync.upsert_metrics(params) do
    {:ok, result} ->
      json(conn, %{
        status: "ok",
        metrics_id: result.id,
        success_rate: result.success_rate,
        synced_at: DateTime.utc_now(),
        local_metrics_count: count_execution_metrics()
      })

    {:error, reason} ->
      conn
      |> put_status(400)
      |> json(%{
        status: "error",
        error: "metrics_sync_failed",
        message: inspect(reason)
      })
  end
end
```

---

## Endpoint 3: Replication Status (CentralCloud)

**URL:** `GET /admin/replication/status`
**Authentication:** Admin only
**Returns:** Status of all replication instances and queue

### Response
```json
{
  "instances": [
    {
      "instance_id": "uuid",
      "instance_name": "singularity-prod-1",
      "http_endpoint": "http://localhost:4000/sync/patterns",
      "is_active": true,
      "last_sync_at": "2025-01-10T10:15:30Z",
      "success_count": 45230,
      "error_count": 2,
      "last_error": null
    }
  ],
  "queue_stats": {
    "pending": 0,
    "success": 45230,
    "failed": 2,
    "total": 45232,
    "last_event_at": "2025-01-10T10:15:30Z"
  },
  "replication_enabled": true,
  "replication_interval_seconds": 5
}
```

### Implementation (CentralCloud)

```elixir
# In CentralCloud.Admin.ReplicationController

def status(conn, _params) do
  {:ok, instances} = CentralCloud.Replication.InstanceRegistry.list_active_instances()
  {:ok, queue_stats} = CentralCloud.Replication.InstanceRegistry.get_queue_stats()

  json(conn, %{
    instances: instances,
    queue_stats: queue_stats,
    replication_enabled: true,
    replication_interval_seconds: 5
  })
end
```

---

## Error Handling & Retries

**pg_net behavior (automatic):**
- ✅ Retries failed requests up to 3 times
- ✅ Exponential backoff (5s, 10s, 20s)
- ✅ Timeout after 5 seconds per request
- ✅ Logs all attempts in `replication_queue` table

**Singularity/Genesis implementation:**
- ✅ Idempotent UPSERTs (using `record_id` as key)
- ✅ Return HTTP 200 on successful upsert
- ✅ Return HTTP 400 + error message on validation failure
- ✅ HTTP 500 will trigger pg_net retry

---

## Registering a New Instance

From CentralCloud Elixir:

```elixir
CentralCloud.Replication.InstanceRegistry.register_instance(%{
  instance_name: "singularity-prod-1",
  instance_id: Ecto.UUID.generate(),
  http_endpoint: "http://singularity-prod-1.internal:4000/sync/patterns"
})
```

This immediately starts sending replication events to that endpoint every 5 seconds.

---

## Monitoring Replication Health

```elixir
# Check instance status
{:ok, status} = CentralCloud.Replication.InstanceRegistry.get_instance_status(instance_id)
IO.inspect(status)
# %{
#   "instance_id" => "...",
#   "last_sync_at" => "2025-01-10T10:15:30Z",
#   "error_count" => 0,
#   "success_count" => 45230,
#   "last_error" => nil
# }

# Check queue stats
{:ok, stats} = CentralCloud.Replication.InstanceRegistry.get_queue_stats()
IO.inspect(stats)
# %{
#   pending: 0,
#   success: 45230,
#   failed: 0,
#   total: 45230,
#   last_event_at: ~U[2025-01-10 10:15:30Z]
# }
```

---

## Production Readiness

✅ **Features:**
- Real-time push (every 5 seconds)
- Event-driven (triggers on INSERT/UPDATE)
- Async processing (pg_cron worker)
- Automatic retries (up to 3x)
- Audit trail (replication_queue table)
- Error tracking (instance last_error)
- Idempotent operations (no duplicates)
- Zero application latency (happens in database)

✅ **Monitoring:**
- Queue stats endpoint
- Instance health status
- Error tracking per instance
- Success/failure counts

✅ **Security:**
- Optional HTTP authentication (add bearer token support)
- HTTPS in production (add to endpoint URL)
- Internal network access (Singularity/Genesis on private network)

---

## Next Steps

1. **Singularity**: Implement `POST /sync/patterns` endpoint
2. **Genesis**: Implement `POST /sync/metrics` endpoint
3. **CentralCloud**: Register instances via `InstanceRegistry.register_instance/1`
4. **Monitor**: Check `/admin/replication/status` to verify sync working

# 5-Database Architecture Summary

**Complete data isolation with pgmq-based inter-service communication (NOT Ecto)**

## Overview

Singularity ecosystem uses **5 separate PostgreSQL databases** with **complete data isolation** and **inter-service communication via pgmq** (PostgreSQL Message Queue - native extension, not ORM).

```
CentralCloud (Elixir + Ecto)
│
├─ OWNS: shared_queue database (pgmq - native)
│        90-day message retention
│
├─ MANAGES: All queue initialization and pruning
│
└─ READS: Archive tables for analytics (read-only)


 ┌──────────┬─────────────┬────────────┬───────────────┐
 │          │             │            │               │
singularity genesis       nexus     centralcloud      (consumers)
(Ecto)     (Ecto)        (Drizzle)   (Ecto - RO)

   ↓          ↓             ↓            ↓
shared_queue (pgmq - 8 queues)
   ↓          ↓             ↓            ↓
LLM requests, job requests, approvals, questions
```

## The 3 ORM Types (Hybrid Approach)

| ORM | Database | Language | Purpose |
|-----|----------|----------|---------|
| **Ecto Repo** | singularity | Elixir | Application data (Agent execution, tasks) |
| **Ecto Repo** | genesis | Elixir | Application data (Code execution results) |
| **Ecto Repo** | centralcloud | Elixir | Application data (Learning, intelligence) |
| **Ecto Repo** | shared_queue | Elixir | Read-only analytics on message archives |
| **pgmq** | shared_queue | Native SQL | Message queue pub/sub (high-performance) |
| **Drizzle ORM** | nexus | TypeScript | Configuration (Models, providers) |

**Terminology Note:** "Repo" = Ecto Database Repository (NOT Git repository). Standard Elixir naming.

**shared_queue uses BOTH:**
- **pgmq functions** for publish/subscribe (high-performance messaging)
- **Ecto schemas** for querying archived messages (type-safe analytics)

## The 5 Databases

### 1. **singularity** (Elixir + Ecto)
- **Ownership:** Each instance (separate DB per instance)
- **Purpose:** Agent execution, task planning, reasoning
- **ORM:** Ecto (schema-based)
- **Access:** Own database + shared_queue (pgmq)
- **Size:** Variable (agents, tasks, learning)

### 2. **genesis** (Elixir + Ecto)
- **Ownership:** Single Genesis instance
- **Purpose:** Code execution, validation, linting
- **ORM:** Ecto
- **Access:** Own database + shared_queue (pgmq)
- **Size:** Small (ephemeral results)

### 3. **centralcloud** (Elixir + Ecto)
- **Ownership:** CentralCloud application
- **Purpose:** Framework learning, intelligence, analytics
- **ORM:** Ecto
- **Access:** Own database (RW) + shared_queue (RO archives only)
- **Size:** Grows with patterns

### 4. **nexus** (TypeScript + Drizzle ORM)
- **Ownership:** Nexus application
- **Purpose:** LLM routing, HITL approval UI
- **ORM:** Drizzle (TypeScript, SQL-first)
- **Access:** Own database + shared_queue (pgmq)
- **Size:** Small (config) + optional logs

### 5. **shared_queue** (PostgreSQL + pgmq + Ecto)
- **Ownership:** CentralCloud EXCLUSIVELY (creates & manages)
- **Extension:** pgmq (native PostgreSQL message queue)
- **Purpose:** Central durable message hub
- **Access:**
  - **pgmq functions** for publish/subscribe (all services)
  - **Ecto schemas** (SharedQueueRepo) for read-only archive queries (CentralCloud analytics)
- **Retention:** 90 days (auto-pruned)
- **Hybrid Approach:** pgmq for performance + Ecto for type-safe queries

## Hybrid: pgmq + Ecto (Best of Both)

✅ **pgmq for publishing/subscribing:**
- Native PostgreSQL message queue (efficient)
- ACID-compliant transactions
- Automatic archival and retention
- Language-agnostic (Elixir, TypeScript, Rust)
- High-throughput messaging
- No ORM overhead

✅ **Ecto for analytics on archives:**
- Type-safe queries on archived messages
- Read-only access to SharedQueueRepo
- Standard Ecto query syntax
- CentralCloud can aggregate learnings from message patterns
- Beautiful integration with existing Ecto code

**Why both?**
- pgmq is optimized for messaging (performance)
- Ecto is optimized for analytics (type safety + convenience)
- Each tool does what it does best

## Queue Architecture

### 8 Message Types (pgmq queues)

| Queue | Publisher | Consumers | Data | Flow |
|-------|-----------|-----------|------|------|
| `llm_requests` | Singularity | Nexus | {agent_id, task_type, messages} | → |
| `llm_results` | Nexus | Singularity | {request_id, result, model} | ← |
| `approval_requests` | Singularity | Nexus, Browser | {id, file_path, diff} | → |
| `approval_responses` | Browser | Singularity | {request_id, approved} | ← |
| `question_requests` | Singularity | Nexus, Browser | {id, question} | → |
| `question_responses` | Browser | Singularity | {request_id, response} | ← |
| `job_requests` | Singularity | Genesis | {id, code, language} | → |
| `job_results` | Genesis | Singularity | {request_id, output, error} | ← |

Each queue has `_archive` table (kept 90 days for analysis).

## Configuration

### Environment Variables

```bash
# Shared Queue (CentralCloud owns this)
SHARED_QUEUE_ENABLED=true
SHARED_QUEUE_DB_URL="postgresql://localhost/shared_queue"
SHARED_QUEUE_RETENTION_DAYS=90
```

### Singularity Config

```elixir
config :singularity, :shared_queue,
  enabled: true,
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  poll_interval_ms: 1000,
  batch_size: 10
```

### CentralCloud Config

```elixir
config :centralcloud, :shared_queue,
  enabled: true,
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  auto_initialize: true,
  retention_days: 90
```

## Data Isolation

### What Each Service Can Access

| Service | Own DB | shared_queue | Others' DBs |
|---------|--------|--------------|------------|
| Singularity | ✅ RW | ✅ RW (pgmq) | ❌ No |
| Genesis | ✅ RW | ✅ RW (pgmq) | ❌ No |
| Nexus | ✅ RW | ✅ RW (pgmq) | ❌ No |
| CentralCloud | ✅ RW | ✅ RO (pgmq) | ❌ No |

**Guarantees:**
- ✅ No cross-instance data leakage
- ✅ No unauthorized database access
- ✅ Config isolation (Nexus secrets private)
- ✅ Learning privacy (CentralCloud intelligence not shared)

## Setup Steps

```bash
# 1. Create databases
createdb singularity genesis centralcloud nexus shared_queue

# 2. CentralCloud initializes shared_queue at startup
# (via SharedQueueManager - creates pgmq extension)

# 3. Run migrations
cd singularity && mix ecto.migrate
cd genesis && mix ecto.migrate
cd centralcloud && mix ecto.migrate
cd nexus && bunx drizzle-kit push

# 4. Verify
psql shared_queue -c "SELECT * FROM pgmq.queue_list();"
```

## Multi-Instance Singularity

When running multiple Singularity instances:

```
Instance 1 DB    Instance 2 DB    Instance 3 DB
(singularity_1)  (singularity_2)  (singularity_3)
      ↓                ↓                ↓
    ╚══════════════ shared_queue ═══════╝
              (pgmq - CentralCloud owned)
                        ↓
            CentralCloud + learning
```

Each instance is completely isolated. They coordinate ONLY through pgmq messages.

## Access Patterns

### Singularity (Ecto + pgmq)
```elixir
# Own data - use Ecto
Singularity.Repo.insert!(agent)

# Shared queue - use pgmq
SharedQueuePublisher.publish_llm_request(request)
SharedQueuePublisher.read_llm_results()
```

### Nexus (Drizzle + pgmq)
```typescript
// Own config - use Drizzle
await db.insert(models).values(config)

// Shared queue - use pgmq client
await sharedQueue.read('llm_requests')
```

### CentralCloud (Ecto + pgmq + SharedQueueRepo)
```elixir
# Own data - use CentralCloud.Repo
CentralCloud.Repo.all(Pattern)

# Archive queries - use SharedQueueRepo with schemas
import Ecto.Query

# Type-safe query on LLM request archives
from(msg in CentralCloud.SharedQueueSchemas.LLMRequestArchive,
  where: msg.enqueued_at > ago(7, "day"),
  select: msg.msg
) |> CentralCloud.SharedQueueRepo.all()

# Count approvals from last 30 days
CentralCloud.SharedQueueSchemas.ApprovalRequestArchive
|> where([m], m.enqueued_at > ago(30, "day"))
|> CentralCloud.SharedQueueRepo.aggregate(:count)

# Analyze question response patterns
CentralCloud.SharedQueueSchemas.QuestionResponseArchive
|> CentralCloud.SharedQueueRepo.all()
|> Enum.group_by(& &1.msg["agent_id"])
```


## Files

**Documentation:**
- `DATABASE_ARCHITECTURE.md` - Complete reference
- `ARCHITECTURE_SUMMARY.md` - This file (quick overview)
- `shared_queue/README.md` - Setup guide

**CentralCloud (Owner):**
- `centralcloud/lib/centralcloud/shared_queue_manager.ex` - pgmq initialization
- `centralcloud/lib/centralcloud/shared_queue_repo.ex` - Ecto repository for querying
- `centralcloud/lib/centralcloud/shared_queue_schemas.ex` - Ecto schemas (16 tables)
- `centralcloud/config/config.exs` - Database + Manager configuration

**Singularity (Producer):**
- `singularity/lib/singularity/shared_queue_publisher.ex` - Publish to pgmq
- `singularity/config/config.exs` - Configuration

**Nexus (Consumer):**
- `nexus/src/shared-queue-handler.ts` - Consume from pgmq

## Summary

| Aspect | Details |
|--------|---------|
| **Total Databases** | 5 (singularity, genesis, centralcloud, nexus, shared_queue) |
| **Queue System** | pgmq (PostgreSQL native) |
| **Analytics Queries** | Ecto schemas + SharedQueueRepo |
| **Message Types** | 8 (LLM, approvals, questions, jobs) |
| **Archive Tables** | 16 (8 active + 8 archives) |
| **Retention** | 90 days (auto-archived and pruned) |
| **Owner of shared_queue** | CentralCloud (exclusive) |
| **Data Isolation** | Complete (no cross-service access) |
| **Configuration** | Environment variables + config.exs |
| **ORMs Used** | Ecto (3 DBs), Drizzle (1 DB), pgmq (1 DB) |

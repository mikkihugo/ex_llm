# Shared Queue Database

Central PostgreSQL message queue for all Singularity instances, Genesis, CentralCloud, and Nexus.

## Overview

Replaces NATS with PostgreSQL `pgmq` extension for durable, ACID-compliant messaging:
- **LLM Requests** - Route agent requests to AI providers (Singularity → Nexus)
- **Approval Requests** - HITL approval workflows (Singularity → Nexus → Browser)
- **Question Requests** - Agent questions to humans (Singularity → Nexus → Browser)
- **Job Results** - Return responses back to agents (Nexus → Singularity)

## Database

```
Database: shared_queue
Host: localhost (DB_HOST env var)
Port: 5432 (DB_PORT env var)
User: postgres (DB_USER env var)
Extension: pgmq (PostgreSQL Message Queue)
```

## Queue Tables (via pgmq)

pgmq provides these automatically:
- `pgmq.llm_requests` - Active LLM requests
- `pgmq.llm_requests_archive` - Historical LLM requests
- `pgmq.approval_requests` - Active approval requests
- `pgmq.approval_requests_archive` - Historical approvals
- `pgmq.question_requests` - Active question requests
- `pgmq.question_requests_archive` - Historical questions

Each queue table has:
- `msg_id` (BIGINT) - Unique message ID
- `read_ct` (INT) - Read count
- `enqueued_at` (TIMESTAMP) - When enqueued
- `vt` (TIMESTAMP) - Visibility timeout
- `msg` (JSONB) - Message content

## Setup

```bash
# 1. Create database
createdb shared_queue

# 2. Create pgmq extension
psql shared_queue -c "CREATE EXTENSION pgmq"

# 3. Initialize queues (via Drizzle migration)
bunx drizzle-kit push -d nexus_llm_server

# 4. Test connection
psql shared_queue -c "SELECT * FROM pgmq.queue_list();"
```

## Architecture

### Message Flow: LLM Request

```
Singularity Agent
    ↓
INSERT INTO pgmq.llm_requests (msg)
    ↓
shared_queue database
    ↓
Nexus polls: SELECT * FROM pgmq.read('llm_requests', limit:10)
    ↓
Nexus calls Claude/Gemini/etc
    ↓
Nexus archives: SELECT pgmq.archive('llm_requests', msg_id)
    ↓
INSERT INTO pgmq.llm_results (msg)
    ↓
Singularity reads: SELECT * FROM pgmq.read('llm_results')
    ↓
Agent processes result
```

### Database Services

| Service | Role | Reads From | Writes To |
|---------|------|-----------|-----------|
| **Singularity** | Agent orchestration | llm_results, job_results | llm_requests, approval_responses, question_responses |
| **Nexus** | LLM Router + HITL Bridge | llm_requests, approval_responses | llm_results |
| **CentralCloud** | Analytics (read-only) | All queues | (none) |
| **Genesis** | Code execution | job_requests | job_results |

## Configuration

### Environment Variables

```bash
# shared_queue database
SHARED_QUEUE_DB_URL="postgresql://postgres:@localhost:5432/shared_queue"

# Or individual components
SHARED_QUEUE_HOST=localhost
SHARED_QUEUE_PORT=5432
SHARED_QUEUE_USER=postgres
SHARED_QUEUE_PASSWORD=
```

### Singularity Configuration

```elixir
# config/config.exs
config :singularity, :shared_queue,
  enabled: true,
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  llm_requests_queue: "llm_requests",
  approval_requests_queue: "approval_requests",
  question_requests_queue: "question_requests",
  poll_interval_ms: 1000,
  batch_size: 10
```

### Nexus Configuration

```typescript
// nexus/src/config.ts
export const sharedQueueConfig = {
  enabled: true,
  databaseUrl:
    process.env.SHARED_QUEUE_DB_URL ||
    `postgresql://${process.env.SHARED_QUEUE_USER || 'postgres'}:${process.env.SHARED_QUEUE_PASSWORD || ''}@${process.env.SHARED_QUEUE_HOST || 'localhost'}:${process.env.SHARED_QUEUE_PORT || '5432'}/shared_queue`,
  llmRequestsQueue: 'llm_requests',
  approvalRequestsQueue: 'approval_requests',
  questionRequestsQueue: 'question_requests',
  pollIntervalMs: 1000,
  batchSize: 10,
};
```

## Testing

```bash
# 1. List all queues
psql shared_queue -c "SELECT * FROM pgmq.queue_list();"

# 2. Send test message
psql shared_queue -c "SELECT * FROM pgmq.send('llm_requests', '{\"agent_id\": \"test\", \"task\": \"hello\"}')"

# 3. Read messages
psql shared_queue -c "SELECT * FROM pgmq.read('llm_requests', limit:=1);"

# 4. Watch real-time
watch "psql shared_queue -c \"SELECT msg_id, read_ct, enqueued_at FROM pgmq.llm_requests LIMIT 10;\""
```

## Migration from NATS

1. **Phase 1: Both Active (Safe)**
   - Deploy Nexus with pgmq consumer
   - Keep NATS running (agents still use NATS)
   - Nexus reads from BOTH pgmq and NATS

2. **Phase 2: Primary Cutover**
   - Agents switch to publish to pgmq
   - Nexus only reads pgmq
   - Archive NATS messages for safety

3. **Phase 3: NATS Retirement**
   - Remove NATS from deployment
   - Confirm all systems stable
   - Archive pgmq history to cold storage

## Files

- `nexus_llm_server/drizzle/shared_queue_schema.ts` - Drizzle schema
- `nexus_llm_server/src/shared-queue-handler.ts` - pgmq consumer
- `singularity/lib/singularity/shared_queue_publisher.ex` - pgmq publisher
- `DATABASE_SETUP.md` - Database initialization guide

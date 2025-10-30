# Shared Queue Database

Central PostgreSQL message queue for all Singularity instances, Genesis, CentralCloud, and external services.

## Overview

Replaces NATS with PostgreSQL `pgmq` extension for durable, ACID-compliant messaging:
- **LLM Requests** - Route agent requests to AI providers (Singularity → External LLM router)
- **Approval Requests** - HITL approval workflows (Singularity → External HITL bridge → Browser)
- **Question Requests** - Agent questions to humans (Singularity → External HITL bridge → Browser)
- **Job Results** - Return responses back to agents (External LLM router → Singularity)

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

# 3. Initialize queues (via CentralCloud migration)
cd centralcloud && mix ecto.migrate

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
External LLM router polls: SELECT * FROM pgmq.read('llm_requests', limit:10)
    ↓
External LLM router calls Claude/Gemini/etc
    ↓
External LLM router archives: SELECT pgmq.archive('llm_requests', msg_id)
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
| **External LLM Router** | LLM Router + HITL Bridge | llm_requests, approval_responses | llm_results |
| **CentralCloud** | Analytics (read-only) | All queues | (none) |
| **Genesis** | Code execution | job_requests | job_results |

## QuantumFlow Integration

### Why QuantumFlow vs pgmq/pgmq

While pgmq provides excellent PostgreSQL-native queuing, QuantumFlow was chosen for the Broadway embedding pipeline because:

- **Workflow Orchestration**: QuantumFlow provides higher-level workflow management with job dependencies, retries, and state tracking
- **Complex Job Lifecycle**: Embedding pipelines require multi-step workflows (data prep → batch processing → result aggregation)
- **Reliability Guarantees**: QuantumFlow's transactional semantics ensure embedding jobs complete or fail atomically
- **Monitoring & Observability**: Built-in metrics and tracing for production embedding workloads
- **Scalability**: Better suited for long-running, resource-intensive embedding jobs vs simple message passing

pgmq remains the primary choice for simple message queuing (LLM requests, approvals), while QuantumFlow handles complex workflows like embedding generation.

### Operating QuantumFlow Workflows for Embeddings

#### Enqueueing Embedding Jobs

```elixir
# Create embedding workflow job
{:ok, job_id} = QuantumFlow.enqueue_job(%{
  type: "embedding_pipeline",
  payload: %{
    artifacts: [
      %{id: 1, artifact_id: "doc_1", content: %{"title" => "Document Title"}},
      %{id: 2, artifact_id: "doc_2", content: "Plain text content"}
    ],
    device: :cuda,
    workers: 10,
    batch_size: 16
  },
  queue: "embedding_jobs",
  priority: 1,
  max_attempts: 3
})
```

#### Checking Job Status

```elixir
# Get job status
{:ok, job} = QuantumFlow.get_job(job_id)
# Returns: %{status: :pending|:running|:completed|:failed, progress: 0.0..1.0}

# List active embedding jobs
{:ok, jobs} = QuantumFlow.list_jobs(queue: "embedding_jobs", status: :running)

# Get job metrics
{:ok, metrics} = QuantumFlow.get_queue_metrics("embedding_jobs")
# Returns: %{pending: 5, running: 2, completed: 100, failed: 1}
```

#### Workflow Execution

```elixir
# Monitor workflow progress
case QuantumFlow.get_job(job_id) do
  {:ok, %{status: :completed, result: result}} ->
    # Process completed embedding results
    process_embedding_results(result)

  {:ok, %{status: :running, progress: progress}} ->
    # Update progress UI
    IO.puts("Embedding progress: #{Float.round(progress * 100, 1)}%")

  {:ok, %{status: :failed, error: error}} ->
    # Handle failure
    Logger.error("Embedding job failed: #{inspect(error)}")
end
```

#### Batch Operations

```elixir
# Enqueue multiple embedding jobs
artifacts_batches = Enum.chunk_every(all_artifacts, 100)

jobs = Enum.map(artifacts_batches, fn batch ->
  QuantumFlow.enqueue_job(%{
    type: "embedding_pipeline",
    payload: %{artifacts: batch, device: :cuda, workers: 8, batch_size: 12},
    queue: "embedding_jobs"
  })
end)

# Wait for all jobs to complete
QuantumFlow.wait_for_jobs(jobs, timeout: :timer.minutes(30))
```

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

### External LLM Router Configuration

Configuration for external LLM routing service (if using):

```typescript
// Example configuration
export const sharedQueueConfig = {
  enabled: true,
  databaseUrl: process.env.SHARED_QUEUE_DB_URL,
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
   - Deploy external LLM router with pgmq consumer
   - Keep NATS running (agents still use NATS)
   - External router reads from BOTH pgmq and NATS

2. **Phase 2: Primary Cutover**
   - Agents switch to publish to pgmq
   - External router only reads pgmq
   - Archive NATS messages for safety

3. **Phase 3: NATS Retirement (COMPLETED)**
   - NATS removed from deployment
   - All systems using pgmq
   - Archive pgmq history to cold storage as needed

## Files

- `centralcloud/lib/centralcloud/shared_queue_registry.ex` - Queue registry
- `centralcloud/lib/centralcloud/shared_queue_manager.ex` - Queue manager
- `singularity/lib/singularity/shared_queue_publisher.ex` - pgmq publisher
- `singularity/lib/singularity/shared_queue_consumer.ex` - pgmq consumer
- `DATABASE_SETUP.md` - Database initialization guide

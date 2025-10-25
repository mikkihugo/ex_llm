# 5-Database Architecture

Complete data isolation between services with a central message queue (shared_queue) for inter-service communication.

## Database Overview

```
┌─────────────────────────────────────────────────────────────────┐
│            Shared Queue Database (CentralCloud OWNED)            │
│                    (Central Message Hub)                         │
│  - pgmq: llm_requests          (Singularity → Nexus)             │
│  - pgmq: approval_requests     (Singularity → Nexus → Browser)   │
│  - pgmq: question_requests     (Singularity → Nexus → Browser)   │
│  - pgmq: job_requests          (Singularity → Genesis)           │
│  - pgmq: llm_results           (Nexus → Singularity)             │
│  - pgmq: job_results           (Genesis → Singularity)           │
│  - pgmq: approval_responses    (Browser → Singularity)           │
│  (All other services are CONSUMERS only)                         │
└─────────────────────────────────────────────────────────────────┘
           ↓            ↓            ↓            ↓
   ┌─────────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐
   │ Singularity │ │ CentralC │ │  Genesis │ │   Nexus    │
   │ (1+ instances)│  cloud  │ │  (code   │ │ (LLM Router│
   │             │ │(Owner of │ │execution)│ │+ HITL UI)  │
   │ - Agents    │ │shared_q) │ │          │ │            │
   │ - Tasks     │ │          │ │ - Execution │ - Config │
   │ - Planning  │ │ - Patterns│ │ - Results │ - Models   │
   │ - Reasoning │ │ - Learning │ - Metrics │ - Providers│
   └─────────────┘ └──────────┘ └──────────┘ └────────────┘
```

**Key Point:** CentralCloud is the SOLE OWNER of the shared_queue database.
All other services (Singularity, Genesis, Nexus) are CONSUMERS that read/write to the queues
owned by CentralCloud. This ensures centralized management and prevents conflicts.

## Database Details

### 1. **singularity** (Elixir)
**Purpose:** Main orchestration, agent execution, task planning, reasoning

**Private Data (NOT shared):**
- Agents and agent state
- Task execution history
- Planning decisions
- SPARC methodology results
- Cost tracking per agent instance
- Learning artifacts (specific to this instance)

**Access to:**
- **shared_queue (read/write)** - Publish LLM/approval/question requests; read results

**Size:** Variable (depends on how many agents, tasks, learning artifacts)

**Isolation:** Each Singularity instance has its own database. Multiple instances do NOT share this database.

```elixir
# Singularity publishes to shared_queue
defmodule Singularity.SharedQueuePublisher do
  def publish_llm_request(request) do
    # INSERT INTO pgmq.llm_requests (msg)
    SharedQueue.publish(:llm_requests, request)
  end

  def publish_approval_request(request) do
    # INSERT INTO pgmq.approval_requests (msg)
    SharedQueue.publish(:approval_requests, request)
  end

  def publish_job_request(request) do
    # INSERT INTO pgmq.job_requests (msg)
    SharedQueue.publish(:job_requests, request)
  end

  def read_llm_results() do
    # SELECT * FROM pgmq.read('llm_results', limit := 10)
    SharedQueue.read(:llm_results, limit: 10)
  end
end
```

### 2. **centralcloud** (Elixir)
**Purpose:** Framework learning, package intelligence, knowledge aggregation

**Private Data (NOT shared, NOT readable by Singularity):**
- Learned framework patterns
- Package metadata aggregation
- Framework learning progress
- Technology stack analysis
- Collected knowledge from all instances (if multi-instance)
- Intelligence Hub state

**Access to:**
- **shared_queue (read-only)** - Analytics: analyze request patterns, approval trends, LLM usage

**Size:** Grows as it learns from package registries and observed frameworks

**Isolation:** Completely private. Singularity/Genesis/Nexus cannot read CentralCloud data.

```elixir
# CentralCloud reads for analytics (NEVER writes to shared_queue)
defmodule CentralCloud.SharedQueueAnalytics do
  def analyze_llm_request_patterns() do
    # SELECT msg FROM pgmq.llm_requests_archive
    # GROUP BY complexity, provider
    SharedQueue.read_archive(:llm_requests, limit: 1000)
  end

  def analyze_approval_patterns() do
    # SELECT msg FROM pgmq.approval_requests_archive
    # What types of approvals happen? How long do they take?
    SharedQueue.read_archive(:approval_requests, limit: 1000)
  end
end
```

### 3. **genesis** (Elixir)
**Purpose:** Code execution, syntax validation, linting

**Private Data (NOT shared):**
- Execution results
- Code validation outputs
- Linting reports
- Performance metrics

**Access to:**
- **shared_queue (read/write)** - Read job_requests; write job_results

**Size:** Small (mainly ephemeral job execution data)

**Isolation:** Completely separate database.

```elixir
# Genesis reads job requests
defmodule Genesis.SharedQueueConsumer do
  def consume_job_requests() do
    # SELECT * FROM pgmq.read('job_requests', limit := 10)
    case SharedQueue.read(:job_requests, limit: 10) do
      {msg_id, request} ->
        result = execute_job(request)
        SharedQueue.publish(:job_results, result)
        SharedQueue.archive(:job_requests, msg_id)
      :empty -> :ok
    end
  end
end
```

### 4. **nexus** (TypeScript/Bun)
**Purpose:** LLM request routing, HITL (Human-in-the-Loop) approval/question UI, provider integration

**Config Data (stored locally, NOT shared):**
- Model registry and availability
- Provider credentials (API keys)
- Model selection rules
- System prompts
- HITL configuration (approval/question routing)

**Private Data (historical logs, optional):**
- Approval history (for audit/analytics)
- Question history
- HITL metrics
- Request logs

**Access to:**
- **shared_queue (read/write)** - Read LLM/approval/question requests; write LLM results

**Size:** Small (config) + optional medium (historical logs)

**Isolation:** Completely separate from CentralCloud. Singularity cannot read Nexus config.

```typescript
// Nexus consumes from shared_queue
async function consumeRequests() {
  // SELECT * FROM pgmq.read('llm_requests', limit := 10)
  const requests = await sharedQueueClient.read('llm_requests', { limit: 10 });

  for (const { msg_id, msg } of requests) {
    // Route to appropriate LLM provider
    const result = await routeToProvider(msg.model, msg.messages);

    // Publish result back
    await sharedQueueClient.publish('llm_results', {
      request_id: msg_id,
      result: result.content,
      model: result.model
    });

    // Archive the request
    await sharedQueueClient.archive('llm_requests', msg_id);
  }
}
```

### 5. **shared_queue** (PostgreSQL with pgmq - CentralCloud Owned)
**Purpose:** Central durable message queue for ALL inter-service communication

**Ownership:** CentralCloud exclusively creates, initializes, and manages this database

**Consumers (read/write access):**
- Singularity - publishes requests, reads responses
- Genesis - reads job requests, publishes results
- Nexus - reads LLM/approval/question requests, publishes results/responses
- CentralCloud - reads archived queues for analytics (read-only after messages are archived)

**Data Type:** NOT a data store - Messages are temporary, moved to archives after processing, then pruned after 90 days

**Setup:** CentralCloud initializes this at startup via `SharedQueueManager.initialize()`
- Retention: 90 days (configurable via `SHARED_QUEUE_RETENTION_DAYS` env var)
- Archives: Messages automatically archived after consumption, kept for analysis
- Cleanup: Archived messages older than 90 days are pruned

**Queue Tables:**

| Queue | Publisher | Consumers | Message Type | Purpose |
|-------|-----------|-----------|--------------|---------|
| `llm_requests` | Singularity | Nexus | `{agent_id, task_type, messages}` | LLM routing |
| `approval_requests` | Singularity | Nexus/Browser | `{id, file_path, diff, description}` | Code approval |
| `question_requests` | Singularity | Nexus/Browser | `{id, question, context}` | Ask human |
| `job_requests` | Singularity | Genesis | `{id, code, language}` | Execute code |
| `llm_results` | Nexus | Singularity | `{request_id, result, model}` | LLM response |
| `job_results` | Genesis | Singularity | `{request_id, output, error}` | Execution result |
| `approval_responses` | Browser | Singularity | `{request_id, approved, reason}` | Human decision |
| `question_responses` | Browser | Singularity | `{request_id, response}` | Human response |

**Retention:** pgmq automatically archives messages after read. Archives are pruned after 7 days (configurable).

```bash
# Setup shared_queue
createdb shared_queue
psql shared_queue -c "CREATE EXTENSION pgmq;"

# pgmq automatically creates tables:
# pgmq.llm_requests
# pgmq.llm_requests_archive
# pgmq.approval_requests
# pgmq.approval_requests_archive
# ... etc
```

## Data Flow Examples

### Example 1: LLM Request → Response

```
Singularity Agent
  ↓ (Elixir)
  SharedQueue.publish(:llm_requests, {
    agent_id: "self-improving-agent",
    task_type: "architect",
    messages: [...]
  })
  ↓
shared_queue.pgmq.llm_requests
  ↓ (pgmq.read)
Nexus LLM Router
  ↓ (TypeScript)
  Analyzes task_type: "architect" → complexity: :complex
  Selects model: Claude Opus
  Calls AI provider
  ↓
SharedQueue.publish(:llm_results, {
  request_id: msg_id,
  result: "...",
  model: "claude-opus"
})
  ↓
shared_queue.pgmq.llm_results
  ↓ (pgmq.read)
Singularity Agent
  (processes result, continues reasoning)
```

### Example 2: Code Approval Workflow

```
Singularity Agent wants to modify code
  ↓
SharedQueue.publish(:approval_requests, {
  id: "uuid",
  file_path: "lib/module.ex",
  diff: "...",
  description: "Add feature X"
})
  ↓
shared_queue.pgmq.approval_requests
  ↓
Nexus HITL Bridge (WebSocket)
  Broadcasts to connected browsers
  ↓
Browser UI displays ApprovalCard
  ↓
Human clicks "Approve" / "Reject"
  ↓
SharedQueue.publish(:approval_responses, {
  request_id: "uuid",
  approved: true
})
  ↓
shared_queue.pgmq.approval_responses
  ↓
Singularity reads response
  Logs approval decision to singularity DB
  Continues execution
```

### Example 3: Code Execution

```
Singularity Agent needs to validate code
  ↓
SharedQueue.publish(:job_requests, {
  id: "uuid",
  code: "def hello, do: :world end",
  language: "elixir"
})
  ↓
shared_queue.pgmq.job_requests
  ↓
Genesis Job Consumer
  Receives request
  Executes: `elixir -c code_file.ex`
  ↓
SharedQueue.publish(:job_results, {
  request_id: "uuid",
  output: "✓ Valid Elixir code",
  error: nil
})
  ↓
shared_queue.pgmq.job_results
  ↓
Singularity reads result
  Logs to singularity DB
  Continues execution
```

## Security & Isolation

### What Each Service CAN See

| Service | Can Read | Can Write | Cannot See |
|---------|----------|-----------|-----------|
| **Singularity** | shared_queue only | shared_queue only | centralcloud, genesis, nexus (config) |
| **CentralCloud** | shared_queue (read-only) | - (read-only) | singularity, genesis, nexus |
| **Genesis** | shared_queue only | shared_queue only | singularity, centralcloud, nexus |
| **Nexus** | shared_queue only | shared_queue only | singularity, centralcloud, genesis |

### Key Guarantees

✅ **Data Isolation:** Each service's database is private
✅ **No Cross-Service Snooping:** Singularity can't read CentralCloud learning data
✅ **Async Communication:** Services communicate only via shared_queue (decoupled)
✅ **Durable Queue:** PostgreSQL pgmq provides ACID guarantees
✅ **Archive Trail:** All messages archived for analytics/auditing
✅ **CentralCloud Privacy:** Analytics service can't be exploited to leak other services' data

## Setup Instructions

```bash
# 1. Create all 5 databases
createdb singularity    # Main orchestration (Elixir)
createdb genesis        # Code execution (Elixir)
createdb centralcloud   # Learning/intelligence (Elixir)
createdb nexus          # LLM router + HITL (Bun/TypeScript)
createdb shared_queue   # Central message queue

# 2. Setup pgmq in shared_queue
psql shared_queue -c "CREATE EXTENSION pgmq;"

# 3. Run migrations for each service
cd singularity && mix ecto.migrate
cd genesis && mix ecto.migrate
cd centralcloud && mix ecto.migrate
cd nexus && bunx drizzle-kit push

# 4. Test pgmq
psql shared_queue -c "SELECT * FROM pgmq.queue_list();"
```

## Environment Variables

```bash
# Singularity
DATABASE_URL="postgresql://localhost/singularity"

# Genesis
GENESIS_DATABASE_URL="postgresql://localhost/genesis"

# CentralCloud
CENTRALCLOUD_DATABASE_URL="postgresql://localhost/centralcloud"

# Nexus
NEXUS_DATABASE_URL="postgresql://localhost/nexus"

# Shared Queue (accessed by ALL services)
SHARED_QUEUE_DB_URL="postgresql://localhost/shared_queue"

# Or individual components
SHARED_QUEUE_HOST=localhost
SHARED_QUEUE_PORT=5432
SHARED_QUEUE_USER=postgres
SHARED_QUEUE_PASSWORD=
```

## Multi-Instance Singularity

When running multiple Singularity instances:

```
Singularity Instance 1
  ↓ (separate DB)
  singularity_1

Singularity Instance 2
  ↓ (separate DB)
  singularity_2

Singularity Instance 3
  ↓ (separate DB)
  singularity_3

        ↓ ↓ ↓ (all publish/read from)

   shared_queue (central hub)

        ↓ ↓ ↓ (all consumed by)

CentralCloud (reads queue for aggregate analytics)
  ↓
centralcloud DB (private learning/intelligence)
```

Each instance is completely independent with its own database. They coordinate only through shared_queue messages. CentralCloud learns from all instances without seeing their private data.

## Migration from NATS

Currently using NATS for messaging. Transition to pgmq:

**Phase 1: Dual Operation (Safe)**
- Deploy pgmq schema
- Add shared_queue publishing to Singularity
- Nexus/Genesis read from BOTH NATS and pgmq
- Keep NATS running

**Phase 2: Cutover**
- Switch all publishers to pgmq
- Remove NATS readers
- Archive pgmq messages for history

**Phase 3: Cleanup**
- Retire NATS
- Confirm all systems stable
- Archive shared_queue history to cold storage

## Files

- `DATABASE_ARCHITECTURE.md` - This file
- `singularity/lib/singularity/shared_queue_publisher.ex` - Publishing interface
- `singularity/lib/singularity/shared_queue_consumer.ex` - Reading results
- `centralcloud/lib/centralcloud/shared_queue_analytics.ex` - Read-only analytics
- `genesis/lib/genesis/shared_queue_consumer.ex` - Job execution consumer
- `nexus/src/shared-queue-handler.ts` - LLM/HITL routing consumer
- `start-all.sh` - Updated to initialize all 5 databases

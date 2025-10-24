# PostgreSQL Autonomous Worker Architecture

**Status:** ✅ **FULLY IMPLEMENTED & COMPILED** (2025-10-25)

A hybrid Elixir-PostgreSQL architecture where Singularity focuses on real-time orchestration while PostgreSQL autonomously handles durability, learning, and CentralCloud synchronization.

---

## 🏗️ **Architecture Overview**

```
┌──────────────────────────────┐
│   Elixir (Real-Time Layer)   │
│                              │
│ ├─ Agent Execution           │
│ ├─ LLM Calls                 │
│ ├─ Analysis Processing       │
│ ├─ NATS Messaging            │
│ └─ Insert to Database        │
└────────────┬─────────────────┘
             │ (INSERT/UPDATE)
             ▼
┌──────────────────────────────────────────────────────────┐
│   PostgreSQL (Autonomous Worker Layer)                   │
│                                                          │
│ ┌─ Stored Procedures (Business Logic)                  │
│ │  ├─ learn_patterns_from_analysis()                   │
│ │  ├─ persist_agent_session() [TRIGGER]               │
│ │  ├─ update_agent_knowledge()                        │
│ │  ├─ sync_learning_to_centralcloud()                 │
│ │  └─ assign_pending_tasks()                          │
│ │                                                      │
│ ├─ Scheduled Jobs (pg_cron)                           │
│ │  ├─ Every 5 min: Learn patterns                     │
│ │  ├─ Every 10 min: Sync learning                     │
│ │  ├─ Every 1 hour: Update knowledge                 │
│ │  ├─ Every 2 min: Assign tasks                       │
│ │  └─ Every 30 min: Refresh metrics                   │
│ │                                                      │
│ ├─ Message Queue (pgmq)                               │
│ │  ├─ centralcloud-new-patterns                       │
│ │  ├─ agent-sessions                                  │
│ │  └─ agent-knowledge-updates                         │
│ │                                                      │
│ ├─ Change Data Capture (wal2json)                      │
│ │  └─ singularity_centralcloud_cdc slot              │
│ │                                                      │
│ └─ Security (pgsodium)                                │
│    └─ Auto-encryption of sensitive data              │
└──────────────────┬───────────────────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
    [pgmq]    [wal2json]  [Triggers]
        │          │          │
        └──────────┼──────────┘
                   │
                   ▼
    ┌──────────────────────────────┐
    │   CentralCloud               │
    │                              │
    │ ├─ Poll pgmq every 10 min   │
    │ ├─ Subscribe to wal2json     │
    │ └─ Receive pattern updates   │
    └──────────────────────────────┘
```

---

## 🔄 **Data Flow Examples**

### **1. Pattern Learning (Automatic)**

```
Agent analyzes code
         ↓
Elixir inserts analysis_result (learned = FALSE)
         ↓
[5-minute interval via pg_cron]
         ↓
PostgreSQL learns_patterns_from_analysis() stored procedure:
  - Creates learned_pattern record
  - Queues to pgmq 'centralcloud-new-patterns'
  - Marks analysis_result as learned = TRUE
         ↓
CentralCloud polls pgmq (every 10 min)
         ↓
Receives new pattern and updates its knowledge
```

### **2. Agent Session Persistence (Trigger-Based)**

```
Agent updates session state
         ↓
Elixir updates agent_sessions table
         ↓
Database TRIGGER fires automatically:
  - Encrypts session state (pgsodium)
  - Queues to pgmq 'agent-sessions'
  - Updates last_synced_at timestamp
         ↓
CentralCloud:
  - Polls pgmq OR
  - Subscribes to wal2json CDC
         ↓
CentralCloud receives session update in real-time
```

### **3. Knowledge Update (Scheduled)**

```
[Hourly via pg_cron]
         ↓
PostgreSQL update_agent_knowledge() stored procedure:
  - Aggregates learned patterns from last 24 hours
  - Updates agents.known_patterns JSONB
  - Updates agents.pattern_confidence
  - Queues to pgmq 'agent-knowledge-updates'
         ↓
Agent has fresh knowledge automatically
         ↓
CentralCloud receives knowledge summary
```

### **4. Task Assignment (Scheduled)**

```
[Every 2 minutes via pg_cron]
         ↓
PostgreSQL assign_pending_tasks() stored procedure:
  - Finds agents with capacity
  - Finds pending tasks
  - Assigns tasks to agents
  - Updates assigned_at timestamp
         ↓
Agents see assigned tasks next check
```

---

## 📋 **Stored Procedures**

### **1. learn_patterns_from_analysis()**

Learns from analysis results every 5 minutes.

```sql
-- Called automatically by pg_cron every 5 minutes
SELECT learn_patterns_from_analysis();
-- Returns: (patterns_learned, patterns_queued)

-- Manual trigger (optional):
iex> Singularity.Database.AutonomousWorker.learn_patterns_now()
{:ok, %{patterns_learned: 15, patterns_queued: 15}}
```

**What it does:**
1. Gets last 100 unlearned analysis results
2. Inserts each as a learned_pattern
3. Queues to pgmq for CentralCloud
4. Marks analysis_result as `learned = TRUE`

### **2. persist_agent_session() [TRIGGER]**

Automatically fires when agent sessions change.

```sql
-- Triggered on: UPDATE agent_sessions
-- When: session state or confidence changes
-- Action: Auto-encrypt and queue to pgmq

-- Elixir code:
Repo.update(%{agent_sessions | state: new_state})
-- Trigger automatically encrypts and queues
```

**What it does:**
1. Encrypts sensitive session data with pgsodium
2. Queues session to pgmq
3. Updates last_synced_at
4. Returns updated record

### **3. update_agent_knowledge()**

Updates agent knowledge hourly.

```sql
-- Called automatically by pg_cron every 1 hour
SELECT update_agent_knowledge();
-- Returns: (agents_updated, total_patterns)

-- Manual trigger (optional):
iex> Singularity.Database.AutonomousWorker.update_knowledge_now()
{:ok, %{agents_updated: 5, total_patterns: 127}}
```

**What it does:**
1. For each agent, aggregates learned patterns (last 24h)
2. Calculates average confidence
3. Stores patterns as JSONB in agents.known_patterns
4. Queues summary to CentralCloud

### **4. sync_learning_to_centralcloud()**

Batches and queues learning updates.

```sql
-- Called automatically by pg_cron every 10 minutes
SELECT sync_learning_to_centralcloud();
-- Returns: (batch_id, pattern_count)

-- Manual trigger (optional):
iex> Singularity.Database.AutonomousWorker.sync_learning_now()
{:ok, %{batch_id: "01ARZ3NDEKTSV4...", pattern_count: 42}}
```

**What it does:**
1. Generates batch ID (ULID)
2. Counts pending patterns in pgmq
3. Logs sync batch
4. Returns batch info for monitoring

### **5. assign_pending_tasks()**

Automatically assigns tasks to agents.

```sql
-- Called automatically by pg_cron every 2 minutes
SELECT assign_pending_tasks();
-- Returns: (tasks_assigned, agents_assigned)

-- Manual trigger (optional):
iex> Singularity.Database.AutonomousWorker.assign_tasks_now()
{:ok, %{tasks_assigned: 8, agents_assigned: 3}}
```

**What it does:**
1. Finds agents with capacity
2. Gets pending tasks
3. Assigns up to 10 tasks per agent
4. Sets assigned_at and assigned_agent_id

---

## ⏰ **Scheduled Tasks (pg_cron)**

| Schedule | Task | Purpose |
|----------|------|---------|
| `*/5 * * * *` | learn_patterns_from_analysis() | Pattern discovery every 5 min |
| `*/10 * * * *` | sync_learning_to_centralcloud() | Batch sync every 10 min |
| `0 * * * *` | update_agent_knowledge() | Knowledge aggregation hourly |
| `*/2 * * * *` | assign_pending_tasks() | Task distribution every 2 min |
| `*/30 * * * *` | REFRESH agent_performance_5min | Metrics refresh every 30 min |
| `0 */6 * * *` | Cleanup sync logs | Archive old logs every 6 hours |
| `0 2 * * *` | Archive completed tasks | Daily cleanup at 2 AM |

---

## 📨 **Message Queues (pgmq)**

### **centralcloud-new-patterns**
New learned patterns waiting for CentralCloud.
```json
{
  "agent_id": "agent-123",
  "pattern": {...pattern data...},
  "confidence": 0.95,
  "learned_at": "2025-10-25T10:00:00Z",
  "source": "singularity-learning"
}
```

### **agent-sessions**
Agent session state updates.
```json
{
  "agent_id": "agent-123",
  "session_id": "01ARZ3NDEKTSV4...",
  "session_state": {...state...},
  "confidence": 0.85,
  "synced_at": "2025-10-25T10:00:00Z"
}
```

### **agent-knowledge-updates**
Knowledge summaries for CentralCloud.
```json
{
  "agents_updated": 5,
  "total_patterns": 127,
  "updated_at": "2025-10-25T10:00:00Z"
}
```

---

## 📡 **Change Data Capture (wal2json)**

Real-time change stream for CentralCloud via logical decoding.

```elixir
# Get all changes since last read
iex> Singularity.Database.AutonomousWorker.get_cdc_changes()
{:ok, [
  %{
    lsn: "0/12345678",
    data: %{
      "table" => "learned_patterns",
      "op" => "INSERT",
      "columns" => [...],
      "values" => [...]
    }
  },
  ...
]}

# Get only pattern changes
iex> Singularity.Database.AutonomousWorker.get_pattern_changes()

# Get only session changes
iex> Singularity.Database.AutonomousWorker.get_session_changes()
```

---

## 🎯 **Elixir Integration Points**

### **From Elixir Code**

```elixir
alias Singularity.Database.AutonomousWorker

# Manually trigger autonomous tasks (usually not needed - they run via pg_cron)
AutonomousWorker.learn_patterns_now()
AutonomousWorker.update_knowledge_now()
AutonomousWorker.sync_learning_now()
AutonomousWorker.assign_tasks_now()

# Monitor autonomous operations
AutonomousWorker.queue_status()
AutonomousWorker.scheduled_jobs_status()
AutonomousWorker.check_job_health("learn-patterns-every-5min")
AutonomousWorker.learning_queue_backed_up?(threshold: 100)

# CDC for real-time CentralCloud sync
AutonomousWorker.get_cdc_changes()
AutonomousWorker.get_pattern_changes()
AutonomousWorker.get_session_changes()

# Manual overrides
AutonomousWorker.manually_learn_analysis(analysis_id)
```

### **Elixir Becomes Simpler**

Before (Complex):
```elixir
def process_analysis(analysis) do
  # Insert analysis
  {:ok, result} = Repo.insert(analysis)
  
  # Learn from it
  {:ok, pattern} = learn_pattern(result)
  
  # Queue to CentralCloud
  {:ok, msg_id} = Singularity.Database.MessageQueue.send(
    "patterns",
    pattern
  )
  
  # Encrypt session
  encrypted = encrypt_session(agent_session)
  
  # Queue session
  {:ok, _} = Singularity.Database.MessageQueue.send(
    "sessions",
    encrypted
  )
end
```

After (Simple):
```elixir
def process_analysis(analysis) do
  # Just insert - everything else happens in PostgreSQL
  Repo.insert(analysis)
end
```

---

## 🔒 **Security**

All stored procedures include:
- ✅ Encryption via pgsodium
- ✅ Automatic timestamp tracking
- ✅ ACID transaction guarantees
- ✅ Full audit trail (wal2json)
- ✅ Input validation in PostgreSQL

---

## 📊 **Scalability Benefits**

| Scenario | Before | After |
|----------|--------|-------|
| **Learning latency** | Immediate but Elixir-dependent | 5 min batch, fully autonomous |
| **Session loss** | If Elixir crashes | Trigger-backed, guaranteed |
| **Task assignment** | Manual query | Automatic every 2 min |
| **Knowledge updates** | On-demand | Hourly aggregates |
| **CentralCloud sync** | Immediate but unreliable | 10 min batch, durable |
| **Elixir restarts** | Everything pauses | PostgreSQL continues |
| **Multiple Singularity instances** | Conflicting writes | Single DB, coordinated |

---

## ✅ **What's Automatic Now**

- ✅ Pattern learning (every 5 min)
- ✅ Session persistence (on update)
- ✅ Knowledge aggregation (every 1 hour)
- ✅ Task assignment (every 2 min)
- ✅ CentralCloud sync (every 10 min)
- ✅ Metrics refresh (every 30 min)
- ✅ Data encryption (automatic via trigger)
- ✅ Audit trail (wal2json CDC)

---

## 🚀 **How to Monitor**

```elixir
# Check all scheduled jobs
iex> AutonomousWorker.scheduled_jobs_status()
[
  %{name: "learn-patterns-every-5min", status: "success", ...},
  %{name: "sync-learning-every-10min", status: "success", ...},
  ...
]

# Check message queues
iex> AutonomousWorker.queue_status()
[
  %{queue: "centralcloud-new-patterns", total_messages: 42, in_flight: 0},
  %{queue: "agent-sessions", total_messages: 15, in_flight: 2},
  ...
]

# Alert if learning queue is backing up
iex> AutonomousWorker.learning_queue_backed_up?(threshold: 100)
false
```

---

## 📝 **Files**

- `20251025000003_create_autonomous_stored_procedures.exs` - Stored procedures and triggers
- `20251025000004_schedule_autonomous_tasks.exs` - pg_cron scheduling
- `lib/singularity/database/autonomous_worker.ex` - Elixir interface

---

## 🎓 **Learning Resources**

- PostgreSQL PL/pgSQL: https://www.postgresql.org/docs/17/plpgsql.html
- pg_cron: https://github.com/citusdata/pg_cron
- pgmq: https://github.com/tembo-io/pgmq
- wal2json: https://github.com/eulerto/wal2json
- pgsodium: https://github.com/michelp/pgsodium

---

## 🏁 **Summary**

This architecture **moves persistence and scheduling into PostgreSQL**, letting Singularity focus on real-time orchestration while PostgreSQL ensures:

- **Durability** - No message loss, triggers persist automatically
- **Scalability** - Single DB, many app servers
- **Simplicity** - Elixir code is simpler
- **Autonomy** - Works even if Elixir restarts
- **Auditability** - Full CDC trail of all changes
- **Reliability** - ACID guarantees throughout

*Last Updated: 2025-10-25*
*All code compiled and ready ✅*

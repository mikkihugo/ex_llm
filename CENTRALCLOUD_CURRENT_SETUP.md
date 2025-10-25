# CentralCloud Current Setup & Queue Architecture

## What's Already Set Up ✅

### 1. Shared Queue Infrastructure (pgmq)
**Location:** `centralcloud/lib/centralcloud/shared_queue_manager.ex`
**Database:** Separate `shared_queue` database with pgmq extension
**Manager:** `CentralCloud.SharedQueueManager` - initializes and manages queues

**Queue Tables Already Defined:**
- ✅ `pgmq.llm_requests` / `_archive` - LLM routing (Singularity ↔ Nexus)
- ✅ `pgmq.llm_results` / `_archive` - LLM responses
- ✅ `pgmq.approval_requests` / `_archive` - Code approval requests
- ✅ `pgmq.approval_responses` / `_archive` - Approval decisions
- ✅ `pgmq.question_requests` / `_archive` - Human questions
- ✅ `pgmq.question_responses` / `_archive` - Human responses
- ✅ `pgmq.job_requests` / `_archive` - Genesis job requests
- ✅ `pgmq.job_results` / `_archive` - Genesis job results

**Ecto Schemas:** `CentralCloud.SharedQueueSchemas` - Type-safe querying of archived messages

### 2. Oban Job Scheduling
**Location:** `centralcloud/config/config.exs`
**Current Jobs:**
- ✅ `CentralCloud.Jobs.PatternAggregationJob` (hourly `0 * * * *`)
- ✅ `CentralCloud.Jobs.StatisticsJob` (hourly `0 * * * *`)
- ✅ `CentralCloud.Jobs.PackageSyncJob` (daily `0 2 * * *`)

**Queue Configuration:**
- `aggregation` queue (concurrency: 2)
- `sync` queue (concurrency: 1)
- `default` queue (concurrency: 5)

### 3. Application Structure
**File:** `centralcloud/lib/centralcloud/application.ex`

**Supervision Tree:**
```
Foundation:
├─ CentralCloud.Repo (main database)
└─ CentralCloud.SharedQueueRepo (shared_queue database)

Infrastructure:
├─ Task: initialize_shared_queue()
└─ Oban (with cron plugin)

Services:
├─ CentralCloud.KnowledgeCache (ETS-based)
├─ CentralCloud.TemplateService
├─ CentralCloud.TemplateLoader

Optional (require NATS):
├─ CentralCloud.NatsClient (still using for now)
├─ CentralCloud.FrameworkLearningAgent
├─ CentralCloud.IntelligenceHub
├─ CentralCloud.TemplateIntelligence
└─ CentralCloud.NATS.PatternValidatorSubscriber
```

---

## What Needs to be Added for Queue-Based Pattern Learning

### Queue Tables to Add (pgmq)
```sql
-- For pattern learning aggregation
pgmq.pattern_messages      -- Singularity instances → patterns
pgmq.pattern_messages_archive

-- For learned patterns export
pgmq.learned_patterns      -- Aggregated learning → export
pgmq.learned_patterns_archive

-- For template syncing
pgmq.template_updates      -- CentralCloud → template distribution
pgmq.template_updates_archive

-- Optional: analytics/heartbeat
pgmq.instance_heartbeat    -- Health checks from instances
pgmq.instance_heartbeat_archive
```

### New Oban Jobs to Create

1. **PatternSyncWorker** (CentralCloud)
   - **Purpose:** Distribute aggregated patterns back to instances
   - **Schedule:** Every hour (after PatternAggregationJob)
   - **Reads:** aggregated_patterns from PatternAggregationJob
   - **Writes:** pattern_messages queue
   - **Action:** Updates Git templates, publishes to queue
   - **Location:** `centralcloud/lib/centralcloud/jobs/pattern_sync_worker.ex`

2. **KnowledgeExportWorker** (CentralCloud)
   - **Purpose:** Export aggregated learned patterns to Git
   - **Schedule:** Daily 1 AM (UTC)
   - **Reads:** learned_patterns from Singularity instances (via queue)
   - **Writes:** Creates Git PR with aggregated learning
   - **Action:** Creates branch, commits, opens PR for human review
   - **Location:** `centralcloud/lib/centralcloud/jobs/knowledge_export_worker.ex`

3. **TemplateDistributionWorker** (CentralCloud)
   - **Purpose:** Sync updated templates to all Singularity instances
   - **Schedule:** Every 4 hours (after pattern/learning updates)
   - **Reads:** Git templates_data repo
   - **Writes:** template_updates queue
   - **Action:** Publishes new/updated templates to queue
   - **Location:** `centralcloud/lib/centralcloud/jobs/template_distribution_worker.ex`

### Updates to Existing Jobs

1. **PatternAggregationJob** (CentralCloud)
   - Currently: Aggregates patterns from package registry
   - **Needs Update:** Also read from `pgmq.pattern_messages` queue
   - **Action:** Aggregate patterns from all Singularity instances
   - **Publish:** Results to queue or database

2. **FrameworkLearningAgent** (CentralCloud)
   - Currently: Uses NATS subscriptions
   - **Needs Update:** Read from `pgmq.pattern_messages` instead of NATS
   - **Action:** Learn from patterns sent by Singularity instances

### New Message Types in Queue

```elixir
# Message: pattern_detection (Singularity → CentralCloud)
%{
  type: "pattern_detection",
  source: "singularity-1",
  patterns: [...],
  timestamp: DateTime.utc_now(),
  instance_id: "singularity-1"
}

# Message: aggregated_patterns (CentralCloud → Singularity)
%{
  type: "aggregated_patterns",
  patterns: [...],
  timestamp: DateTime.utc_now(),
  source: "centralcloud"
}

# Message: learned_patterns (Singularity → CentralCloud)
%{
  type: "learned_patterns",
  source: "singularity-2",
  artifacts: [...],
  usage_count: 500,
  success_rate: 0.95,
  timestamp: DateTime.utc_now()
}

# Message: learning_exported (CentralCloud → All)
%{
  type: "learning_exported",
  pr_url: "https://github.com/...",
  artifacts_count: 15,
  timestamp: DateTime.utc_now(),
  branch: "feature/learned-patterns-20251025"
}

# Message: templates_updated (CentralCloud → All)
%{
  type: "templates_updated",
  git_url: "https://github.com/...",
  updated_files: [...],
  timestamp: DateTime.utc_now()
}
```

---

## Implementation Checklist

### Phase 1: Add Queue Tables
- [ ] Create migration in CentralCloud to add new pgmq queues:
  - `pattern_messages`
  - `learned_patterns`
  - `template_updates`
  - `instance_heartbeat` (optional)

### Phase 2: Create New Jobs
- [ ] Create `PatternSyncWorker` in CentralCloud
  - Reads aggregated patterns
  - Updates templates in Git
  - Publishes to queue

- [ ] Create `KnowledgeExportWorker` in CentralCloud
  - Reads learned_patterns from queue
  - Creates PR for aggregated learning
  - Single source of truth (no more conflicting PRs)

- [ ] Create `TemplateDistributionWorker` in CentralCloud
  - Reads templates_data from Git
  - Publishes updates to queue
  - Replaces Git direct access

### Phase 3: Update Existing Jobs
- [ ] Update `PatternAggregationJob`
  - Read from `pgmq.pattern_messages` queue
  - Include patterns from all Singularity instances
  - Aggregate + rank + store results

- [ ] Update `FrameworkLearningAgent`
  - Replace NATS subscriptions with queue reads
  - Process pattern_messages from queue

### Phase 4: Remove from Singularity
- [ ] Remove `PatternSyncJob` from Singularity
- [ ] Remove `KnowledgeExportWorker` from Singularity
- [ ] Update `TemplateSyncWorker` to read from queue instead of Git

### Phase 5: Add Queue Message Producers (Singularity)
- [ ] Update `CodeIngestWorker`:
  - Write detected patterns to `pgmq.pattern_messages`

- [ ] Update `DeadCodeCheck`:
  - Write analysis results to `pgmq.pattern_messages`

- [ ] Update `MetricsAggregationWorker`:
  - Write learned patterns to `pgmq.learned_patterns`

---

## Configuration Changes Needed

### CentralCloud config.exs

```elixir
# Add new queue definitions
config :centralcloud, :shared_queue,
  enabled: System.get_env("SHARED_QUEUE_ENABLED", "true") == "true",
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  auto_initialize: true,
  retention_days: String.to_integer(System.get_env("SHARED_QUEUE_RETENTION_DAYS", "90")),
  queues: [
    "pattern_messages",
    "learned_patterns",
    "template_updates",
    "instance_heartbeat"
  ]

# Add new jobs to Oban cron
config :centralcloud, Oban,
  # ... existing config ...
  plugins: [
    # ... existing plugins ...
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", CentralCloud.Jobs.PatternAggregationJob},
       {"0 * * * *", CentralCloud.Jobs.PatternSyncWorker},    # NEW
       {"0 1 * * *", CentralCloud.Jobs.KnowledgeExportWorker}, # NEW
       {"0 * * * *", CentralCloud.Jobs.TemplateDistributionWorker}, # NEW
       # ... existing jobs ...
     ]}
  ]
```

---

## Summary

### Already Available
✅ SharedQueue infrastructure (pgmq) with 8 queue tables
✅ Oban job scheduling with 3 existing jobs
✅ Application supervision structure
✅ NATS still available for backward compatibility

### To Add for Queue-Based Pattern Learning
- 4 new pgmq queue tables
- 3 new Oban jobs in CentralCloud
- 2 updated Oban jobs in CentralCloud
- Message type definitions and schemas
- Updates to Singularity workers (producers)

### Benefits of This Setup
✅ CentralCloud owns all aggregation logic (single source of truth)
✅ Durable messaging (PostgreSQL persists everything)
✅ No conflicting PRs (one export per aggregation cycle)
✅ Scalable (can add unlimited Singularity instances)
✅ Backward compatible (NATS still works)

---

## Next Steps

1. **Define queue tables** - Add pgmq schema definitions to SharedQueueManager
2. **Create new CentralCloud jobs** - PatternSync, KnowledgeExport, TemplateDistribution
3. **Remove from Singularity** - Delete PatternSyncJob and KnowledgeExportWorker
4. **Update message producers** - Make Singularity workers write to queues
5. **Update message consumers** - Make CentralCloud jobs read from queues

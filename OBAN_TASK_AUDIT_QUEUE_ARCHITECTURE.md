# Oban Task Audit - Queue-Based Architecture

## New Architecture Overview

```
SINGULARITY INSTANCES (Local Only)
├─ Detect patterns locally
├─ Parse code locally
├─ Write to shared queue (PostgreSQL in CentralCloud)
└─ Read aggregated results from queue

        ↓ (PostgreSQL Message Queue - Durable)

CENTRALCLOUD (Hub)
├─ PatternAggregationJob: Read from queue, aggregate patterns from all instances
├─ PatternSyncWorker: Distribute aggregated patterns back via queue
├─ KnowledgeExportWorker: Export aggregated learning to Git (single source of truth)
└─ Other jobs: Intelligence, Cache, etc.
```

**Key Changes:**
- ✅ Durable messaging (PostgreSQL instead of NATS)
- ✅ Centralized aggregation (CentralCloud only)
- ✅ Queue-based instead of pub/sub
- ✅ Singularity instances are consumers, not processors

---

## Tasks by Location

### Singularity (6 Tasks - Local Only)

#### Startup (One-Time via SetupBootstrap)

1. **KnowledgeMigrateWorker** ✅
   - Purpose: Load JSON templates to local database
   - Location: Singularity
   - Why: Local knowledge base initialization
   - Write to Queue: No (local only)

2. **TemplatesDataLoadWorker** ✅
   - Purpose: Load local templates_data to PostgreSQL
   - Location: Singularity
   - Why: Local template initialization
   - Write to Queue: No (local only)

3. **CodeIngestWorker** (Startup + Weekly) ✅
   - Purpose: Parse Singularity codebase for semantic search + embeddings
   - Location: Singularity
   - Why: Analyzes local codebase
   - Write to Queue: Maybe (code patterns/embeddings sent to CentralCloud for aggregation)

4. **RagSetupWorker** ✅
   - Purpose: Initialize RAG system
   - Location: Singularity
   - Why: Local RAG initialization
   - Write to Queue: No (local only)

#### Recurring

5. **BackupWorker** ✅
   - Purpose: Database backups via pg_dump (hourly + daily)
   - Location: Singularity
   - Why: Backs up Singularity's local databases
   - Write to Queue: No (local only)

6. **DeadCodeDailyCheck** ✅
   - Purpose: Run Rust analyzers on local codebase
   - Location: Singularity
   - Why: Analyzes Singularity's own code
   - Write to Queue: Maybe (results sent to CentralCloud for aggregation)

7. **DeadCodeWeeklySummary** ✅
   - Purpose: Generate dead code weekly report
   - Location: Singularity
   - Why: Local code quality reporting
   - Write to Queue: No (local reporting)

---

### CentralCloud (4 Tasks - Aggregation + Hub)

#### Existing

1. **PatternAggregationJob** (Hourly) ✅
   - Purpose: Read patterns from all instances via shared queue
   - Location: CentralCloud
   - Why: Central aggregation point
   - Reads from Queue: ✅ Yes (pattern messages from all instances)
   - Publishes to Queue: ✅ Yes (aggregated patterns back to instances)

#### New / Moved

2. **PatternSyncWorker** (New - Recurring) ⭐
   - Purpose: Distribute aggregated patterns to all instances
   - Location: CentralCloud
   - Why: Central distribution hub
   - Reads from Queue: ✅ PatternAggregationJob results
   - Publishes to Queue: ✅ Aggregated patterns to instances
   - Note: Replaces Singularity.PatternSyncJob

3. **KnowledgeExportWorker** (Moved from Singularity) ⭐
   - Purpose: Export aggregated learned patterns to Git
   - Location: CentralCloud (was Singularity)
   - Why: Single source of truth, no conflicting PRs
   - Reads from Queue: ✅ Learned patterns from all instances
   - Publishes to Queue: ✅ Export status
   - Note: Creates ONE PR with all instances' learning aggregated

4. **FrameworkLearningAgent** / **PackageIntelligence** / etc.
   - Purpose: Consume from shared queue, generate insights
   - Location: CentralCloud
   - Why: Central intelligence hub
   - Reads from Queue: ✅ Multiple message types
   - Publishes to Queue: ✅ Insights back to instances

---

### Tasks Removed from Singularity

| Task | Old Location | New Location | Reason |
|------|--------------|--------------|--------|
| PatternSyncJob | Singularity | CentralCloud | Central distribution hub |
| KnowledgeExportWorker | Singularity | CentralCloud | Single source of truth for Git exports |
| TemplateSyncWorker | Singularity | pg_cron | Should read from queue/DB, not local Git |

---

## Task Distribution Summary

### Before (NATS Architecture)
```
Singularity:
- KnowledgeMigrateWorker ✓
- TemplatesDataLoadWorker ✓
- CodeIngestWorker ✓
- RagSetupWorker ✓
- BackupWorker ✓
- DeadCodeChecks ✓
- PatternSyncJob ✗ (should be Central)
- TemplateSyncWorker ✗ (should be Queue-based)
- KnowledgeExportWorker ✗ (should be Central)
Total: 9 tasks (3 wrong)

CentralCloud:
- PatternAggregationJob ✓
Total: 1 task
```

### After (Queue Architecture)
```
Singularity:
- KnowledgeMigrateWorker ✓
- TemplatesDataLoadWorker ✓
- CodeIngestWorker ✓
- RagSetupWorker ✓
- BackupWorker ✓
- DeadCodeDailyCheck ✓
- DeadCodeWeeklySummary ✓
Total: 7 tasks ✅ (all correct)

CentralCloud:
- PatternAggregationJob ✓ (already exists)
- PatternSyncWorker ⭐ (NEW - moved from Singularity)
- KnowledgeExportWorker ⭐ (NEW - moved from Singularity)
- FrameworkLearningAgent ✓
- PackageIntelligence ✓
- etc.
Total: 5+ tasks ✅ (all correct)
```

---

## Message Flow (Queue-Based)

### Pattern Learning Example

```
SINGULARITY 1:
  CodeIngestWorker detects patterns
  → Writes: {type: "patterns", source: "singularity-1", patterns: [...]}
  → Queue in CentralCloud DB

SINGULARITY 2:
  DeadCodeCheck detects patterns
  → Writes: {type: "patterns", source: "singularity-2", patterns: [...]}
  → Queue in CentralCloud DB

SINGULARITY 3:
  CodeIngestWorker detects patterns
  → Writes: {type: "patterns", source: "singularity-3", patterns: [...]}
  → Queue in CentralCloud DB

CENTRALCLOUD:
  PatternAggregationJob (runs hourly)
  → Reads all pattern messages from queue
  → Aggregates: frequency, success_rate, confidence
  → Stores: "top_100_patterns"
  → Publishes: {type: "aggregated_patterns", patterns: [...]}
  → Back to queue

CENTRALCLOUD:
  PatternSyncWorker (triggered by aggregation)
  → Reads aggregated patterns
  → Updates: templates_data Git repo
  → Publishes: {type: "patterns_updated", url: "..."}
  → Back to queue

SINGULARITY 1,2,3:
  Read from queue: "patterns_updated"
  → Pull new templates from Git
  → Update local cache
  → Use aggregated patterns
```

---

## Queue Message Types

| Type | Source | Destination | Format |
|------|--------|-------------|--------|
| `patterns` | Singularity instances | CentralCloud Queue | `{type, source, patterns, timestamp}` |
| `code_analysis` | Singularity instances | CentralCloud Queue | `{type, source, analysis, timestamp}` |
| `learned_artifacts` | Singularity instances | CentralCloud Queue | `{type, source, artifacts, usage_count, success_rate}` |
| `aggregated_patterns` | CentralCloud | CentralCloud Queue | `{type, patterns, stats, timestamp}` |
| `patterns_updated` | CentralCloud | CentralCloud Queue | `{type, git_url, timestamp}` |
| `aggregated_learning` | CentralCloud | CentralCloud Queue | `{type, artifacts, export_pr_url}` |

---

## Implementation Plan

### Phase 1 (Completed)
- ✅ Move 3 cache tasks to pg_cron

### Phase 2 (Queue Architecture Migration)

1. **Remove from Singularity:**
   - ❌ Delete `PatternSyncJob`
   - ❌ Delete `KnowledgeExportWorker`
   - ❌ Update `TemplateSyncWorker` to pg_cron (read from queue/DB)

2. **Add to CentralCloud:**
   - ✅ Enhance `PatternAggregationJob` to publish back to queue
   - ⭐ Create `PatternSyncWorker` (reads aggregated patterns, syncs Git)
   - ⭐ Create `KnowledgeExportWorker` (reads aggregated learning, exports to Git)

3. **Setup Queue Infrastructure:**
   - ✅ Configure pgmq or similar in CentralCloud DB
   - ✅ Enable durable message storage
   - ✅ Create queue tables for each message type

4. **Update Message Producers:**
   - ✅ CodeIngestWorker: Write patterns to queue instead of NATS
   - ✅ DeadCodeCheck: Write analysis to queue instead of NATS
   - ✅ Other workers: Use queue instead of NATS

5. **Update Message Consumers:**
   - ✅ CentralCloud jobs: Read from queue instead of NATS
   - ✅ Singularity instances: Consume aggregated results from queue

### Phase 3 (Optimization)
- Move more pure SQL tasks to pg_cron
- Optimize queue consumption (batching, etc.)

---

## Result (Final Architecture)

### Singularity (7 tasks)
- **Startup:** Knowledge Migration, Templates Load, Code Ingest, RAG Setup
- **Recurring:** Backups, Dead Code Analysis
- **Message Role:** Producers (write patterns/analysis to queue)

### CentralCloud (5+ tasks)
- **Aggregation:** PatternAggregation (reads queue)
- **Distribution:** PatternSync (writes aggregated patterns to queue + Git)
- **Learning:** KnowledgeExport (writes aggregated learning to Git + queue)
- **Intelligence:** FrameworkLearning, PackageIntelligence, etc.
- **Message Role:** Aggregator + Hub (reads from all, publishes to all)

### Queue (PostgreSQL - Durable)
- ✅ Persists all messages
- ✅ Ensures no loss during restarts
- ✅ Single source of truth for inter-instance communication
- ✅ Managed centrally by CentralCloud

---

## Benefits of Queue Architecture vs NATS

| Aspect | NATS | PostgreSQL Queue |
|--------|------|------------------|
| Durable | ❌ (memory-based) | ✅ (persistent) |
| Centralized | ❌ (broadcast) | ✅ (CentralCloud manages) |
| Reliable | ⚠️ (best effort) | ✅ (guaranteed) |
| Operational | Complex | Simple (SQL) |
| Cost | Separate service | Already have DB |
| Recovery | Restart needed | Automatic replay |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ SINGULARITY INSTANCE 1                                          │
├─────────────────────────────────────────────────────────────────┤
│ KnowledgeMigrate → CodeIngest → RagSetup                       │
│ CodeIngestWorker (detects patterns)                            │
│ DeadCodeCheck (analyzes code)                                  │
│ BackupWorker (local backups)                                   │
│                          ↓                                      │
│         Writes to Queue (PostgreSQL in CentralCloud)           │
└─────────────────────────────────────────────────────────────────┘

                    Similar for Instances 2, 3, ...

         ↓ (PostgreSQL Message Queue - Durable)

┌─────────────────────────────────────────────────────────────────┐
│ CENTRALCLOUD                                                    │
├─────────────────────────────────────────────────────────────────┤
│ Read Queue (patterns from all instances)                       │
│           ↓                                                     │
│ PatternAggregationJob (aggregate + rank)                       │
│           ↓                                                     │
│ PatternSyncWorker (distribute aggregated patterns)             │
│ KnowledgeExportWorker (export to Git)                          │
│           ↓                                                     │
│ Write to Queue (aggregated results)                            │
└─────────────────────────────────────────────────────────────────┘

         ↓ (PostgreSQL Message Queue - Durable)

┌─────────────────────────────────────────────────────────────────┐
│ SINGULARITY INSTANCES 1,2,3                                     │
├─────────────────────────────────────────────────────────────────┤
│ Read from Queue (aggregated patterns, learning results)        │
│ Update local caches, templates                                 │
│ Use shared knowledge for code analysis, generation             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

✅ **7 Singularity tasks** - Local processing + produce to queue
✅ **5+ CentralCloud tasks** - Aggregate + distribute
✅ **Queue-based messaging** - Durable, reliable, centralized
✅ **No conflicting operations** - Single source of truth in CentralCloud
✅ **Scalable** - Can add more Singularity instances without changes

**Pattern:** Singularity instances are **workers**, CentralCloud is the **hub**.

# Oban Task Audit - Verify All Tasks Belong in Singularity

## Summary

**Total Oban Tasks:** 17
- **✅ Belong in Singularity:** 15
- **⚠️ Needs Redesign:** 1 (TemplateSyncWorker - architecture issue)
- **❓ Unclear:** 1 (DataExportWorker - not yet found)

---

## Detailed Analysis

### ✅ DEFINITELY SINGULARITY (15 Tasks)

#### Startup Tasks (One-Time via SetupBootstrap)

1. **KnowledgeMigrateWorker**
   - Purpose: Load JSON templates to database
   - Belongs in: Singularity ✅
   - Reason: Initializes Singularity's own knowledge base

2. **TemplatesDataLoadWorker**
   - Purpose: Sync templates_data/ to PostgreSQL
   - Belongs in: Singularity ✅
   - Reason: Local template initialization (see note below about TemplateSyncWorker)

3. **CodeIngestWorker**
   - Purpose: Parse Singularity codebase for semantic search
   - Belongs in: Singularity ✅
   - Reason: Analyzes Singularity's own code

4. **RagSetupWorker**
   - Purpose: Full RAG system initialization
   - Belongs in: Singularity ✅
   - Reason: Singularity's own RAG implementation

#### Continuous Tasks (Oban Cron - Every N minutes/hours/days)

5. **MetricsAggregationWorker** (every 5 min)
   - Purpose: Aggregate telemetry events into metrics
   - Belongs in: Singularity ✅
   - Reason: Singularity's own telemetry system

6. **FeedbackAnalysisWorker** (every 30 min)
   - Purpose: Analyze agent metrics, identify improvements
   - Belongs in: Singularity ✅
   - Reason: Drives Singularity's autonomous agent evolution

7. **AgentEvolutionWorker** (hourly)
   - Purpose: Apply improvements to agents
   - Belongs in: Singularity ✅
   - Reason: Core Singularity capability

8. **PatternSyncJob** (every 5 min)
   - Purpose: Sync framework patterns to ETS cache, NATS, JSON files
   - Belongs in: Singularity ✅
   - Reason: Local pattern detection system

9. **DeadCodeDailyCheck** (daily 9 AM)
   - Purpose: Run Rust analyzers on Singularity codebase
   - Belongs in: Singularity ✅
   - Reason: Analyzes Singularity's own code

10. **DeadCodeWeeklySummary** (Monday 9 AM)
    - Purpose: Generate dead code weekly report
    - Belongs in: Singularity ✅
    - Reason: Singularity's own code quality

11. **CacheClearWorker** (daily 3 AM)
    - Purpose: Clear Elixir CodeAnalysis cache
    - Belongs in: Singularity ✅
    - Reason: Clears Singularity's own in-memory cache

12. **RegistrySyncWorker** (daily 4 AM)
    - Purpose: Run code analyzers, store in Singularity's registry
    - Belongs in: Singularity ✅
    - Reason: Singularity's own code registry

13. **TemplateEmbedWorker** (weekly Sunday 5 AM)
    - Purpose: Generate ML embeddings for templates
    - Belongs in: Singularity ✅
    - Reason: Singularity's own embedding generation

14. **CodeIngestWorker** (weekly Sunday 6 AM - RECURRING)
    - Purpose: Weekly re-parse of codebase
    - Belongs in: Singularity ✅
    - Reason: Singularity's own code analysis (also runs on startup)

15. **BackupWorker** (hourly + daily)
    - Purpose: Database backups via pg_dump
    - Belongs in: Singularity ✅
    - Reason: Backs up Singularity's own databases (singularity, centralcloud, genesis_db)

#### Knowledge Export (DUPLICATE - SHOULD BE IN CENTRALCLOUD)

16. **KnowledgeExportWorker** (daily midnight)
    - Purpose: Auto-promote learned patterns to Git
    - Workflow:
      1. Find high-quality learned artifacts (100+ uses, 95%+ success)
      2. Create Git branch in Singularity's repo
      3. Commit to `templates_data/learned/`
      4. Create PR for human review
    - **Currently in:** Singularity ❌
    - **Should be in:** CentralCloud ✅
    - **Reason:** CentralCloud owns pattern learning via PatternAggregationJob
    - **Problem:**
      - ❌ Each Singularity instance would create its own PR
      - ❌ Duplicate export logic per instance
      - ❌ Conflicts/chaos with multiple Git operations
      - ❌ CentralCloud should do single aggregated export
    - **Correct Architecture:**
      ```
      Singularity 1 → learns patterns → sends to CentralCloud (NATS)
      Singularity 2 → learns patterns → sends to CentralCloud (NATS)
      Singularity 3 → learns patterns → sends to CentralCloud (NATS)
      CentralCloud → aggregates + ranks + exports to Git (once!)
      ↓
      All instances pull updated patterns from Git
      ```

---

### ⚠️ NEEDS REDESIGN (1 Task)

#### TemplateSyncWorker (daily 2 AM)

**Current Status:** In Singularity
**Proposed Change:** Needs architectural redesign

**Current Behavior:**
```elixir
Singularity.TemplateStore.sync(force: true)
# Reads from /templates_data (local Git repo)
# Syncs to Singularity's PostgreSQL
```

**Architectural Problem:**
- ❌ Singularity reads templates from its local `/templates_data`
- ❌ This duplicates work - CentralCloud already owns the template repository
- ❌ Creates potential for divergence between instances

**Correct Architecture:**
```
Central Cloud (owns templates)
    ↓ (git → db)
CentralCloud.templates table
    ↓ (db-to-db sync via postgres_fdw)
Singularity.templates table
```

**Recommendation:**
Replace with **pg_cron stored procedure** (if available), or redesign as:
1. Enable `postgres_fdw` for cross-database connection
2. Create pg_cron procedure:
   ```sql
   CREATE PROCEDURE sync_templates_from_centralcloud()
   LANGUAGE SQL
   AS $$
     DELETE FROM templates WHERE source = 'centralcloud';
     INSERT INTO templates (...)
     SELECT * FROM central_services.public.templates;
   $$;
   ```
3. Schedule via pg_cron (not Oban)
4. Remove TemplateSyncWorker

**Status:** ⚠️ Design Issue (currently "works" but architecturally wrong)

---

## Decision Matrix

### Tasks Already in Correct Place

| Task | Platform | Why | Priority |
|------|----------|-----|----------|
| KnowledgeMigrateWorker | Oban | Validation + transformation | High |
| TemplatesDataLoadWorker | Oban | Local init | Medium |
| CodeIngestWorker | Oban | ML embeddings + Rust parsing | High |
| RagSetupWorker | Oban | Complex orchestration | High |
| MetricsAggregationWorker | Oban | Complex aggregation | High |
| FeedbackAnalysisWorker | Oban | Pattern analysis logic | High |
| AgentEvolutionWorker | Oban | Complex evolution logic | High |
| PatternSyncJob | Oban | ETS + NATS + JSON sync | High |
| DeadCodeDailyCheck | Oban | Rust analyzer integration | High |
| DeadCodeWeeklySummary | Oban | Report generation | Medium |
| CacheClearWorker | Oban | Elixir in-memory cache | High |
| RegistrySyncWorker | Oban | Rust analyzer + DB storage | High |
| TemplateEmbedWorker | Oban | ML inference | High |
| BackupWorker | Oban | Shell execution (pg_dump) | High |
| KnowledgeExportWorker | Oban | Git operations + logic | High |

### Tasks Needing Architecture Change

| Task | Current | Proposed | Reason |
|------|---------|----------|--------|
| TemplateSyncWorker | Oban (local Git) | pg_cron (CentralCloud DB) | CentralCloud owns templates |

---

## Conclusion

✅ **14/16 tasks are in the right place**

❌ **2 tasks need to be moved or redesigned:**

1. **TemplateSyncWorker** → Redesign
   - Currently: Reads from local `/templates_data`
   - Should: Sync from CentralCloud database (pg_cron)

2. **KnowledgeExportWorker** → MOVE TO CENTRALCLOUD
   - Currently: Each Singularity instance exports its own patterns to Git
   - Should: CentralCloud exports aggregated patterns (once, centrally)
   - Problem: Multiple instances would create conflicting PRs

---

## Implementation Plan

### Phase 1 (Completed)
- ✅ Move 3 pure SQL cache tasks to pg_cron (Cache Cleanup, Refresh, Prewarm)

### Phase 2 (Redesign Hybrid Tasks)
1. **TemplateSyncWorker** - Redesign to use CentralCloud DB:
   - Set up postgres_fdw for cross-database queries
   - Create pg_cron procedure to sync from CentralCloud
   - Replace Oban job with pg_cron scheduling
   - Benefit: 50-75% faster, zero Oban overhead

2. **KnowledgeExportWorker** - MOVE to CentralCloud:
   - Remove from Singularity completely
   - Create equivalent job in CentralCloud
   - CentralCloud exports aggregated patterns (from all instances)
   - Single source of truth for Git exports
   - Benefit: No conflicting PRs, centralized learning

### Result (Final)
- **pg_cron tasks:** 22 (19 current + 1 TemplateSyncWorker + 2 potential)
- **Oban in Singularity:** 4 remaining (CodeIngest, BackupWorker, DeadCode checks, RAG setup)
- **Oban in CentralCloud:** PatternAggregation + KnowledgeExport (new)

---

## Notes for Future Review

### Why KnowledgeExportWorker MUST MOVE to CentralCloud

```
WRONG (Current):
Singularity 1 learns → PR created →
Singularity 2 learns → PR created → CONFLICT!
Singularity 3 learns → PR created → CHAOS!

RIGHT (Proposed):
Singularity 1 learns → sends patterns to CentralCloud (NATS)
Singularity 2 learns → sends patterns to CentralCloud (NATS)
Singularity 3 learns → sends patterns to CentralCloud (NATS)
                              ↓
CentralCloud aggregates all patterns → SINGLE PR → Templates updated
                              ↓
All instances pull new templates from Git (read-only)
```

This is the **correct multi-instance architecture**:
- No conflicting operations
- Single source of truth (CentralCloud)
- Centralized learning + export
- Each instance reads shared, aggregated patterns

### Why TemplateSyncWorker Should Change

```
WRONG:
Singularity reads /templates_data → Duplicates CentralCloud's work

RIGHT:
CentralCloud owns git sync → Singularity syncs from CentralCloud DB
```

This aligns with multi-instance where CentralCloud is the single source of truth.


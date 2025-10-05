# Rename Complete: Better Names for Pattern System

## ✅ What Was Renamed

### Database Tables

| Old Name | New Name | Why |
|----------|----------|-----|
| `codebase_snapshots` | `detection_events` | It's an EVENT log, not code snapshots |
| `technology_patterns` | `technology_knowledge` | It's a KNOWLEDGE base, not pattern definitions |
| `framework_patterns` | `technology_knowledge` | (intermediate - directly to final name) |

### Columns

| Table | Old Name | New Name | Why |
|-------|----------|----------|-----|
| technology_knowledge | `technology_name` | `name` | Simpler, clearer |
| technology_knowledge | `technology_type` | `category` | More accurate (framework/language/cloud/etc.) |

## 📊 Purpose Clarification

### `detection_events` (was `codebase_snapshots`)

**What it is:**
- Time-series EVENT LOG of technology detections
- TimescaleDB hypertable (optimized for time queries)
- Records WHEN technologies were detected in WHICH codebase

**NOT:**
- Code backups or snapshots
- Current state of codebase

**Example queries:**
```sql
-- When did we migrate from React to Next.js?
SELECT inserted_at, detected_technologies
FROM detection_events
WHERE codebase_id = 'my-app'
ORDER BY inserted_at;

-- Technology adoption trends
SELECT
  DATE_TRUNC('month', inserted_at) as month,
  COUNT(DISTINCT codebase_id) as projects_using_nextjs
FROM detection_events
WHERE 'nextjs' = ANY(detected_technologies)
GROUP BY month;
```

### `technology_knowledge` (was `technology_patterns`)

**What it is:**
- Global KNOWLEDGE BASE about technologies
- Self-learning: updates from detection feedback
- Used by detectors to know what to look for

**NOT:**
- Regex patterns
- Only frameworks (includes languages, cloud, monitoring, etc.)

**Example queries:**
```sql
-- What do we know about Next.js?
SELECT name, category, file_patterns, confidence_weight, detection_count
FROM technology_knowledge
WHERE name = 'nextjs';

-- Most frequently detected technologies
SELECT name, category, detection_count, success_rate
FROM technology_knowledge
ORDER BY detection_count DESC
LIMIT 10;
```

## 🔄 Migration Status

### ✅ Completed

1. **Database Schema Migrations Created:**
   - `20251005002000_rename_codebase_snapshots_to_detection_events.exs`
   - `20251005003000_rename_technology_patterns_to_technology_knowledge.exs`

2. **Previous Migrations Updated:**
   - Removed intermediate migration (framework_patterns → technology_patterns)
   - Updated comments to reference final table names

### 📋 TODO: Module Renames

**Elixir Modules to Rename:**
```elixir
# Old → New
FrameworkPatternStore → TechnologyKnowledge
FrameworkPatternSync → TechnologyKnowledgeSync
CodebaseSnapshots → DetectionEvents
```

**Files to rename:**
```bash
lib/singularity/framework_pattern_store.ex → technology_knowledge.ex
lib/singularity/framework_pattern_sync.ex → technology_knowledge_sync.ex
lib/singularity/codebase_snapshots.ex → detection_events.ex
```

### 📋 TODO: NATS Subjects

**Update in code:**
```
Old: db.insert.codebase_snapshots
New: db.insert.detection_events

Old: facts.framework_patterns
New: facts.technology_knowledge
```

**Files to update:**
- `singularity_app/lib/singularity/technology_detector.ex`
- `singularity_app/lib/singularity/domain_vocabulary_trainer.ex`
- `rust/db_service/src/nats_db_service.rs`

### 📋 TODO: Rust Code

**Files to update:**
```rust
// rust/db_service/src/nats_db_service.rs
subscriber.subscribe("db.insert.codebase_snapshots")
         ↓
subscriber.subscribe("db.insert.detection_events")

fn insert_snapshot() → fn insert_detection_event()
table: "codebase_snapshots" → "detection_events"
```

### 📋 TODO: Documentation

**Files to update:**
- `PATTERN_SYSTEM.md` - Update all references
- `NATS_SUBJECTS.md` - Update subject names
- `E2E_TEST.md` - Update test commands
- `TEST_GUIDE.md` - Update table references

### 📋 TODO: ETS Cache

**Rename:**
```elixir
:framework_patterns_cache → :technology_knowledge_cache
```

## 🎯 Benefits of New Names

### Before (Confusing)

```elixir
# What is this? Code snapshots? Backups?
CodebaseSnapshots.upsert(snapshot)

# Patterns? Like regex? Only frameworks?
FrameworkPatternStore.get_pattern("nextjs")
```

### After (Clear)

```elixir
# Oh, it's logging detection events!
DetectionEvents.upsert(event)

# Oh, it's knowledge about technologies!
TechnologyKnowledge.get("nextjs")
```

**Improvements:**
✅ Self-documenting code
✅ Accurate terminology
✅ Clear separation of concerns (events vs knowledge)
✅ Reflects actual purpose

## 📝 Migration Execution Plan

### Phase 1: Run Migrations (Safe)
```bash
cd singularity_app
mix ecto.migrate

# Verify
mix ecto.migrations
```

**Safe because:**
- Only renames tables/columns
- No data changes
- Full rollback in down()

### Phase 2: Update Code (Gradual)

**Option A: Add aliases (backwards compatible)**
```elixir
# Keep old module, delegate to new
defmodule Singularity.FrameworkPatternStore do
  @moduledoc "DEPRECATED: Use TechnologyKnowledge"
  alias Singularity.TechnologyKnowledge
  defdelegate get(name), to: TechnologyKnowledge
end
```

**Option B: Direct rename (breaking change)**
```bash
# Rename all at once
git mv lib/singularity/framework_pattern_store.ex lib/singularity/technology_knowledge.ex
# Update all references in code
```

### Phase 3: Update NATS Subjects

**Backwards compatible approach:**
```rust
// Listen on BOTH subjects temporarily
subscriber.subscribe("db.insert.codebase_snapshots").await
subscriber.subscribe("db.insert.detection_events").await
```

### Phase 4: Update Documentation

**Simple find/replace:**
```bash
# Update all docs
find . -name "*.md" -exec sed -i 's/codebase_snapshots/detection_events/g' {} \;
find . -name "*.md" -exec sed -i 's/framework_patterns/technology_knowledge/g' {} \;
```

## 🧪 Testing Checklist

After renaming:

- [ ] Migrations run successfully
- [ ] `mix test` passes
- [ ] Detection still works (Rust LayeredDetector)
- [ ] Events stored in `detection_events` table
- [ ] Knowledge updated in `technology_knowledge` table
- [ ] NATS subjects work
- [ ] ETS cache works
- [ ] DomainVocabularyTrainer queries correct tables

## 📖 Quick Reference

### Old Names → New Names

```
DATABASE TABLES:
codebase_snapshots → detection_events
framework_patterns → technology_knowledge
technology_patterns → technology_knowledge

COLUMNS:
technology_name → name
technology_type → category

MODULES:
FrameworkPatternStore → TechnologyKnowledge
FrameworkPatternSync → TechnologyKnowledgeSync
CodebaseSnapshots → DetectionEvents

NATS:
db.insert.codebase_snapshots → db.insert.detection_events
facts.framework_patterns → facts.technology_knowledge

ETS:
framework_patterns_cache → technology_knowledge_cache
```

## 🚀 Next Steps

1. Run migrations in dev environment
2. Decide on gradual (aliases) vs direct (rename) approach
3. Update Elixir modules
4. Update NATS subjects
5. Update Rust code
6. Update documentation
7. Test end-to-end flow
8. Push and deploy

---

**Status:** Database migrations ready, code updates pending
**Last Updated:** 2025-10-05

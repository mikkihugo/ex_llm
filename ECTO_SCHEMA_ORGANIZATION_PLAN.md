# 📊 Ecto Schema Organization Action Plan

**Current State:** 63 schemas | 51% scattered across domains | 49% centralized | Duplicates & orphans
**Target State:** 63 schemas | Single centralized location | No duplicates | Clear ownership
**Effort:** 4-6 hours for critical fixes | 2-3 days for full reorganization

---

## Overview

Singularity has **63 Ecto schemas** with a **hybrid organization** (some centralized, some scattered). This creates cognitive overhead and duplicates.

**Key Finding:** You already have a centralized `/schemas/` directory with 31 schemas—the solution is to move the other 32 there and resolve duplicates.

---

## Current Organization

### Centralized (31 schemas in `/schemas/`)
```
lib/singularity/schemas/
├── knowledge_artifact.ex
├── template.ex
├── code_chunk.ex
├── capability.ex
├── rule.ex
├── epic.ex
├── feature.ex
├── ... (24 more)
```

✅ **Good:** All in one place, easy to find
❌ **Problem:** Only 49% of schemas here

### Scattered Across Domains (32 schemas)
```
lib/singularity/analysis/
├── metadata.ex (Ecto schema mixed with logic)

lib/singularity/architecture_engine/
├── ... (schemas embedded in modules)

lib/singularity/storage/knowledge/
├── knowledge_artifact.ex (DUPLICATE!)

lib/singularity/storage/code/
├── code_location_index.ex (deeply nested)
├── patterns/code_pattern.ex (mixed with logic)

lib/singularity/tools/
├── tool_call.ex (embedded, unclear purpose)
└── tool_result.ex (embedded, unclear purpose)

... (and more scattered locations)
```

❌ **Problem:** Hard to find schemas
❌ **Problem:** Duplicates (KnowledgeArtifact defined in 2 places)
❌ **Problem:** Schema + logic mixed in same file

---

## Critical Issues to Fix First

### 🔴 ISSUE #1: Duplicate KnowledgeArtifact (MUST FIX)

**Problem:**
```
Location 1: /schemas/knowledge_artifact.ex
  Module: Singularity.Schemas.KnowledgeArtifact
  Table: knowledge_artifacts

Location 2: /storage/knowledge/knowledge_artifact.ex
  Module: Singularity.Knowledge.KnowledgeArtifact
  Table: curated_knowledge_artifacts
```

**Why it's bad:**
- Confusing which to use
- Possible data duplication
- Different table names (same domain, different structure)

**Solution:**
1. ✅ Keep: `schemas/knowledge_artifact.ex` (more mature, has learning loop support)
2. 🗑️ Delete: `storage/knowledge/knowledge_artifact.ex`
3. ✏️ Update: All imports pointing to old location
4. ✔️ Verify: No duplicate table creation in migrations

**Effort:** 30 minutes

**Files to Update:**
```bash
grep -r "Storage.Knowledge.KnowledgeArtifact" --include="*.ex" | wc -l
# Update all references to point to Schemas.KnowledgeArtifact
```

---

### 🔴 ISSUE #2: CodeLocationIndex Misplacement (MUST FIX)

**Problem:**
```
Current Location: /storage/code/storage/code_location_index.ex
  - Deeply nested path
  - 484 lines mixing schema + service logic
  - Module name inconsistent (top-level Singularity.CodeLocationIndex)
```

**Why it's bad:**
- Hard to locate (nested under storage/code/storage/)
- Schema and business logic mixed
- Violates single responsibility principle

**Solution:**
1. **Separate schema from logic:**
   ```
   BEFORE:
   storage/code/storage/code_location_index.ex (484 LOC)
   ├── Ecto schema definition
   ├── Indexing service logic
   ├── Query helpers
   └── Integration code

   AFTER:
   schemas/code_location_index.ex (50 LOC)
   └── Only schema definition

   storage/code/code_location_index_service.ex (434 LOC)
   └── All service logic
   ```

2. ✏️ Update: All imports
3. ✔️ Verify: Migrations still work

**Effort:** 1 hour

---

### 🟡 ISSUE #3: Scattered Schemas (SHOULD FIX)

**Problem:** 32 schemas across domains instead of 1 location

**Current locations:**
```
lib/singularity/analysis/metadata.ex
lib/singularity/architecture_engine/*/
lib/singularity/knowledge/knowledge_artifact.ex (DELETE per Issue #1)
lib/singularity/storage/code/code_location_index.ex (MOVE per Issue #2)
lib/singularity/storage/code/patterns/
lib/singularity/tools/tool_*.ex
lib/singularity/embedding/
lib/singularity/schemas/ (31 schemas already here!)
```

**Solution:** Move all to `/schemas/` following this structure:

```
lib/singularity/schemas/
├── core/
│   ├── knowledge_artifact.ex
│   ├── code_chunk.ex
│   ├── template.ex
│   └── ...
├── analysis/
│   ├── metadata.ex
│   ├── code_analysis_result.ex
│   ├── technology_detection.ex
│   └── ...
├── architecture/
│   ├── file_naming_violation.ex
│   ├── file_architecture_pattern.ex
│   ├── framework_learning.ex
│   └── ...
├── execution/
│   ├── capability.ex
│   ├── epic.ex
│   ├── feature.ex
│   ├── rule.ex
│   └── ...
├── tools/
│   ├── tool.ex (embedded schema)
│   ├── tool_param.ex (embedded schema)
│   ├── tool_call.ex
│   ├── tool_result.ex
│   └── instructor_schemas.ex
├── monitoring/
│   ├── agent_metric.ex
│   ├── quality_finding.ex
│   ├── search_metric.ex
│   └── ...
├── package_registry/
│   ├── package_dependency.ex
│   ├── package_code_example.ex
│   └── ...
├── access_control/
│   ├── user_codebase_permission.ex
│   └── user_preferences.ex
└── ml_training/
    ├── t5_training_session.ex
    └── ...
```

**Why this structure:**
- ✅ All schemas in one place (`schemas/`)
- ✅ Organized by subsystem (analysis, execution, tools)
- ✅ Clear hierarchy (easy to navigate)
- ✅ Follows existing Singularity pattern
- ✅ Minimal changes to imports (just path change)

**Effort:** 2-3 hours (mostly moving files + updating imports)

---

## 4-Phase Implementation Plan

### Phase 1: Fix Critical Duplicates (30 min - DO FIRST)

**Goal:** Eliminate duplicate KnowledgeArtifact

1. Verify `schemas/knowledge_artifact.ex` is the source of truth
   ```bash
   grep -l "knowledge_artifacts" singularity/lib/singularity/**/*.ex
   # Should show only one file
   ```

2. Delete `storage/knowledge/knowledge_artifact.ex`
   ```bash
   rm singularity/lib/singularity/storage/knowledge/knowledge_artifact.ex
   ```

3. Find all imports
   ```bash
   grep -r "Storage.Knowledge.KnowledgeArtifact" --include="*.ex"
   ```

4. Update to use `Schemas.KnowledgeArtifact`
   ```bash
   # Use Edit tool to update each file
   find . -name "*.ex" -exec sed -i 's/Storage\.Knowledge\.KnowledgeArtifact/Schemas.KnowledgeArtifact/g' {} \;
   ```

5. Compile and verify
   ```bash
   mix compile
   ```

**Commit:** `fix: Resolve KnowledgeArtifact duplication - keep schemas/ version`

---

### Phase 2: Separate Mixed Concerns (1 hour - DO SECOND)

**Goal:** Move CodeLocationIndex schema to `/schemas/`

1. Extract schema definition from `storage/code/storage/code_location_index.ex`
   - Lines 1-50: Schema definition → new file
   - Lines 51-484: Service logic → keep as is

2. Create `schemas/code_location_index.ex`
   ```elixir
   defmodule Singularity.Schemas.CodeLocationIndex do
     use Ecto.Schema
     # ... schema definition only
   end
   ```

3. Create `storage/code/code_location_index_service.ex`
   ```elixir
   defmodule Singularity.Storage.Code.CodeLocationIndexService do
     alias Singularity.Schemas.CodeLocationIndex
     # ... all service logic
   end
   ```

4. Update imports throughout codebase
   ```bash
   grep -r "CodeLocationIndex" --include="*.ex" | grep -v "schemas"
   # Update each to use Schemas.CodeLocationIndex
   ```

5. Compile and verify
   ```bash
   mix compile
   ```

**Commit:** `refactor: Separate CodeLocationIndex schema from service logic`

---

### Phase 3: Consolidate Scattered Schemas (2-3 hours)

**Goal:** Move all 32 scattered schemas to `/schemas/` with subdirectory organization

**Step 1: Create directory structure**
```bash
mkdir -p lib/singularity/schemas/{core,analysis,architecture,execution,tools,monitoring,package_registry,access_control,ml_training}
```

**Step 2: Move schemas by category**

| Source | Destination | Files |
|--------|-------------|-------|
| `analysis/metadata.ex` | `schemas/analysis/metadata.ex` | 1 |
| `storage/code/patterns/` | `schemas/analysis/` | 2 |
| `tools/tool*.ex` | `schemas/tools/` | 2 |
| `architecture_engine/` | `schemas/architecture/` | 3 |
| `embedding/` | `schemas/core/` | 1 |
| ... (and more) | `schemas/*/` | 32 total |

**Step 3: Update ALL imports**
```bash
# Find all import statements
grep -r "import.*Singularity\." --include="*.ex" | grep -v "schemas/"

# For each location change, update imports
# Example: analysis/metadata → schemas/analysis/metadata
find . -name "*.ex" -exec sed -i 's/Singularity\.Analysis\.Metadata/Singularity.Schemas.Analysis.Metadata/g' {} \;
```

**Step 4: Verify compilation**
```bash
mix compile
# Should have 0 errors after all updates
```

**Step 5: Verify tests still pass**
```bash
mix test
```

**Commit:** `refactor: Consolidate all Ecto schemas to centralized /schemas/ directory`

---

### Phase 4: Add AI Navigation Metadata (2-3 hours)

**Goal:** Add AI v2.1 metadata to ALL schemas

Only ~25% of schemas have comprehensive AI metadata. Add to remaining 75%.

**For each schema file, add:**
```elixir
defmodule Singularity.Schemas.YourSchema do
  @moduledoc """
  Your Schema - [purpose in one line]

  ## Module Identity

  ```json
  {
    "module": "Singularity.Schemas.YourSchema",
    "purpose": "[what it stores]",
    "role": "data_store",
    "layer": "persistence",
    "table": "your_table",
    "record_count_estimate": "HIGH|MEDIUM|LOW",
    "alternatives": {
      "OtherSchema": "Why use this instead"
    }
  }
  ```

  ## Database

  ```yaml
  table: your_table
  indexes:
    - columns: [user_id, created_at]
      type: btree
  relationships:
    belongs_to: [User]
    has_many: [OtherSchema]
  ```

  ## Anti-Patterns

  ### ❌ DO NOT create "YourSchemaView"
  **Why:** Query schema directly using Repo.get/2

  ### ❌ DO NOT embed this schema
  **Use instead:** Persistent table for relational queries
  ```

  ## Search Keywords

  schema, persistence, ecto, your_domain, your_concern, relational_data
  """

  use Ecto.Schema
  import Ecto.Changeset
  # ... rest of schema
end
```

**Batch update script:**
```bash
# For each schema without metadata, add the template
# Can be automated with a script
```

**Commit:** `docs: Add AI navigation metadata to all Ecto schemas`

---

## Expected Impact

### Before
```
Schemas scattered across:
- /schemas/ (31 schemas)
- /analysis/ (mixed)
- /storage/knowledge/ (duplicates)
- /storage/code/ (deeply nested)
- /tools/ (unclear purpose)
- /architecture_engine/ (mixed)
- /embedding/ (mixed)
- ... (7 more locations)

Problems:
❌ Hard to find schemas
❌ Duplicates (KnowledgeArtifact)
❌ Schema + logic mixed
❌ Inconsistent naming
❌ Only 25% have AI metadata
```

### After
```
All schemas in:
/schemas/
├── core/ (8 schemas)
├── analysis/ (10 schemas)
├── architecture/ (4 schemas)
├── execution/ (11 schemas)
├── tools/ (6 schemas)
├── monitoring/ (7 schemas)
├── package_registry/ (4 schemas)
├── access_control/ (2 schemas)
└── ml_training/ (4 schemas)

Benefits:
✅ Single location - find any schema immediately
✅ No duplicates - single source of truth
✅ Clear organization - organized by domain
✅ Consistent naming - all in Schemas namespace
✅ 100% AI metadata - all documented
```

---

## Quick Start Checklist

### Day 1: Critical Fixes (1.5 hours)

- [ ] Phase 1: Fix KnowledgeArtifact duplication (30 min)
  - [ ] Verify schemas/ version is source of truth
  - [ ] Delete storage/knowledge/knowledge_artifact.ex
  - [ ] Update all imports
  - [ ] Compile and verify
  - [ ] Commit

- [ ] Phase 2: Separate CodeLocationIndex (1 hour)
  - [ ] Extract schema from service logic
  - [ ] Create new schema file
  - [ ] Create new service file
  - [ ] Update imports
  - [ ] Compile and verify
  - [ ] Commit

### Day 2-3: Consolidation (3-4 hours)

- [ ] Phase 3: Move all schemas to /schemas/ (2-3 hours)
  - [ ] Create directory structure
  - [ ] Move files by category
  - [ ] Update all imports (automated if possible)
  - [ ] Compile and verify
  - [ ] Run tests
  - [ ] Commit

### Day 3-4: Documentation (2-3 hours)

- [ ] Phase 4: Add AI metadata (2-3 hours)
  - [ ] Create metadata template
  - [ ] Apply to all 63 schemas
  - [ ] Verify compilation
  - [ ] Commit

### Total Effort: 4-6 hours for critical fixes | 6-8 hours for full consolidation

---

## Verification Steps

After each phase:

```bash
# 1. Check for compilation errors
mix compile

# 2. Check for import errors
grep -r "undefined module" --include="*.ex"

# 3. Run tests
mix test

# 4. Check for remaining scattered schemas
find lib/singularity -name "*.ex" -type f | xargs grep -l "Ecto.Schema" | grep -v "schemas/"

# 5. Verify no duplicate tables
grep -r "schema(" lib/singularity/schemas --include="*.ex" | cut -d'"' -f2 | sort | uniq -d
```

---

## Rollback Strategy

If something breaks:

```bash
# Revert to previous commit
git revert <commit-hash>

# Or reset entire branch
git reset --hard <previous-commit>
```

Each phase is independent, so you can:
1. Do Phase 1 (critical)
2. If Phase 2 fails, revert and try again
3. Only continue to Phase 3 once Phase 1-2 pass

---

## Success Criteria

✅ **Ecto schema organization is successful when:**

1. **Single location:** All 63 schemas in `/schemas/` with subdirectories
2. **No duplicates:** Single source of truth for each schema
3. **Clear ownership:** Each schema has obvious domain (analysis, execution, tools, etc.)
4. **Mixed concerns separated:** No schema files with embedded service logic
5. **Consistent naming:** All schemas in `Singularity.Schemas.*` namespace
6. **AI metadata complete:** 100% of schemas documented
7. **Tests pass:** All 63+ tests pass after reorganization
8. **Compilation clean:** Zero errors, no import issues

---

## Recommended Order

**Phases in order of importance:**

1. ✅ **Phase 1: Critical** (30 min) - Fix duplicates
2. ✅ **Phase 2: Critical** (1 hour) - Separate concerns
3. ⏳ **Phase 3: Important** (3 hours) - Consolidate location
4. ⏳ **Phase 4: Nice-to-have** (2-3 hours) - Documentation

**DO Phases 1-3 now.** Phase 4 can be done later.

---

## Related Organization Work

This Ecto consolidation is part of the broader code organization improvement:

- **Code Organization:** See `CODE_ORGANIZATION_ACTION_PLAN.md`
  - Phases 1-4: Module reorganization (9-11 days)

- **Ecto Schemas:** This document
  - Phases 1-3: Schema consolidation (4-5 hours)

- **Extraction Infrastructure:** Already done (this session)
  - Phases 1-2.2: Completed

**Recommended:** Do Ecto Phases 1-3 **before** Code Organization, because moving schemas is quicker and unblocks other refactoring.

---

## Need More Details?

Read the comprehensive analysis documents:
- `SCHEMA_ANALYSIS_SUMMARY.txt` - Executive overview of all 63 schemas
- `ECTO_SCHEMAS_ANALYSIS.md` - Detailed analysis with diagrams
- `ECTO_SCHEMAS_QUICK_REFERENCE.md` - Searchable table of all schemas

---

**Ready to start? Begin with Phase 1: Fix KnowledgeArtifact duplication (30 min).**

# Knowledge Base Implementation Summary

## What We Built

A **Living Knowledge Base** system for internal tooling with bidirectional Git ←→ PostgreSQL sync, semantic search, and learning loops.

**Inspired by HashiCorp's architecture** (Terraform state, Vault policies) but optimized for **internal use** (features > speed/security).

---

## Architecture

```
templates_data/ (Moon Data Library)
      │ Git source of truth
      │ Human-editable JSONs
      │ Version controlled
      ↓
   Validate (moon run templates_data:validate)
      ↓
PostgreSQL 'singularity' Database
   knowledge_artifacts Table
      │ Dual storage (raw JSON + JSONB)
      │ pgvector embeddings
      │ Usage tracking
      ↓
  Learning Loop (usage tracking)
      ↓
  Export High-Quality Patterns
      ↓
templates_data/learned/
      │ Auto-exported learned patterns
      ↓
   Human Review & Promotion
      ↓
templates_data/{quality|frameworks|prompts}/
      │ Curated, proven patterns
      └─→ Re-sync to DB
```

---

## Files Created

### Migrations
- `singularity_app/priv/repo/migrations/20251006112622_create_knowledge_artifacts.exs`
  - Creates `knowledge_artifacts` table
  - Dual storage: `content_raw` (TEXT) + `content` (JSONB)
  - pgvector embeddings
  - Generated columns (language, tags)
  - GIN indexes for fast JSONB queries

### Core Modules
- `singularity_app/lib/singularity/knowledge/artifact_store.ex`
  - Main API for knowledge artifacts
  - Methods: `store/4`, `get/3`, `search/2`, `query_jsonb/1`
  - Bidirectional sync: `sync_from_git/1`, `export_learned_to_git/1`
  - Usage tracking: `record_usage/2`

- `singularity_app/lib/singularity/knowledge/knowledge_artifact.ex`
  - Ecto schema for `knowledge_artifacts` table
  - Dual storage validation
  - Virtual fields for similarity scores

### Mix Tasks
- `singularity_app/lib/mix/tasks/knowledge.migrate.ex`
  - Imports existing JSONs into database
  - Supports dry-run mode
  - Auto-detects artifact types from paths

### Scripts
- `scripts/setup-database.sh`
  - Creates `singularity` database (shared for dev/test/prod)
  - Installs extensions (pgvector, timescaledb, postgis)
  - Runs Ecto migrations

### Moon Configuration
- `templates_data/.moon/project.yml`
  - Moon tasks for validation, sync, embedding
  - `validate`, `sync-to-db`, `sync-from-db`, `embed-all`, `stats`

### Documentation
- `KNOWLEDGE_ARTIFACTS_SETUP.md` - Complete setup guide
- `DATABASE_STRATEGY.md` - Single shared DB rationale
- `templates_data/DUAL_STORAGE_DESIGN.md` - Raw + JSONB design
- `CLAUDE.md` - Updated with knowledge base workflows
- `README.md` - Updated for internal tooling focus

### Config Updates
- `singularity_app/config/config.exs` - Default DB: `singularity`
- `singularity_app/config/dev.exs` - Dev DB: `singularity`
- `singularity_app/config/test.exs` - Test DB: `singularity` (sandboxed)

---

## Database Schema

```sql
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  artifact_type TEXT NOT NULL,
  artifact_id TEXT NOT NULL,
  version TEXT DEFAULT '1.0.0',

  -- Dual storage
  content_raw TEXT NOT NULL,     -- Original JSON string (audit trail)
  content JSONB NOT NULL,        -- Parsed for fast queries

  -- Semantic search
  embedding vector(1536),

  -- Generated columns (auto-extracted from JSONB)
  language TEXT GENERATED ALWAYS AS (content->>'language') STORED,
  tags TEXT[] GENERATED ALWAYS AS (
    ARRAY(SELECT jsonb_array_elements_text(content->'tags'))
  ) STORED,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(artifact_type, artifact_id, version),
  CHECK (content = content_raw::jsonb)  -- Ensure consistency
);

-- Indexes
CREATE INDEX idx_type_lang ON knowledge_artifacts(artifact_type, language);
CREATE INDEX idx_content_gin ON knowledge_artifacts USING gin(content);
CREATE INDEX idx_tags ON knowledge_artifacts USING gin(tags);
CREATE INDEX idx_embedding ON knowledge_artifacts USING ivfflat(embedding vector_cosine_ops);
```

---

## Key Design Decisions

### 1. Single Shared Database (`singularity`)

**Instead of:** `singularity_dev`, `singularity_test`, `singularity_prod`
**Why:** Internal tooling, learning across environments, simpler setup

**Isolation:**
- Dev: Direct access
- Test: Ecto.Adapters.SQL.Sandbox (transactions, rolled back)
- Prod: Same DB (internal use, no multi-tenant)

### 2. Dual Storage (Raw JSON + JSONB)

**Why both?**
- `content_raw` (TEXT) - Audit trail, exact original, export to Git
- `content` (JSONB) - Fast queries, GIN index, semantic search
- `CHECK (content = content_raw::jsonb)` - Ensure consistency

**Use cases:**
- Raw: Debugging, export, audit logs
- JSONB: Queries (`@>` operator), updates, aggregations

### 3. Generated Columns

```sql
language TEXT GENERATED ALWAYS AS (content->>'language') STORED,
tags TEXT[] GENERATED ALWAYS AS (...) STORED,
```

**Benefits:**
- Fast filtering (indexed)
- Always in sync with JSONB (PostgreSQL guarantees)
- No manual denormalization

### 4. Artifact Types (Namespaces)

Different JSON shapes, same table:

- `quality_template` - Language quality standards
- `framework_pattern` - Framework-specific patterns
- `system_prompt` - LLM system prompts
- `code_template_*` - Code generation templates
- `package_metadata` - npm/cargo/hex/pypi packages

**Flexibility:** Add new types without schema changes!

### 5. Bidirectional Sync

**Git → DB** (curated knowledge):
```bash
moon run templates_data:sync-to-db
```

**DB → Git** (learned patterns):
```bash
moon run templates_data:sync-from-db
# Exports artifacts with high success_rate + usage_count
# to templates_data/learned/
```

---

## Workflows

### Add New Template
```bash
# 1. Create JSON
vim templates_data/quality/rust-production.json

# 2. Validate
moon run templates_data:validate

# 3. Sync to DB
moon run templates_data:sync-to-db

# 4. Query!
iex> ArtifactStore.get("quality_template", "rust-production")
```

### Semantic Search
```elixir
alias Singularity.Knowledge.ArtifactStore

# Search across all artifacts
{:ok, results} = ArtifactStore.search(
  "async worker with error handling",
  language: "elixir",
  top_k: 5
)

# Each result has similarity score
results
|> Enum.each(fn artifact ->
  IO.puts "#{artifact.artifact_id} (#{artifact.similarity})"
end)
```

### JSONB Queries
```elixir
# Fast containment queries (uses GIN index)
{:ok, templates} = ArtifactStore.query_jsonb(
  artifact_type: "quality_template",
  filter: %{"language" => "elixir", "quality_level" => "production"}
)
```

### Learning Loop
```elixir
# In your code: Track usage
{:ok, template} = ArtifactStore.get("quality_template", "elixir-production")
# ... use template ...
ArtifactStore.record_usage("elixir-production", success: true)

# After 100+ uses with 95%+ success...
```

```bash
# Export learned patterns back to Git
moon run templates_data:sync-from-db

# Review
ls templates_data/learned/quality_template/

# Promote if good
mv templates_data/learned/quality_template/elixir-production.json \
   templates_data/quality/elixir-production-v2.json
```

---

## Setup Instructions

### 1. Enter Nix Shell
```bash
nix develop
```

### 2. Create Database
```bash
./scripts/setup-database.sh
```

Creates `singularity` database with extensions.

### 3. Import Existing JSONs
```bash
cd singularity_app
mix knowledge.migrate
```

Scans and imports:
- `templates_data/**/*.json`
- `singularity_app/priv/code_quality_templates/*.json`
- `rust/tool_doc_index/templates/framework/*.json`
- `rust/tool_doc_index/templates/language/*.json`

### 4. Generate Embeddings
```bash
moon run templates_data:embed-all
```

Creates vector index for semantic search.

### 5. Verify
```bash
iex -S mix

iex> Singularity.Repo.aggregate(Singularity.Knowledge.KnowledgeArtifact, :count)
45  # Number of imported artifacts

iex> ArtifactStore.search("async", top_k: 3)
{:ok, [...]}
```

---

## Internal Tooling Philosophy

**Features & Learning > Speed & Security**

Since this is personal development tooling (not shipped software):

✅ **Optimize for:**
- Rich features, experimentation, fast iteration
- Developer experience, powerful workflows
- Learning loops (usage tracking, pattern extraction)
- Verbose logging, debugging, introspection
- Aggressive caching (no memory limits)

❌ **Don't optimize for:**
- Performance/scale (internal use only)
- Security hardening (you control everything)
- Production constraints (no SLAs, no multi-tenant)
- Backwards compatibility (break things, learn fast)

**Example:** Store everything (raw + parsed + embeddings + usage + search history) for maximum learning - storage is cheap, insights are valuable!

---

## Next Steps

1. **Run the setup:**
   ```bash
   nix develop
   ./scripts/setup-database.sh
   mix knowledge.migrate
   moon run templates_data:embed-all
   ```

2. **Start using it:**
   ```elixir
   iex> ArtifactStore.search("your query here")
   ```

3. **Let it learn:**
   - Use templates in your code
   - Track success/failure
   - Export learned patterns back to Git
   - Human review and promote

4. **Iterate:**
   - Add new artifact types
   - Experiment with different embeddings
   - Build UI for knowledge base exploration
   - No production constraints - go wild!

---

## Summary

✅ **Single shared database** (`singularity`) for all environments
✅ **Dual storage** (raw JSON + JSONB) for audit + performance
✅ **Semantic search** (pgvector embeddings)
✅ **Bidirectional sync** (Git ←→ PostgreSQL)
✅ **Learning loops** (usage tracking → export to Git)
✅ **Moon monorepo** integration
✅ **Nix** reproducibility
✅ **Internal tooling** (features > speed/security)

**HashiCorp-inspired, optimized for personal AI development!** 🚀

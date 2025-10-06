# Knowledge Artifacts Setup Guide

## Overview

This guide sets up the **Living Knowledge Base** system:
- **Git** (`templates_data/`) - Source of truth, human-editable JSONs
- **PostgreSQL** (`knowledge_artifacts` table) - Runtime queries, semantic search, learning
- **Bidirectional sync** - Git ←→ Database for continuous learning

## Architecture

```
templates_data/ (Git)     ←─────→    PostgreSQL (knowledge_artifacts)
├── quality/                          ├── Dual storage (raw JSON + JSONB)
├── frameworks/                       ├── pgvector embeddings
├── prompts/                          ├── Usage tracking
└── code_generation/                  └── Learning metrics
      │                                     │
      │ moon run templates_data:sync-to-db │
      ↓                                     ↓
   PostgreSQL ←─────────────────────── Semantic search
      │                                  Query, learn
      │ (high success_rate)                   │
      ↓                                       ↓
   templates_data/learned/           Track usage, improve
   (auto-exported)
```

## Prerequisites

1. **Nix development environment**
   ```bash
   nix develop
   # OR
   direnv allow
   ```

2. **PostgreSQL running** (auto-starts in Nix)
   ```bash
   pg_isready
   ```

## Setup Steps

### 1. Enter Nix Shell

```bash
cd /home/mhugo/code/singularity
nix develop
```

This starts:
- PostgreSQL with pgvector extension
- Elixir 1.18.4
- All required tools

### 2. Create Database

```bash
./scripts/setup-database.sh
```

This:
✅ Creates `singularity` database
✅ Installs extensions (pgvector, timescaledb, postgis)
✅ Runs Ecto migrations
✅ Creates `knowledge_artifacts` table

**What it creates:**

```sql
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY,
  artifact_type TEXT NOT NULL,       -- 'quality_template', 'framework_pattern', etc.
  artifact_id TEXT NOT NULL,
  version TEXT DEFAULT '1.0.0',

  -- Dual storage
  content_raw TEXT NOT NULL,         -- Original JSON string
  content JSONB NOT NULL,            -- Parsed for fast queries

  -- Semantic search
  embedding vector(1536),

  -- Generated columns (auto-extracted from JSONB)
  language TEXT GENERATED ALWAYS AS (content->>'language') STORED,
  tags TEXT[] GENERATED ALWAYS AS (...) STORED,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(artifact_type, artifact_id, version)
);
```

### 3. Import Existing JSONs

```bash
cd singularity_app
mix knowledge.migrate
```

This scans and imports:
- `templates_data/**/*.json`
- `singularity_app/priv/code_quality_templates/*.json`
- `rust/tool_doc_index/templates/framework/*.json`
- `rust/tool_doc_index/templates/language/*.json`

**Progress output:**
```
📄 Processing: templates_data/quality/elixir-production.json
   ✅ Migrated: quality_template/elixir-production (v1.0.0)

📄 Processing: templates_data/frameworks/phoenix.json
   ✅ Migrated: framework_pattern/phoenix (v1.0.0)

...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Migration Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total files:     45
✅ Successful:   45
❌ Failed:       0
```

### 4. Generate Embeddings

```bash
moon run templates_data:embed-all
```

This creates vector index for semantic search:
```sql
CREATE INDEX knowledge_artifacts_embedding_idx
ON knowledge_artifacts
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);
```

### 5. Verify Setup

```bash
# IEx shell
cd singularity_app
iex -S mix
```

```elixir
# Check count
alias Singularity.Knowledge.{ArtifactStore, KnowledgeArtifact}
alias Singularity.Repo

Repo.aggregate(KnowledgeArtifact, :count)
# => 45

# Test semantic search
{:ok, results} = ArtifactStore.search("async worker pattern", language: "elixir", top_k: 5)

# Test JSONB query
{:ok, templates} = ArtifactStore.query_jsonb(
  artifact_type: "quality_template",
  filter: %{"language" => "elixir"}
)

# Get specific artifact
{:ok, artifact} = ArtifactStore.get("quality_template", "elixir-production")
artifact.content["requirements"]
```

## Usage Workflows

### Workflow 1: Add New Template (Git → DB)

```bash
# 1. Create JSON in Git
vim templates_data/quality/rust-production.json

# 2. Validate
moon run templates_data:validate

# 3. Sync to DB
moon run templates_data:sync-to-db

# 4. Now queryable!
iex> ArtifactStore.get("quality_template", "rust-production")
```

### Workflow 2: Learn from Usage (DB → Git)

```elixir
# In your code: Use a template
{:ok, template} = ArtifactStore.get("quality_template", "elixir-production")

# Track success
ArtifactStore.record_usage("elixir-production", success: true)
# After 100 uses with 95%+ success...
```

```bash
# Export learned patterns back to Git
moon run templates_data:sync-from-db

# This creates:
# templates_data/learned/quality_template/elixir-production.json

# Review and promote if good
mv templates_data/learned/quality_template/elixir-production.json \
   templates_data/quality/elixir-production-v2.json
```

### Workflow 3: Semantic Search

```elixir
# Find similar patterns across ALL artifact types
{:ok, results} = ArtifactStore.search(
  "NATS consumer with error handling",
  artifact_types: ["code_template_messaging", "framework_pattern"],
  language: "elixir",
  top_k: 5
)

Enum.each(results, fn artifact ->
  IO.puts "#{artifact.artifact_type}/#{artifact.artifact_id} (similarity: #{artifact.similarity})"
end)

# Output:
# code_template_messaging/elixir-nats-consumer (similarity: 0.94)
# framework_pattern/phoenix (similarity: 0.87)
# ...
```

## Moon Tasks

All tasks run in monorepo mode:

```bash
# Validate JSONs
moon run templates_data:validate

# Sync Git → DB
moon run templates_data:sync-to-db

# Sync DB → Git (learned patterns)
moon run templates_data:sync-from-db

# Generate embeddings
moon run templates_data:embed-all

# Statistics
moon run templates_data:stats
```

## Database Configuration

### Single Shared Database

**All environments use `singularity` database:**

- **Dev**: `mix.exs` + `config/dev.exs` → `database: "singularity"`
- **Test**: `config/test.exs` → `database: "singularity"` + Sandbox
- **Prod**: `config/runtime.exs` → `database: "singularity"` (or from env)

**Why single DB?**
- Internal tooling (not shipped software)
- Learning across environments
- Simpler setup
- No production constraints

### Test Isolation

Tests use `Ecto.Adapters.SQL.Sandbox`:
- Each test runs in a transaction
- Rolled back after test
- No interference with dev data

```elixir
# test/test_helper.exs
Ecto.Adapters.SQL.Sandbox.mode(Singularity.Repo, :manual)

# In test
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Singularity.Repo)
end
```

## Files Created

### New Migrations
- `singularity_app/priv/repo/migrations/20251006112622_create_knowledge_artifacts.exs`

### New Modules
- `singularity_app/lib/singularity/knowledge/artifact_store.ex` - Main API
- `singularity_app/lib/singularity/knowledge/knowledge_artifact.ex` - Ecto schema
- `singularity_app/lib/mix/tasks/knowledge.migrate.ex` - Migration task

### New Scripts
- `scripts/setup-database.sh` - Database setup automation

### Updated Configs
- `singularity_app/config/config.exs` - Default DB: `singularity`
- `singularity_app/config/dev.exs` - Dev DB: `singularity`
- `singularity_app/config/test.exs` - Test DB: `singularity` (sandboxed)

### Documentation
- `DATABASE_STRATEGY.md` - Single DB strategy explained
- `templates_data/DUAL_STORAGE_DESIGN.md` - Raw + JSONB storage design
- `KNOWLEDGE_ARTIFACTS_SETUP.md` - This file!

## Troubleshooting

### PostgreSQL not running

```bash
# Check
pg_isready

# If not running, enter Nix shell
nix develop

# Or manual start (if not using Nix services)
pg_ctl -D $PGDATA -l logfile start
```

### Migration errors

```bash
# Drop and recreate
dropdb singularity
./scripts/setup-database.sh
```

### Re-import all JSONs

```bash
cd singularity_app
mix knowledge.migrate --dry-run  # Check first
mix knowledge.migrate            # Actually import
```

### Check database

```bash
psql singularity

-- List tables
\dt

-- Check knowledge_artifacts
SELECT artifact_type, COUNT(*) FROM knowledge_artifacts GROUP BY artifact_type;

-- Check embeddings
SELECT COUNT(*) FROM knowledge_artifacts WHERE embedding IS NOT NULL;
```

## Summary

✅ **Single shared database** (`singularity`) for all environments
✅ **Dual storage** (raw JSON + JSONB) for audit + performance
✅ **Semantic search** (pgvector embeddings)
✅ **Bidirectional sync** (Git ←→ PostgreSQL)
✅ **Learning loops** (usage tracking → export to Git)
✅ **Moon monorepo** integration
✅ **Nix** reproducibility

**Next:** Run the setup and start using the knowledge base!

```bash
nix develop
./scripts/setup-database.sh
cd singularity_app && mix knowledge.migrate
moon run templates_data:embed-all
```

Then explore in IEx! 🚀

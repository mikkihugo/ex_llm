# Database Migration Summary

## Overview

7 critical database migrations have been created to align the database schema with the codebase's Ecto schemas and runtime table creation logic.

## Migration Files Created

### 1. `20250101000007_create_semantic_code_search_tables.exs` (12KB)
**Purpose**: Create unified semantic code search schema (8 tables)

**Tables Created**:
- `codebase_metadata` - Main codebase metadata with 50+ columns and vector embeddings (1536-dim)
- `codebase_registry` - Tracks codebase paths and analysis status
- `graph_nodes` - Graph nodes for Apache AGE compatibility with vector embeddings (1536-dim)
- `graph_edges` - Graph edges for relationships (DAG support)
- `graph_types` - Predefined graph types (CallGraph, ImportGraph, SemanticGraph, DataFlowGraph)
- `vector_search` - Semantic search with vector embeddings (1536-dim)
- `vector_similarity_cache` - Performance cache for similarity scores

**Key Features**:
- Uses 1536-dimensional vectors (OpenAI text-embedding-3-small)
- IVFFlat vector indexes for fast cosine similarity search
- Comprehensive metrics: Halstead, PageRank, complexity, quality, security
- JSONB fields for flexible semantic features, dependencies, and symbols
- Matches runtime schema from `SemanticCodeSearch.create_unified_schema/1`

### 2. `20250101000008_add_missing_vector_indexes.exs` (3.3KB)
**Purpose**: Add missing IVFFlat vector indexes for existing tables

**Indexes Created**:
- `rules.embedding` (768-dim) - Rule semantic search
- `code_embeddings.embedding` (768-dim) - Code chunk search
- `code_locations.embedding` (768-dim) - Symbol location search
- `rag_documents.embedding` (768-dim) - RAG document search
- `rag_queries.query_embedding` (768-dim) - Query similarity
- `semantic_cache.query_embedding` (768-dim) - Cache lookup by similarity

**Key Features**:
- All indexes use IVFFlat with cosine similarity (`vector_cosine_ops`)
- Enables fast semantic search across all existing vector columns
- Uses 768 dimensions (Google text-embedding-004)

### 3. `20250101000009_create_autonomy_tables.exs` (3.4KB)
**Purpose**: Create autonomy system tables for rule execution tracking and evolution

**Tables Created**:
- `rule_executions` - Time-series record of rule executions for analysis
  - Tracks confidence, decision, reasoning, execution time
  - Records outcome (success/failure) for learning
  - Foreign key to `rules` table

- `rule_evolution_proposals` - Consensus-based rule improvement proposals
  - Tracks proposed patterns and thresholds
  - Voting system with consensus detection
  - Status: proposed, approved, rejected, expired

**Key Features**:
- Binary ID primary keys matching autonomy system
- Context snapshots at execution time (JSONB)
- Voting and consensus tracking for multi-agent learning

**Schemas**:
- `Singularity.Autonomy.RuleExecution`
- `Singularity.Autonomy.RuleEvolutionProposal`

### 4. `20250101000010_create_quality_tracking_tables.exs` (2.5KB)
**Purpose**: Create quality tracking tables for security and code analysis

**Tables Created**:
- `quality_runs` - Individual quality tool executions
  - Tool: sobelow, mix_audit, dialyzer, custom
  - Status: ok, warning, error
  - Tracks warning count, start/finish times

- `quality_findings` - Individual findings/warnings from quality runs
  - Category, message, file, line, severity
  - Foreign key to `quality_runs`
  - Immutable (no updated_at)

**Key Features**:
- Tracks all quality tool executions
- Links findings to runs for traceability
- Indexes on severity, category for fast filtering

**Schemas**:
- `Singularity.Quality.Run`
- `Singularity.Quality.Finding`

### 5. `20250101000011_create_technology_detection_tables.exs` (4.4KB)
**Purpose**: Create focused technology detection tables (replaces generic `technology_knowledge`)

**Tables Created**:
- `technology_patterns` - Detection patterns for technologies
  - File/directory/config patterns
  - Build/dev/install/test commands
  - Self-learning metrics (detection count, success rate)
  - Extended metadata for detector signatures

- `technology_templates` - Code generation templates
  - Identifier, category, version
  - Template as JSON map
  - Checksum for integrity

**Key Features**:
- Drops old `technology_knowledge` table (too generic)
- Self-learning detection with metrics
- Unique constraint on (technology_name, technology_type)

**Schemas**:
- `Singularity.Schemas.TechnologyPattern`
- `Singularity.Schemas.TechnologyTemplate`

### 6. `20250101000012_create_codebase_snapshots_table.exs` (2.3KB)
**Purpose**: Create focused `codebase_snapshots` table (replaces `detection_events`)

**Table Created**:
- `codebase_snapshots` - Detected technology snapshots
  - Codebase ID and snapshot ID (composite unique key)
  - Metadata, summary, detected technologies
  - Features (JSONB)
  - Immutable (no updated_at)

**Key Features**:
- Drops old `detection_events` table (too generic)
- Focused on technology detection snapshots
- GIN indexes on JSONB fields for fast queries

**Schema**:
- `Singularity.Schemas.CodebaseSnapshot`

### 7. `20250101000013_create_git_coordination_tables.exs` (4.5KB)
**Purpose**: Create git coordination tables for multi-agent operations

**Tables Created**:
- `git_agent_sessions` - Agent workspace tracking (replaces `git_sessions`)
  - Agent ID, branch, workspace path
  - Correlation ID for tracking
  - Status and metadata

- `git_pending_merges` - Pending merge tracking
  - Branch, PR number, agent ID
  - Task and correlation IDs

- `git_merge_history` - Historical merge outcomes
  - Branch, agent ID, merge commit
  - Status: success, conflict, failure
  - Details (JSONB)

**Key Features**:
- Drops old `git_sessions` and `git_commits` tables
- Enables multi-agent git coordination
- Tracks merge history for analysis

**Module**:
- `Singularity.Git.GitStateStore` (contains embedded schemas)

## Important Notes

### Conflicts with Existing Migration

There is an existing migration `20250101000014_align_schema_table_names.exs` that has some overlap:
- It also renames `detection_events` → `codebase_snapshots`
- It also handles `git_sessions` → `git_agent_sessions`
- It also splits `technology_knowledge` → `technology_templates` + `technology_patterns`

**Resolution Strategy**:
1. **Option A (Recommended)**: Delete migration 20250101000014 and use the new migrations 7, 11, 12, 13
2. **Option B**: Keep 20250101000014 and skip migrations that conflict (7, 11, 12, 13)
3. **Option C**: Merge the logic, keeping whichever approach is cleaner

The new migrations are more modular and production-ready with:
- Proper up/down functions
- Comprehensive indexes
- Better documentation
- Separate concerns (one migration per feature)

### Vector Dimensions

- **1536-dim vectors**: Semantic code search tables (OpenAI text-embedding-3-small)
- **768-dim vectors**: Legacy tables (Google text-embedding-004)

### Migration Order

Execute migrations in this order:
1. 20250101000007 (semantic search tables)
2. 20250101000008 (vector indexes)
3. 20250101000009 (autonomy tables)
4. 20250101000010 (quality tables)
5. 20250101000011 (technology detection tables)
6. 20250101000012 (codebase snapshots)
7. 20250101000013 (git coordination)

## Running Migrations

```bash
# Check migration status
mix ecto.migrations

# Run all pending migrations
mix ecto.migrate

# Rollback last migration
mix ecto.rollback

# Rollback to specific version
mix ecto.rollback --to 20250101000006
```

## Verification

After running migrations, verify with:

```sql
-- Check all tables exist
SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;

-- Check vector indexes
SELECT indexname, tablename FROM pg_indexes WHERE indexname LIKE '%vector%';

-- Check foreign keys
SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;
```

## Troubleshooting

### If migrations fail:

1. Check PostgreSQL has pgvector extension:
   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

2. Check for conflicting tables:
   ```sql
   DROP TABLE IF EXISTS <table_name> CASCADE;
   ```

3. Reset migrations (nuclear option):
   ```bash
   mix ecto.drop
   mix ecto.create
   mix ecto.migrate
   ```

### If vector indexes fail:

Ensure pgvector version supports IVFFlat:
```sql
SELECT * FROM pg_extension WHERE extname = 'vector';
```

Minimum version: pgvector 0.5.0+

## Schema Alignment Status

| Schema | Table | Status |
|--------|-------|--------|
| `SemanticCodeSearch` (runtime) | `codebase_metadata`, `codebase_registry`, `graph_nodes`, `graph_edges`, `graph_types`, `vector_search`, `vector_similarity_cache` | ✅ Migration 7 |
| `RuleExecution` | `rule_executions` | ✅ Migration 9 |
| `RuleEvolutionProposal` | `rule_evolution_proposals` | ✅ Migration 9 |
| `Quality.Run` | `quality_runs` | ✅ Migration 10 |
| `Quality.Finding` | `quality_findings` | ✅ Migration 10 |
| `TechnologyPattern` | `technology_patterns` | ✅ Migration 11 |
| `TechnologyTemplate` | `technology_templates` | ✅ Migration 11 |
| `CodebaseSnapshot` | `codebase_snapshots` | ✅ Migration 12 |
| `Git.GitStateStore` | `git_agent_sessions`, `git_pending_merges`, `git_merge_history` | ✅ Migration 13 |
| Existing tables | Vector indexes | ✅ Migration 8 |

## Next Steps

1. Review the migrations for any project-specific adjustments
2. Decide on conflict resolution strategy for migration 20250101000014
3. Test migrations in development environment
4. Run migrations in staging/production
5. Update seeds if needed
6. Remove runtime table creation from `SemanticCodeSearch` module once migration 7 is applied

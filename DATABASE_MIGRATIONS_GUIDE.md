# Database Migrations Guide

## Architecture Overview

Singularity uses **Elixir Ecto migrations** as the single source of truth for database schema. This guide explains the migration strategy and when to use additional optimization layers.

## Migration Layers

### 1. Elixir Migrations (Primary - Required)

**Location**: `singularity_app/priv/repo/migrations/*.exs`

**Purpose**: Core application schema (tables, indexes, constraints)

**Run with**:
```bash
# Enter nix development shell
nix develop

# Run migrations
cd singularity_app
mix ecto.migrate
```

**Key migrations**:
- `20251005030000_create_code_files.exs` - Code file storage
- `20251005030001_create_embeddings.exs` - Vector embeddings with HNSW index
- `20251005_add_rag_cache.exs` - LLM semantic cache
- `20251004222000_create_framework_patterns.exs` - Technology pattern detection

### 2. Rust Migrations (Optional - Performance Layer)

**Location**: `rust/db_service/migrations/*.sql`

**Purpose**: Advanced optimizations for large-scale deployments
- Partitioning for 750M+ lines of code
- Bloom filters for deduplication
- Custom parallel query functions
- TimescaleDB integration

**When to use**:
- ✅ Repository size > 100GB
- ✅ Query performance < 50ms required
- ✅ Multiple concurrent users (10+)
- ❌ Single developer, small codebase
- ❌ Development/testing environment

**Run with**:
```bash
# Apply Rust service optimizations (optional)
cd rust/db_service
cargo run --bin migrations
```

**What Rust migrations add**:
1. **`002_rag_optimizations.sql`**: Hash partitioning (16 partitions)
2. **`003_partition_optimized.sql`**: Adaptive partitioning based on size
3. **`004_enable_pg_cache.sql`**: Query result caching + bloom filters

### 3. flake.nix Setup (Dev Environment Only)

**Location**: `flake.nix` lines 466-486

**Purpose**: Bootstrap development databases with extensions

**What it does**:
```bash
# Creates databases (if not exists)
- singularity_dev
- singularity_test
- singularity_embeddings (legacy, may be removed)

# Enables extensions in all DBs
- vector (pgvector for embeddings)
- pgvecto_rs (alternative vector implementation)
```

**Does NOT create schema** - migrations handle that!

## Migration Order

Correct execution order for fresh setup:

```bash
# 1. Enter nix shell (creates DBs + extensions)
nix develop

# 2. Run Elixir migrations (creates schema)
cd singularity_app
mix ecto.create  # Create DB if needed
mix ecto.migrate

# 3. (Optional) Run Rust optimizations for production
cd ../rust/db_service
cargo run --bin migrations
```

## Schema Consistency Rules

### ✅ DO:
- Define all tables in Elixir migrations first
- Use Rust migrations only for performance optimizations
- Test Elixir migrations in development
- Document Rust migration prerequisites

### ❌ DON'T:
- Create tables in flake.nix
- Duplicate schema between Elixir and Rust
- Run Rust migrations before Elixir migrations
- Modify production schema manually

## Troubleshooting

### Error: `code_files` table doesn't exist

**Cause**: Elixir migrations not run

**Fix**:
```bash
cd singularity_app
mix ecto.migrate
```

### Error: `vector` extension not available

**Cause**: pgvector not installed

**Fix**:
```bash
# Already handled by flake.nix, but to verify:
psql -d singularity_dev -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Migrations out of sync

**Reset dev database** (⚠️ destroys data):
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

## Production Deployment

For production deployments (Fly.io, etc):

```bash
# 1. Ensure DATABASE_URL is set
export DATABASE_URL="postgres://user:pass@host/dbname"

# 2. Run Elixir migrations
cd singularity_app
MIX_ENV=prod mix ecto.migrate

# 3. (Optional) Apply Rust optimizations if needed
cd ../rust/db_service
DATABASE_URL=$DATABASE_URL cargo run --release --bin migrations
```

## Current Schema Summary

**Tables created by Elixir migrations**:
- `code_files` - Parsed code files with metadata
- `embeddings` - 768-dim vectors with HNSW index
- `llm_semantic_cache` - Cached LLM responses
- `framework_patterns` - Technology detection patterns
- `tool_knowledge` - MCP tool schemas
- `code_fingerprints` - Deduplication hashes
- `rag_performance_stats` - Query performance tracking

**Indexes**:
- HNSW indexes on all vector columns (for <50ms searches)
- GIN indexes on JSONB metadata
- B-tree indexes on foreign keys and filters

## References

- Elixir Ecto migrations: https://hexdocs.pm/ecto_sql/Ecto.Migration.html
- pgvector HNSW: https://github.com/pgvector/pgvector#hnsw
- TimescaleDB partitioning: https://docs.timescale.com/use-timescale/latest/hypertables/

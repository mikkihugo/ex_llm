# Database Strategy (Internal Tooling)

## Philosophy: Single Shared Database

For internal tooling (not shipped software), we use **ONE PostgreSQL database** for all environments.

### Why Single DB?

✅ **Learning across environments** - Dev experiments flow to test/prod
✅ **Simpler setup** - One connection, one place for knowledge
✅ **Data sharing** - Easy to copy patterns between envs
✅ **Nix-friendly** - Single PostgreSQL service
✅ **No production constraints** - We control everything!

## Database: `singularity`

```sql
-- One database, many schemas (optional) or prefixed tables

CREATE DATABASE singularity;

-- Extensions (shared across all envs)
CREATE EXTENSION IF NOT EXISTS vector;      -- pgvector
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgis;
```

## Table Strategy: Shared Tables

**All environments use the SAME `knowledge_artifacts` table.**

Why?
- Internal tool = we want ALL learning in one place
- Dev discovers pattern → Test validates → Query from anywhere
- No isolation needed (not multi-tenant, just YOU)

```sql
-- Shared table (no env prefix)
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY,
  artifact_type TEXT,
  artifact_id TEXT,
  content_raw TEXT,
  content JSONB,
  embedding vector(1536),
  ...
);

-- Optional: Add env tag if you want separation
-- But for internal use, usually not needed
```

## Elixir Config (Simplified)

### `config/dev.exs`
```elixir
config :singularity, Singularity.Repo,
  database: "singularity",  # Shared DB
  username: "mhugo",
  hostname: "localhost"
```

### `config/test.exs`
```elixir
config :singularity, Singularity.Repo,
  database: "singularity",  # Same DB!
  pool: Ecto.Adapters.SQL.Sandbox  # Sandboxed for tests
```

### `config/runtime.exs` (prod, if ever needed)
```elixir
config :singularity, Singularity.Repo,
  database: "singularity",  # Still same DB
  url: System.get_env("DATABASE_URL")  # Or from env
```

## Test Isolation (Using Sandbox)

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

## Setup Workflow

### 1. Create Database (Once)

```bash
# In Nix shell
nix develop

# Create database
createdb singularity

# Or if using system PostgreSQL
psql -c "CREATE DATABASE singularity;"
```

### 2. Run Migrations

```bash
cd singularity_app

# Run migrations (creates tables)
mix ecto.migrate

# This creates knowledge_artifacts table (and others)
```

### 3. Import Knowledge Artifacts

```bash
# Migrate existing JSONs to database
mix knowledge.migrate

# Generate embeddings
moon run templates_data:embed-all
```

### 4. Verify

```bash
# Check database
psql singularity -c "SELECT COUNT(*) FROM knowledge_artifacts;"

# Or in IEx
iex -S mix
iex> Singularity.Repo.aggregate(Singularity.Knowledge.KnowledgeArtifact, :count)
```

## Nix Integration

Add PostgreSQL to your `flake.nix` or `devenv.nix`:

```nix
# flake.nix
{
  services.postgres = {
    enable = true;
    package = pkgs.postgresql_17;
    initialDatabases = [{ name = "singularity"; }];
    extensions = extensions: [
      extensions.postgis
      extensions.timescaledb
      extensions.pgvector
    ];
  };
}
```

Or manual setup in `devenv.sh`:

```bash
# Ensure PostgreSQL is running
if ! pg_isready -q; then
  echo "Starting PostgreSQL..."
  pg_ctl -D $PGDATA -l logfile start
fi

# Create database if doesn't exist
psql -lqt | cut -d \| -f 1 | grep -qw singularity || createdb singularity
```

## Learning Flow (Single DB)

```
┌─────────────────────────────────────────┐
│  Dev: Experiment with patterns          │
│  INSERT INTO knowledge_artifacts        │
│  Track usage, success rate             │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Test: Validate patterns                │
│  Same table, sandboxed transactions     │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Export: Proven patterns → Git          │
│  mix run -e "ArtifactStore.export..."   │
│  Only exports high success_rate         │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  Git: Curated knowledge (templates_data)│
│  Human review, version control          │
└─────────────────────────────────────────┘
              ↓ (sync back)
┌─────────────────────────────────────────┐
│  DB: Re-import curated patterns         │
│  Available in ALL envs (dev/test/prod)  │
└─────────────────────────────────────────┘
```

## Mix Tasks (DB-Aware)

All Mix tasks auto-detect environment from `MIX_ENV`:

```bash
# Development (default)
mix knowledge.migrate           # Uses singularity DB

# Test
MIX_ENV=test mix test           # Uses singularity DB + Sandbox

# Production (if needed)
MIX_ENV=prod mix knowledge.migrate
```

## Backup Strategy (Internal Use)

Since it's internal, backups are simple:

```bash
# Dump entire database
pg_dump singularity > backups/singularity_$(date +%Y%m%d).sql

# Or just knowledge artifacts
pg_dump -t knowledge_artifacts singularity > backups/knowledge_$(date +%Y%m%d).sql

# Restore
psql singularity < backups/singularity_20251006.sql
```

## When to Split Databases?

**Only if:**
- You want COMPLETE isolation (paranoia mode)
- Different PostgreSQL versions per env (rare)
- Separate physical machines (unlikely for internal tool)

**Otherwise:** Single shared DB is simpler and better for learning!

## Summary

| Aspect | Strategy |
|--------|----------|
| **Database** | `singularity` (one for all) |
| **Tables** | Shared (no env prefixes) |
| **Test Isolation** | Ecto.Adapters.SQL.Sandbox |
| **Setup** | `createdb singularity && mix ecto.migrate` |
| **Learning Flow** | Dev → Test → Export → Git → Re-import |
| **Nix** | Single PostgreSQL service |

**Simple, powerful, perfect for internal tooling!**

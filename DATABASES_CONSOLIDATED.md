# Consolidated Database Configuration

**Date:** October 25, 2025
**Status:** ✅ Complete

## Summary

Renamed `genesis_db` to `genesis` and added `nexus` database for the unified Nexus server.

## Database Structure

```
PostgreSQL Instance (localhost:5432)
├── singularity       - Main Elixir/Phoenix app
├── centralcloud      - CentralCloud services
├── genesis           - Genesis improvement sandbox (renamed from genesis_db)
├── nexus             - Nexus TypeScript server (HITL history & metrics) ✨ NEW
├── genesis_test      - Test database for Genesis (renamed from genesis_db_test)
└── [other dbs]
```

## Changes Made

### 1. Renamed `genesis_db` → `genesis`

**Files Updated:**
- `genesis/config/config.exs` - Main config
- `genesis/config/test.exs` - Test config
- `genesis/config/dev.exs` - Dev config
- `genesis/config/prod.exs` - Prod config
- `genesis/lib/genesis/repo.ex` - Ecto repository docs
- `genesis/lib/genesis/isolation_manager.ex` - Moduledoc
- `genesis/lib/genesis/application.ex` - Moduledoc
- `genesis/lib/genesis/metrics_collector.ex` - Moduledoc
- `singularity/lib/singularity/database/backup_worker.ex` - Backup list
- `start-all.sh` - Setup script
- All markdown documentation files

**Database Names:**
- Production: `genesis` (was `genesis_db`)
- Test: `genesis_test` (was `genesis_db_test`)

### 2. Created `nexus` Database

**Files Created:**
- `nexus/src/db.ts` - PostgreSQL connection & schema
- `nexus/DATABASE_SETUP.md` - Database setup guide

**Files Updated:**
- `nexus/package.json` - Added `pg` driver (v8.11.3)
- `nexus/src/server.ts` - Database initialization (Layer 0)
- `nexus/CLAUDE.md` - Database component documentation

**Database Name:**
- `nexus` (configurable via `NEXUS_DB` env var)

**Tables Created Automatically:**
- `approval_requests` - Code approvals
- `question_requests` - Agent questions
- `hitl_metrics` - Response time tracking

## Database Configuration

### Genesis

```bash
# Environment variables
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=

# Genesis connects to: nexus/config/config.exs
config :genesis, Genesis.Repo, database: "genesis"
```

### Nexus

```bash
# Environment variables
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
NEXUS_DB=nexus          # New: database name

# Nexus connects via: src/db.ts
const config = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  database: process.env.NEXUS_DB || 'nexus',
  user: process.env.DB_USER || 'postgres',
}
```

## Backup Configuration

The Singularity backup worker now backs up all 4 databases:

```elixir
@databases ["singularity", "centralcloud", "genesis", "nexus"]
```

**Backup locations:**
```
.db-backup/hourly/backup_YYYYMMDD_HHMMSS/
├── singularity.sql
├── centralcloud.sql
├── genesis.sql        (renamed from genesis_db.sql)
└── nexus.sql          (new)

.db-backup/daily/backup_YYYYMMDD_HHMMSS/
└── [same structure]
```

## Quick Start

### Create Databases Manually (Optional)

The databases are created automatically on first application startup, but you can create them manually:

```bash
# Genesis
createdb -U postgres genesis

# Nexus
createdb -U postgres nexus
```

### Start Services

```bash
# 1. Terminal 1: PostgreSQL (if not running)
brew services start postgresql  # macOS
sudo systemctl start postgresql  # Linux

# 2. Terminal 2: Start Singularity, Genesis, Centralcloud
cd /path/to/singularity-incubation
./start-all.sh

# 3. Terminal 3: Start Nexus
cd nexus
bun run dev
```

### Verify Databases

```bash
# List all databases
psql -U postgres -l

# Check genesis
psql -U postgres -d genesis -c "\dt"

# Check nexus
psql -U postgres -d nexus -c "SELECT * FROM approval_requests LIMIT 1;"
```

## Database Purposes

### `singularity`
- **App:** Main Elixir/Phoenix application
- **Content:** Knowledge base, templates, execution history
- **Size:** ~100-500 MB
- **Schema:** Ecto migrations (auto-managed)

### `centralcloud`
- **App:** CentralCloud services
- **Content:** Framework learning, package intelligence, knowledge cache
- **Size:** ~50-200 MB
- **Schema:** Ecto migrations (auto-managed)

### `genesis`
- **App:** Genesis improvement sandbox
- **Content:** Experiment records, metrics, rollback history
- **Size:** ~10-100 MB
- **Schema:** Ecto migrations (auto-managed)

### `nexus`
- **App:** Nexus TypeScript unified server
- **Content:** Approval requests, decisions, questions, metrics
- **Size:** ~10-50 MB
- **Schema:** Auto-created on first connection (in `db.ts`)

## Testing

### Genesis (Elixir)

```bash
cd genesis

# Test database is: genesis_test (auto-created)
mix test

# Dev database is: genesis
MIX_ENV=dev mix ecto.migrate
iex -S mix
```

### Nexus (TypeScript)

```bash
cd nexus

# Dev database is: nexus (auto-created)
bun run dev

# Verify database
psql -U postgres -d nexus -c "SELECT COUNT(*) FROM approval_requests;"
```

## Architecture Diagram

```
Singularity (Elixir)
    │
    ├── singularity DB ──────────┐
    ├── centralcloud DB ─────────┤
    ├── genesis DB ──────────────┤ PostgreSQL
    │                            │ Instance
    └── NATS (llm.request,       │
        approval.request) ──┐    │
                             │   │
Nexus (TypeScript/Bun)       │   │
    │                        │   │
    ├── NATS Handler ────────┘   │
    ├── HITL Bridge              │
    ├── Remix UI                 │
    └── nexus DB ────────────────┘
```

## Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `genesis/config/config.exs` | Genesis main config | ✅ Updated (genesis_db → genesis) |
| `genesis/config/test.exs` | Genesis test config | ✅ Updated (genesis_db_test → genesis_test) |
| `genesis/lib/genesis/repo.ex` | Genesis Ecto repo | ✅ Updated (docs) |
| `singularity/lib/singularity/database/backup_worker.ex` | Backup worker | ✅ Updated (nexus added) |
| `nexus/src/db.ts` | Nexus PostgreSQL driver | ✅ Created |
| `nexus/src/server.ts` | Nexus server | ✅ Updated (DB init) |
| `nexus/package.json` | Nexus dependencies | ✅ Updated (pg added) |
| `nexus/CLAUDE.md` | Nexus docs | ✅ Updated (DB component) |
| `nexus/DATABASE_SETUP.md` | Nexus DB setup | ✅ Created |
| `start-all.sh` | Startup script | ✅ Updated (genesis ref) |

## Migration Path

If you have an existing `genesis_db` database in PostgreSQL:

```bash
# Backup old database
pg_dump -U postgres genesis_db > genesis_db.sql

# Create new database
createdb -U postgres genesis

# Restore
psql -U postgres genesis < genesis_db.sql

# Remove old database (optional)
dropdb -U postgres genesis_db
```

## Next Steps

1. ✅ Database naming consolidated
2. ✅ Nexus database configured
3. ✅ PostgreSQL driver added to Nexus
4. ⏳ **TODO:** Update environment templates (.env.example)
5. ⏳ **TODO:** Update deployment docs (Docker, K8s, etc.)

---

**Status:** Production Ready
**All databases:** PostgreSQL on localhost:5432
**Backup:** Automatic hourly/daily via Singularity
**Documentation:** Complete in each app directory

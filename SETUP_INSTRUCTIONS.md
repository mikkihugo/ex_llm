# Database Setup Instructions

## Summary of Changes

The following fixes have been applied to support all three Elixir applications (singularity, centralcloud, genesis):

### 1. flake.nix - PostgreSQL Extensions
Updated to include proper PostgreSQL extensions:
- **pgvector** - Vector embeddings for semantic search
- **postgis** - Geospatial queries
- **timescaledb** - Time-series data
- **pgtap** - PostgreSQL testing framework
- **pg_cron** - Scheduled tasks

### 2. setup-database.sh - Three Database Setup
Now sets up three independent databases:
- **singularity** - Main application
- **centralcloud** - Package intelligence and framework learning
- **genesis** - Autonomous experiments and improvement tracking

### 3. Migration Files
Updated to properly handle extension creation for all three databases.

## Steps to Complete Setup

### Step 1: Exit and Re-enter Nix Shell
The flake.nix has been updated with new PostgreSQL extensions. You need to exit the current Nix shell and re-enter it to use the new PostgreSQL build:

```bash
exit
nix develop
```

Or if using direnv:
```bash
direnv allow
direnv reload
```

This will rebuild PostgreSQL with pgvector and other extensions included.

### Step 2: Run Database Setup
Once back in the Nix shell, run the comprehensive database setup script:

```bash
./scripts/setup-database.sh
```

This script will:
1. ✅ Create/verify PostgreSQL is running
2. ✅ Create three databases (singularity, centralcloud, genesis)
3. ✅ Install all required extensions in each database
4. ✅ Run Ecto migrations for all three applications

### Expected Output

```
🗄️  Singularity Database Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Setting up databases: 'singularity', 'centralcloud', and 'genesis'

✅ PostgreSQL is running

Creating database 'singularity'...
✅ Database created

📦 Installing PostgreSQL extensions...
✅ Extensions installed

[... setup continues for each database ...]

✨ Database setup complete!

Databases created:
  • singularity (Singularity)
  • centralcloud (CentralCloud)
  • genesis (Genesis)
```

### Step 3: Verify Setup

After setup completes, verify all tables were created:

```bash
# Check singularity database
psql -d singularity -c "\dt" | head -20

# Check extensions
psql -d singularity -c "\dx" | grep -E "vector|timescale|postgis"
```

## Troubleshooting

### "type vector does not exist"
This means pgvector extension wasn't created. Ensure you:
1. Exited and re-entered `nix develop`
2. Ran `./scripts/setup-database.sh` after the new shell loaded

### PostgreSQL won't start
Check the log:
```bash
cat .dev-db/pg/postgres.log
```

### Extensions still missing
If extensions still fail after re-entering the shell, check what PostgreSQL is being used:
```bash
which postgres
postgres --version
```

Should show a very recent Nix store path with "pgvector" in nearby files.

## Files Modified

- `flake.nix` - Added pgvector, timescaledb, postgis, pgtap, pg_cron to PostgreSQL
- `scripts/setup-database.sh` - Added Genesis database support
- `singularity/priv/repo/migrations/20240101000001_enable_extensions.exs` - Comprehensive extension list
- `singularity/priv/repo/migrations/20240101000002_create_core_tables.exs` - Reverted to use vector type

## Next Steps After Setup

Once databases are ready:

```bash
# 1. Compile Elixir code
cd singularity && mix compile

# 2. Run tests
mix test

# 3. Import knowledge artifacts
mix knowledge.migrate

# 4. Start the application
mix phx.server
```

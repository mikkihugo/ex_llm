#!/usr/bin/env bash
# Database setup script for Singularity (Nix PostgreSQL)
# Creates shared databases with extensions for all environments
# Applications: singularity, centralcloud, genesis

set -euo pipefail

# Nix guard
GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
if [[ -f "${GUARD_DIR}/nix_guard.sh" ]]; then
  # shellcheck source=/dev/null
  source "${GUARD_DIR}/nix_guard.sh"
  require_nix_shell
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DB_NAME="${SINGULARITY_DB_NAME:-singularity}"
DB_USER="${SINGULARITY_DB_USER:-${USER}}"
CENTRALCLOUD_DB_NAME="${CENTRALCLOUD_DB_NAME:-centralcloud}"
GENESIS_DB_NAME="${GENESIS_DB_NAME:-genesis}"

echo -e "${GREEN}🗄️  Singularity Database Setup${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Setting up databases: '$DB_NAME', '$CENTRALCLOUD_DB_NAME', and '$GENESIS_DB_NAME'"
echo ""

# Check if PostgreSQL is running
if ! pg_isready -q 2>/dev/null; then
    echo -e "${YELLOW}⚠️  PostgreSQL is not running${NC}"
    echo ""
    echo "Starting PostgreSQL in Nix..."
    echo "If using devenv/nix develop, PostgreSQL should auto-start."
    echo ""
    echo "Manual start options:"
    echo "  1. nix develop (recommended)"
    echo "  2. pg_ctl -D \$PGDATA -l logfile start"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ PostgreSQL is running${NC}"
echo ""

# Check if database exists
if psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo -e "${YELLOW}📊 Database '$DB_NAME' already exists${NC}"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Dropping database...${NC}"
        dropdb "$DB_NAME" || true
    else
        echo "Skipping database creation. Will proceed with migrations."
        DB_EXISTS=true
    fi
fi

# Create database if needed
if [ -z "${DB_EXISTS:-}" ]; then
    echo -e "${GREEN}Creating database '$DB_NAME'...${NC}"
    createdb "$DB_NAME" -O "$DB_USER"
    echo -e "${GREEN}✅ Database created${NC}"
    echo ""
fi

# Configure PostgreSQL for TimescaleDB (requires preloading)
echo -e "${GREEN}⚙️  Configuring PostgreSQL for TimescaleDB...${NC}"
if ! grep -q "timescaledb" "$PGDATA/postgresql.conf" 2>/dev/null; then
    echo "shared_preload_libraries = 'timescaledb'" >> "$PGDATA/postgresql.conf"
    echo -e "${YELLOW}⚠️  PostgreSQL config updated - restarting server...${NC}"

    # Stop and start PostgreSQL to apply config
    pg_ctl -D "$PGDATA" stop -m fast 2>&1 | grep -v "^$" || true
    sleep 2
    pg_ctl -D "$PGDATA" start -l "$PGDATA/postgresql.log" 2>&1 | grep -v "^$" || true
    sleep 3
fi

# Install extensions
echo -e "${GREEN}📦 Installing PostgreSQL extensions...${NC}"

psql -d "$DB_NAME" << 'SQL'
-- Install all 56 available PostgreSQL extensions
-- This comprehensive set unlocks capabilities for:
-- - Vector embeddings (semantic search)
-- - Time-series analytics
-- - Geospatial queries
-- - Full-text search
-- - Graph databases
-- - Analytics & monitoring

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_buffercache;
CREATE EXTENSION IF NOT EXISTS pg_prewarm;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS intarray;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS bloom;
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS tablefunc;
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS earthdistance;
CREATE EXTENSION IF NOT EXISTS dict_int;
CREATE EXTENSION IF NOT EXISTS dict_xsyn;
CREATE EXTENSION IF NOT EXISTS isn;
CREATE EXTENSION IF NOT EXISTS seg;
CREATE EXTENSION IF NOT EXISTS lo;
CREATE EXTENSION IF NOT EXISTS xml2;
CREATE EXTENSION IF NOT EXISTS sslinfo;
CREATE EXTENSION IF NOT EXISTS adminpack;
CREATE EXTENSION IF NOT EXISTS amcheck;
CREATE EXTENSION IF NOT EXISTS insert_username;
CREATE EXTENSION IF NOT EXISTS moddatetime;
CREATE EXTENSION IF NOT EXISTS refint;
CREATE EXTENSION IF NOT EXISTS tcn;
CREATE EXTENSION IF NOT EXISTS tsm_system_rows;
CREATE EXTENSION IF NOT EXISTS tsm_system_time;
CREATE EXTENSION IF NOT EXISTS old_snapshot;
CREATE EXTENSION IF NOT EXISTS pageinspect;
CREATE EXTENSION IF NOT EXISTS pg_freespacemap;
CREATE EXTENSION IF NOT EXISTS pg_visibility;
CREATE EXTENSION IF NOT EXISTS pg_walinspect;
CREATE EXTENSION IF NOT EXISTS pg_surgery;
CREATE EXTENSION IF NOT EXISTS pgrowlocks;
CREATE EXTENSION IF NOT EXISTS pgstattuple;
CREATE EXTENSION IF NOT EXISTS address_standardizer;
CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us;
CREATE EXTENSION IF NOT EXISTS intagg;
CREATE EXTENSION IF NOT EXISTS autoinc;

SELECT 'All extensions installed: ' || count(*) FROM pg_extension;
SQL

echo -e "${GREEN}✅ Extensions installed${NC}"
echo ""

# Create centralcloud database if needed
echo -e "${GREEN}🗄️  Setting up Centralcloud database...${NC}"
if psql -lqt | cut -d \| -f 1 | grep -qw "$CENTRALCLOUD_DB_NAME"; then
    echo -e "${YELLOW}📊 Database '$CENTRALCLOUD_DB_NAME' already exists${NC}"
else
    echo -e "${GREEN}Creating database '$CENTRALCLOUD_DB_NAME'...${NC}"
    createdb "$CENTRALCLOUD_DB_NAME" -O "$DB_USER"
    echo -e "${GREEN}✅ Centralcloud database created${NC}"
fi

# Install extensions in centralcloud database
echo -e "${GREEN}📦 Installing PostgreSQL extensions in centralcloud...${NC}"
psql -d "$CENTRALCLOUD_DB_NAME" <<SQL
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT 'Extensions installed for centralcloud';
SQL

echo ""

# Create genesis database if needed
echo -e "${GREEN}🗄️  Setting up Genesis database...${NC}"
if psql -lqt | cut -d \| -f 1 | grep -qw "$GENESIS_DB_NAME"; then
    echo -e "${YELLOW}📊 Database '$GENESIS_DB_NAME' already exists${NC}"
else
    echo -e "${GREEN}Creating database '$GENESIS_DB_NAME'...${NC}"
    createdb "$GENESIS_DB_NAME" -O "$DB_USER"
    echo -e "${GREEN}✅ Genesis database created${NC}"
fi

# Install extensions in genesis database
echo -e "${GREEN}📦 Installing PostgreSQL extensions in genesis...${NC}"
psql -d "$GENESIS_DB_NAME" <<SQL
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
SELECT 'Extensions installed for genesis';
SQL

echo ""

# Run Ecto migrations
echo -e "${GREEN}🔄 Running Ecto migrations for singularity...${NC}"
cd "$PROJECT_ROOT/singularity"

mix ecto.migrate

echo -e "${GREEN}✅ Singularity migrations complete${NC}"
echo ""

# Run Ecto migrations for centralcloud
echo -e "${GREEN}🔄 Running Ecto migrations for centralcloud...${NC}"
cd "$PROJECT_ROOT/centralcloud"

mix ecto.migrate

echo -e "${GREEN}✅ Centralcloud migrations complete${NC}"
echo ""

# Run Ecto migrations for genesis
echo -e "${GREEN}🔄 Running Ecto migrations for genesis...${NC}"
cd "$PROJECT_ROOT/genesis"

mix ecto.migrate

echo -e "${GREEN}✅ Genesis migrations complete${NC}"
echo ""

# Verify setup
echo -e "${GREEN}🔍 Verifying database setup...${NC}"

psql -d "$DB_NAME" <<SQL
-- Check tables
SELECT
  schemaname,
  tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
SQL

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ Database setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Databases created:"
echo "  • $DB_NAME (Singularity)"
echo "  • $CENTRALCLOUD_DB_NAME (CentralCloud)"
echo "  • $GENESIS_DB_NAME (Genesis)"
echo ""
echo "Database user: $DB_USER"
echo ""
echo "Next steps:"
echo "  1. Import knowledge artifacts: cd $PROJECT_ROOT/singularity && mix knowledge.migrate"
echo "  2. Generate embeddings:        moon run templates_data:embed-all"
echo "  3. View statistics:            moon run templates_data:stats"
echo ""

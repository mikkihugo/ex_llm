#!/usr/bin/env bash
# Database setup script for Singularity (Nix PostgreSQL)
# Creates shared database with extensions for all environments

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

echo -e "${GREEN}🗄️  Singularity Database Setup${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Setting up databases: '$DB_NAME' and '$CENTRALCLOUD_DB_NAME'"
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

# Install extensions
echo -e "${GREEN}📦 Installing PostgreSQL extensions...${NC}"

psql -d "$DB_NAME" <<SQL
-- Vector embeddings (pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

-- TimescaleDB (time-series data)
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- PostGIS (geospatial, if needed)
CREATE EXTENSION IF NOT EXISTS postgis;

-- Apache AGE (graph database with Cypher queries)
CREATE EXTENSION IF NOT EXISTS age;

-- PgRouting (graph routing algorithms)
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- PgTAP (PostgreSQL testing)
CREATE EXTENSION IF NOT EXISTS pgtap;

-- PgCron (scheduled tasks)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Postgres FDW (Foreign Data Wrapper)
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Full-text search (pg_trgm for similarity)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Additional useful extensions
CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS ltree;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS unaccent;

SELECT 'Extension installed: ' || extname
FROM pg_extension
WHERE extname IN ('vector', 'timescaledb', 'postgis', 'age', 'pgrouting', 'pgtap', 'pg_cron', 'postgres_fdw', 'uuid-ossp', 'pg_trgm', 'btree_gin', 'btree_gist', 'pg_stat_statements', 'hstore', 'ltree', 'fuzzystrmatch', 'unaccent');
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
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
SELECT 'Extensions installed for centralcloud';
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
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo ""
echo "Next steps:"
echo "  1. Import knowledge artifacts: mix knowledge.migrate"
echo "  2. Generate embeddings:        moon run templates_data:embed-all"
echo "  3. View statistics:            moon run templates_data:stats"
echo ""

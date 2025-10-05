#!/usr/bin/env bash
set -e

echo "=== Testing Database Migrations ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}Error: Must be run from singularity_app directory${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Checking PostgreSQL connection...${NC}"
if mix run -e "Singularity.Repo.query!(\"SELECT 1\")" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Database connection OK${NC}"
else
    echo -e "${RED}✗ Cannot connect to database${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Checking migration status...${NC}"
mix ecto.migrations

echo ""
echo -e "${YELLOW}Step 3: Running pending migrations...${NC}"
mix ecto.migrate

echo ""
echo -e "${YELLOW}Step 4: Verifying migrations with SQL script...${NC}"
psql $DATABASE_URL -f priv/repo/migrations/verify_migrations.sql

echo ""
echo -e "${YELLOW}Step 5: Testing rollback (last migration)...${NC}"
mix ecto.rollback --step 1

echo ""
echo -e "${YELLOW}Step 6: Re-running migration...${NC}"
mix ecto.migrate

echo ""
echo -e "${GREEN}=== Migration Test Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Review MIGRATION_SUMMARY.md for details"
echo "2. Resolve conflict with migration 20250101000014 if needed"
echo "3. Test in staging environment"
echo "4. Deploy to production"

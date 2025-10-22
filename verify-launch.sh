#!/usr/bin/env bash
# Singularity Prototype Launch Verification Script
# Checks if all requirements are met for prototype launch

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}🔍 Singularity Prototype Launch Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

# Track overall status
ALL_CHECKS_PASSED=true
WARNINGS=0

# Helper function to check command exists
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -1 || echo "unknown")
        echo -e "  ${GREEN}✅ $name${NC} - $version"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "  ${RED}❌ $name - NOT FOUND (REQUIRED)${NC}"
            ALL_CHECKS_PASSED=false
            return 1
        else
            echo -e "  ${YELLOW}⚠️  $name - NOT FOUND (optional)${NC}"
            WARNINGS=$((WARNINGS + 1))
            return 0
        fi
    fi
}

# Helper function to check service
check_service() {
    local name=$1
    local check_cmd=$2
    local required=$3
    
    if eval "$check_cmd" &> /dev/null; then
        echo -e "  ${GREEN}✅ $name - RUNNING${NC}"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "  ${RED}❌ $name - NOT RUNNING (REQUIRED)${NC}"
            ALL_CHECKS_PASSED=false
            return 1
        else
            echo -e "  ${YELLOW}⚠️  $name - NOT RUNNING (optional)${NC}"
            WARNINGS=$((WARNINGS + 1))
            return 0
        fi
    fi
}

# 1. Check System Requirements
echo -e "${YELLOW}[1/7] System Requirements${NC}"
check_command "nix" "Nix" "true"
check_command "direnv" "direnv" "false"
check_command "git" "Git" "true"
echo ""

# 2. Check Nix Environment
echo -e "${YELLOW}[2/7] Nix Environment${NC}"
if [ -n "${IN_NIX_SHELL:-}" ] || [ -n "${DIRENV_IN_ENVRC:-}" ]; then
    echo -e "  ${GREEN}✅ Nix shell active${NC}"
else
    echo -e "  ${RED}❌ Not in Nix shell - Run 'nix develop' or 'direnv allow'${NC}"
    ALL_CHECKS_PASSED=false
fi

check_command "elixir" "Elixir" "true"
check_command "mix" "Mix" "true"
check_command "bun" "Bun" "true"
check_command "psql" "PostgreSQL Client" "true"
check_command "nats-server" "NATS Server" "true"
check_command "rustc" "Rust" "false"
echo ""

# 3. Check Services Running
echo -e "${YELLOW}[3/7] Required Services${NC}"
check_service "PostgreSQL" "pg_isready -q" "true"
check_service "NATS Server" "pgrep -x nats-server" "false"
echo ""

# 4. Check Database
echo -e "${YELLOW}[4/7] Database Status${NC}"
if pg_isready -q; then
    if psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "singularity"; then
        echo -e "  ${GREEN}✅ Database 'singularity' exists${NC}"
        
        # Check extensions
        EXTENSIONS=$(psql -d singularity -tAc "SELECT count(*) FROM pg_extension WHERE extname IN ('vector', 'timescaledb', 'postgis')" 2>/dev/null || echo "0")
        if [ "$EXTENSIONS" -ge 1 ]; then
            echo -e "  ${GREEN}✅ PostgreSQL extensions installed${NC}"
        else
            echo -e "  ${YELLOW}⚠️  Missing some PostgreSQL extensions${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
        
        # Check tables
        TABLE_COUNT=$(psql -d singularity -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null || echo "0")
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}✅ Database has $TABLE_COUNT tables${NC}"
        else
            echo -e "  ${YELLOW}⚠️  No tables found - Run './scripts/setup-database.sh'${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "  ${RED}❌ Database 'singularity' not found - Run './scripts/setup-database.sh'${NC}"
        ALL_CHECKS_PASSED=false
    fi
else
    echo -e "  ${RED}❌ PostgreSQL not accessible${NC}"
fi
echo ""

# 5. Check Configuration
echo -e "${YELLOW}[5/7] Configuration Files${NC}"
if [ -f ".env" ]; then
    echo -e "  ${GREEN}✅ .env file exists${NC}"
    
    # Check critical env vars
    if grep -q "SECRET_KEY_BASE=" .env && [ "$(grep SECRET_KEY_BASE= .env | cut -d= -f2)" != "" ]; then
        echo -e "  ${GREEN}✅ SECRET_KEY_BASE configured${NC}"
    else
        echo -e "  ${RED}❌ SECRET_KEY_BASE missing or empty${NC}"
        ALL_CHECKS_PASSED=false
    fi
    
    if grep -q "DATABASE_URL=" .env; then
        echo -e "  ${GREEN}✅ DATABASE_URL configured${NC}"
    else
        echo -e "  ${YELLOW}⚠️  DATABASE_URL not in .env (will use default)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${YELLOW}⚠️  .env file not found - Create from .env.example${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -f ".env.example" ]; then
    echo -e "  ${GREEN}✅ .env.example exists (template)${NC}"
fi
echo ""

# 6. Check Dependencies
echo -e "${YELLOW}[6/7] Dependencies${NC}"
if [ -d "singularity_app/deps" ]; then
    echo -e "  ${GREEN}✅ Elixir dependencies installed${NC}"
else
    echo -e "  ${YELLOW}⚠️  Elixir deps not installed - Run 'cd singularity_app && mix deps.get'${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -d "singularity_app/_build" ]; then
    echo -e "  ${GREEN}✅ Elixir application compiled${NC}"
else
    echo -e "  ${YELLOW}⚠️  Elixir not compiled - Run 'cd singularity_app && mix compile'${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if [ -d "llm-server/node_modules" ]; then
    echo -e "  ${GREEN}✅ AI Server dependencies installed${NC}"
else
    echo -e "  ${YELLOW}⚠️  AI Server deps not installed - Run 'cd llm-server && bun install'${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# 7. Check Running Services
echo -e "${YELLOW}[7/7] Application Status${NC}"
if lsof -i:4000 &> /dev/null; then
    echo -e "  ${GREEN}✅ Elixir app running (port 4000)${NC}"
else
    echo -e "  ${YELLOW}⚠️  Elixir app not running${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

if lsof -i:3000 &> /dev/null; then
    echo -e "  ${GREEN}✅ AI Server running (port 3000)${NC}"
else
    echo -e "  ${YELLOW}⚠️  AI Server not running${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Final Summary
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo -e "${BLUE}📊 Verification Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
echo ""

if [ "$ALL_CHECKS_PASSED" = true ]; then
    if [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}🎉 ALL CHECKS PASSED - Ready to launch!${NC}"
        echo ""
        echo -e "Your system is fully configured and ready."
        echo -e "Run ${GREEN}./start-all.sh${NC} to start all services."
        exit 0
    else
        echo -e "${GREEN}✅ REQUIRED CHECKS PASSED${NC}"
        echo -e "${YELLOW}⚠️  $WARNINGS warnings (non-critical)${NC}"
        echo ""
        echo -e "Your system meets minimum requirements."
        echo -e "You can proceed with launch, but consider addressing warnings."
        echo ""
        echo -e "To start: ${GREEN}./start-all.sh${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ LAUNCH BLOCKED - Critical issues found${NC}"
    echo ""
    echo -e "Fix the issues marked with ${RED}❌${NC} above before launching."
    echo ""
    echo -e "${YELLOW}Quick fixes:${NC}"
    echo -e "  1. Run ${GREEN}nix develop${NC} to enter Nix shell"
    echo -e "  2. Run ${GREEN}./scripts/setup-database.sh${NC} to setup database"
    echo -e "  3. Create ${GREEN}.env${NC} file from .env.example"
    echo -e "  4. Generate SECRET_KEY_BASE with ${GREEN}mix phx.gen.secret${NC}"
    echo ""
    echo -e "Then run this verification script again."
    exit 1
fi

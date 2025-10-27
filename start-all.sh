#!/usr/bin/env bash
# Singularity Complete System Startup Script
# Starts all required services in proper order
# 
# Current Architecture (October 2025):
# - Singularity (Core Elixir/OTP) - port 4000
# - CentralCloud (Pattern Intelligence) - port 4001  
# - Observer (Phoenix Web UI) - port 4002
# - PostgreSQL (Database)
# - NATS (Message Queue)
# 
# Note: AI server (TypeScript/Bun) was removed - AI calls go directly through ExLLM

set -euo pipefail

# Nix guard
if [[ -f "scripts/lib/nix_guard.sh" ]]; then
  # shellcheck source=/dev/null
  source scripts/lib/nix_guard.sh
  require_nix_shell
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting Singularity System...${NC}"

# Check for existing processes and warn
echo -e "\n${YELLOW}Checking for existing processes...${NC}"
existing_processes=()

if pgrep -f "nats-server" > /dev/null; then
    existing_processes+=("NATS Server")
fi

if pgrep -f "postgres" > /dev/null; then
    existing_processes+=("PostgreSQL")
fi

if pgrep -f "elixir.*singularity" > /dev/null || pgrep -f "beam.*singularity" > /dev/null; then
    existing_processes+=("Elixir Application")
fi

if pgrep -f "elixir.*observer" > /dev/null || pgrep -f "beam.*observer" > /dev/null; then
    existing_processes+=("Observer")
fi

if pgrep -f "elixir.*centralcloud" > /dev/null || pgrep -f "beam.*centralcloud" > /dev/null; then
    existing_processes+=("Centralcloud")
fi

if pgrep -f "elixir.*genesis" > /dev/null || pgrep -f "beam.*genesis" > /dev/null; then
    existing_processes+=("Genesis")
fi

if [ ${#existing_processes[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Found existing processes:${NC}"
    for process in "${existing_processes[@]}"; do
        echo "  - $process"
    done
    echo -e "${YELLOW}The script will attempt to use existing processes or start new ones as needed.${NC}"
    echo ""
fi

# 1. Check and start NATS
echo -e "\n${YELLOW}[1/6] Checking NATS...${NC}"
if pgrep -x "nats-server" > /dev/null; then
    echo "✅ NATS already running"
else
    echo "Starting NATS with JetStream..."
    nats-server -c .nats/nats-server.conf > logs/nats.log 2>&1 &
    sleep 2
    if pgrep -x "nats-server" > /dev/null; then
        echo "✅ NATS started on port 4222"
    else
        echo -e "${RED}❌ Failed to start NATS${NC}"
        exit 1
    fi
fi

# 2. Check PostgreSQL
echo -e "\n${YELLOW}[2/6] Checking PostgreSQL...${NC}"
if pg_isready -h localhost -p 5432 -q; then
    echo "✅ PostgreSQL is running"
else
    echo -e "${RED}❌ PostgreSQL is not running. Please start it:${NC}"
    echo "  sudo systemctl start postgresql"
    echo "  or: brew services start postgresql"
    echo "  or: ./scripts/setup-database.sh"
    exit 1
fi

# 3. Start Centralcloud
echo -e "\n${YELLOW}[3/6] Starting Centralcloud...${NC}"

# Check for existing Centralcloud processes
if pgrep -f "elixir.*centralcloud" > /dev/null || pgrep -f "beam.*centralcloud" > /dev/null; then
    echo "✅ Centralcloud already running"
else
    cd centralcloud

    # Install dependencies if needed
    if [ ! -d "deps" ]; then
        echo "Installing Centralcloud dependencies..."
        mix deps.get
    fi

    # Compile if needed
    if [ ! -d "_build" ]; then
        echo "Compiling Centralcloud application..."
        mix compile
    fi

    # Run migrations
    echo "Running Centralcloud database migrations..."
    mix ecto.migrate
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Centralcloud migrations failed${NC}"
        echo "Check that PostgreSQL is running and centralcloud database exists"
        exit 1
    fi
    echo "✅ Centralcloud migrations up to date"

    # Start the application with hot reload
    echo "Starting Centralcloud application (with hot reload)..."
    MIX_ENV=dev iex --name centralcloud@127.0.0.1 --cookie singularity-secret -S mix > ../logs/centralcloud.log 2>&1 &
    sleep 3

    if pgrep -f "elixir.*centralcloud" > /dev/null; then
        echo "✅ Centralcloud started"
    else
        echo -e "${YELLOW}⚠️  Centralcloud may have failed to start${NC}"
        echo "Check logs/centralcloud.log for details"
    fi
    cd ..
fi

# 4. Start Genesis
echo -e "\n${YELLOW}[4/6] Starting Genesis...${NC}"

# Check for existing Genesis processes
if pgrep -f "elixir.*genesis" > /dev/null || pgrep -f "beam.*genesis" > /dev/null; then
    echo "✅ Genesis already running"
else
    cd genesis

    # Install dependencies if needed
    if [ ! -d "deps" ]; then
        echo "Installing Genesis dependencies..."
        mix deps.get
    fi

    # Compile if needed
    if [ ! -d "_build" ]; then
        echo "Compiling Genesis application..."
        mix compile
    fi

    # Run migrations
    echo "Running Genesis database migrations..."
    mix ecto.migrate
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Genesis migrations failed${NC}"
        echo "Check that PostgreSQL is running and genesis database exists"
        exit 1
    fi
    echo "✅ Genesis migrations up to date"

    # Start the application with hot reload
    echo "Starting Genesis application (with hot reload)..."
    MIX_ENV=dev iex --name genesis@127.0.0.1 --cookie singularity-secret -S mix > ../logs/genesis.log 2>&1 &
    sleep 3

    if pgrep -f "elixir.*genesis" > /dev/null; then
        echo "✅ Genesis started"
    else
        echo -e "${YELLOW}⚠️  Genesis may have failed to start${NC}"
        echo "Check logs/genesis.log for details"
    fi
    cd ..
fi

# 5. Start Singularity Application
echo -e "\n${YELLOW}[5/6] Starting Singularity Application...${NC}"

# Check for existing Singularity processes
if pgrep -f "elixir.*singularity" > /dev/null || pgrep -f "beam.*singularity" > /dev/null; then
    echo "✅ Singularity already running"
else
    cd singularity

    # Install dependencies if needed
    if [ ! -d "deps" ]; then
        echo "Installing Elixir dependencies..."
        mix deps.get
    fi

    # Compile if needed
    if [ ! -d "_build" ]; then
        echo "Compiling Elixir application..."
        mix compile
    fi

    # Run migrations
    echo "Running Singularity database migrations..."
    mix ecto.migrate
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Singularity migrations failed${NC}"
        echo "Check that PostgreSQL is running and singularity database exists"
        exit 1
    fi
    echo "✅ Singularity migrations up to date"

    # Start the application with hot reload
    echo "Starting Singularity application (with hot reload)..."
    MIX_ENV=dev iex --name singularity@127.0.0.1 --cookie singularity-secret -S mix phx.server > ../logs/singularity.log 2>&1 &
    sleep 5

    if pgrep -f "elixir.*singularity" > /dev/null || pgrep -f "beam.*singularity" > /dev/null; then
        echo "✅ Singularity started"
    else
        echo -e "${YELLOW}⚠️  Singularity may have failed to start${NC}"
        echo "Check logs/singularity.log for details"
    fi
    cd ..
fi

# 6. Start Observer (Phoenix Web UI)
echo -e "\n${YELLOW}[6/6] Starting Observer...${NC}"

# Check for existing Observer processes
if pgrep -f "elixir.*observer" > /dev/null || pgrep -f "beam.*observer" > /dev/null; then
    echo "✅ Observer already running"
else
    cd observer

    # Install dependencies if needed
    if [ ! -d "deps" ]; then
        echo "Installing Observer dependencies..."
        mix deps.get
    fi

    # Compile if needed
    if [ ! -d "_build" ]; then
        echo "Compiling Observer application..."
        mix compile
    fi

    # Run migrations
    echo "Running Observer database migrations..."
    mix ecto.migrate
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Observer migrations failed${NC}"
        echo "Check that PostgreSQL is running and observer database exists"
        exit 1
    fi
    echo "✅ Observer migrations up to date"

    # Start the application with hot reload
    echo "Starting Observer application (with hot reload)..."
    MIX_ENV=dev iex --name observer@127.0.0.1 --cookie singularity-secret -S mix phx.server > ../logs/observer.log 2>&1 &
    sleep 3

    if pgrep -f "elixir.*observer" > /dev/null; then
        echo "✅ Observer started on port 4002"
    else
        echo -e "${YELLOW}⚠️  Observer may have failed to start${NC}"
        echo "Check logs/observer.log for details"
    fi
    cd ..
fi

# Final status check
echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Singularity System Status:${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"

# Check each service
services=(
    "nats-server:4222:NATS"
    "postgres:N/A:PostgreSQL"
    "elixir.*centralcloud:4001:CentralCloud"
    "elixir.*genesis:N/A:Genesis"
    "elixir.*singularity:4000:Singularity"
    "elixir.*observer:4002:Observer"
)

all_running=true
for service in "${services[@]}"; do
    IFS=':' read -r process port name <<< "$service"

    if [ "$port" = "N/A" ]; then
        if pgrep -f "$process" > /dev/null; then
            echo -e "  ✅ $name: ${GREEN}Running${NC}"
        else
            echo -e "  ❌ $name: ${RED}Not Running${NC}"
            all_running=false
        fi
    else
        if lsof -i:$port > /dev/null 2>&1; then
            echo -e "  ✅ $name: ${GREEN}Running on port $port${NC}"
        else
            echo -e "  ❌ $name: ${RED}Not Running${NC}"
            all_running=false
        fi
    fi
done

echo -e "${GREEN}═══════════════════════════════════════${NC}"

if $all_running; then
    echo -e "\n${GREEN}✨ All services are running!${NC}"
    echo -e "\nYou can now:"
    echo "  • Singularity (Core): http://localhost:4000"
    echo "  • CentralCloud (Patterns): http://localhost:4001"
    echo "  • Observer (Web UI): http://localhost:4002"
    echo "  • View logs: tail -f logs/*.log"
    echo "  • AI calls go directly through ExLLM (no HTTP intermediary)"
else
    echo -e "\n${YELLOW}⚠️  Some services failed to start${NC}"
    echo "Check the logs directory for details"
fi

echo -e "\nTo stop all services, run: ${YELLOW}./stop-all.sh${NC}"

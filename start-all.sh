#!/usr/bin/env bash
# Singularity Complete System Startup Script
# Starts all required services in proper order

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

# 1. Check and start NATS
echo -e "\n${YELLOW}[1/4] Checking NATS...${NC}"
if pgrep -x "nats-server" > /dev/null; then
    echo "✅ NATS already running"
else
    echo "Starting NATS with JetStream..."
    nats-server -js -sd .nats -p 4222 > logs/nats.log 2>&1 &
    sleep 2
    if pgrep -x "nats-server" > /dev/null; then
        echo "✅ NATS started on port 4222"
    else
        echo -e "${RED}❌ Failed to start NATS${NC}"
        exit 1
    fi
fi

# 2. Check PostgreSQL
echo -e "\n${YELLOW}[2/4] Checking PostgreSQL...${NC}"
if pg_isready -q; then
    echo "✅ PostgreSQL is running"
else
    echo -e "${RED}❌ PostgreSQL is not running. Please start it:${NC}"
    echo "  sudo systemctl start postgresql"
    echo "  or: brew services start postgresql"
    exit 1
fi

# 3. Start Elixir Application
echo -e "\n${YELLOW}[3/4] Starting Elixir Application...${NC}"
if pgrep -f "beam.*singularity" > /dev/null; then
    echo "✅ Elixir app already running"
else
    cd singularity_app

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

    # Start the application
    echo "Starting Elixir application..."
    MIX_ENV=dev elixir --name singularity@127.0.0.1 --cookie singularity-secret -S mix phx.server > ../logs/elixir.log 2>&1 &
    sleep 5

    if pgrep -f "beam.*singularity" > /dev/null; then
        echo "✅ Elixir app started on port 4000"
    else
        echo -e "${YELLOW}⚠️  Elixir app may have failed to start${NC}"
        echo "Check logs/elixir.log for details"
    fi
    cd ..
fi

# 4. Start AI Server (TypeScript)
echo -e "\n${YELLOW}[4/4] Starting AI Server...${NC}"
if lsof -i:3000 > /dev/null 2>&1; then
    echo "✅ AI Server already running on port 3000"
else
    cd ai-server

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing AI Server dependencies..."
        bun install
    fi

    # Load environment variables
    if [ -f "../.env" ]; then
        export $(cat ../.env | grep -v '^#' | xargs)
    fi

    echo "Starting AI Server..."
    bun run src/server.ts > ../logs/ai-server.log 2>&1 &
    sleep 3

    if lsof -i:3000 > /dev/null 2>&1; then
        echo "✅ AI Server started on port 3000"
    else
        echo -e "${RED}❌ Failed to start AI Server${NC}"
        echo "Check logs/ai-server.log for details"
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
    "beam:4000:Elixir App"
    "bun:3000:AI Server"
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
    echo "  • Test AI Server: curl http://localhost:3000/health"
    echo "  • Test Elixir: curl http://localhost:4000/health"
    echo "  • Test orchestration: curl http://localhost:3000/v1/orchestrated/chat"
    echo "  • View logs: tail -f logs/*.log"
else
    echo -e "\n${YELLOW}⚠️  Some services failed to start${NC}"
    echo "Check the logs directory for details"
fi

echo -e "\nTo stop all services, run: ${YELLOW}./stop-all.sh${NC}"

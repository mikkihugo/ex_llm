#!/usr/bin/env bash
# Start all services (PostgreSQL + NATS + AI Server)
set -euo pipefail

echo "🚀 Starting all Singularity services..."

# Start PostgreSQL first (required by Elixir app)
echo "1️⃣ Starting PostgreSQL..."
./scripts/start-postgres.sh

# Start NATS (required by Elixir app)
echo "2️⃣ Starting NATS..."
./scripts/start-nats.sh

# Start AI Server (required for LLM integration)
echo "3️⃣ Starting AI Server..."
./scripts/start-llm-server.sh

echo ""
echo "✅ All services started!"
echo "   🗄️  PostgreSQL: postgres://localhost:${PGPORT:-5432}/postgres"
echo "   📡 NATS: nats://localhost:${NATS_PORT:-4222}"
echo "   🤖 AI Server: Running (see llm-server/logs/llm-server.log)"
echo ""
echo "Next steps:"
echo "   cd singularity && mix phx.server"
echo ""
echo "To stop all services: ./scripts/stop-all.sh"
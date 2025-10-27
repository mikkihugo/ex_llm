#!/usr/bin/env bash
# Start all services (PostgreSQL + NATS + Singularity)
set -euo pipefail

echo "🚀 Starting all Singularity services..."

# Start PostgreSQL first (required by Elixir app)
echo "1️⃣ Starting PostgreSQL..."
./scripts/start-postgres.sh

# Start NATS (required by Elixir app)
echo "2️⃣ Starting NATS..."
./scripts/start-nats.sh

echo ""
echo "✅ Core services started!"
echo "   🗄️  PostgreSQL: postgres://localhost:${PGPORT:-5432}/postgres"
echo "   📡 NATS: nats://localhost:${NATS_PORT:-4222}"
echo ""
echo "Next steps:"
echo "   cd singularity && mix phx.server"
echo "   cd centralcloud && mix phx.server  # (optional, for multi-instance learning)"
echo ""
echo "To stop all services: ./scripts/stop-all.sh"
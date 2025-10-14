#!/usr/bin/env bash
# Stop all services (AI Server + NATS + PostgreSQL)
set -euo pipefail

echo "🛑 Stopping all Singularity services..."

# Stop AI Server first
echo "1️⃣ Stopping AI Server..."
./scripts/stop-ai-server.sh

# Stop NATS
echo "2️⃣ Stopping NATS..."
./scripts/stop-nats.sh

# Stop PostgreSQL
echo "3️⃣ Stopping PostgreSQL..."
./scripts/stop-postgres.sh

echo ""
echo "✅ All services stopped!"
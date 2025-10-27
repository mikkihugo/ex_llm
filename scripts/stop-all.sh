#!/usr/bin/env bash
# Stop all services (NATS + PostgreSQL)
set -euo pipefail

echo "🛑 Stopping all Singularity services..."

# Stop NATS
echo "1️⃣ Stopping NATS..."
./scripts/stop-nats.sh

# Stop PostgreSQL
echo "2️⃣ Stopping PostgreSQL..."
./scripts/stop-postgres.sh

echo ""
echo "✅ All services stopped!"
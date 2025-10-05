#!/bin/bash
# Stop all Singularity services

echo "🛑 Stopping Singularity services..."

# Kill AI Server
echo -n "Stopping AI Server... "
pkill -f "bun.*server.ts" 2>/dev/null || true
echo "✓"

# Kill Elixir
echo -n "Stopping Elixir app... "
pkill -f "beam.*singularity" 2>/dev/null || true
echo "✓"

# Kill DB Service
echo -n "Stopping DB Service... "
pkill -f "target.*db_service" 2>/dev/null || true
echo "✓"

# Optionally kill NATS (comment out if you want to keep it running)
echo -n "Stopping NATS... "
pkill -x "nats-server" 2>/dev/null || true
echo "✓"

echo "✅ All services stopped"
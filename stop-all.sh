#!/bin/bash
# Stop all Singularity services

echo "🛑 Stopping Singularity services..."

# Kill Observer (Phoenix Web UI)
echo -n "Stopping Observer... "
pkill -f "beam.*observer" 2>/dev/null || true
echo "✓"

# Kill CentralCloud
echo -n "Stopping CentralCloud... "
pkill -f "beam.*centralcloud" 2>/dev/null || true
echo "✓"

# Kill Genesis
echo -n "Stopping Genesis... "
pkill -f "beam.*genesis" 2>/dev/null || true
echo "✓"

# Kill Singularity (Core)
echo -n "Stopping Singularity... "
pkill -f "beam.*singularity" 2>/dev/null || true
echo "✓"

# Optionally kill NATS (comment out if you want to keep it running)
echo -n "Stopping NATS... "
pkill -x "nats-server" 2>/dev/null || true
echo "✓"

echo "✅ All services stopped"
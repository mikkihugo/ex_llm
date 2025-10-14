#!/usr/bin/env bash
# Start NATS server (simple request/reply, no JetStream)
set -euo pipefail

NATS_DIR="${PWD}/.nats"
NATS_PID_FILE="${NATS_DIR}/nats-server.pid"
NATS_PORT="${NATS_PORT:-4222}"

mkdir -p "$NATS_DIR"

if [ -f "$NATS_PID_FILE" ] && kill -0 "$(cat "$NATS_PID_FILE")" 2>/dev/null; then
    echo "📡 NATS already running on port $NATS_PORT (PID: $(cat "$NATS_PID_FILE"))"
    exit 0
fi

echo "📡 Starting NATS (simple request/reply) on port $NATS_PORT..."
rm -f "$NATS_PID_FILE"

# Start NATS server without JetStream for better LLM performance
nats-server -p "$NATS_PORT" > "$NATS_DIR/nats-server.log" 2>&1 &
NATS_PID=$!
echo $NATS_PID > "$NATS_PID_FILE"

sleep 2

if kill -0 $NATS_PID 2>/dev/null; then
    echo "   ✅ NATS running on nats://localhost:$NATS_PORT (PID: $NATS_PID)"
    echo "   📝 Logs: $NATS_DIR/nats-server.log"
else
    echo "   ❌ Failed to start NATS server"
    echo "   📝 Check logs: $NATS_DIR/nats-server.log"
    rm -f "$NATS_PID_FILE"
    exit 1
fi
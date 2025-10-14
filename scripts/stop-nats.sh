#!/usr/bin/env bash
# Stop both NATS servers (LLM and JetStream)
set -euo pipefail

NATS_DIR="${PWD}/.nats"
NATS_PID_FILE="${NATS_DIR}/nats-server.pid"
NATS_JETSTREAM_PID_FILE="${NATS_DIR}/nats-jetstream.pid"

# Stop NATS (LLM) server
if [ -f "$NATS_PID_FILE" ]; then
    NATS_PID=$(cat "$NATS_PID_FILE")
    if kill -0 "$NATS_PID" 2>/dev/null; then
        echo "🛑 Stopping NATS (LLM) server (PID: $NATS_PID)..."
        kill "$NATS_PID"
        sleep 1
        if kill -0 "$NATS_PID" 2>/dev/null; then
            echo "   Force killing NATS (LLM) server..."
            kill -9 "$NATS_PID" 2>/dev/null || true
        fi
        echo "   ✅ NATS (LLM) server stopped"
    else
        echo "   NATS (LLM) server not running (stale PID file)"
    fi
    rm -f "$NATS_PID_FILE"
else
    echo "📡 NATS (LLM) server not running (no PID file)"
fi

# Stop NATS JetStream server
if [ -f "$NATS_JETSTREAM_PID_FILE" ]; then
    NATS_JS_PID=$(cat "$NATS_JETSTREAM_PID_FILE")
    if kill -0 "$NATS_JS_PID" 2>/dev/null; then
        echo "🛑 Stopping NATS JetStream server (PID: $NATS_JS_PID)..."
        kill "$NATS_JS_PID"
        sleep 1
        if kill -0 "$NATS_JS_PID" 2>/dev/null; then
            echo "   Force killing NATS JetStream server..."
            kill -9 "$NATS_JS_PID" 2>/dev/null || true
        fi
        echo "   ✅ NATS JetStream server stopped"
    else
        echo "   NATS JetStream server not running (stale PID file)"
    fi
    rm -f "$NATS_JETSTREAM_PID_FILE"
else
    echo "📡 NATS JetStream server not running (no PID file)"
fi
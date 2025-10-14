#!/usr/bin/env bash
# Stop AI Server
set -euo pipefail

AI_SERVER_DIR="${PWD}/ai-server"
AI_SERVER_PID_FILE="${AI_SERVER_DIR}/.ai-server.pid"

if [ ! -f "$AI_SERVER_PID_FILE" ]; then
    echo "🤖 AI Server not running (no PID file)"
    exit 0
fi

AI_SERVER_PID=$(cat "$AI_SERVER_PID_FILE")

if kill -0 $AI_SERVER_PID 2>/dev/null; then
    echo "🤖 Stopping AI Server (PID: $AI_SERVER_PID)..."
    kill $AI_SERVER_PID

    # Wait for process to stop (max 5 seconds)
    for i in {1..10}; do
        if ! kill -0 $AI_SERVER_PID 2>/dev/null; then
            break
        fi
        sleep 0.5
    done

    # Force kill if still running
    if kill -0 $AI_SERVER_PID 2>/dev/null; then
        echo "   ⚠️  Force stopping AI Server..."
        kill -9 $AI_SERVER_PID 2>/dev/null || true
    fi

    echo "   ✅ AI Server stopped"
else
    echo "🤖 AI Server not running (stale PID file)"
fi

rm -f "$AI_SERVER_PID_FILE"

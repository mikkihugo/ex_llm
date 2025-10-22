#!/usr/bin/env bash
# Start AI Server (TypeScript/Bun)
set -euo pipefail

AI_SERVER_DIR="${PWD}/llm-server"
AI_SERVER_PID_FILE="${AI_SERVER_DIR}/.llm-server.pid"
AI_SERVER_LOG_FILE="${AI_SERVER_DIR}/logs/llm-server.log"

# Create logs directory if it doesn't exist
mkdir -p "${AI_SERVER_DIR}/logs"

if [ -f "$AI_SERVER_PID_FILE" ] && kill -0 "$(cat "$AI_SERVER_PID_FILE")" 2>/dev/null; then
    echo "🤖 AI Server already running (PID: $(cat "$AI_SERVER_PID_FILE"))"
    exit 0
fi

if [ ! -d "$AI_SERVER_DIR" ]; then
    echo "   ❌ AI Server directory not found: $AI_SERVER_DIR"
    exit 1
fi

echo "🤖 Starting AI Server..."
rm -f "$AI_SERVER_PID_FILE"

# Start AI Server with Bun
cd "$AI_SERVER_DIR"
bun run start > "$AI_SERVER_LOG_FILE" 2>&1 &
AI_SERVER_PID=$!
echo $AI_SERVER_PID > "$AI_SERVER_PID_FILE"

sleep 2

if kill -0 $AI_SERVER_PID 2>/dev/null; then
    echo "   ✅ AI Server running (PID: $AI_SERVER_PID)"
    echo "   📝 Logs: $AI_SERVER_LOG_FILE"
else
    echo "   ❌ Failed to start AI Server"
    echo "   📝 Check logs: $AI_SERVER_LOG_FILE"
    rm -f "$AI_SERVER_PID_FILE"
    exit 1
fi

#!/bin/bash

# Start Unified Services Script
# Starts all services with the unified NATS server architecture

set -e

echo "🚀 Starting Unified Singularity Services..."

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# Start NATS server
echo "📡 Starting NATS server..."
if ! pgrep -f "nats-server" > /dev/null; then
    nats-server -js -sd .nats -p 4222 &
    sleep 2
    echo "✅ NATS server started"
else
    echo "✅ NATS server already running"
fi

# Start consolidated detector service
echo "🔍 Starting consolidated detector service..."
cd rust/consolidated_detector
cargo run &
DETECTOR_PID=$!
cd ../..
echo "✅ Consolidated detector started (PID: $DETECTOR_PID)"

# Start Elixir application
echo "⚡ Starting Elixir application..."
cd singularity_app
mix phx.server &
ELIXIR_PID=$!
cd ..
echo "✅ Elixir application started (PID: $ELIXIR_PID)"

# Start AI server
echo "🤖 Starting AI server..."
cd ai-server
bun run dev &
AI_PID=$!
cd ..
echo "✅ AI server started (PID: $AI_PID)"

echo ""
echo "🎉 All services started!"
echo ""
echo "Services:"
echo "  📡 NATS Server: nats://localhost:4222"
echo "  🔍 Detector: rust/consolidated_detector"
echo "  ⚡ Elixir: http://localhost:4000"
echo "  🤖 AI Server: http://localhost:3000"
echo ""
echo "Unified NATS Subjects:"
echo "  nats.request - Single entry point"
echo "  detector.analyze - Framework detection"
echo "  ai.llm.request - LLM requests"
echo ""
echo "To stop all services:"
echo "  pkill -f 'nats-server|consolidated_detector|mix phx.server|bun run dev'"
echo ""
echo "Logs:"
echo "  tail -f singularity_app/log/dev.log"
echo "  tail -f ai-server/logs/ai-server.log"
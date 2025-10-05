#!/bin/bash
# Test the complete orchestration pipeline
set -e

echo "🧪 Testing Orchestration Pipeline"
echo "================================="

# Check if NATS is running
echo "✅ Checking NATS..."
if pgrep -x "nats-server" > /dev/null; then
    echo "   NATS is running on port 4222"
else
    echo "   ⚠️  NATS not running. Starting it..."
    nats-server -js -sd .nats -p 4222 &
    sleep 2
fi

# Check if AI Server is running
echo "✅ Checking AI Server..."
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "   AI Server is running on port 3000"
else
    echo "   ⚠️  AI Server not running. Start it with: bun run ai-server/src/server.ts"
fi

# Test 1: Direct Chat (baseline)
echo ""
echo "📝 Test 1: Direct Chat Endpoint (baseline)"
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [
      {"role": "user", "content": "Write a simple hello world function"}
    ]
  }' | jq -r '.choices[0].message.content' | head -20

# Test 2: Orchestrated Chat (with ExecutionCoordinator)
echo ""
echo "🎯 Test 2: Orchestrated Chat (ExecutionCoordinator + TemplateOptimizer)"
curl -X POST http://localhost:3000/v1/orchestrated/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Create a NATS consumer service in Elixir"}
    ],
    "language": "elixir"
  }' | jq '.x_metrics // .system_fingerprint'

# Test 3: Complex Task (should use higher-tier model)
echo ""
echo "🚀 Test 3: Complex Task (should select optimal model)"
curl -X POST http://localhost:3000/v1/orchestrated/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Implement a distributed rate limiter with sliding window algorithm, including Elixir GenServer, ETS storage, and clustering support"}
    ]
  }' | jq '.x_metrics // {model: .model}'

# Test 4: Cache Hit Test
echo ""
echo "💾 Test 4: Cache Hit (second identical request should be instant)"
echo "   First request:"
time curl -s -X POST http://localhost:3000/v1/orchestrated/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What is 2+2?"}
    ]
  }' | jq -r '.x_metrics.cache_hit'

echo "   Second request (should hit cache):"
time curl -s -X POST http://localhost:3000/v1/orchestrated/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "What is 2+2?"}
    ]
  }' | jq -r '.x_metrics.cache_hit'

echo ""
echo "✨ Orchestration Pipeline Tests Complete!"
echo ""
echo "Pipeline Flow:"
echo "1. AI Server receives request"
echo "2. Task complexity analyzed (simple/medium/complex)"
echo "3. Request sent via NATS to ExecutionCoordinator"
echo "4. TemplateOptimizer selects best template"
echo "5. HybridAgent selects optimal model based on complexity"
echo "6. Response cached in MemoryCache/SemanticCache"
echo "7. Metrics returned to client"
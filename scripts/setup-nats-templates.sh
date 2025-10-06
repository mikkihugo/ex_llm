#!/usr/bin/env bash
# Setup NATS JetStream KV for template caching

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/nix_guard.sh"

echo "🚀 Setting up NATS JetStream KV for templates..."

# Check if NATS server is running
if ! nats account info &>/dev/null; then
    echo "❌ NATS server not running or not accessible"
    echo "   Start NATS with: nats-server -js"
    exit 1
fi

echo "✅ NATS server is running"

# Create KV buckets for template caching
echo "📦 Creating NATS KV buckets..."

# Main templates bucket (high-frequency access)
nats kv add templates \
    --description="Template cache (ETS + NATS distributed)" \
    --ttl=30m \
    --replicas=3 \
    --storage=memory \
    --max-bucket-size=1GB \
    --history=5 \
    --max-value-size=1MB \
    || echo "⚠️  'templates' bucket already exists"

# Hot templates (very frequently accessed)
nats kv add templates-hot \
    --description="Hot templates (frameworks, languages)" \
    --ttl=1h \
    --replicas=3 \
    --storage=memory \
    --max-bucket-size=512MB \
    --history=3 \
    || echo "⚠️  'templates-hot' bucket already exists"

# Cold templates (rarely accessed, persistent)
nats kv add templates-cold \
    --description="Cold templates (archived, persistent)" \
    --ttl=24h \
    --replicas=1 \
    --storage=file \
    --max-bucket-size=2GB \
    --history=10 \
    || echo "⚠️  'templates-cold' bucket already exists"

# Verify buckets
echo ""
echo "📊 NATS KV Buckets:"
nats kv ls

echo ""
echo "✅ NATS JetStream KV setup complete!"
echo ""
echo "Usage from Elixir:"
echo "  Singularity.Knowledge.TemplateCache.get(\"framework\", \"phoenix\")"
echo ""
echo "Usage from CLI:"
echo "  nats kv get templates framework.phoenix"
echo ""

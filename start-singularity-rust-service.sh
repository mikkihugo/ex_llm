#!/bin/bash

# Start Singularity Rust Service (Automated)
# This script starts the Rust service in background

set -e

echo "🚀 Starting Singularity Rust Service (Automated)..."

# Check if NATS is running
if ! nc -z localhost 4222 2>/dev/null; then
    echo "❌ NATS server is not running. Please start NATS first:"
    echo "   nats-server -js"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "rust/Cargo.toml" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# Set environment variables
export NATS_URL=${NATS_URL:-"nats://127.0.0.1:4222"}
export RUST_LOG=${RUST_LOG:-"info"}

echo "📡 Connecting to NATS at: $NATS_URL"
echo "🔧 Log level: $RUST_LOG"

# Build and run the service
cd rust

echo "🔨 Building singularity-rust-service..."
cargo build --release --bin singularity-rust-service

echo "🎯 Starting Rust service in background..."
nohup cargo run --release --bin singularity-rust-service > ../logs/singularity-rust-service.log 2>&1 &

# Save PID
echo $! > ../logs/singularity-rust-service.pid

echo "✅ Singularity Rust Service started!"
echo "📝 Logs: logs/singularity-rust-service.log"
echo "🆔 PID: $(cat ../logs/singularity-rust-service.pid)"
echo ""
echo "To stop: kill \$(cat logs/singularity-rust-service.pid)"

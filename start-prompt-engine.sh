#!/bin/bash

# Start Prompt Engine NATS Service
# This script starts the Rust prompt engine as a NATS service

set -e

echo "🚀 Starting Prompt Engine NATS Service..."

# Check if NATS is running
if ! nc -z localhost 4222 2>/dev/null; then
    echo "❌ NATS server is not running. Please start NATS first:"
    echo "   nats-server -js"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "rust/prompt_engine/Cargo.toml" ]; then
    echo "❌ Please run this script from the singularity project root"
    exit 1
fi

# Set environment variables
export NATS_URL=${NATS_URL:-"nats://127.0.0.1:4222"}
export RUST_LOG=${RUST_LOG:-"info"}

echo "📡 Connecting to NATS at: $NATS_URL"
echo "🔧 Log level: $RUST_LOG"

# Build and run the prompt engine service
cd rust/prompt_engine

echo "🔨 Building prompt engine service..."
cargo build --release --bin prompt_engine_service

echo "🎯 Starting prompt engine service..."
cargo run --release --bin prompt_engine_service

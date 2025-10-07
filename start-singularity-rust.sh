#!/bin/bash

# Start Singularity Rust - Unified Binary
# This script starts all Rust services in one binary

set -e

echo "🚀 Starting Singularity Rust (Unified Binary)..."

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

# Build and run the unified binary
cd rust

echo "🔨 Building singularity-rust binary..."
cargo build --release --bin singularity-rust

echo "🎯 Starting all Rust services..."
cargo run --release --bin singularity-rust

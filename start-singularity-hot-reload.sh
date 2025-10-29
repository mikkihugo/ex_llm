#!/bin/bash

# Start Singularity with Hot Reload
# This script starts the system with conservative memory settings and hot reload enabled

echo "🚀 Starting Singularity with Hot Reload..."

# Set conservative Erlang VM settings
export ERL_FLAGS="+P 5000 +Q 5000 +A 1 +sbt u +swt very_low"

# Enable hot reload
export MIX_ENV=dev

# Start Singularity with hot reload (no Phoenix endpoint - pure Elixir app)
cd nexus/singularity

echo "📦 Compiling and starting Singularity..."
echo "🔥 Hot reload enabled - code changes are automatically reloaded via CodeFileWatcher"
echo "🌐 Web UI available at http://localhost:4002 (Observer app)"
echo ""
echo "Note: Singularity is a pure Elixir app (no Phoenix endpoint)"
echo "      CodeFileWatcher automatically watches lib/ and reloads modules when files change"
echo "      Running in IEx for interactive development with automatic recompilation"
echo "      Press Ctrl+C twice to stop the server"
echo ""

# Use IEx for interactive development - CodeFileWatcher handles automatic reloading
iex -S mix
#!/bin/bash

# Start Singularity with Hot Reload
# This script starts the system with conservative memory settings and hot reload enabled

echo "🚀 Starting Singularity with Hot Reload..."

# Set conservative Erlang VM settings
export ERL_FLAGS="+P 5000 +Q 5000 +A 1 +sbt u +swt very_low"

# Enable hot reload
export MIX_ENV=dev

# Start Phoenix server with hot reload
cd nexus/singularity

echo "📦 Compiling and starting Singularity..."
echo "🔥 Hot reload enabled - code changes will be automatically reloaded"
echo "🌐 Server will be available at http://localhost:4000"
echo "📊 Observer will be available at http://localhost:4002"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

mix phx.server
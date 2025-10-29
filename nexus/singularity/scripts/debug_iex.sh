#!/usr/bin/env bash
# Script to start IEx with debugging enabled
# Usage: ./scripts/debug_iex.sh

set -e

cd "$(dirname "$0")/.."

# Ensure we're in the right directory
if [ ! -f "mix.exs" ]; then
    echo "Error: mix.exs not found. Are you in the project root?"
    exit 1
fi

echo "Starting IEx with debugging enabled..."
echo ""

# Set environment variable to enable debugger
export ENABLE_DEBUGGER=true

# Start IEx with the application loaded
iex -S mix

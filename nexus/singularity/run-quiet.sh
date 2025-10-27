#!/bin/bash

# Run Singularity in quiet mode to reduce log verbosity
# This script sets up environment variables for gentle, quiet operation

echo "Starting Singularity in quiet mode..."

# Set quiet mode environment variables
export AUTO_INGESTION_QUIET_MODE=true
export HTDAG_AUTO_INGESTION_ENABLED=true
export HTDAG_DEBOUNCE_MS=3000
export HTDAG_MAX_CONCURRENT=2
export HTDAG_BATCH_SIZE=3
export HTDAG_RATE_LIMIT_PER_MIN=20

# Set log level to reduce verbosity
export LOG_LEVEL=warn

# Run with optimized Erlang flags for gentle operation
export ERL_FLAGS="+P 10000 +Q 10000 +A 2 +sbt u +swt very_low"

echo "Environment configured for quiet operation:"
echo "  - Quiet mode: enabled"
echo "  - HTDAG debounce: 3 seconds"
echo "  - Max concurrent DAGs: 2"
echo "  - Rate limit: 20 files/minute"
echo "  - Log level: warn"
echo ""

# Start the server
mix phx.server
#!/usr/bin/env bash
# Run Ecto migration with proper memory settings

cd singularity

# Set heap size for Erlang VM
export ERL_FLAGS="+hmax 0"

echo "Running Ecto migration..."
mix ecto.migrate

echo "Migration complete!"

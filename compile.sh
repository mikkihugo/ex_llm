#!/bin/bash
# Singularity compilation wrapper
# Makes mix compile work normally from any directory

set -e

# Find the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Run the command in Nix environment
exec nix develop "$PROJECT_ROOT"#dev --command bash -c "cd singularity_app && mix compile"
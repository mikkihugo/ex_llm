#!/usr/bin/env bash
# Build custom Codex with builtin tool filtering for Singularity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_SERVER_DIR="$(dirname "$SCRIPT_DIR")"
SINGULARITY_ROOT="$(dirname "$AI_SERVER_DIR")"
CODEX_DIR="$SINGULARITY_ROOT/vendor/codex"
CODEX_RS_DIR="$CODEX_DIR/codex-rs"

echo "🔨 Building Codex with builtin tool filtering..."
echo "   Source: $CODEX_RS_DIR"
echo "   Target: $AI_SERVER_DIR/bin/codex"

# Check if codex source exists
if [ ! -d "$CODEX_RS_DIR" ]; then
  echo "❌ Error: Codex source not found at $CODEX_RS_DIR"
  echo "   Run: git clone https://github.com/mikkihugo/codex vendor/codex"
  exit 1
fi

# Check we're on the right branch
cd "$CODEX_DIR"
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "feat/builtin-tool-filtering" ]; then
  echo "⚠️  Warning: Codex is on branch '$CURRENT_BRANCH'"
  echo "   Expected: 'feat/builtin-tool-filtering'"
  echo "   Continuing anyway..."
fi

# Build Codex
cd "$CODEX_RS_DIR"
echo "📦 Running cargo build --release..."
cargo build --release

# Copy binary
echo "📋 Copying binary..."
cp target/release/codex "$AI_SERVER_DIR/bin/codex"
chmod +x "$AI_SERVER_DIR/bin/codex"

# Verify
if [ -x "$AI_SERVER_DIR/bin/codex" ]; then
  echo "✅ Codex built successfully!"
  echo "   Binary: $AI_SERVER_DIR/bin/codex"

  # Show version
  "$AI_SERVER_DIR/bin/codex" --version || echo "   (binary ready, version check skipped)"
else
  echo "❌ Error: Binary not found or not executable"
  exit 1
fi

#!/usr/bin/env bash
# pgvector Extension Setup Script
# Installs pgvector PostgreSQL extension via pgxn
#
# This mirrors the pg_uuidv7 installation approach
# pgvector provides vector embeddings for semantic search

set -e

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"

echo "🔍 Checking for pgvector installation..."

# Check if pgvector is already installed
if psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -tc "SELECT 1 FROM pg_extension WHERE extname = 'vector'" 2>/dev/null | grep -q 1; then
  echo "✅ pgvector already installed"
  exit 0
fi

# Check if pgxn is available
if ! command -v pgxn &> /dev/null; then
  echo "❌ pgxn not found in PATH"
  echo ""
  echo "To install pgvector, first install pgxnclient:"
  echo "  macOS:         brew install pgxnclient"
  echo "  Ubuntu/Debian: sudo apt-get install pgxnclient"
  echo ""
  echo "Then run: pgxn install pgvector"
  exit 1
fi

# Install pgvector via pgxn
echo "📦 Installing pgvector via pgxn..."
if pgxn install pgvector > /dev/null 2>&1; then
  echo "✅ pgvector installed successfully"

  # Create extension in PostgreSQL
  echo "🔌 Creating vector extension in PostgreSQL..."
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d postgres -c "CREATE EXTENSION IF NOT EXISTS vector" > /dev/null 2>&1
  echo "✅ vector extension ready for semantic search"
  exit 0
else
  echo "⚠️  pgxn install pgvector failed"
  echo ""
  echo "Installation options:"
  echo "1. Build from source:"
  echo "     git clone https://github.com/pgvector/pgvector.git"
  echo "     cd pgvector && make && make install"
  echo ""
  echo "2. Using Homebrew (macOS):"
  echo "     brew install pgvector"
  echo ""
  exit 1
fi

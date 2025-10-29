#!/bin/bash
# Rust Consolidation Migration Script
#
# This script migrates from the old confusing lib/engine split
# to the new clean consolidated structure.

set -e  # Exit on error

echo "🚀 Starting Rust consolidation migration..."
echo ""

# Backup old structure
echo "📦 Backing up old rust/ directory..."
if [ -d "rust_backup" ]; then
    echo "⚠️  rust_backup already exists, removing..."
    rm -rf rust_backup
fi
cp -r rust rust_backup
echo "✅ Backup created at rust_backup/"
echo ""

# Move consolidated crates into place
echo "🔄 Moving consolidated crates..."

# Remove old lib and engine directories
echo "  Removing old rust/lib/architecture_lib..."
rm -rf rust/lib/architecture_lib

echo "  Removing old rust/lib/code_lib..."
rm -rf rust/lib/code_lib

echo "  Removing old rust/lib/knowledge_lib..."
rm -rf rust/lib/knowledge_lib


echo "  Removing old rust/engine/code_engine..."
rm -rf rust/engine/code_engine

echo "  Removing old rust/engine/knowledge_engine..."
rm -rf rust/engine/knowledge_engine

# Move consolidated crates
echo "  Moving rust_new/architecture → rust/architecture..."
mv rust_new/architecture rust/

echo "  Moving rust_new/code_analysis → rust/code_analysis..."
mv rust_new/code_analysis rust/

echo "  Moving rust_new/knowledge → rust/knowledge..."
mv rust_new/knowledge rust/

# Clean up rust_new
echo "  Removing rust_new/ directory..."
rm -rf rust_new

echo "✅ Crates moved successfully!"
echo ""

# Update workspace Cargo.toml if it exists
if [ -f "rust/Cargo.toml" ]; then
    echo "📝 Updating rust/Cargo.toml workspace..."
    # This is a placeholder - you'll need to manually update workspace members
    echo "⚠️  Please manually update rust/Cargo.toml to replace:"
    echo "    - 'lib/architecture_lib' → 'architecture'"
    echo "    - 'lib/code_lib' → 'code_analysis'"
    echo "    - 'lib/knowledge_lib' → 'knowledge'"
    echo "    - Remove 'engine/code_engine'"
    echo "    - Remove 'engine/knowledge_engine'"
    echo ""
fi

# Summary
echo "✨ Migration complete!"
echo ""
echo "New structure:"
echo "  rust/architecture/     ← was lib/architecture_lib + engine/architecture_engine"
echo "  rust/code_analysis/    ← was lib/code_lib + engine/code_engine"
echo "  rust/knowledge/        ← was lib/knowledge_lib + engine/knowledge_engine"
echo ""
echo "Unchanged (global services):"
echo "  rust/service/          ← All global NATS services"
echo "  templates_data/        ← Git-backed templates"
echo "  rust-central/          ← Legacy central services"
echo ""
echo "Next steps:"
echo "  1. Update rust/Cargo.toml workspace members (if exists)"
echo "  2. Update singularity/mix.exs rustler_crates paths"
echo "  3. Test compilation: cd rust/architecture && cargo build --features nif"
echo "  4. Test Elixir integration: cd singularity && mix compile"
echo ""
echo "If something goes wrong, restore from backup:"
echo "  rm -rf rust && mv rust_backup rust"
echo ""

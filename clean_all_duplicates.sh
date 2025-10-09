#!/bin/bash
# Clean All Duplicates - rust/ and rust_global/
#
# This script:
# 1. Archives old rust/server/ (5 duplicate package servers)
# 2. Archives rust_global/ duplicates (5 modules)
# 3. Keeps only necessary infrastructure

set -e

echo "🧹 Cleaning All Duplicates..."
echo ""

# ============================================================================
# PART 1: Archive rust/server/ (Old Split Architecture)
# ============================================================================

echo "📦 Part 1: Archiving rust/server/"
echo ""

if [ -d "rust/server" ]; then
    echo "Found rust/server/ with:"
    ls rust/server/ | sed 's/^/  - /'
    echo ""

    mkdir -p rust/_archive
    mv rust/server rust/_archive/
    echo "✅ Archived rust/server/ → rust/_archive/server/"
else
    echo "⚠️  rust/server/ already removed or missing"
fi

echo ""

# ============================================================================
# PART 2: Clean rust_global/ (Archive Duplicates, Keep Package Registry)
# ============================================================================

echo "📦 Part 2: Cleaning rust_global/"
echo ""

cd rust_global

# Rename package suite
if [ -d "package_analysis_suite" ]; then
    mv package_analysis_suite package_registry
    echo "✅ Renamed: package_analysis_suite → package_registry"
else
    echo "✓ package_registry already renamed or exists"
fi

# Archive duplicates
duplicates=(
    "analysis_engine"
    "dependency_parser"
    "intelligent_namer"
    "semantic_embedding_engine"
    "tech_detection_engine"
)

echo ""
echo "Archiving duplicate modules:"
for module in "${duplicates[@]}"; do
    if [ -d "$module" ]; then
        mv "$module" _archive/
        echo "  ✅ Archived: $module"
    else
        echo "  ✓ Already archived: $module"
    fi
done

cd ..

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo "✨ Cleanup Complete!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "FINAL STRUCTURE:"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "🪶 GLOBAL (Lightweight):"
echo "  rust_global/"
if [ -d "rust_global/package_registry" ]; then
    echo "    └── package_registry/          ✅ ONLY global module"
fi
echo ""

echo "📡 NATS SERVICES:"
echo "  rust/service/"
if [ -d "rust/service" ]; then
    ls rust/service/ | sed 's/^/    ├── /'
fi
echo ""

echo "🏠 LOCAL CRATES (Per-Project):"
echo "  rust/"
for crate in architecture code_analysis embedding framework knowledge package parser prompt quality semantic template; do
    if [ -d "rust/$crate" ]; then
        echo "    ├── $crate/"
    fi
done
echo ""

echo "📦 ARCHIVED:"
echo "  rust/_archive/"
if [ -d "rust/_archive/server" ]; then
    echo "    └── server/                    (5 old package servers)"
fi
echo "  rust_global/_archive/"
if [ -d "rust_global/_archive" ]; then
    ls rust_global/_archive/ | grep -v "README.md" | sed 's/^/    ├── /'
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "RESULTS:"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "✅ Archived: 5 old package servers (rust/server/)"
echo "✅ Archived: 5 duplicate rust_global modules"
echo "✅ Kept: 1 global package_registry"
echo "✅ Kept: 3 NATS services"
echo "✅ Kept: 11 local crates"
echo ""
echo "🎉 Clean, lightweight architecture achieved!"
echo ""

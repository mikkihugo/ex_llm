#!/bin/bash
# Final Cleanup - Archive All Duplicates
set -e

echo "🧹 FINAL CLEANUP - Archiving Duplicates"
echo "========================================"
echo ""

# ============================================================================
# What We're Keeping vs Archiving
# ============================================================================

echo "📋 PLAN:"
echo ""
echo "✅ KEEP (11 local crates):"
echo "   rust/architecture, code_analysis, embedding, framework,"
echo "   knowledge, parser, prompt, quality, semantic, template"
echo "   (NOT package - it's a duplicate!)"
echo ""
echo "✅ KEEP (3 centralcloud services):"
echo "   Rust:"
echo "     - centralcloud/rust/package_intelligence (uses ../../parser_engine)"
echo "   Elixir (NATS via centralcloud app):"
echo "     - intelligence_hub"
echo "     - knowledge_cache"
echo ""
echo "✅ KEEP (1 global registry):"
echo "   rust_global/package_registry"
echo ""
echo "❌ ARCHIVE (duplicates):"
echo "   - rust/package/ (duplicate of rust_global/)"
echo "   - rust/server/ (5 old package servers)"
echo "   - rust_global/ duplicates (5 modules)"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi
echo ""

# ============================================================================
# PART 1: Archive rust/package/ (duplicate of global)
# ============================================================================

echo "📦 Part 1: Archiving rust/package/"
if [ -d "rust/package" ]; then
    mkdir -p rust/_archive
    mv rust/package rust/_archive/
    echo "✅ Archived: rust/package/ → rust/_archive/package/"
    echo "   (Duplicate of rust_global/package_registry/)"
else
    echo "✓ Already archived or missing"
fi
echo ""

# ============================================================================
# PART 2: Archive rust/server/ (5 old package servers)
# ============================================================================

echo "📦 Part 2: Archiving rust/server/"
if [ -d "rust/server" ]; then
    mkdir -p rust/_archive
    mv rust/server rust/_archive/
    echo "✅ Archived: rust/server/ → rust/_archive/server/"
    echo "   (Old split architecture - 5 package servers)"
else
    echo "✓ Already archived or missing"
fi
echo ""

# ============================================================================
# PART 3: Clean rust_global/ (keep only package_registry)
# ============================================================================

echo "📦 Part 3: Cleaning rust_global/"
cd rust_global

# Rename package suite to package_registry
if [ -d "package_analysis_suite" ]; then
    mv package_analysis_suite package_registry
    echo "✅ Renamed: package_analysis_suite → package_registry"
elif [ -d "package_registry" ]; then
    echo "✓ package_registry already exists"
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
echo "Archiving rust_global/ duplicates:"
for module in "${duplicates[@]}"; do
    if [ -d "$module" ]; then
        mv "$module" _archive/
        echo "  ✅ $module"
    else
        echo "  ✓ $module (already archived)"
    fi
done

cd ..
echo ""

# ============================================================================
# PART 4: Update symlinks (remove package_engine)
# ============================================================================

echo "📦 Part 4: Updating symlinks"
if [ -L "singularity_app/native/package_engine" ]; then
    rm singularity_app/native/package_engine
    echo "✅ Removed: package_engine symlink (package is global, not local)"
else
    echo "✓ package_engine symlink already removed"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "✨ CLEANUP COMPLETE!"
echo "===================="
echo ""

echo "📊 FINAL STRUCTURE:"
echo ""

echo "🏠 LOCAL (rust/) - 10 crates:"
for crate in architecture code_analysis embedding framework knowledge parser prompt quality semantic template; do
    if [ -d "rust/$crate" ]; then
        echo "   ✓ $crate/"
    fi
done
echo ""

echo "📡 CENTRALCLOUD SERVICES - 3 (1 Rust + 2 Elixir):"
if [ -d "centralcloud/rust/package_intelligence" ]; then
    echo "   ✓ package_intelligence/ (Rust - uses parser_engine)"
fi
if [ -f "centralcloud/lib/centralcloud/intelligence_hub.ex" ]; then
    echo "   ✓ intelligence_hub (Elixir - NATS service)"
fi
if [ -f "centralcloud/lib/centralcloud/knowledge_cache.ex" ]; then
    echo "   ✓ knowledge_cache (Elixir - NATS service)"
fi
echo ""

echo "🌍 GLOBAL (rust_global/) - 1:"
if [ -d "rust_global/package_registry" ]; then
    echo "   ✓ package_registry/"
fi
echo ""

echo "📦 ARCHIVED (rust/_archive/):"
if [ -d "rust/_archive/package" ]; then
    echo "   - package/ (was duplicate)"
fi
if [ -d "rust/_archive/server" ]; then
    echo "   - server/ (5 old servers)"
fi
echo ""

echo "📦 ARCHIVED (rust_global/_archive/):"
if [ -d "rust_global/_archive" ]; then
    ls rust_global/_archive/ | grep -v "README.md" | sed 's/^/   - /'
fi
echo ""

echo "✅ Results:"
echo "   - 10 local crates (package moved to global!)"
echo "   - 3 NATS services"
echo "   - 1 global package registry"
echo "   - 7 modules archived"
echo ""
echo "🎉 Clean architecture achieved!"

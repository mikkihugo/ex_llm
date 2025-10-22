#!/bin/bash
# Archive Duplicate rust_global Modules
#
# Since we have rust/service/ for NATS-based AI services,
# we can archive duplicate modules from rust_global/

set -e

echo "🧹 Archiving duplicate rust_global modules..."
echo ""

cd rust_global

# Check if modules exist
echo "📋 Checking modules..."
for module in analysis_engine dependency_parser intelligent_namer semantic_embedding_engine tech_detection_engine package_analysis_suite; do
    if [ -d "$module" ]; then
        echo "  ✓ Found: $module"
    else
        echo "  ⚠️  Missing: $module"
    fi
done
echo ""

# Rename package suite
echo "📦 Renaming package_analysis_suite → package_registry..."
if [ -d "package_analysis_suite" ]; then
    mv package_analysis_suite package_registry
    echo "  ✅ Renamed to package_registry"
else
    echo "  ⚠️  Already renamed or missing"
fi
echo ""

# Archive duplicates
echo "📦 Archiving duplicate modules..."

modules_to_archive=(
    "analysis_engine"
    "dependency_parser"
    "intelligent_namer"
    "semantic_embedding_engine"
    "tech_detection_engine"
)

for module in "${modules_to_archive[@]}"; do
    if [ -d "$module" ]; then
        echo "  Moving $module → _archive/"
        mv "$module" _archive/
        echo "  ✅ Archived: $module"
    else
        echo "  ⚠️  Already archived or missing: $module"
    fi
done
echo ""

# Update archive README
echo "📝 Updating _archive/README.md..."
cat > _archive/README.md << 'EOF'
# Archived Rust Code

This directory contains deprecated/old Rust code that is no longer actively used.

## Archived (2025-10-09) - Initial Cleanup

### Legacy Servers & Tools
- **codeintelligence_server** - Old monolithic code intelligence server
- **consolidated_detector** - Old consolidated framework detector
- **mozilla-code-analysis** - Mozilla's rust-code-analysis integration
- **unified_server** - Old unified server attempt
- **singularity** - Old embedded Elixir app (duplicate)
- **src/** - Old shared source code

## Archived (2025-10-09) - Duplicate Removal

### Duplicate Modules (Now in rust/ or rust/service/)

**analysis_engine**
- Duplicate of: `rust/code_analysis/` + `rust/service/code_service/`
- Reason: Heavy code analysis should be local, not global
- Use instead: Local rust/code_analysis/ for fast analysis

**dependency_parser**
- Duplicate of: `rust/parser/formats/dependency/`
- Reason: Dependency parsing is per-project, not global
- Use instead: Local rust/parser/ for parsing

**intelligent_namer**
- Duplicate of: `rust/architecture/naming_*` + `rust/service/architecture_service/`
- Reason: Naming is context-specific, should be local with AI via NATS
- Use instead: Local rust/architecture/ for naming, call AI via NATS if needed

**semantic_embedding_engine**
- Duplicate of: `rust/code_analysis/embeddings/` + `rust/service/embedding_service/`
- Reason: Embeddings should be generated locally, AI models via NATS
- Use instead: Local rust/code_analysis/embeddings/, call AI via NATS if needed

**tech_detection_engine**
- Duplicate of: `rust/architecture/technology_detection/` + `rust/service/framework_service/`
- Reason: Framework detection is per-project, AI fallback via NATS
- Use instead: Local rust/architecture/technology_detection/, call AI via NATS if needed

## Active Code (in rust_global/)

- **package_registry** - External package analysis (npm, cargo, hex, pypi)
  - This is the ONLY truly global module
  - Indexes external packages for all Singularity instances

## Why These Were Duplicates

Global should be **lightweight aggregated intelligence**, not heavy processing:
- ✅ Global: External package metadata, learned patterns, quality benchmarks
- ❌ Global: Per-project code analysis, parsing, embeddings

Architecture:
- **Local (rust/)**: Heavy processing, fast local analysis
- **Services (rust/service/)**: AI coordination via NATS
- **Global (rust_global/)**: Only external package registry

## Restoration

To restore archived code:
```bash
mv rust_global/_archive/module_name rust_global/
```

## Permanent Deletion

After confirming code is no longer needed (6+ months):
```bash
rm -rf rust_global/_archive/module_name
```
EOF
echo "  ✅ Updated _archive/README.md"
echo ""

# Verify result
echo "✨ Archive complete! Verifying..."
echo ""
echo "Active modules in rust_global/:"
ls -d */ 2>/dev/null | grep -v "_archive" | sed 's|/||'
echo ""
echo "Archived modules in rust_global/_archive/:"
ls -d _archive/*/ 2>/dev/null | sed 's|_archive/||' | sed 's|/||'
echo ""

echo "✅ Done!"
echo ""
echo "rust_global/ is now lightweight!"
echo "  ✓ package_registry/ - External packages (ONLY global module)"
echo "  ✓ _archive/ - All duplicates archived"
echo ""
echo "Benefits:"
echo "  • Lightweight global (only 1 module)"
echo "  • No duplicates (clear architecture)"
echo "  • AI via NATS (rust/service/*)"
echo "  • Fast local processing (rust/*)"
echo ""

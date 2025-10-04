#!/bin/bash
# analysis-suite reorganization script
# Run this from: crates/analysis-suite/

set -e

echo "🏗️  Starting analysis-suite reorganization..."

# Phase 1: Move vector files to vectors/ module
echo "📦 Phase 1: Consolidating vectors..."
mv src/vectors.rs src/vectors/embeddings.rs 2>/dev/null || true
mv src/vector_index.rs src/vectors/index.rs 2>/dev/null || true
mv src/advanced_vectors.rs src/vectors/advanced.rs 2>/dev/null || true
mv src/analysis/semantic/custom_tokenizers.rs src/vectors/tokenizers.rs 2>/dev/null || true
mv src/analysis/semantic/statistical_vectors.rs src/vectors/statistical.rs 2>/dev/null || true
mv src/analysis/semantic/retrieval_vectors.rs src/vectors/retrieval.rs 2>/dev/null || true

# Phase 2: Move graph files from analysis/graph/ to graph/
echo "📊 Phase 2: Consolidating graph..."
mv src/analysis/graph/pagerank.rs src/graph/pagerank.rs 2>/dev/null || true
mv src/analysis/graph/code_graph.rs src/graph/code_graph.rs 2>/dev/null || true
mv src/analysis/graph/code_insights.rs src/graph/insights.rs 2>/dev/null || true
mv src/analysis/dag/vector_integration.rs src/graph/dag.rs 2>/dev/null || true

# Phase 3: Update imports (will need manual fixing)
echo "🔧 Phase 3: Updating imports..."

# Replace old vector imports
find src -name "*.rs" -type f -exec sed -i \
  -e 's|crate::vectors;|crate::vectors::embeddings;|g' \
  -e 's|crate::vector_index|crate::vectors::index|g' \
  -e 's|crate::advanced_vectors|crate::vectors::advanced|g' \
  -e 's|crate::analysis::semantic::custom_tokenizers|crate::vectors::tokenizers|g' \
  -e 's|crate::analysis::semantic::statistical_vectors|crate::vectors::statistical|g' \
  -e 's|crate::analysis::semantic::retrieval_vectors|crate::vectors::retrieval|g' \
  {} \;

# Replace old graph imports
find src -name "*.rs" -type f -exec sed -i \
  -e 's|crate::analysis::graph::pagerank|crate::graph::pagerank|g' \
  -e 's|crate::analysis::graph::code_graph|crate::graph::code_graph|g' \
  -e 's|crate::analysis::graph::code_insights|crate::graph::insights|g' \
  -e 's|crate::analysis::dag::vector_integration|crate::graph::dag|g' \
  {} \;

# Replace domain imports
find src -name "*.rs" -type f -exec sed -i \
  -e 's|crate::storage::graph::CodeSymbols|crate::domain::symbols::CodeSymbols|g' \
  -e 's|crate::storage::graph::FunctionSymbol|crate::domain::symbols::FunctionSymbol|g' \
  -e 's|crate::storage::graph::StructSymbol|crate::domain::symbols::StructSymbol|g' \
  -e 's|crate::storage::graph::EnumSymbol|crate::domain::symbols::EnumSymbol|g' \
  -e 's|crate::storage::graph::TraitSymbol|crate::domain::symbols::TraitSymbol|g' \
  -e 's|crate::storage::graph::FileNode|crate::domain::files::FileNode|g' \
  -e 's|crate::storage::graph::FileMetadata|crate::domain::files::FileMetadata|g' \
  -e 's|crate::storage::graph::FileRelationship|crate::domain::files::FileRelationship|g' \
  -e 's|crate::storage::graph::SemanticFeatures|crate::domain::files::SemanticFeatures|g' \
  -e 's|crate::storage::graph::ComplexityMetrics|crate::domain::metrics::ComplexityMetrics|g' \
  -e 's|crate::storage::graph::RelationshipType|crate::domain::relationships::RelationshipType|g' \
  -e 's|crate::storage::graph::RelationshipStrength|crate::domain::relationships::RelationshipStrength|g' \
  {} \;

# Clean up empty directories
echo "🧹 Cleaning up..."
find src -type d -empty -delete 2>/dev/null || true

echo "✅ Reorganization complete!"
echo ""
echo "⚠️  Manual steps required:"
echo "1. Extract Graph impl from storage/graph.rs to graph/mod.rs (lines 363-780)"
echo "2. Split types/trait_types.rs into domain/* files"
echo "3. Update lib.rs to export new modules"
echo "4. Run: cargo build to fix remaining import errors"
echo "5. Delete old files after verification"

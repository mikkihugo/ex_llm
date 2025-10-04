# analysis-suite Reorganization Progress

## ✅ Completed

### 1. New Module Structure Created
```
src/
├── domain/          # ✅ Created with mod.rs
│   ├── symbols.rs   # ✅ Extracted from storage/graph.rs (CodeSymbols, FunctionSymbol, etc.)
│   ├── files.rs     # ✅ Extracted (FileNode, FileMetadata, SemanticFeatures)
│   ├── metrics.rs   # ✅ Extracted (ComplexityMetrics)
│   ├── relationships.rs  # ✅ Extracted (RelationshipType, RelationshipStrength)
│   ├── analysis.rs  # ⏳ TODO: Extract from types/trait_types.rs
│   ├── naming.rs    # ⏳ TODO: Extract from types/trait_types.rs
│   ├── refactoring.rs  # ⏳ TODO: Extract from types/trait_types.rs
│   └── metadata.rs  # ⏳ TODO: Extract from types/trait_types.rs
│
├── graph/           # ✅ Created with mod.rs
│   ├── mod.rs       # ⏳ TODO: Extract Graph + DAGStats from storage/graph.rs (lines 364-780)
│   ├── pagerank.rs  # ⏳ TODO: Move from analysis/graph/
│   ├── code_graph.rs  # ⏳ TODO: Move from analysis/graph/
│   ├── insights.rs  # ⏳ TODO: Move from analysis/graph/code_insights.rs
│   └── dag.rs       # ⏳ TODO: Move from analysis/dag/vector_integration.rs
│
├── vectors/         # ✅ Created with mod.rs
│   ├── embeddings.rs  # ⏳ TODO: Move from vectors.rs
│   ├── index.rs       # ⏳ TODO: Move from vector_index.rs
│   ├── advanced.rs    # ⏳ TODO: Move from advanced_vectors.rs
│   ├── tokenizers.rs  # ⏳ TODO: Move from analysis/semantic/custom_tokenizers.rs
│   ├── statistical.rs # ⏳ TODO: Move from analysis/semantic/statistical_vectors.rs
│   └── retrieval.rs   # ⏳ TODO: Move from analysis/semantic/retrieval_vectors.rs
│
└── traits/          # ✅ Created with mod.rs
    └── analysis.rs  # ⏳ TODO: Extract CodeAnalysisAgent from types/trait_types.rs
```

### 2. Migration Script Created
✅ `reorganize.sh` - Automates file moves and import replacements

## ⏳ TODO: Next Steps

### Step 1: Run Migration Script
```bash
cd crates/analysis-suite
./reorganize.sh
```

This will:
- Move vector files to `vectors/` module
- Move graph files from `analysis/graph/` to `graph/`
- Update imports automatically
- Clean up empty directories

### Step 2: Extract Graph Implementation
**Manual step required** (Graph impl is 416 lines):

```bash
# Extract lines 364-780 from storage/graph.rs to graph/mod.rs
# This includes:
# - pub struct Graph { ... }
# - impl Graph { ... }  (all methods)
# - pub struct DAGStats { ... }
```

Add to `graph/mod.rs` after line 17:
```rust
use std::{
  collections::{HashMap, HashSet},
  sync::Arc,
};

use petgraph::{
  stable_graph::NodeIndex,
  visit::EdgeRef,
  Directed,
  Graph as PetGraph,
};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::domain::{
  files::{FileMetadata, FileNode, FileRelationship, SemanticFeatures},
  relationships::{RelationshipStrength, RelationshipType},
};

// [INSERT Graph and DAGStats here from storage/graph.rs:364-780]
```

### Step 3: Split trait_types.rs
Extract types to domain files:

**domain/analysis.rs:**
- CodeContext
- CodeAnalysisResult
- CodeUnderstandingContext
- CodeAnalysisCapabilities

**domain/naming.rs:**
- NamingIssue
- NamingSeverity
- NameCheckResult

**domain/refactoring.rs:**
- RefactoringSuggestion
- RefactoringEffort
- RefactoringPriority
- DuplicateInfo
- DuplicateSeverity
- UnusedCodeInfo

**domain/metadata.rs:**
- FunctionMetadata
- CodeLocation
- StructContext
- FunctionContext
- RegistryCode

**traits/analysis.rs:**
- CodeAnalysisAgent trait

### Step 4: Update lib.rs
Add new modules to exports:

```rust
// Add new modules
pub mod domain;
pub mod graph;
pub mod vectors;
pub mod traits;

// Re-export for backward compatibility
pub use domain::*;
pub use graph::*;
pub use vectors::*;
pub use traits::*;
```

### Step 5: Update storage/mod.rs
Remove graph from storage exports:

```rust
// Remove this line:
pub use graph::*;

// Graph is now in crate::graph
```

### Step 6: Fix Remaining Imports
After migration script runs, fix any remaining imports:

```bash
# Check for errors
cargo build 2>&1 | grep "error\[E0" | head -20

# Common fixes needed:
# - Update use statements in analysis modules
# - Update re-exports in lib.rs
# - Fix circular dependencies if any
```

### Step 7: Delete Old Files (After Verification)
Once build passes:
```bash
rm src/vectors.rs
rm src/vector_index.rs
rm src/advanced_vectors.rs
rm src/types/trait_types.rs
rm src/types/types.rs  # If exists
# storage/graph.rs will be mostly empty - can delete after Graph extraction
```

## 📊 Benefits

1. **Clear Separation**: Domain types, algorithms, storage clearly separated
2. **No More 780-line Files**: Largest file will be ~200 lines
3. **Domain-Driven**: Types organized by domain (symbols, files, metrics, naming, refactoring)
4. **Easier Navigation**: Related code grouped together
5. **Backward Compatible**: Re-exports maintain old import paths

## 🚨 Common Issues

### Import Errors
If you see errors like `cannot find type 'X' in crate 'analysis_suite'`:
- Check lib.rs has `pub use domain::*;`
- Check domain/mod.rs re-exports all types
- Verify file was moved to correct location

### Circular Dependencies
If you see circular dependency errors:
- domain types should NOT import from graph or analysis
- graph can import from domain
- analysis can import from domain and graph

### Missing Types
If types seem missing after reorganization:
- Check they were added to corresponding domain file
- Verify domain/mod.rs re-exports them
- Ensure lib.rs re-exports domain module

//! Storage Layer for Codebase Analysis
//!
//! This module provides multiple storage backends optimized for different use cases.
//!
//! ## Path Centralization
//!
//! **ALL storage MUST use `sparc_engine::core::paths::SPARCPaths`**
//! - No hardcoded paths allowed
//! - Global storage: `~/.cache/sparc-engine/global/`
//! - Per-project: `~/.cache/sparc-engine/<project-id>/`
//! - Sessions: `~/.cache/sparc-engine/<project-id>/sessions/`
//!
//! # Storage Backends
//!
//! ## Temporary Helpers (Optional)
//! - **FileStore**: Temporary file cache (in-memory HashMap)
//! - **ASTStore**: Temporary AST cache (in-memory HashMap)
//!
//! ## Primary Storage
//! - **AnalysisStore**: Generic persistent storage system
//!   - **redb**: Own database file (`SPARCPaths::project_code_storage()`)
//!   - **VectorDAG**: In-memory graph (loaded from own redb)
//!   - **Tantivy**: Full-text search index (`SPARCPaths::project_search_index()`)
//!
//! ## Session Storage
//! - **ManagerSession**: Per-project session tracking
//!   - Phases, inputs, outputs, responses, artifacts, debug, calls
//!   - All in `SPARCPaths::project_sessions(project_id)`
//!
//! # Architecture
//!
//! ```text
//! ~/.cache/sparc-engine/
//! ├── global/                          # Cross-project (GlobalManagerCache)
//! │   ├── libraries.redb
//! │   ├── patterns.redb
//! │   └── models.redb
//! │
//! └── <project-id>/                    # Per-project storage
//!     ├── analysis_storage.redb       # AnalysisStore (UNIFIED - all features)
//!     ├── analysis_cache.redb         # DEPRECATED (migrated to code_storage.redb)
//!     ├── framework_cache.redb        # FrameworkStorage
//!     ├── search.idx/                 # Tantivy search index
//!     └── sessions/                   # ManagerSession
//!         ├── phases/
//!         ├── inputs/
//!         ├── outputs/
//!         ├── responses/
//!         ├── artifacts/
//!         ├── debug/
//!         ├── calls/
//!         └── vector_index/
//!
//! Optional addon (feature = "fact-sync"):
//!   prompt_engine::fact_core → Can read from CodeStorage
//!                             → For prompt learning/optimization
//! ```
//!
//! **Storage hierarchy:**
//! 1. **AnalysisStore** - Primary, comprehensive per-project storage
//!    - Replaces deprecated `PersistentAnalysisStore` from memory module
//!    - All features consolidated: checksums, agent decisions, vectors, metadata
//! 2. **fact_core** - Optional addon that reads from AnalysisStore
//! 3. **ManagerSession** - Per-project session tracking
//! 4. **FileStore/ASTStore** - Optional temporary caches
//!
//! ## Migration from PersistentAnalysisStore
//!
//! All features from `src/memory/persistent_analysis.rs` have been migrated to `AnalysisStore`:
//!
//! | Feature | Old (PersistentAnalysisStore) | New (AnalysisStore) |
//! |---------|------------------------------|-------------------|
//! | File checksums | `store_file_analysis()` | `store_checksum()`, `file_changed()` |
//! | Agent decisions | Part of CachedFileAnalysis | `store_agent_decisions()`, `get_agent_decisions()` |
//! | Success patterns | ProjectAnalysisCache | ProjectMetadata |
//! | Vectors | VECTOR_STORE_TABLE | `store_vectors()`, `get_all_vectors()` |
//! | Project metadata | PROJECT_METADATA_TABLE | `store_project_metadata()` |
//!
//! **Single database**: `code_storage.redb` (was split across `code_storage.redb` + `analysis_cache.redb`)

// In-memory graph (moved from analysis/dag/vector_dag.rs)
pub mod graph;

// Temporary in-memory storage (optional helpers)
pub mod index_storage;
pub mod metadata_storage;
pub mod session_manager;

// DEPRECATED: All storage functionality moved to codebase module
// Use codebase::storage::CodebaseDatabase instead

// All old databases removed - use codebase::storage::CodebaseDatabase
// Legacy re-exports removed - import directly from codebase module

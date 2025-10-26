//! # Codebase Module
//!
//! Core analysis capabilities for parsers and analysis service.
//! Everything needed in one place - single source of truth.
//!
//! ## SAFe 6.0 Capability Architecture
//!
//! This module stores ANALYSIS RESULTS (what our code CAN DO):
//! - Code capabilities (parsing, analysis, transformation)
//! - Performance metrics
//! - Quality assessments
//!
//! External facts (GitHub, npm, CVEs) are stored in fact-system.

pub mod metadata;
pub mod storage;  // Pure computation - no I/O
// pub mod analysis;  // DISABLED: Contains CodebaseDatabase - refactor to use data from Elixir
// pub mod parsers;  // DISABLED: Uses CodeMetadata type that's only relevant when storing
pub mod vectors;
// pub mod vector_adapter;  // DISABLED: Bridge only needed when writing to database
pub mod graphs;
// pub mod config;  // DISABLED: Uses AnalysisConfig which depends on disabled analysis module
// pub mod parser_registry;  // DISABLED: Uses ParserCapabilities for parser management
// pub mod semantic_cache;  // DISABLED: Cache only needed when using database
pub mod capability;  // NEW: SAFe 6.0 aligned capability model
// pub mod capability_storage;  // DISABLED: Database operations now in Elixir (PostgreSQL)
// pub mod sparc_integration;  // DISABLED: Check if has database dependencies

// Re-export main types for easy access
pub use metadata::*;
pub use storage::*;
// pub use analysis::*;  // DISABLED - see above
// pub use parsers::*;  // DISABLED
pub use vectors::*;
// pub use vector_adapter::*;  // DISABLED
pub use graphs::*;
// pub use config::*;  // DISABLED
// pub use parser_registry::*;  // DISABLED
// pub use semantic_cache::*;  // DISABLED
pub use capability::*;  // NEW: CodeCapability, CapabilityKind, etc.
// pub use capability_storage::*;  // DISABLED - see above
// pub use sparc_integration::*;  // DISABLED - see above

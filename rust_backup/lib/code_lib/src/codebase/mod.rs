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
pub mod storage;
pub mod analysis;
pub mod parsers;
pub mod vectors;
pub mod vector_adapter;  // NEW: Bridge between parser output and vector storage
pub mod graphs;
pub mod config;
pub mod parser_registry;
pub mod semantic_cache;  // NEW: Global semantic embeddings cache
pub mod capability;  // NEW: SAFe 6.0 aligned capability model
pub mod capability_storage;  // NEW: Capability persistence layer
pub mod sparc_integration;  // NEW: SPARC dual-source knowledge query

// Re-export main types for easy access
pub use metadata::*;
pub use storage::*;
pub use analysis::*;
pub use parsers::*;
pub use vectors::*;
pub use vector_adapter::*;  // NEW: VectorAdapter for parser→vector conversion
pub use graphs::*;
pub use config::*;
pub use parser_registry::*;
pub use semantic_cache::*;
pub use capability::*;  // NEW: CodeCapability, CapabilityKind, etc.
pub use capability_storage::*;  // NEW: CapabilityStorage, CapabilityStats
pub use sparc_integration::*;  // NEW: SparcKnowledge, HowToResult, UnderstandingResult

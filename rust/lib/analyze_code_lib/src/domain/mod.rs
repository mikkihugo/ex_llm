//! Domain types for code analysis
//!
//! This module contains all domain-specific data structures organized by concern:
//! - symbols: Code symbols from parsing (functions, structs, enums, traits)
//! - files: File-level metadata and relationships
//! - metrics: Analysis metrics (complexity, performance, quality)
//! - relationships: Graph relationship types and strengths
//!
//! TODO: Extract from types/trait_types.rs:
//! - analysis: Core analysis domain types
//! - naming: Naming-related types and issues
//! - refactoring: Refactoring suggestions and metadata
//! - metadata: Additional metadata types

// pub mod analysis;      // TODO: Extract from types/trait_types.rs
pub mod files;
// pub mod metadata;      // TODO: Extract from types/trait_types.rs
pub mod metrics;
// pub mod naming;        // TODO: Extract from types/trait_types.rs
// pub mod refactoring;   // TODO: Extract from types/trait_types.rs
pub mod relationships;
pub mod symbols;

// Re-export all types for convenience
// pub use analysis::*;
pub use files::*;
// pub use metadata::*;
pub use metrics::*;
// pub use naming::*;
// pub use refactoring::*;
pub use relationships::*;
pub use symbols::*;

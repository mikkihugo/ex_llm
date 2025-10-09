//! Parser Framework - Core traits and types for language-specific parsers
//! 
//! This crate provides the common interface that all language parsers must implement.
//! It defines the core traits, AST types, and error handling that parsers use.

pub mod traits;
pub mod ast;
pub mod metrics;
pub mod errors;

pub use traits::*;
pub use ast::*;
pub use metrics::*;
pub use errors::*;
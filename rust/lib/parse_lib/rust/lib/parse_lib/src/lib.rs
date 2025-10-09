//! Parse Library - Unified parsing utilities
//! 
//! Contains:
//! - rca: Mozilla rust-code-analyzer
//! - template_meta: Template metadata parsing
//! - template_parser: Template parser
//! - dependency: Dependency parsing

pub mod rca;
pub mod template_meta;
pub mod template_parser;
pub mod dependency;

// Re-export commonly used items
pub use rca as rust_code_analyzer;

//! Shared Types for Codebase Analysis
//!
//! This module provides shared types used across all codebase analysis systems
//! and agent modules. It serves as the foundation for both algorithmic and
//! LLM-powered analysis.
//!
//! # AI Coder Benefits
//!
//! - **Unified Types**: Consistent types across all analysis systems
//! - **No Duplication**: Types defined once, used everywhere
//! - **Clear Foundation**: Solid foundation for both algorithmic and LLM analysis
//! - **Easy Integration**: Agents can easily leverage codebase analysis

pub mod cache_types;
pub mod trait_types;
pub mod types;

// Re-export main types for easy access
pub use cache_types::*;
pub use trait_types::*;
pub use types::*;

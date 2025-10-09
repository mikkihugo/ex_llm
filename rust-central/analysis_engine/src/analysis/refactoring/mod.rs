//! Refactoring Analysis
//!
//! Provides refactoring analysis capabilities including refactoring opportunities,
//! naming improvements, and structure optimization suggestions.
//!
//! # AI Coder Benefits
//!
//! - **Refactoring Awareness**: Names that support future refactoring
//! - **Improvement Suggestions**: Suggest better names during refactoring
//! - **Structure Optimization**: Names that improve code structure
//! - **Refactoring Opportunities**: Identify areas needing better naming

pub mod naming_improvements;
pub mod refactoring_opportunities;
pub mod structure_optimization;

// Re-export main types
pub use naming_improvements::*;
pub use refactoring_opportunities::*;
pub use structure_optimization::*;

//! Refactoring Analysis
//!
//! Provides refactoring analysis capabilities including refactoring opportunities
//! and structure optimization suggestions.
//!
//! # AI Coder Benefits
//!
//! - **Refactoring Awareness**: Identify structural improvements
//! - **Structure Optimization**: Suggests reorganizing large/complex code
//! - **Refactoring Opportunities**: Highlights specific transformations

pub mod refactoring_opportunities;
pub mod structure_optimization;

// Re-export main types
pub use refactoring_opportunities::*;
pub use structure_optimization::*;

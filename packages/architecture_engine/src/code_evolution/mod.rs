//! Code Evolution and History
//!
//! Provides code evolution analysis including change tracking, naming evolution,
//! and migration suggestions.
//!
//! # AI Coder Benefits
//!
//! - **Evolution Awareness**: Names that evolve well over time
//! - **Deprecation Awareness**: Avoid names that become deprecated
//! - **Migration Support**: Names that support future migrations
//! - **Change Tracking**: Learn from code evolution patterns

pub mod change_analyzer;
pub mod deprecated_detector;
pub mod naming_evolution;

// Re-export main types
pub use change_analyzer::*;
pub use deprecated_detector::*;
pub use naming_evolution::*;

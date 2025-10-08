//! Code CodePatterns and Anti-patterns
//!
//! Provides pattern detection capabilities including design pattern recognition,
//! anti-pattern detection, and naming pattern analysis.
//!
//! # AI Coder Benefits
//!
//! - **CodePattern Awareness**: Names that follow established patterns
//! - **Anti-pattern Avoidance**: Avoid names that create anti-patterns
//! - **Consistency**: Ensure naming consistency across patterns
//! - **CodePattern Suggestions**: Suggest pattern-based names

pub mod anti_pattern_detector;
pub mod naming_patterns;
pub mod pattern_detector;

// Re-export main types
pub use anti_pattern_detector::*;
pub use naming_patterns::*;
pub use pattern_detector::*;

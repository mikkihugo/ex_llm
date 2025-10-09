//! Framework Analysis Module
//!
//! Detects and analyzes frameworks, libraries, and ecosystems used in codebases.
//! Provides framework-specific insights and recommendations.

pub mod detector;
pub mod analyzer;
pub mod patterns;

pub use detector::*;
pub use analyzer::*;
pub use patterns::*;
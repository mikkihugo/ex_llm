//! Technology Detection Module
//!
//! Detects and analyzes technologies, frameworks, libraries, and ecosystems used in codebases.
//! Provides technology-specific insights and recommendations.

pub mod analyzer;
pub mod detector;
pub mod patterns;

pub use analyzer::*;
pub use detector::*;
pub use patterns::*;

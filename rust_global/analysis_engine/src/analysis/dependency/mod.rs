//! Dependency Analysis Module
//!
//! Analyzes dependencies, circular dependencies, and dependency health.
//! Integrates with fact-system for dependency knowledge and vulnerabilities.

pub mod detector;
pub mod graph;
pub mod health;

pub use detector::*;
pub use graph::*;
pub use health::*;
//! Architecture Analysis Module
//!
//! Analyzes architectural patterns, design principles, and code organization.
//! Integrates with fact-system for architectural knowledge and patterns.

pub mod detector;
pub mod patterns;
pub mod principles;

pub use detector::*;
pub use patterns::*;
pub use principles::*;
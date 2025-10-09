//! Code Metrics and Statistics
//!
//! Provides comprehensive code metrics collection including lines of code,
//! function metrics, class metrics, and module-level statistics.
//!
//! # AI Coder Benefits
//!
//! - **Size Awareness**: Names based on code size and complexity
//! - **Function Metrics**: Names that reflect function characteristics
//! - **Module Organization**: Names that fit module structure
//! - **Project Metrics**: Names consistent with project scale

pub mod project_metrics;

// Re-export main types
pub use project_metrics::*;

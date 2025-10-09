//! Performance Analysis Module
//!
//! Comprehensive performance analysis including bottleneck detection,
//! optimization opportunities, and resource usage analysis.

pub mod detector;
pub mod optimizer;
pub mod profiler;

pub use detector::*;
pub use optimizer::*;
pub use profiler::*;
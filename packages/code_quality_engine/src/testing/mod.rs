//! Testing Module
//!
//! Comprehensive testing framework for the analysis-suite.

pub mod coverage;
pub mod coverage_collection;
pub mod parser_integration;
pub mod visualization;

// Re-export specific types to avoid conflicts
pub use coverage::{CoverageAnalyzer, CoverageReport, CoverageAnalysis};
pub use coverage_collection::{CoverageDataCollector};
pub use parser_integration::{ParserCoverageCollector, ParserCoverageData};
pub use visualization::{CoverageVisualizer, ChartGenerator, MapGenerator, DashboardGenerator};

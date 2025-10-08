//! Code Graph Construction and Analysis
//!
//! Provides code graph building capabilities for understanding code structure,
//! dependencies, relationships, PageRank centrality, and intelligent code insights.
//!
//! # AI Coder Benefits
//!
//! - **Dependency Analysis**: Understands how code components depend on each other
//! - **Structure Understanding**: Maps the overall code structure
//! - **Relationship Modeling**: Identifies relationships between code elements
//! - **Naming Context**: Provides context for intelligent naming suggestions
//! - **PageRank Centrality**: Identifies important nodes in code graphs
//! - **Code Insights**: Advanced insights, patterns, and recommendations

pub mod code_graph;
pub mod code_insights;
pub mod pagerank;

// Re-export main types
pub use code_graph::*;
pub use code_insights::*;
pub use pagerank::*;

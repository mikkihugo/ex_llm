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

// Core code graph types
pub use code_graph::{
    CodeDependencyGraph as CodeGraph, CodeGraphBuilder, GraphType, GraphNode, GraphEdge,
    GraphMetrics, CodebaseCodePatterns, NamingCodePattern,
};

// Code insights and analysis
pub use code_insights::{
    CodeInsightsEngine, IntelligentInsight, InsightType,
    CodeInsightsResult,
};

// PageRank analysis types
pub use pagerank::{
    PageRankIntegration, PageRankConfig, PageRankMetrics, PageRankResult,
    CentralPageRank,
};

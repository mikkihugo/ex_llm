//! Dependency Analysis Module
//!
//! Analyzes dependencies, circular dependencies, and dependency health.
//! Integrates with fact-system for dependency knowledge and vulnerabilities.

pub mod detector;
pub mod graph;
pub mod health;

// Explicit re-exports to avoid ambiguous glob re-exports
// Dependencies and vulnerabilities
pub use detector::{
    Dependency, DependencyAnalysis, DependencyHealthMetrics, DependencyNode, DependencyNodeType,
    DependencyRecommendation, DependencySource, DependencyType, DependencyVulnerability,
    RecommendationPriority, VulnerabilitySeverity,
};

// Circular dependencies
pub use detector::{CircularDependency, CircularDependencyImpact, CircularDependencySeverity};

// Graph structures and analysis
pub use graph::{
    CentralityMetrics, DependencyEdge, DependencyEdgeType, DependencyGraph, GraphMetrics,
};

// Health analysis
pub use health::{CostLevel, CriticalityLevel, DependencyHealthAnalysis, DependencyHealthAnalyzer};

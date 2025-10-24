//! Analysis Layer for Code Analysis
//!
//! This module provides PURE CODE ANALYSIS only (no architecture, no quality).
//! For architecture/framework analysis, use architecture_engine.
//! For quality/linting, use quality_engine.
//!
//! # Components (Code Analysis Only)
//!
//! - **metrics/**: Code metrics and statistics (LOC, complexity, etc.)
//! - **performance/**: Performance analysis and monitoring
//! - **security/**: Security vulnerability analysis
//! - **dependency/**: Dependency graph analysis
//! - **control_flow**: Control flow and complexity analysis
//! - **semantic/**: Semantic analysis and vector embeddings
//! - **graph/**: Code graph construction and analysis
//! - **dag/**: Directed Acyclic Graph for file relationships
//! - **multilang/**: Cross-language analysis
//! - **central_heuristics**: Universal scoring (PageRank, file importance)
//! - **refactoring_suggestions**: Universal refactoring engine

pub mod central_heuristics;
pub mod control_flow;
pub mod dag;
pub mod dependency;
pub mod graph;
pub mod metrics;
pub mod multilang;
pub mod performance;
pub mod refactoring_suggestions;
pub mod results;
pub mod security;
pub mod semantic;

// Re-export main types with careful grouping to avoid conflicts

// Central heuristics and graph analysis
pub use central_heuristics::*;

// DAG and graph analysis
pub use dag::{PromptCoordinator, VectorIntegration};
pub use graph::*;

// Dependency analysis (excluding conflicts with security)
pub use dependency::{
    Dependency, DependencyAnalysis, DependencyHealthMetrics, DependencyNode, DependencyNodeType,
    DependencyRecommendation, DependencySource, DependencyType, DependencyVulnerability,
    CircularDependency, CircularDependencyImpact, CircularDependencySeverity,
    CentralityMetrics as DependencyCentralityMetrics, DependencyEdge, DependencyEdgeType,
    DependencyGraph, GraphMetrics as DependencyGraphMetrics,
    CostLevel, CriticalityLevel, DependencyHealthAnalysis, DependencyHealthAnalyzer,
};

// Code metrics and analysis (exclude conflicting names)
pub use metrics::*;
pub use multilang::*;
pub use performance::{
    PerformanceAnalysis, PerformanceBottleneck, BottleneckType, PerformanceSeverity,
    BottleneckLocation, PerformanceImpact, ScalabilityImpact, OptimizationOpportunity,
    OptimizationType, ImplementationEffort, ResourceUsage, MemoryUsage, MemoryLeak,
    CPUUsage, CPUIntensiveFunction, NetworkUsage, SlowRequest, NetworkBottleneck,
    NetworkBottleneckType, DiskUsage, SlowIOOperation, IOOperationType,
    PerformanceRecommendation, PerformanceRecommendationPriority, PerformanceCategory,
    PerformanceMetadata, PerformanceDetectorTrait, PerformancePatternRegistry, PerformancePattern,
    OptimizationAnalysis, Optimization, OptimizationLocation,
    OptimizationRecommendation, OptimizationCategory as OptimizerCategory,
    OptimizationMetadata, OptimizationPattern, PerformanceOptimizer,
    ProfilingAnalysis, PerformanceMetrics, ProfilingMetadata, ProfilingPattern, PerformanceProfiler,
};
pub use refactoring_suggestions::*;
pub use results::*;

// Security analysis (primary source for RecommendationPriority and VulnerabilitySeverity)
pub use security::*;

// Semantic analysis
pub use semantic::*;

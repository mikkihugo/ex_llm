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
//! - **pattern_detection**: Pattern Registry integration for comprehensive pattern matching

pub mod architecture;
pub mod central_heuristics;
pub mod control_flow;
pub mod dag;
pub mod dependency;
pub mod graph;
pub mod metrics;
pub mod multilang;
pub mod pattern_detection;
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
    CentralityMetrics as DependencyCentralityMetrics, CircularDependency, CircularDependencyImpact,
    CircularDependencySeverity, CostLevel, CriticalityLevel, Dependency, DependencyAnalysis,
    DependencyEdge, DependencyEdgeType, DependencyGraph, DependencyHealthAnalysis,
    DependencyHealthAnalyzer, DependencyHealthMetrics, DependencyNode, DependencyNodeType,
    DependencyRecommendation, DependencySource, DependencyType, DependencyVulnerability,
    GraphMetrics as DependencyGraphMetrics,
};

// Code metrics and analysis (exclude conflicting names)
pub use metrics::*;
pub use multilang::*;
pub use performance::{
    BottleneckLocation, BottleneckType, CPUIntensiveFunction, CPUUsage, DiskUsage, IOOperationType,
    ImplementationEffort, MemoryLeak, MemoryUsage, NetworkBottleneck, NetworkBottleneckType,
    NetworkUsage, Optimization, OptimizationAnalysis, OptimizationLocation, OptimizationMetadata,
    OptimizationOpportunity, OptimizationPattern, OptimizationRecommendation, OptimizationType,
    PerformanceAnalysis, PerformanceBottleneck, PerformanceCategory, PerformanceDetectorTrait,
    PerformanceImpact, PerformanceMetadata, PerformanceMetrics, PerformanceOptimizer,
    PerformancePattern, PerformancePatternRegistry, PerformanceProfiler, PerformanceRecommendation,
    PerformanceRecommendationPriority, PerformanceSeverity, ProfilingAnalysis, ProfilingMetadata,
    ProfilingPattern, ResourceUsage, ScalabilityImpact, SlowIOOperation, SlowRequest,
};
pub use refactoring_suggestions::*;
pub use results::*;

// Security analysis (primary source for RecommendationPriority and VulnerabilitySeverity)
pub use security::*;

// Semantic analysis
pub use semantic::*;

// Pattern detection with PatternRegistry integration
pub use pattern_detection::{
    detect_security_patterns_from_registry, detect_vulnerabilities_from_patterns, matches_pattern,
    query_patterns_for_category, query_patterns_for_language, record_pattern_match, PatternMatch,
    RegistryPattern,
};

//! Performance Analysis Module
//!
//! Comprehensive performance analysis including bottleneck detection,
//! optimization opportunities, and resource usage analysis.

pub mod detector;
pub mod optimizer;
pub mod profiler;

// Core performance analysis (from detector)
pub use detector::{
    PerformanceAnalysis, PerformanceBottleneck, BottleneckType, PerformanceSeverity,
    BottleneckLocation, PerformanceImpact, ScalabilityImpact, OptimizationOpportunity,
    OptimizationType, ImplementationEffort, ResourceUsage, MemoryUsage, MemoryLeak,
    CPUUsage, CPUIntensiveFunction, NetworkUsage, SlowRequest, NetworkBottleneck,
    NetworkBottleneckType, DiskUsage, SlowIOOperation, IOOperationType,
    PerformanceRecommendation, PerformanceRecommendationPriority, PerformanceCategory,
    PerformanceMetadata, PerformanceDetectorTrait, PerformancePatternRegistry, PerformancePattern,
};

// Optimization-specific types (from optimizer, excluding duplicates)
pub use optimizer::{
    OptimizationAnalysis, Optimization, OptimizationLocation,
    OptimizationRecommendation, PerformanceRecommendationPriority, OptimizationCategory as OptimizerCategory,
    OptimizationMetadata, OptimizationPattern, PerformanceOptimizer,
};

// Profiling-specific types (from profiler, excluding duplicates)
pub use profiler::{
    ProfilingAnalysis, PerformanceMetrics, ProfilingMetadata, ProfilingPattern, PerformanceProfiler,
};
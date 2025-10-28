//! Performance Analysis Module
//!
//! Comprehensive performance analysis including bottleneck detection,
//! optimization opportunities, and resource usage analysis.

pub mod detector;
pub mod optimizer;
pub mod profiler;

// Core performance analysis (from detector)
pub use detector::{
    BottleneckLocation, BottleneckType, CPUIntensiveFunction, CPUUsage, DiskUsage, IOOperationType,
    ImplementationEffort, MemoryLeak, MemoryUsage, NetworkBottleneck, NetworkBottleneckType,
    NetworkUsage, OptimizationOpportunity, OptimizationType, PerformanceAnalysis,
    PerformanceBottleneck, PerformanceCategory, PerformanceDetectorTrait, PerformanceImpact,
    PerformanceMetadata, PerformancePattern, PerformancePatternRegistry, PerformanceRecommendation,
    PerformanceRecommendationPriority, PerformanceSeverity, ResourceUsage, ScalabilityImpact,
    SlowIOOperation, SlowRequest,
};

// Optimization-specific types (from optimizer, excluding duplicates)
pub use optimizer::{
    Optimization, OptimizationAnalysis, OptimizationCategory as OptimizerCategory,
    OptimizationLocation, OptimizationMetadata, OptimizationPattern, OptimizationRecommendation,
    PerformanceOptimizer,
};

// Profiling-specific types (from profiler, excluding duplicates)
pub use profiler::{
    PerformanceMetrics, PerformanceProfiler, ProfilingAnalysis, ProfilingMetadata, ProfilingPattern,
};

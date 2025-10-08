//! Main Code Analyzer
//! 
//! Orchestrates all analysis modules for comprehensive code analysis.
//! Pure analysis - no I/O operations.

use crate::types::*;
use anyhow::Result;

/// Main codebase analyzer that orchestrates all analysis systems
pub struct MainAnalyzer {
    /// Quality analysis module
    pub quality_analyzer: crate::quality_analyzer::QualityAnalyzer,
    /// Framework detection module
    pub framework_detector: crate::framework_detector::FrameworkDetector,
    /// Cross-language analysis module
    pub cross_language_analyzer: crate::cross_language_analyzer::CrossLanguageAnalyzer,
    /// Performance tracking module
    pub performance_tracker: crate::performance_tracker::PerformanceTracker,
    /// Metrics collection module
    pub metrics_collector: crate::metrics_collector::MetricsCollector,
}

impl MainAnalyzer {
    /// Create a new main analyzer
    pub fn new() -> Result<Self> {
        Ok(Self {
            quality_analyzer: crate::quality_analyzer::QualityAnalyzer::new()?,
            framework_detector: crate::framework_detector::FrameworkDetector::new()?,
            cross_language_analyzer: crate::cross_language_analyzer::CrossLanguageAnalyzer::new()?,
            performance_tracker: crate::performance_tracker::PerformanceTracker::new(),
            metrics_collector: crate::metrics_collector::MetricsCollector::new(),
        })
    }

    /// Analyze code and return quality analysis results
    pub fn analyze_code(&self, code: &str, context: &crate::CodeContext) -> Result<crate::analysis::quality_analyzer::CodeAnalysisResult, String> {
        self.quality_analyzer.analyze_code(code, context)
    }

    /// Get performance report
    pub fn get_performance_report(&self) -> PerformanceReport {
        self.performance_tracker.get_performance_report()
    }

    /// Analyze cross-language patterns
    pub async fn analyze_cross_language_patterns(
        &self,
        files: &[ParsedFile],
    ) -> Result<CrossLanguageAnalysis, String> {
        self.cross_language_analyzer.analyze_cross_language_patterns(files).await
    }

    /// Evaluate quality gates
    pub async fn evaluate_quality_gates(
        &self,
        files: &[ParsedFile],
    ) -> Result<QualityGateResults, String> {
        self.quality_analyzer.evaluate_quality_gates(files).await
    }

    /// Detect frameworks
    pub fn detect_frameworks(&self, path: &std::path::Path) -> Result<Vec<String>> {
        self.framework_detector.detect_frameworks(path)
    }

    /// Get aggregate metrics
    pub fn get_aggregate_metrics(&self) -> crate::metrics_collector::AggregateMetrics {
        self.metrics_collector.calculate_aggregate_metrics()
    }
}

impl Default for MainAnalyzer {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| panic!("Failed to initialize MainAnalyzer"))
    }
}
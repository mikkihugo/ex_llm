//! Quality Analysis Module
//! 
//! Handles code quality analysis, quality gates, and consistency checks.
//! Pure analysis - no I/O operations.

use crate::types::*;
use anyhow::Result;

/// Quality analyzer for code analysis
pub struct QualityAnalyzer {
    /// Performance tracker
    pub performance_tracker: PerformanceTracker,
    /// Analysis systems
    pub metrics_collector: crate::analysis::metrics::MetricsCollector,
    /// External crate dependencies
    pub code_analysis_engine: CodeAnalysisEngine,
    pub linting_engine: LintingEngine,
}

impl QualityAnalyzer {
    /// Create a new quality analyzer
    pub fn new() -> Result<Self> {
        Ok(Self {
            performance_tracker: PerformanceTracker::new(),
            metrics_collector: crate::analysis::metrics::MetricsCollector::new(),
            code_analysis_engine: CodeAnalysisEngine::new(),
            linting_engine: LintingEngine::new(),
        })
    }

    /// Analyze code and return quality analysis results
    pub fn analyze_code(&self, code: &str, context: &crate::CodeContext) -> Result<crate::analysis::quality_analyzer::CodeAnalysisResult, String> {
        // Pure code analysis - no I/O
        self.code_analysis_engine.analyze_code(code, context)
    }

    /// Get performance report
    pub fn get_performance_report(&self) -> PerformanceReport {
        self.performance_tracker.get_performance_report()
    }

    fn analyze_quality_consistency(&self, files: &[ParsedFile]) -> QualityConsistency {
        let mut consistency = QualityConsistency::default();

        let mut total_complexity = 0.0;
        let mut total_maintainability = 0.0;
        let mut total_technical_debt = 0.0;
        let mut file_count = 0;

        for file in files.iter() {
            total_complexity += file.metrics.cyclomatic_complexity;
            total_maintainability += file.metrics.maintainability_index;
            total_technical_debt += file.metrics.technical_debt_ratio;
            file_count += 1;
        }

        if file_count > 0 {
            consistency.average_complexity = total_complexity / file_count as f64;
            consistency.average_maintainability = total_maintainability / file_count as f64;
            consistency.average_technical_debt = total_technical_debt / file_count as f64;

            // Calculate consistency score
            consistency.consistency_score = self.calculate_consistency_score(files);
        }

        consistency
    }
    fn calculate_consistency_score(&self, files: &[ParsedFile]) -> f64 {
        if files.len() < 2 {
            return 1.0;
        }

        let complexities: Vec<f64> = files
            .iter()
            .map(|f| f.metrics.cyclomatic_complexity)
            .collect();
        let maintainabilities: Vec<f64> = files
            .iter()
            .map(|f| f.metrics.maintainability_index)
            .collect();

        // Calculate coefficient of variation (lower is more consistent)
        let complexity_cv = self.coefficient_of_variation(&complexities);
        let maintainability_cv = self.coefficient_of_variation(&maintainabilities);

        // Convert to consistency score (higher is more consistent)
        let complexity_score = (1.0 - complexity_cv).max(0.0);
        let maintainability_score = (1.0 - maintainability_cv).max(0.0);

        (complexity_score + maintainability_score) / 2.0
    }
    fn coefficient_of_variation(&self, values: &[f64]) -> f64 {
        if values.is_empty() {
            return 0.0;
        }

        let mean = values.iter().sum::<f64>() / values.len() as f64;
        if mean == 0.0 {
            return 0.0;
        }

        let variance = values.iter().map(|x| (x - mean).powi(2)).sum::<f64>() / values.len() as f64;
        let std_dev = variance.sqrt();

        std_dev / mean
    }
    fn analyze_complexity_distribution(&self, files: &[ParsedFile]) -> ComplexityDistribution {
        let mut distribution = ComplexityDistribution::default();

        for file in files.iter() {
            let complexity = file.metrics.cyclomatic_complexity;

            if complexity < 5.0 {
                distribution.low_complexity += 1;
            } else if complexity < 15.0 {
                distribution.medium_complexity += 1;
            } else {
                distribution.high_complexity += 1;
            }

            distribution.total_files += 1;
        }

        distribution
    }
    pub async fn evaluate_quality_gates(
        &self,
        files: &[ParsedFile],
    ) -> Result<QualityGateResults, String> {
        let mut results = QualityGateResults::default();

        // Gate 1: Complexity threshold
        let high_complexity_files: Vec<&ParsedFile> = files
            .iter()
            .filter(|f| f.metrics.cyclomatic_complexity > 15.0)
            .collect();

        results.complexity_gate = QualityGate {
            name: "Cyclomatic Complexity".to_string(),
            passed: high_complexity_files.is_empty(),
            threshold: 15.0,
            actual_value: if files.is_empty() {
                0.0
            } else {
                files
                    .iter()
                    .map(|f| f.metrics.cyclomatic_complexity)
                    .sum::<f64>()
                    / files.len() as f64
            },
            failed_files: high_complexity_files
                .iter()
                .map(|f| f.name.clone())
                .collect(),
        };

        // Gate 2: Maintainability threshold
        let low_maintainability_files: Vec<&ParsedFile> = files
            .iter()
            .filter(|f| f.metrics.maintainability_index < 20.0)
            .collect();

        results.maintainability_gate = QualityGate {
            name: "Maintainability Index".to_string(),
            passed: low_maintainability_files.is_empty(),
            threshold: 20.0,
            actual_value: if files.is_empty() {
                0.0
            } else {
                files
                    .iter()
                    .map(|f| f.metrics.maintainability_index)
                    .sum::<f64>()
                    / files.len() as f64
            },
            failed_files: low_maintainability_files
                .iter()
                .map(|f| f.name.clone())
                .collect(),
        };

        // Gate 3: Technical debt threshold
        let high_debt_files: Vec<&ParsedFile> = files
            .iter()
            .filter(|f| f.metrics.technical_debt_ratio > 0.5)
            .collect();

        results.technical_debt_gate = QualityGate {
            name: "Technical Debt Ratio".to_string(),
            passed: high_debt_files.is_empty(),
            threshold: 0.5,
            actual_value: if files.is_empty() {
                0.0
            } else {
                files
                    .iter()
                    .map(|f| f.metrics.technical_debt_ratio)
                    .sum::<f64>()
                    / files.len() as f64
            },
            failed_files: high_debt_files.iter().map(|f| f.name.clone()).collect(),
        };

        // Overall gate result
        results.overall_passed = results.complexity_gate.passed
            && results.maintainability_gate.passed
            && results.technical_debt_gate.passed;

        Ok(results)
    }
}

impl Default for QualityAnalyzer {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| panic!("Failed to initialize QualityAnalyzer"))
    }
}
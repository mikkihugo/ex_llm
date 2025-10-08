//! Metrics Collection Module
//! 
//! Handles code metrics collection and analysis.
//! Pure analysis - no I/O operations.

use crate::types::*;

/// Metrics collector for code analysis
pub struct MetricsCollector {
    /// Internal metrics storage
    pub metrics: std::collections::HashMap<String, FileMetrics>,
}

impl MetricsCollector {
    /// Create a new metrics collector
    pub fn new() -> Self {
        Self {
            metrics: std::collections::HashMap::new(),
        }
    }

    /// Extract metrics from analysis result
    pub fn extract_metrics_from_analysis(
        &self,
        analysis_result: &universal_parser::AnalysisResult,
    ) -> FileMetrics {
        // Extract basic metrics
        let mut metrics = FileMetrics {
            lines_of_code: analysis_result.line_metrics.code_lines,
            blank_lines: analysis_result.line_metrics.blank_lines,
            comment_lines: analysis_result.line_metrics.comment_lines,
            total_lines: analysis_result.line_metrics.code_lines
                + analysis_result.line_metrics.blank_lines
                + analysis_result.line_metrics.comment_lines,
            cyclomatic_complexity: analysis_result.complexity_metrics.cyclomatic,
            cognitive_complexity: analysis_result.complexity_metrics.cognitive,
            maintainability_index: analysis_result.maintainability_metrics.index,
            technical_debt_ratio: analysis_result.maintainability_metrics.technical_debt_ratio,
            duplication_percentage: analysis_result
                .maintainability_metrics
                .duplication_percentage,
            halstead_volume: analysis_result.halstead_metrics.volume,
            halstead_difficulty: analysis_result.halstead_metrics.difficulty,
            halstead_effort: analysis_result.halstead_metrics.effort,
        };

        // Extract language-specific insights and enhance metrics
        self.enhance_metrics_with_language_data(&mut metrics, analysis_result);

        metrics
    }

    /// Enhance metrics with language-specific analysis data
    fn enhance_metrics_with_language_data(
        &self,
        metrics: &mut FileMetrics,
        analysis_result: &universal_parser::AnalysisResult,
    ) {
        // Language-specific enhancements would go here
        // For now, we'll keep it simple
        match analysis_result.language {
            universal_parser::ProgrammingLanguage::Rust => {
                // Rust-specific metrics enhancement
                if metrics.cyclomatic_complexity > 10.0 {
                    metrics.technical_debt_ratio += 0.1;
                }
            }
            universal_parser::ProgrammingLanguage::Python => {
                // Python-specific metrics enhancement
                if metrics.lines_of_code > 1000 {
                    metrics.maintainability_index -= 5.0;
                }
            }
            _ => {
                // Default enhancement
            }
        }
    }

    /// Store metrics for a file
    pub fn store_metrics(&mut self, file_path: String, metrics: FileMetrics) {
        self.metrics.insert(file_path, metrics);
    }

    /// Get metrics for a file
    pub fn get_metrics(&self, file_path: &str) -> Option<&FileMetrics> {
        self.metrics.get(file_path)
    }

    /// Get all metrics
    pub fn get_all_metrics(&self) -> &std::collections::HashMap<String, FileMetrics> {
        &self.metrics
    }

    /// Calculate aggregate metrics
    pub fn calculate_aggregate_metrics(&self) -> AggregateMetrics {
        let mut aggregate = AggregateMetrics::default();

        for metrics in self.metrics.values() {
            aggregate.total_lines_of_code += metrics.lines_of_code;
            aggregate.total_files += 1;
            aggregate.average_complexity += metrics.cyclomatic_complexity;
            aggregate.average_maintainability += metrics.maintainability_index;
            aggregate.total_technical_debt += metrics.technical_debt_ratio;
        }

        if aggregate.total_files > 0 {
            aggregate.average_complexity /= aggregate.total_files as f64;
            aggregate.average_maintainability /= aggregate.total_files as f64;
            aggregate.average_technical_debt = aggregate.total_technical_debt / aggregate.total_files as f64;
        }

        aggregate
    }
}

impl Default for MetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

/// Aggregate metrics across all files
#[derive(Debug, Clone, Default)]
pub struct AggregateMetrics {
    pub total_files: u64,
    pub total_lines_of_code: u64,
    pub average_complexity: f64,
    pub average_maintainability: f64,
    pub average_technical_debt: f64,
}
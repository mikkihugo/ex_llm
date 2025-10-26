//! Quality Engine - Main Module
//!
//! Orchestrates all quality analysis functionality using modular components.
//! Pure analysis - no I/O operations.

use serde::{Deserialize, Serialize};

// Import modular components
use crate::linting_engine::{LintingEngine, LintingEngineConfig, QualityRule, RuleSeverity, RuleCategory, QualityThresholds, QualityIssue};
use crate::quality_gates::{QualityGates, QualityGateResult, QualityGateStatus, QualityMetrics};

/// Main quality engine
pub struct QualityEngine {
    /// Linting engine
    pub linting_engine: LintingEngine,
    /// Quality gates
    pub quality_gates: QualityGates,
}

impl QualityEngine {
    /// Create a new quality engine
    pub fn new(config: LintingEngineConfig) -> Self {
        let quality_gates = QualityGates::new(config.thresholds.clone());
        Self {
            linting_engine: LintingEngine::new(config),
            quality_gates,
        }
    }

    /// Analyze code quality
    pub fn analyze_code(&self, code: &str, language: &str) -> QualityAnalysisResult {
        let linting_issues = self.linting_engine.analyze_code(code, language);
        let metrics = self.calculate_metrics(code, language);
        let gate_results = self.quality_gates.evaluate_all_gates(&metrics);

        QualityAnalysisResult {
            linting_issues,
            gate_results,
            metrics,
            overall_score: self.calculate_overall_score(&gate_results),
        }
    }

    /// Calculate code metrics
    fn calculate_metrics(&self, code: &str, language: &str) -> QualityMetrics {
        // Basic metrics calculation
        let lines: Vec<&str> = code.lines().collect();
        let max_line_length = lines.iter().map(|line| line.len()).max().unwrap_or(0);
        
        QualityMetrics {
            complexity: self.calculate_complexity(code),
            max_line_length,
            test_coverage: self.calculate_test_coverage(code),
            duplication: self.calculate_duplication(code),
        }
    }

    fn calculate_complexity(&self, code: &str) -> f64 {
        // Basic complexity calculation
        let mut complexity = 1.0;
        for line in code.lines() {
            if line.contains("if ") || line.contains("while ") || line.contains("for ") {
                complexity += 1.0;
            }
        }
        complexity
    }

    fn calculate_test_coverage(&self, code: &str) -> f64 {
        // Basic test coverage calculation
        let total_lines = code.lines().count() as f64;
        let test_lines = code.lines().filter(|line| line.contains("test") || line.contains("Test")).count() as f64;
        if total_lines > 0.0 {
            (test_lines / total_lines) * 100.0
        } else {
            0.0
        }
    }

    fn calculate_duplication(&self, code: &str) -> f64 {
        // Basic duplication calculation
        let lines: Vec<&str> = code.lines().collect();
        let mut duplicates = 0;
        for i in 0..lines.len() {
            for j in (i + 1)..lines.len() {
                if lines[i] == lines[j] && !lines[i].trim().is_empty() {
                    duplicates += 1;
                }
            }
        }
        if lines.len() > 0 {
            (duplicates as f64 / lines.len() as f64) * 100.0
        } else {
            0.0
        }
    }

    fn calculate_overall_score(&self, gate_results: &[QualityGateResult]) -> f64 {
        let passed_gates = gate_results.iter().filter(|gate| gate.status == QualityGateStatus::Passed).count();
        if gate_results.is_empty() {
            100.0
        } else {
            (passed_gates as f64 / gate_results.len() as f64) * 100.0
        }
    }
}

impl Default for QualityEngine {
    fn default() -> Self {
        Self::new(LintingEngineConfig::default())
    }
}

/// Quality analysis result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityAnalysisResult {
    pub linting_issues: Vec<QualityIssue>,
    pub gate_results: Vec<QualityGateResult>,
    pub metrics: QualityMetrics,
    pub overall_score: f64,
}
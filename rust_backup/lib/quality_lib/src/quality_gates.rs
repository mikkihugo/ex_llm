//! Quality Gates Module
//! 
//! Handles quality gate evaluation and enforcement.
//! Pure analysis - no I/O operations.

use serde::{Deserialize, Serialize};

/// Quality gate result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityGateResult {
    pub gate_name: String,
    pub status: QualityGateStatus,
    pub threshold: f64,
    pub actual_value: f64,
    pub message: String,
    pub details: Vec<String>,
}

/// Quality gate status
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum QualityGateStatus {
    Passed,
    Failed,
    Warning,
    Skipped,
}

/// Quality gates evaluator
pub struct QualityGates {
    pub thresholds: QualityThresholds,
}

impl QualityGates {
    /// Create a new quality gates evaluator
    pub fn new(thresholds: QualityThresholds) -> Self {
        Self { thresholds }
    }

    /// Evaluate complexity gate
    pub fn evaluate_complexity_gate(&self, complexity: f64) -> QualityGateResult {
        let status = if complexity <= self.thresholds.max_complexity {
            QualityGateStatus::Passed
        } else {
            QualityGateStatus::Failed
        };

        QualityGateResult {
            gate_name: "Cyclomatic Complexity".to_string(),
            status,
            threshold: self.thresholds.max_complexity,
            actual_value: complexity,
            message: if status == QualityGateStatus::Passed {
                "Complexity is within acceptable limits".to_string()
            } else {
                "Complexity exceeds threshold".to_string()
            },
            details: vec![],
        }
    }

    /// Evaluate line length gate
    pub fn evaluate_line_length_gate(&self, max_line_length: usize) -> QualityGateResult {
        let status = if max_line_length <= self.thresholds.max_line_length {
            QualityGateStatus::Passed
        } else {
            QualityGateStatus::Failed
        };

        QualityGateResult {
            gate_name: "Line Length".to_string(),
            status,
            threshold: self.thresholds.max_line_length as f64,
            actual_value: max_line_length as f64,
            message: if status == QualityGateStatus::Passed {
                "Line length is within acceptable limits".to_string()
            } else {
                "Line length exceeds threshold".to_string()
            },
            details: vec![],
        }
    }

    /// Evaluate test coverage gate
    pub fn evaluate_coverage_gate(&self, coverage: f64) -> QualityGateResult {
        let status = if coverage >= self.thresholds.min_test_coverage {
            QualityGateStatus::Passed
        } else {
            QualityGateStatus::Failed
        };

        QualityGateResult {
            gate_name: "Test Coverage".to_string(),
            status,
            threshold: self.thresholds.min_test_coverage,
            actual_value: coverage,
            message: if status == QualityGateStatus::Passed {
                "Test coverage meets requirements".to_string()
            } else {
                "Test coverage is below threshold".to_string()
            },
            details: vec![],
        }
    }

    /// Evaluate duplication gate
    pub fn evaluate_duplication_gate(&self, duplication: f64) -> QualityGateResult {
        let status = if duplication <= self.thresholds.max_duplication {
            QualityGateStatus::Passed
        } else {
            QualityGateStatus::Failed
        };

        QualityGateResult {
            gate_name: "Code Duplication".to_string(),
            status,
            threshold: self.thresholds.max_duplication,
            actual_value: duplication,
            message: if status == QualityGateStatus::Passed {
                "Duplication is within acceptable limits".to_string()
            } else {
                "Duplication exceeds threshold".to_string()
            },
            details: vec![],
        }
    }

    /// Evaluate all gates
    pub fn evaluate_all_gates(&self, metrics: &QualityMetrics) -> Vec<QualityGateResult> {
        vec![
            self.evaluate_complexity_gate(metrics.complexity),
            self.evaluate_line_length_gate(metrics.max_line_length),
            self.evaluate_coverage_gate(metrics.test_coverage),
            self.evaluate_duplication_gate(metrics.duplication),
        ]
    }
}

/// Quality metrics for evaluation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityMetrics {
    pub complexity: f64,
    pub max_line_length: usize,
    pub test_coverage: f64,
    pub duplication: f64,
}

/// Quality thresholds
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityThresholds {
    pub max_complexity: f64,
    pub max_line_length: usize,
    pub min_test_coverage: f64,
    pub max_duplication: f64,
}

impl Default for QualityThresholds {
    fn default() -> Self {
        Self {
            max_complexity: 10.0,
            max_line_length: 120,
            min_test_coverage: 80.0,
            max_duplication: 5.0,
        }
    }
}
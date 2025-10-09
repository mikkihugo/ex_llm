//! Unified Score System for SPARC Engine
//!
//! Consolidates all score types into a single, consistent system.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use sparc_methodology::{PhaseExecutionStatus, SPARCProject};

/// Unified score types for all SPARC metrics
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Score {
  /// Quality score (0.0 - 1.0)
  Quality(f64),
  /// Performance score (0.0 - 1.0)
  Performance(f64),
  /// Health score (0.0 - 1.0)
  Health(f64),
  /// Success rate (0.0 - 1.0)
  Success(f64),
  /// Optimization score (0.0 - 1.0)
  Optimization(f64),
}

impl Score {
  /// Get the numeric value of the score
  pub fn value(&self) -> f64 {
    match self {
      Score::Quality(v) => *v,
      Score::Performance(v) => *v,
      Score::Health(v) => *v,
      Score::Success(v) => *v,
      Score::Optimization(v) => *v,
    }
  }

  /// Get the score type name
  pub fn type_name(&self) -> &'static str {
    match self {
      Score::Quality(_) => "quality",
      Score::Performance(_) => "performance",
      Score::Health(_) => "health",
      Score::Success(_) => "success",
      Score::Optimization(_) => "optimization",
    }
  }

  /// Check if score is above threshold
  pub fn is_above_threshold(&self, threshold: f64) -> bool {
    self.value() >= threshold
  }

  /// Get score as percentage
  pub fn as_percentage(&self) -> f64 {
    self.value() * 100.0
  }
}

/// Unified thresholds for all SPARC metrics (scores, alerts, etc.)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnifiedThresholds {
  // Score thresholds
  pub quality_warning: f64,
  pub quality_critical: f64,
  pub performance_warning: f64,
  pub performance_critical: f64,
  pub health_warning: f64,
  pub health_critical: f64,
  pub success_warning: f64,
  pub success_critical: f64,
  pub optimization_warning: f64,
  pub optimization_critical: f64,

  // Alert thresholds
  pub phase_timeout_warning_hours: u32,
  pub phase_timeout_critical_hours: u32,
  pub agent_error_rate_warning: f64,
  pub agent_error_rate_critical: f64,
  pub resource_utilization_warning: f64,
  pub resource_utilization_critical: f64,
}

impl Default for UnifiedThresholds {
  fn default() -> Self {
    Self {
      // Score thresholds
      quality_warning: 0.7,
      quality_critical: 0.5,
      performance_warning: 0.6,
      performance_critical: 0.4,
      health_warning: 0.8,
      health_critical: 0.6,
      success_warning: 0.9,
      success_critical: 0.7,
      optimization_warning: 0.75,
      optimization_critical: 0.6,

      // Alert thresholds
      phase_timeout_warning_hours: 2,
      phase_timeout_critical_hours: 4,
      agent_error_rate_warning: 0.1,
      agent_error_rate_critical: 0.2,
      resource_utilization_warning: 0.8,
      resource_utilization_critical: 0.95,
    }
  }
}

/// Unified score calculator for all SPARC metrics
pub struct ScoreCalculator {
  thresholds: UnifiedThresholds,
}

impl ScoreCalculator {
  pub fn new() -> Self {
    Self { thresholds: UnifiedThresholds::default() }
  }

  pub fn with_thresholds(thresholds: UnifiedThresholds) -> Self {
    Self { thresholds }
  }

  /// Calculate quality score from project data
  pub fn calculate_quality_score(&self, project: &SPARCProject) -> Score {
    // Use real project data to calculate quality
    let phase_count = project.phase_analysis.len() as f64;
    if phase_count == 0.0 {
      return Score::Quality(0.5); // Default for new projects
    }

    let mut total_score = 0.0;
    let mut completed_phases = 0;

    for (phase, analysis) in &project.phase_analysis {
      if let Some(status) = project.phase_status.get(phase) {
        match status {
          PhaseExecutionStatus::Completed => {
            total_score += 1.0;
            completed_phases += 1;
          }
          PhaseExecutionStatus::InProgress => {
            total_score += 0.7;
            completed_phases += 1;
          }
          PhaseExecutionStatus::Overdue => {
            total_score += 0.3;
            completed_phases += 1;
          }
          _ => {}
        }
      }
    }

    let quality_score = if completed_phases == 0 { 0.5 } else { (total_score / completed_phases as f64).min(1.0) };

    Score::Quality(quality_score)
  }

  /// Calculate performance score from execution times
  pub fn calculate_performance_score(&self, total_execution_time_ms: u64) -> Score {
    // Convert execution time to performance score (lower time = higher score)
    let max_expected_time = 3600000; // 1 hour in milliseconds
    let performance_score = if total_execution_time_ms > max_expected_time {
      0.3 // Poor performance
    } else {
      1.0 - (total_execution_time_ms as f64 / max_expected_time as f64) * 0.7
    };

    Score::Performance(performance_score.max(0.0).min(1.0))
  }

  /// Calculate health score from agent metrics
  pub fn calculate_health_score(&self, success_rate: f64) -> Score {
    Score::Health(success_rate)
  }

  /// Calculate success rate from agent performance
  pub fn calculate_success_rate(&self, total_calls: u32, successful_calls: u32) -> Score {
    let success_rate = if total_calls == 0 {
      0.5 // Default for no calls
    } else {
      successful_calls as f64 / total_calls as f64
    };

    Score::Success(success_rate)
  }

  /// Calculate optimization score from project efficiency
  pub fn calculate_optimization_score(&self, project: &SPARCProject) -> Score {
    // Use the same logic as quality score for now
    self.calculate_quality_score(project)
  }

  /// Get all thresholds as a HashMap for easy lookup
  pub fn get_all_thresholds(&self) -> HashMap<String, f64> {
    let mut thresholds = HashMap::new();
    thresholds.insert("quality_warning".to_string(), self.thresholds.quality_warning);
    thresholds.insert("quality_critical".to_string(), self.thresholds.quality_critical);
    thresholds.insert("performance_warning".to_string(), self.thresholds.performance_warning);
    thresholds.insert("performance_critical".to_string(), self.thresholds.performance_critical);
    thresholds.insert("health_warning".to_string(), self.thresholds.health_warning);
    thresholds.insert("health_critical".to_string(), self.thresholds.health_critical);
    thresholds.insert("success_warning".to_string(), self.thresholds.success_warning);
    thresholds.insert("success_critical".to_string(), self.thresholds.success_critical);
    thresholds.insert("optimization_warning".to_string(), self.thresholds.optimization_warning);
    thresholds.insert("optimization_critical".to_string(), self.thresholds.optimization_critical);
    thresholds
  }

  /// Get threshold for a score type
  pub fn get_threshold(&self, score_type: &str, level: &str) -> f64 {
    match (score_type, level) {
      ("quality", "warning") => self.thresholds.quality_warning,
      ("quality", "critical") => self.thresholds.quality_critical,
      ("performance", "warning") => self.thresholds.performance_warning,
      ("performance", "critical") => self.thresholds.performance_critical,
      ("health", "warning") => self.thresholds.health_warning,
      ("health", "critical") => self.thresholds.health_critical,
      ("success", "warning") => self.thresholds.success_warning,
      ("success", "critical") => self.thresholds.success_critical,
      ("optimization", "warning") => self.thresholds.optimization_warning,
      ("optimization", "critical") => self.thresholds.optimization_critical,
      _ => 0.5, // Default threshold
    }
  }
}

impl Default for ScoreCalculator {
  fn default() -> Self {
    Self::new()
  }
}

// Type aliases for backward compatibility
pub type ScoreThresholds = UnifiedThresholds;
pub type AlertThresholds = UnifiedThresholds;

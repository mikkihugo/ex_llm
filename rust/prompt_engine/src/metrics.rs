//! Prompt metrics module
//!
//! Performance metrics and tracking for prompt optimization.

// use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Prompt metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptMetrics {
  pub total_prompts: u32,
  pub avg_optimization_time: u64,
  pub success_rate: f64,
}

/// Optimization metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationMetrics {
  pub optimizations_performed: u32,
  pub avg_improvement: f64,
  pub best_improvement: f64,
}

/// Performance tracker
pub struct PerformanceTracker {
  metrics: PromptMetrics,
  #[allow(dead_code)]
  optimization_metrics: OptimizationMetrics,
}

impl Default for PerformanceTracker {
  fn default() -> Self {
    Self::new()
  }
}

impl PerformanceTracker {
  pub fn new() -> Self {
    Self {
      metrics: PromptMetrics { total_prompts: 0, avg_optimization_time: 0, success_rate: 0.0 },
      optimization_metrics: OptimizationMetrics { optimizations_performed: 0, avg_improvement: 0.0, best_improvement: 0.0 },
    }
  }

  pub fn record_processing(&mut self, time_ms: u64) {
    self.metrics.total_prompts += 1;
    if self.metrics.total_prompts == 1 {
      self.metrics.avg_optimization_time = time_ms;
    } else {
      self.metrics.avg_optimization_time = (self.metrics.avg_optimization_time + time_ms) / 2;
    }
    self.metrics.success_rate = 1.0; // Assume success for now
  }

  pub fn get_metrics(&self) -> PromptMetrics {
    self.metrics.clone()
  }
}

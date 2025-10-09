//! Analysis Monitoring Service
//!
//! Generic monitoring service for codebase analysis (renamed from SPARC-specific)
//! Provides observability capabilities without SPARC-specific naming.

use std::{collections::HashMap, sync::Arc};

use serde::{Deserialize, Serialize};
use serde_json::Value;
use sparc_methodology::SPARCProject;
use tokio::sync::RwLock;
use uuid::Uuid;

/// Analysis monitor with metrics tracking
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisMonitor {
  pub metrics: HashMap<Uuid, AnalysisMetrics>,
  pub health_statuses: HashMap<Uuid, AnalysisHealthStatus>,
}

impl AnalysisMonitor {
  pub fn new() -> Self {
    Self { metrics: HashMap::new(), health_statuses: HashMap::new() }
  }

  pub fn update_metrics(&mut self, project: &SPARCProject) {
    let project_uuid = Uuid::parse_str(&project.id).unwrap_or_else(|_| Uuid::new_v4());
    let metrics = AnalysisMetrics {
      project_name: project.name.clone(),
      completion_percentage: 0.0, // Calculate based on project state
      quality_score: 0.0,
      performance_score: 0.0,
    };
    self.metrics.insert(project_uuid, metrics);
  }

  pub fn check_health(&mut self, project: &SPARCProject) -> AnalysisHealthStatus {
    let project_uuid = Uuid::parse_str(&project.id).unwrap_or_else(|_| Uuid::new_v4());
    let status = AnalysisHealthStatus { overall_health: crate::types::HealthLevel::Healthy, issues: Vec::new() };
    self.health_statuses.insert(project_uuid, status.clone());
    status
  }

  pub fn get_metrics(&self, project_id: Uuid) -> Option<&AnalysisMetrics> {
    self.metrics.get(&project_id)
  }

  pub fn get_health_status(&self, project_id: Uuid) -> Option<&AnalysisHealthStatus> {
    self.health_statuses.get(&project_id)
  }

  pub fn get_all_metrics(&self) -> &HashMap<Uuid, AnalysisMetrics> {
    &self.metrics
  }

  pub fn get_all_health_statuses(&self) -> &HashMap<Uuid, AnalysisHealthStatus> {
    &self.health_statuses
  }
}

/// Analysis metrics for a project
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisMetrics {
  pub project_name: String,
  pub completion_percentage: f64,
  pub quality_score: f64,
  pub performance_score: f64,
}

impl Default for AnalysisMetrics {
  fn default() -> Self {
    Self { project_name: String::new(), completion_percentage: 0.0, quality_score: 0.0, performance_score: 0.0 }
  }
}

/// Health status for analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AnalysisHealthStatus {
  pub overall_health: crate::types::HealthLevel,
  pub issues: Vec<crate::types::HealthIssue>,
}

/// Analysis monitoring async wrapper
pub struct AnalysisMonitorAsync {
  monitor: Arc<RwLock<AnalysisMonitor>>,
}

// Keep old SPARC name as alias for external compatibility
pub type SparcMonitoringService = AnalysisMonitorAsync;

impl AnalysisMonitorAsync {
  /// Create a new monitoring engine
  pub fn new() -> Self {
    Self { monitor: Arc::new(RwLock::new(AnalysisMonitor::new())) }
  }

  /// Update project metrics
  pub async fn update_project_metrics(&self, project: &SPARCProject) {
    let mut monitor = self.monitor.write().await;
    monitor.update_metrics(project);
  }

  /// Check project health
  pub async fn check_project_health(&self, project: &SPARCProject) -> AnalysisHealthStatus {
    let mut monitor = self.monitor.write().await;
    monitor.check_health(project)
  }

  /// Get project metrics
  pub async fn get_project_metrics(&self, project_id: uuid::Uuid) -> Option<AnalysisMetrics> {
    let monitor = self.monitor.read().await;
    monitor.get_metrics(project_id).cloned()
  }

  /// Get project health status
  pub async fn get_project_health(&self, project_id: uuid::Uuid) -> Option<AnalysisHealthStatus> {
    let monitor = self.monitor.read().await;
    monitor.get_health_status(project_id).cloned()
  }

  /// Get all project metrics
  pub async fn get_all_metrics(&self) -> Vec<AnalysisMetrics> {
    let monitor = self.monitor.read().await;
    monitor.get_all_metrics().values().cloned().collect()
  }

  /// Get all health statuses
  pub async fn get_all_health_statuses(&self) -> Vec<AnalysisHealthStatus> {
    let monitor = self.monitor.read().await;
    monitor.get_all_health_statuses().values().cloned().collect()
  }

  /// Generate monitoring report
  pub async fn generate_report(&self) -> MonitoringReport {
    let metrics = self.get_all_metrics().await;
    let health_statuses = self.get_all_health_statuses().await;

    let total_projects = metrics.len();
    let healthy_projects = health_statuses.iter().filter(|h| h.overall_health == crate::types::HealthLevel::Healthy).count();
    let warning_projects = health_statuses.iter().filter(|h| h.overall_health == crate::types::HealthLevel::Warning).count();
    let critical_projects = health_statuses.iter().filter(|h| h.overall_health == crate::types::HealthLevel::Critical).count();

    let total_issues = health_statuses.iter().map(|h| h.issues.len()).sum::<usize>();

    MonitoringReport { total_projects, healthy_projects, warning_projects, critical_projects, total_issues, generated_at: chrono::Utc::now() }
  }

  /// Emit monitoring events to EventBus
  pub async fn emit_monitoring_events(&self, project: &SPARCProject) {
    // This would integrate with the EventBus to emit monitoring events
    // For now, we'll just log the events

    let project_uuid = Uuid::parse_str(&project.id).unwrap_or_else(|_| Uuid::new_v4());
    let metrics = self.get_project_metrics(project_uuid).await;
    if let Some(metrics) = metrics {
      tracing::info!("SPARC Project Metrics: {} - Phase: {:?} - Completion: {}%", metrics.project_name, project.current_phase, metrics.completion_percentage);
    }

    let health = self.check_project_health(project).await;
    if health.overall_health != crate::types::HealthLevel::Healthy {
      tracing::warn!("SPARC Project Health Issue: {} - Status: {:?} - Issues: {}", project.name, health.overall_health, health.issues.len());
    }
  }
}

/// Monitoring report
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct MonitoringReport {
  pub total_projects: usize,
  pub healthy_projects: usize,
  pub warning_projects: usize,
  pub critical_projects: usize,
  pub total_issues: usize,
  pub generated_at: chrono::DateTime<chrono::Utc>,
}

impl AnalysisMonitorAsync {
  /// Export metrics as JSON for external consumption
  pub async fn export_metrics_json(&self) -> Result<Value, serde_json::Error> {
    use crate::types::HealthLevel;
    let monitor = self.monitor.read().await;
    let report = MonitoringReport {
      total_projects: monitor.metrics.len(),
      healthy_projects: monitor.health_statuses.values().filter(|s| matches!(s.overall_health, HealthLevel::Healthy)).count(),
      warning_projects: monitor.health_statuses.values().filter(|s| matches!(s.overall_health, HealthLevel::Warning)).count(),
      critical_projects: monitor.health_statuses.values().filter(|s| matches!(s.overall_health, HealthLevel::Critical)).count(),
      total_issues: monitor.health_statuses.values().map(|h| h.issues.len()).sum(),
      generated_at: chrono::Utc::now(),
    };
    serde_json::to_value(report)
  }
}

impl Default for AnalysisMonitorAsync {
  fn default() -> Self {
    Self::new()
  }
}

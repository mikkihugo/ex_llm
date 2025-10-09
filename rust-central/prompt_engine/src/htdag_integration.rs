//! HTDAG Integration for Prompt Engine
//!
//! Connects to Elixir's HTDAG to track template performance over time.
//! Karolinska approach - track what works, learn, improve!

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

/// HTDAG connection for template performance tracking
pub struct HTDAGConnector {
    /// NATS client for communication with Elixir HTDAG
    nats_client: Option<async_nats::Client>,

    /// Local cache of performance metrics
    performance_cache: Arc<RwLock<PerformanceCache>>,
}

/// Performance data tracked by HTDAG
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplatePerformance {
    pub template_id: String,
    pub task_type: String,
    pub success_rate: f64,
    pub quality_score: f64,
    pub generation_time_ms: u64,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// Local cache of HTDAG performance data
#[derive(Debug, Default)]
struct PerformanceCache {
    /// Best templates per task type
    best_templates: std::collections::HashMap<String, String>,

    /// Recent performance metrics
    recent_metrics: Vec<TemplatePerformance>,
}

impl HTDAGConnector {
    /// Create new HTDAG connector
    pub async fn new() -> Result<Self> {
        // Try to connect to NATS if available
        let nats_client = match std::env::var("NATS_URL") {
            Ok(url) => {
                match async_nats::connect(&url).await {
                    Ok(client) => {
                        log::info!("Connected to NATS for HTDAG integration");
                        Some(client)
                    }
                    Err(e) => {
                        log::warn!("NATS not available, using local cache: {}", e);
                        None
                    }
                }
            }
            Err(_) => {
                log::info!("NATS_URL not set, using local HTDAG cache");
                None
            }
        };

        Ok(Self {
            nats_client,
            performance_cache: Arc::new(RwLock::new(PerformanceCache::default())),
        })
    }

    /// Record template usage to HTDAG
    pub async fn record_usage(
        &self,
        template_id: String,
        task_type: String,
        success: bool,
        quality_score: f64,
        generation_time_ms: u64,
    ) -> Result<()> {
        let performance = TemplatePerformance {
            template_id: template_id.clone(),
            task_type: task_type.clone(),
            success_rate: if success { 1.0 } else { 0.0 },
            quality_score,
            generation_time_ms,
            timestamp: chrono::Utc::now(),
        };

        // Send to Elixir HTDAG via NATS
        if let Some(client) = &self.nats_client {
            let subject = "htdag.template.performance";
            let payload = serde_json::to_vec(&performance)?;

            if let Err(e) = client.publish(subject, payload.into()).await {
                log::warn!("Failed to send to HTDAG: {}", e);
            }
        }

        // Update local cache
        let mut cache = self.performance_cache.write().await;
        cache.recent_metrics.push(performance.clone());

        // Keep only last 1000 metrics
        if cache.recent_metrics.len() > 1000 {
            cache.recent_metrics.remove(0);
        }

        // Update best template if this one is better
        let key = task_type.clone();
        let current_best = cache.best_templates.get(&key);

        if success && quality_score > 0.8 {
            if current_best.is_none() || current_best == Some(&template_id) {
                cache.best_templates.insert(key, template_id);
            }
        }

        Ok(())
    }

    /// Get best template for task type from HTDAG
    pub async fn get_best_template(&self, task_type: &str) -> Result<Option<String>> {
        // Try to get from Elixir HTDAG first
        if let Some(client) = &self.nats_client {
            let subject = format!("htdag.template.best.{}", task_type);

            match client.request(subject, "".into()).await {
                Ok(msg) => {
                    if let Ok(template_id) = String::from_utf8(msg.payload.to_vec()) {
                        if !template_id.is_empty() {
                            return Ok(Some(template_id));
                        }
                    }
                }
                Err(e) => {
                    log::debug!("HTDAG query failed, using cache: {}", e);
                }
            }
        }

        // Fall back to local cache
        let cache = self.performance_cache.read().await;
        Ok(cache.best_templates.get(task_type).cloned())
    }

    /// Get performance history from HTDAG
    pub async fn get_performance_history(
        &self,
        template_id: &str,
    ) -> Result<Vec<TemplatePerformance>> {
        let cache = self.performance_cache.read().await;

        let history: Vec<_> = cache
            .recent_metrics
            .iter()
            .filter(|m| m.template_id == template_id)
            .cloned()
            .collect();

        Ok(history)
    }

    /// Sync with Elixir HTDAG
    pub async fn sync_with_elixir(&self) -> Result<()> {
        if let Some(client) = &self.nats_client {
            // Request full sync from Elixir
            let response = client
                .request("htdag.sync.templates", "".into())
                .await?;

            if let Ok(data) = serde_json::from_slice::<HTDAGSyncData>(&response.payload) {
                let mut cache = self.performance_cache.write().await;
                cache.best_templates = data.best_templates;
                log::info!("Synced {} templates from HTDAG", cache.best_templates.len());
            }
        }

        Ok(())
    }
}

/// HTDAG sync data from Elixir
#[derive(Debug, Serialize, Deserialize)]
struct HTDAGSyncData {
    best_templates: std::collections::HashMap<String, String>,
    performance_summary: Vec<TemplateSummary>,
}

/// Template performance summary
#[derive(Debug, Serialize, Deserialize)]
struct TemplateSummary {
    template_id: String,
    total_uses: u64,
    avg_quality: f64,
    avg_time_ms: u64,
}

/// Karolinska-style learning from HTDAG
pub struct KarolinskaLearner {
    htdag: HTDAGConnector,
}

impl KarolinskaLearner {
    pub fn new(htdag: HTDAGConnector) -> Self {
        Self { htdag }
    }

    /// Learn which templates work best over time
    pub async fn learn_optimal_templates(&self) -> Result<LearningInsights> {
        // Get performance history
        let cache = self.htdag.performance_cache.read().await;

        // Analyze patterns
        let mut insights = LearningInsights::default();

        for metric in &cache.recent_metrics {
            // Track success patterns
            if metric.success_rate > 0.9 && metric.quality_score > 0.85 {
                insights.successful_patterns.push(PatternInsight {
                    template: metric.template_id.clone(),
                    task_type: metric.task_type.clone(),
                    confidence: metric.quality_score,
                });
            }

            // Track failures to avoid
            if metric.success_rate < 0.5 || metric.quality_score < 0.5 {
                insights.failure_patterns.push(PatternInsight {
                    template: metric.template_id.clone(),
                    task_type: metric.task_type.clone(),
                    confidence: 1.0 - metric.quality_score,
                });
            }
        }

        // Deduplicate and sort by confidence
        insights.successful_patterns.sort_by(|a, b|
            b.confidence.partial_cmp(&a.confidence).unwrap()
        );
        insights.successful_patterns.dedup_by(|a, b|
            a.template == b.template && a.task_type == b.task_type
        );

        Ok(insights)
    }
}

/// Learning insights from HTDAG analysis
#[derive(Debug, Default)]
pub struct LearningInsights {
    pub successful_patterns: Vec<PatternInsight>,
    pub failure_patterns: Vec<PatternInsight>,
}

/// Pattern insight from HTDAG
#[derive(Debug, Clone)]
pub struct PatternInsight {
    pub template: String,
    pub task_type: String,
    pub confidence: f64,
}
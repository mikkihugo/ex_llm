//! Execution tracking for continuous learning

use std::{collections::HashMap, time::Duration};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::prompt_tracking::{
    PromptExecutionData, PromptExecutionEntry, PromptTrackingQuery, PromptTrackingStorage,
};

/// Execution result for tracking
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionResult {
    pub prompt_id: String,
    pub context: ExecutionContext,
    pub duration: Duration,
    pub success_score: f64,
    pub user_changes: Vec<String>,
    pub confidence: f64,
    pub error_messages: Vec<String>,
}

/// Execution context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionContext {
    pub task_description: String,
    pub repository_path: String,
    pub project_tech_stack: Vec<String>,
    pub environment_vars: HashMap<String, String>,
}

/// Metrics collector for performance tracking
pub struct MetricsCollector {
    metrics: HashMap<String, Vec<f64>>,
}

impl Default for MetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

impl MetricsCollector {
    pub fn new() -> Self {
        Self {
            metrics: HashMap::new(),
        }
    }

    pub fn record(&mut self, metric: &str, value: f64) {
        self.metrics
            .entry(metric.to_string())
            .or_default()
            .push(value);
    }

    pub fn average(&self, metric: &str) -> Option<f64> {
        self.metrics.get(metric).map(|values| {
            if values.is_empty() {
                0.0
            } else {
                values.iter().sum::<f64>() / values.len() as f64
            }
        })
    }
}

/// Execution tracker for learning system
pub struct ExecutionTracker {
    fact_store: PromptTrackingStorage,
    metrics_collector: MetricsCollector,
}

impl ExecutionTracker {
    pub fn new(fact_store: PromptTrackingStorage) -> Self {
        Self {
            fact_store,
            metrics_collector: MetricsCollector::new(),
        }
    }

    /// Track an execution
    pub async fn track_execution(&mut self, execution: ExecutionResult) -> Result<String> {
        // Calculate context hash
        let context_hash = self.hash_context(&execution.context);

        // Create execution entry
        let fact = PromptExecutionEntry {
            prompt_id: execution.prompt_id.clone(),
            execution_time_ms: execution.duration.as_millis() as u64,
            success: execution.success_score > 0.5,
            confidence_score: execution.confidence,
            context_signature: context_hash,
            response_length: 0,
            timestamp: chrono::Utc::now(),
            metadata: HashMap::new(),
        };

        // Store execution data
        let fact_id = self
            .fact_store
            .store(PromptExecutionData::PromptExecution(fact))
            .await?;

        // Update metrics
        self.metrics_collector.record(
            &format!("execution_time_{}", execution.prompt_id),
            execution.duration.as_secs_f64(),
        );
        self.metrics_collector.record(
            &format!("success_rate_{}", execution.prompt_id),
            execution.success_score,
        );
        self.metrics_collector.record(
            &format!("confidence_{}", execution.prompt_id),
            execution.confidence,
        );

        // Update training examples if significant
        if execution.success_score > 0.9 || execution.success_score < 0.3 {
            self.update_training_examples(execution).await?;
        }

        Ok(fact_id)
    }

    /// Hash execution context for deduplication
    fn hash_context(&self, context: &ExecutionContext) -> String {
        use std::{
            collections::hash_map::DefaultHasher,
            hash::{Hash, Hasher},
        };

        let mut hasher = DefaultHasher::new();
        context.task_description.hash(&mut hasher);
        context.repository_path.hash(&mut hasher);
        context.project_tech_stack.hash(&mut hasher);

        format!("{:x}", hasher.finish())
    }

    /// Update training examples for DSPy optimization
    async fn update_training_examples(&self, execution: ExecutionResult) -> Result<()> {
        // Store high-quality and poor examples for future DSPy training
        // High-quality examples (>0.9) serve as positive training data
        // Poor examples (<0.3) help identify what to avoid

        let example_quality = if execution.success_score > 0.9 {
            "positive"
        } else if execution.success_score < 0.3 {
            "negative"
        } else {
            return Ok(()); // Skip medium-quality examples
        };

        // Create training example metadata
        let mut metadata = HashMap::new();
        metadata.insert("quality".to_string(), example_quality.to_string());
        metadata.insert(
            "success_score".to_string(),
            execution.success_score.to_string(),
        );
        metadata.insert("confidence".to_string(), execution.confidence.to_string());
        metadata.insert(
            "user_changes_count".to_string(),
            execution.user_changes.len().to_string(),
        );
        metadata.insert(
            "context_hash".to_string(),
            self.hash_context(&execution.context),
        );

        // Store as execution entry with training flag
        let training_fact = PromptExecutionEntry {
            prompt_id: format!("training_{}", execution.prompt_id),
            execution_time_ms: execution.duration.as_millis() as u64,
            success: execution.success_score > 0.5,
            confidence_score: execution.confidence,
            context_signature: self.hash_context(&execution.context),
            response_length: 0, // Not tracked for training examples
            timestamp: chrono::Utc::now(),
            metadata,
        };

        self.fact_store
            .store(PromptExecutionData::PromptExecution(training_fact))
            .await?;

        tracing::info!(
            "{} training example stored: {} (score: {:.2}, confidence: {:.2})",
            if execution.success_score > 0.9 {
                "Positive"
            } else {
                "Negative"
            },
            execution.prompt_id,
            execution.success_score,
            execution.confidence
        );

        Ok(())
    }

    /// Get performance summary for a prompt
    pub async fn get_performance_summary(&self, prompt_id: &str) -> Result<PerformanceSummary> {
        let executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(prompt_id.to_string()))
            .await?;

        let mut total_success = 0.0;
        let mut total_time = Duration::ZERO;
        let mut modification_count = 0;

        for fact in &executions {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                total_success += if exec.success { 1.0 } else { 0.0 };
                total_time += Duration::from_millis(exec.execution_time_ms);
                modification_count += exec.metadata.len(); // Use metadata length as proxy
            }
        }

        let count = executions.len() as f64;

        Ok(PerformanceSummary {
            prompt_id: prompt_id.to_string(),
            execution_count: executions.len(),
            average_success_rate: if count > 0.0 {
                total_success / count
            } else {
                0.0
            },
            average_execution_time: if executions.is_empty() {
                Duration::ZERO
            } else {
                total_time / executions.len() as u32
            },
            average_modifications: if executions.is_empty() {
                0.0
            } else {
                modification_count as f64 / count
            },
            confidence_trend: self.calculate_confidence_trend(&executions),
        })
    }

    /// Calculate confidence trend over time
    fn calculate_confidence_trend(&self, executions: &[PromptExecutionData]) -> ConfidenceTrend {
        if executions.is_empty() {
            return ConfidenceTrend::Stable;
        }

        // Sort by timestamp
        let mut sorted_execs: Vec<_> = executions
            .iter()
            .filter_map(|f| {
                if let PromptExecutionData::PromptExecution(exec) = f {
                    Some(exec)
                } else {
                    None
                }
            })
            .collect();

        sorted_execs.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));

        // Calculate trend
        if sorted_execs.len() < 2 {
            return ConfidenceTrend::Stable;
        }

        let recent_avg = sorted_execs[sorted_execs.len() / 2..]
            .iter()
            .map(|e| e.confidence_score)
            .sum::<f64>()
            / (sorted_execs.len() / 2) as f64;

        let older_avg = sorted_execs[..sorted_execs.len() / 2]
            .iter()
            .map(|e| e.confidence_score)
            .sum::<f64>()
            / (sorted_execs.len() / 2) as f64;

        if recent_avg > older_avg * 1.1 {
            ConfidenceTrend::Improving
        } else if recent_avg < older_avg * 0.9 {
            ConfidenceTrend::Degrading
        } else {
            ConfidenceTrend::Stable
        }
    }
}

/// Performance summary for a prompt
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceSummary {
    pub prompt_id: String,
    pub execution_count: usize,
    pub average_success_rate: f64,
    pub average_execution_time: Duration,
    pub average_modifications: f64,
    pub confidence_trend: ConfidenceTrend,
}

/// Confidence trend over time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConfidenceTrend {
    Improving,
    Stable,
    Degrading,
}

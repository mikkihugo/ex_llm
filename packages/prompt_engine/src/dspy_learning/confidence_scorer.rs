//! Confidence scoring and adjustment using neural ML and DSPy evaluation

use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::{
    dspy_learning::{ConfidencePredictor, ExecutionResult, PromptFeatures},
    prompt_tracking::{PromptTrackingQuery, PromptTrackingStorage, FeedbackType, PromptExecutionData, PromptFeedbackEntry},
};

/// Confidence adjustment result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfidenceAdjustment {
    pub prompt_id: String,
    pub old_confidence: f64,
    pub new_confidence: f64,
    pub adjustment_reason: String,
    /// ML-based confidence prediction (if available)
    pub ml_confidence: Option<f64>,
}

/// Confidence scorer using neural ML and DSPy evaluation
pub struct ConfidenceScorer {
    fact_store: PromptTrackingStorage,
    /// Neural network predictor for confidence (optional, requires ml-analysis feature)
    neural_predictor: Option<ConfidencePredictor>,
}

impl ConfidenceScorer {
    pub fn new(fact_store: PromptTrackingStorage) -> Self {
        // Initialize neural predictor if ml-analysis feature is enabled
        let neural_predictor = ConfidencePredictor::new().ok();

        Self {
            fact_store,
            neural_predictor,
        }
    }

    /// Calculate confidence adjustment based on execution (with optional neural ML)
    pub async fn calculate_adjustment(
        &self,
        execution: &ExecutionResult,
    ) -> Result<ConfidenceAdjustment> {
        // Get current confidence
        let old_confidence = self.get_current_confidence(&execution.prompt_id).await?;

        // Extract features for ML prediction
        let features = self
            .extract_features(&execution.prompt_id, execution)
            .await?;

        // Try neural prediction first
        let (new_confidence, ml_confidence) = if let Some(predictor) = &self.neural_predictor {
            match predictor.predict(&features) {
                Ok(ml_pred) => {
                    // Blend neural prediction with heuristic for robustness
                    let heuristic = self.calculate_heuristic_confidence(execution, old_confidence);
                    let blended = ml_pred * 0.7 + heuristic * 0.3; // 70% ML, 30% heuristic
                    (blended, Some(ml_pred))
                }
                Err(_) => {
                    // Fallback to heuristic if neural prediction fails
                    (
                        self.calculate_heuristic_confidence(execution, old_confidence),
                        None,
                    )
                }
            }
        } else {
            // No neural network available, use heuristic
            (
                self.calculate_heuristic_confidence(execution, old_confidence),
                None,
            )
        };

        // Clamp to valid range
        let new_confidence = new_confidence.clamp(0.1, 1.0);

        // Generate reason
        let reason = self.generate_adjustment_reason(
            old_confidence,
            new_confidence,
            execution,
            ml_confidence,
        );

        Ok(ConfidenceAdjustment {
            prompt_id: execution.prompt_id.clone(),
            old_confidence,
            new_confidence,
            adjustment_reason: reason,
            ml_confidence,
        })
    }

    /// Extract features from execution history for ML prediction
    async fn extract_features(
        &self,
        prompt_id: &str,
        current_execution: &ExecutionResult,
    ) -> Result<PromptFeatures> {
        // Get historical executions
        let executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(prompt_id.to_string()))
            .await?;

        let mut success_count = 0;
        let mut total_confidence = 0.0;
        let error_count = current_execution.error_messages.len();

        for fact in &executions {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                if exec.success {
                    success_count += 1;
                }
                total_confidence += exec.confidence_score;
            }
        }

        let execution_count = executions.len();
        let success_rate = if execution_count > 0 {
            success_count as f64 / execution_count as f64
        } else {
            current_execution.success_score
        };

        let avg_confidence = if execution_count > 0 {
            total_confidence / execution_count as f64
        } else {
            current_execution.confidence
        };

        Ok(PromptFeatures {
            success_rate,
            avg_confidence,
            execution_count,
            prompt_length: prompt_id.len(), // Simplified
            complexity_score: 0.5,          // Could be enhanced
            domain_match: 0.7,              // Could be enhanced
            recency_score: 1.0,             // Current execution
            user_feedback: 1.0 - (current_execution.user_changes.len() as f64 / 10.0).min(1.0),
            error_rate: if execution_count > 0 {
                error_count as f64 / execution_count as f64
            } else if current_execution.error_messages.is_empty() {
                0.0
            } else {
                1.0
            },
            improvement_trend: 0.0, // Could track trend over time
        })
    }

    /// Calculate heuristic confidence (original logic)
    fn calculate_heuristic_confidence(
        &self,
        execution: &ExecutionResult,
        old_confidence: f64,
    ) -> f64 {
        // Calculate adjustment factors
        let success_factor = execution.success_score;
        let modification_factor = 1.0 - (execution.user_changes.len() as f64 * 0.1).min(0.5);
        let error_factor = 1.0 - (execution.error_messages.len() as f64 * 0.2).min(0.8);

        // Weighted adjustment
        let raw_adjustment = success_factor * 0.5 + modification_factor * 0.3 + error_factor * 0.2;

        // Apply momentum (gradual changes)
        let momentum = 0.3;
        old_confidence * (1.0 - momentum) + raw_adjustment * momentum
    }

    /// Apply confidence adjustment
    pub async fn apply_adjustment(
        &self,
        prompt_id: &str,
        adjustment: ConfidenceAdjustment,
    ) -> Result<()> {
        // Store as feedback entry
        let feedback = PromptFeedbackEntry {
            prompt_id: prompt_id.to_string(),
            feedback_type: if adjustment.new_confidence > adjustment.old_confidence {
                FeedbackType::Quality
            } else {
                FeedbackType::Performance
            },
            rating: adjustment.new_confidence,
            comment: Some(adjustment.adjustment_reason.clone()),
            user_id: None,
            timestamp: chrono::Utc::now(),
            context: HashMap::new(),
        };

        self.fact_store
            .store(PromptExecutionData::PromptFeedback(feedback))
            .await?;

        tracing::info!(
            "Adjusted confidence for {}: {:.2} -> {:.2} ({})",
            prompt_id,
            adjustment.old_confidence,
            adjustment.new_confidence,
            adjustment.adjustment_reason
        );

        Ok(())
    }

    /// Get current confidence for a prompt
    async fn get_current_confidence(&self, prompt_id: &str) -> Result<f64> {
        // Query recent executions
        let executions = self
            .fact_store
            .query(PromptTrackingQuery::PromptExecutions(prompt_id.to_string()))
            .await?;

        if executions.is_empty() {
            return Ok(0.5); // Default confidence
        }

        // Calculate weighted average of recent confidences
        let mut total_confidence = 0.0;
        let mut total_weight = 0.0;

        for (i, fact) in executions.iter().rev().take(10).enumerate() {
            if let PromptExecutionData::PromptExecution(exec) = fact {
                // Recent executions have higher weight
                let weight = 1.0 / (i as f64 + 1.0);
                total_confidence += exec.confidence_score * weight;
                total_weight += weight;
            }
        }

        Ok(if total_weight > 0.0 {
            total_confidence / total_weight
        } else {
            0.5
        })
    }

    /// Generate human-readable reason for adjustment
    fn generate_adjustment_reason(
        &self,
        old: f64,
        new: f64,
        execution: &ExecutionResult,
        ml_confidence: Option<f64>,
    ) -> String {
        let mut reasons: Vec<String> = Vec::new();

        // Add ML prediction info if available
        if let Some(ml_conf) = ml_confidence {
            reasons.push(format!("Neural ML prediction: {:.2}", ml_conf));
        }

        if execution.success_score > 0.8 {
            reasons.push("High success rate".to_string());
        } else if execution.success_score < 0.3 {
            reasons.push("Low success rate".to_string());
        }

        if !execution.user_changes.is_empty() {
            reasons.push(format!(
                "{} user modifications",
                execution.user_changes.len()
            ));
        }

        if !execution.error_messages.is_empty() {
            reasons.push(format!(
                "{} errors encountered",
                execution.error_messages.len()
            ));
        }

        let method = if ml_confidence.is_some() {
            "ML-enhanced"
        } else {
            "Heuristic"
        };

        if new > old {
            format!("Confidence increased ({}): {}", method, reasons.join(", "))
        } else if new < old {
            format!("Confidence decreased ({}): {}", method, reasons.join(", "))
        } else {
            format!("Confidence unchanged ({})", method)
        }
    }

    /// Check if prompt needs reoptimization
    pub async fn needs_reoptimization(&self, prompt_id: &str) -> Result<bool> {
        let confidence = self.get_current_confidence(prompt_id).await?;

        // Get recent feedback
        let recent_feedback = self
            .fact_store
            .query(PromptTrackingQuery::RecentFeedback(
                std::time::Duration::from_secs(7 * 24 * 3600), // Last week
            ))
            .await?;

        let negative_feedback_count = recent_feedback
            .iter()
            .filter(|f| {
                if let PromptExecutionData::PromptFeedback(feedback) = f {
                    feedback.prompt_id == prompt_id
                        && matches!(feedback.feedback_type, FeedbackType::Performance)
                } else {
                    false
                }
            })
            .count();

        // Reoptimize if confidence is low or too much negative feedback
        Ok(confidence < 0.6 || negative_feedback_count > 5)
    }
}

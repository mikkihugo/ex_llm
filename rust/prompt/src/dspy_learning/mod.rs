//! DSPy Learning Integration with FACT storage
//!
//! This module integrates the existing DSPy optimizer with FACT storage
//! to create a continuous learning system for prompt optimization.

pub mod confidence_scorer;
pub mod execution_tracker;
pub mod learning_loop;
pub mod ml_trainer;
pub mod neural_ml;
pub mod prompt_selector;

use std::path::PathBuf;

use anyhow::Result;
pub use confidence_scorer::{ConfidenceAdjustment, ConfidenceScorer};
pub use execution_tracker::{ExecutionContext, ExecutionResult, ExecutionTracker};
pub use learning_loop::{ContinuousLearningLoop, LearningConfig};
pub use ml_trainer::MLTrainer;
pub use neural_ml::{ConfidencePredictor, PromptEmbedder, PromptFeatures, TrainingConfig, TrainingMetrics};
pub use prompt_selector::{PromptSelector, RepositoryContext, SelectedPrompt, Task};

use crate::{
  dspy::optimizer::{SparcOptimizer, COPRO},
  prompt_tracking::{FactStorage, PromptTrackingStorage},
};

/// Initialize the DSPy learning system with FACT storage and configuration
pub async fn initialize_learning_system(storage_path: impl AsRef<std::path::Path>, config: Option<LearningConfig>) -> Result<LearningSystem> {
  let storage_path = storage_path.as_ref();
  let fact_store = PromptTrackingStorage::new(storage_path)?;
  let config = config.unwrap_or_default();

  // Determine model save path (sibling to storage)
  let model_save_path = if let Some(parent) = storage_path.parent() {
    parent.join("ml_models").join("confidence_predictor.safetensors")
  } else {
    PathBuf::from("ml_models/confidence_predictor.safetensors")
  };

  // Ensure model directory exists
  if let Some(model_dir) = model_save_path.parent() {
    std::fs::create_dir_all(model_dir)?;
  }

  Ok(LearningSystem {
    fact_store: fact_store.clone(),
    prompt_selector: PromptSelector::new(fact_store.clone()),
    execution_tracker: ExecutionTracker::new(fact_store.clone()),
    confidence_scorer: ConfidenceScorer::new(fact_store.clone()),
    ml_trainer: MLTrainer::new(fact_store.clone(), model_save_path),
    copro_optimizer: COPRO {
      breadth: config.copro_breadth,
      depth: config.copro_depth,
      init_temperature: config.copro_temperature,
      track_stats: true, // Enable production monitoring
      prompt_model: None,
    },
    sparc_optimizer: SparcOptimizer::default(),
  })
}

/// Initialize with default configuration
pub async fn initialize_learning_system_default(storage_path: impl AsRef<std::path::Path>) -> Result<LearningSystem> {
  initialize_learning_system(storage_path, None).await
}

/// Complete learning system integrating DSPy with FACT
pub struct LearningSystem {
  pub fact_store: FactStorage,
  pub prompt_selector: PromptSelector,
  pub execution_tracker: ExecutionTracker,
  pub confidence_scorer: ConfidenceScorer,
  pub ml_trainer: MLTrainer,
  pub copro_optimizer: COPRO,
  pub sparc_optimizer: SparcOptimizer,
}

impl LearningSystem {
  /// Run a complete learning cycle
  pub async fn learning_cycle(&mut self, execution: ExecutionResult) -> Result<()> {
    // 1. Track execution in FACT storage
    let _fact_id = self.execution_tracker.track_execution(execution.clone()).await?;

    // 2. Adjust confidence scores
    let adjustment = self.confidence_scorer.calculate_adjustment(&execution).await?;

    self.confidence_scorer.apply_adjustment(&execution.prompt_id, adjustment.clone()).await?;

    // 3. Trigger reoptimization if needed
    if adjustment.new_confidence < 0.7 {
      self.trigger_reoptimization(&execution.prompt_id).await?;
    }

    Ok(())
  }

  /// Trigger DSPy reoptimization for a prompt
  async fn trigger_reoptimization(&self, prompt_id: &str) -> Result<()> {
    tracing::info!("Triggering DSPy reoptimization for prompt: {}", prompt_id);

    // 1. Get execution history for training data
    let executions = self.fact_store.query(crate::prompt_tracking::FactQuery::PromptExecutions(prompt_id.to_string())).await?;

    if executions.len() < 5 {
      tracing::warn!("Insufficient data for reoptimization: {} executions (minimum 5 required)", executions.len());
      return Ok(());
    }

    // 2. Calculate current performance metrics
    let mut success_count = 0;
    let mut total_confidence = 0.0;

    for fact in &executions {
      if let crate::prompt_tracking::PromptFactType::PromptExecution(exec) = fact {
        if exec.success {
          success_count += 1;
        }
        total_confidence += exec.confidence_score;
      }
    }

    let success_rate = success_count as f64 / executions.len() as f64;
    let avg_confidence = total_confidence / executions.len() as f64;

    tracing::info!("Current performance: {:.1}% success, {:.2} confidence across {} executions", success_rate * 100.0, avg_confidence, executions.len());

    // 3. Create optimization task using COPRO
    // The COPRO optimizer will analyze execution patterns and generate improved prompts
    let optimization_metadata = std::collections::HashMap::from([
      ("baseline_success".to_string(), format!("{:.2}", success_rate)),
      ("baseline_confidence".to_string(), format!("{:.2}", avg_confidence)),
      ("sample_size".to_string(), executions.len().to_string()),
      ("trigger".to_string(), "manual_reoptimization".to_string()),
    ]);

    // 4. Store optimization request for async processing
    let evolution_fact = crate::prompt_tracking::PromptEvolutionFact {
      original_prompt_id: prompt_id.to_string(),
      evolved_prompt_id: format!("{}_optimizing", prompt_id),
      evolution_type: crate::prompt_tracking::EvolutionType::Optimization,
      performance_improvement: 0.0, // Will be calculated after optimization
      evolution_timestamp: chrono::Utc::now(),
      evolution_metadata: optimization_metadata,
    };

    self.fact_store.store(crate::prompt_tracking::PromptFactType::PromptEvolution(evolution_fact)).await?;

    tracing::info!("Reoptimization queued for prompt: {}", prompt_id);

    Ok(())
  }
}

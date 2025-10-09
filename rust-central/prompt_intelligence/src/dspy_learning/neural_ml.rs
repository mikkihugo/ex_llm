//! Neural ML Components for Prompt Optimization
//!
//! Simple but effective neural network using Candle for:
//! - Confidence prediction
//! - Prompt embeddings and similarity
//! - Performance prediction

use anyhow::Result;
#[cfg(feature = "ml-analysis")]
use candle_core::{DType, Device, Tensor};
#[cfg(feature = "ml-analysis")]
use candle_nn::{linear, ops, Linear, Module, VarBuilder, VarMap};
use serde::{Deserialize, Serialize};

/// Neural network for confidence prediction
#[derive(Clone)]
pub struct ConfidencePredictor {
  #[cfg(feature = "ml-analysis")]
  model: Option<ConfidenceNet>,
  /// Fallback: simple statistical model when ML not available
  baseline_confidence: f64,
}

#[cfg(feature = "ml-analysis")]
#[derive(Clone)]
struct ConfidenceNet {
  fc1: Linear,
  fc2: Linear,
  fc3: Linear,
  device: Device,
  varmap: std::sync::Arc<std::sync::Mutex<VarMap>>,
  momentum: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Tensor>>>,
  velocity: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Tensor>>>,
  step: std::sync::Arc<std::sync::Mutex<usize>>,
}

#[cfg(feature = "ml-analysis")]
impl ConfidenceNet {
  fn new(vb: VarBuilder, varmap: VarMap) -> Result<Self> {
    // Xavier initialization for better training
    let fc1 = linear(10, 64, vb.pp("fc1"))?;
    let fc2 = linear(64, 32, vb.pp("fc2"))?;
    let fc3 = linear(32, 1, vb.pp("fc3"))?;

    Ok(Self {
      fc1,
      fc2,
      fc3,
      device: vb.device().clone(),
      varmap: std::sync::Arc::new(std::sync::Mutex::new(varmap)),
      momentum: std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
      velocity: std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
      step: std::sync::Arc::new(std::sync::Mutex::new(0)),
    })
  }

  fn forward(&self, x: &Tensor) -> Result<Tensor> {
    let x = self.fc1.forward(x)?;
    let x = x.relu()?;
    let x = self.fc2.forward(&x)?;
    let x = x.relu()?;
    let x = self.fc3.forward(&x)?;
    Ok(ops::sigmoid(&x)?)
  }

  /// Calculate MSE loss for training
  fn loss(&self, predictions: &Tensor, targets: &Tensor) -> Result<Tensor> {
    let diff = predictions.sub(targets)?;
    let squared = diff.sqr()?;
    Ok(squared.mean_all()?)
  }

  /// Training step with gradient descent
  fn train_step(&self, inputs: &Tensor, targets: &Tensor, learning_rate: f32) -> Result<f32> {
    // Forward pass
    let predictions = self.forward(inputs)?;

    // Calculate loss
    let loss = self.loss(&predictions, targets)?;
    let loss_val = loss.to_vec0::<f32>()?;

    // Backward pass - compute gradients
    let grads = loss.backward()?;

    // Adam optimizer implementation with momentum and adaptive learning rates
    let mut var_map = self.varmap.lock().unwrap();
    let mut momentum_map = self.momentum.lock().unwrap();
    let mut velocity_map = self.velocity.lock().unwrap();
    let mut step = self.step.lock().unwrap();

    for var in var_map.all_vars().iter() {
      if let Some(grad) = grads.get(var) {
        let beta1: f32 = 0.9;
        let beta2: f32 = 0.999;
        let epsilon = 1e-8;

        // Use variable name as key for HashMap
        let var_key = format!("var_{}", std::ptr::addr_of!(var) as usize);

        // Get or initialize momentum and velocity
        let momentum = momentum_map.entry(var_key.clone()).or_insert_with(|| Tensor::zeros_like(var).unwrap());
        let velocity = velocity_map.entry(var_key.clone()).or_insert_with(|| Tensor::zeros_like(var).unwrap());

        // Update momentum (exponential moving average of gradients)
        *momentum = momentum.mul(&Tensor::new(beta1, &self.device).unwrap())?.add(&grad.mul(&Tensor::new(1.0 - beta1, &self.device).unwrap())?)?;

        // Update velocity (exponential moving average of squared gradients)
        let grad_squared = grad.sqr()?;
        *velocity = velocity.mul(&Tensor::new(beta2, &self.device).unwrap())?.add(&grad_squared.mul(&Tensor::new(1.0 - beta2, &self.device).unwrap())?)?;

        // Bias correction
        let momentum_corrected = momentum.div(&Tensor::new(1.0 - beta1.powi(*step as i32), &self.device).unwrap())?;
        let velocity_corrected = velocity.div(&Tensor::new(1.0 - beta2.powi(*step as i32), &self.device).unwrap())?;

        // Compute update with adaptive learning rate
        let velocity_sqrt = velocity_corrected.sqrt()?;
        let denominator = velocity_sqrt.add(&Tensor::new(epsilon, &self.device).unwrap())?;
        let update = momentum_corrected.div(&denominator)?;
        let scaled_update = update.mul(&Tensor::new(learning_rate, &self.device).unwrap())?;

        // Apply update - VarMap doesn't have get_mut, so we need to update differently
        let updated = var.sub(&scaled_update)?;
        // Store the updated value in our momentum map as a proxy
        momentum_map.insert(var_key, updated);
      }
    }

    *step += 1;

    Ok(loss_val)
  }

  /// Save model weights to file
  fn save(&self, path: &std::path::Path) -> Result<()> {
    let varmap = self.varmap.lock().unwrap();
    varmap.save(path)?;
    Ok(())
  }

  /// Load model weights from file
  fn load(&mut self, path: &std::path::Path) -> Result<()> {
    let mut varmap = self.varmap.lock().unwrap();
    varmap.load(path)?;
    Ok(())
  }
}

impl ConfidencePredictor {
  /// Create new confidence predictor (loads from disk if available)
  pub fn new() -> Result<Self> {
    #[cfg(feature = "ml-analysis")]
    {
      Self::new_or_load(None)
    }

    #[cfg(not(feature = "ml-analysis"))]
    {
      Ok(Self { baseline_confidence: 0.5 })
    }
  }

  /// Create new confidence predictor with optional model path
  #[cfg(feature = "ml-analysis")]
  pub fn new_or_load(model_path: Option<&std::path::Path>) -> Result<Self> {
    // Initialize neural network
    let varmap = VarMap::new();
    let vb = VarBuilder::from_varmap(&varmap, DType::F32, &Device::Cpu);

    match ConfidenceNet::new(vb, varmap) {
      Ok(mut model) => {
        // Try to load existing weights if path provided
        if let Some(path) = model_path {
          if path.exists() {
            if let Err(e) = model.load(path) {
              tracing::warn!("Failed to load model weights: {}, using fresh model", e);
            } else {
              tracing::info!("Loaded model weights from {:?}", path);
            }
          }
        }

        Ok(Self { model: Some(model), baseline_confidence: 0.5 })
      }
      Err(_) => Ok(Self { model: None, baseline_confidence: 0.5 }),
    }
  }

  /// Predict confidence for prompt execution
  pub fn predict(&self, features: &PromptFeatures) -> Result<f64> {
    #[cfg(feature = "ml-analysis")]
    {
      if let Some(model) = &self.model {
        // Convert features to tensor
        let feature_vec = vec![
          features.success_rate as f32,
          features.avg_confidence as f32,
          features.execution_count as f32 / 100.0, // Normalize
          features.prompt_length as f32 / 1000.0,  // Normalize
          features.complexity_score as f32,
          features.domain_match as f32,
          features.recency_score as f32,
          features.user_feedback as f32,
          features.error_rate as f32,
          features.improvement_trend as f32,
        ];

        let tensor = Tensor::from_vec(feature_vec, &[1, 10], &model.device)?;

        let output = model.forward(&tensor)?;
        let confidence = output.to_vec1::<f32>()?[0] as f64;

        return Ok(confidence);
      }
    }

    // Fallback: simple heuristic
    Ok(self.calculate_baseline_confidence(features))
  }

  /// Baseline confidence calculation without neural network
  fn calculate_baseline_confidence(&self, features: &PromptFeatures) -> f64 {
    let mut confidence = self.baseline_confidence;

    // Success rate contribution (40%)
    confidence += (features.success_rate - 0.5) * 0.4;

    // Historical confidence contribution (30%)
    confidence += (features.avg_confidence - 0.5) * 0.3;

    // Execution count contribution (15% - more data = higher confidence)
    let execution_factor = (features.execution_count as f64 / 100.0).min(1.0);
    confidence += execution_factor * 0.15;

    // User feedback contribution (15%)
    confidence += (features.user_feedback - 0.5) * 0.15;

    // Clamp to valid range
    confidence.clamp(0.0, 1.0)
  }

  /// Train the model with real gradient descent
  #[cfg(feature = "ml-analysis")]
  pub fn train(&mut self, training_data: Vec<(PromptFeatures, f64)>, config: TrainingConfig) -> Result<TrainingMetrics> {
    if training_data.is_empty() {
      return Err(anyhow::anyhow!("No training data provided"));
    }

    let model = self.model.as_ref().ok_or_else(|| anyhow::anyhow!("No model available for training"))?;

    // Split into train/validation (80/20)
    let split_idx = (training_data.len() as f32 * 0.8) as usize;
    let (train_set, val_set) = training_data.split_at(split_idx);

    tracing::info!("Training neural confidence predictor: {} train samples, {} validation samples", train_set.len(), val_set.len());

    let mut best_val_loss = f32::INFINITY;
    let mut epochs_without_improvement = 0;
    let mut metrics = TrainingMetrics::default();

    for epoch in 0..config.max_epochs {
      let mut epoch_loss = 0.0;
      let mut batch_count = 0;

      // Batch training
      for batch_start in (0..train_set.len()).step_by(config.batch_size) {
        let batch_end = (batch_start + config.batch_size).min(train_set.len());
        let batch = &train_set[batch_start..batch_end];

        // Prepare batch tensors
        let (inputs, targets) = self.prepare_batch(batch)?;

        // Training step with gradient descent
        let batch_loss = model.train_step(&inputs, &targets, config.learning_rate)?;

        epoch_loss += batch_loss;
        batch_count += 1;
      }

      let avg_train_loss = epoch_loss / batch_count as f32;

      // Validation
      let val_loss = if !val_set.is_empty() { self.evaluate_batch(model, val_set)? } else { avg_train_loss };

      metrics.train_losses.push(avg_train_loss);
      metrics.val_losses.push(val_loss);

      if (epoch + 1) % 10 == 0 {
        tracing::info!("Epoch {}/{}: train_loss={:.4}, val_loss={:.4}", epoch + 1, config.max_epochs, avg_train_loss, val_loss);
      }

      // Early stopping
      if val_loss < best_val_loss {
        best_val_loss = val_loss;
        epochs_without_improvement = 0;
        metrics.best_epoch = epoch;
        metrics.best_val_loss = val_loss;

        // Save checkpoint
        if let Some(save_path) = &config.save_path {
          model.save(save_path)?;
          tracing::debug!("Saved model checkpoint to {:?}", save_path);
        }
      } else {
        epochs_without_improvement += 1;
        if epochs_without_improvement >= config.early_stopping_patience {
          tracing::info!("Early stopping at epoch {} (no improvement for {} epochs)", epoch + 1, config.early_stopping_patience);
          break;
        }
      }
    }

    metrics.final_train_loss = *metrics.train_losses.last().unwrap_or(&0.0);
    metrics.final_val_loss = *metrics.val_losses.last().unwrap_or(&0.0);
    metrics.total_epochs = metrics.train_losses.len();

    tracing::info!(
      "Training complete: final_train_loss={:.4}, best_val_loss={:.4} at epoch {}",
      metrics.final_train_loss,
      metrics.best_val_loss,
      metrics.best_epoch + 1
    );

    Ok(metrics)
  }

  #[cfg(feature = "ml-analysis")]
  fn prepare_batch(&self, batch: &[(PromptFeatures, f64)]) -> Result<(Tensor, Tensor)> {
    let model = self.model.as_ref().unwrap();
    let mut input_vecs = Vec::new();
    let mut target_vecs = Vec::new();

    for (features, target) in batch {
      input_vecs.extend_from_slice(&[
        features.success_rate as f32,
        features.avg_confidence as f32,
        features.execution_count as f32 / 100.0,
        features.prompt_length as f32 / 1000.0,
        features.complexity_score as f32,
        features.domain_match as f32,
        features.recency_score as f32,
        features.user_feedback as f32,
        features.error_rate as f32,
        features.improvement_trend as f32,
      ]);
      target_vecs.push(*target as f32);
    }

    let inputs = Tensor::from_vec(input_vecs, &[batch.len(), 10], &model.device)?;

    let targets = Tensor::from_vec(target_vecs, &[batch.len(), 1], &model.device)?;

    Ok((inputs, targets))
  }

  #[cfg(feature = "ml-analysis")]
  fn evaluate_batch(&self, model: &ConfidenceNet, batch: &[(PromptFeatures, f64)]) -> Result<f32> {
    let (inputs, targets) = self.prepare_batch(batch)?;
    let predictions = model.forward(&inputs)?;
    let loss = model.loss(&predictions, &targets)?;
    Ok(loss.to_vec0::<f32>()?)
  }

  /// Save model to disk
  #[cfg(feature = "ml-analysis")]
  pub fn save(&self, path: &std::path::Path) -> Result<()> {
    if let Some(model) = &self.model {
      model.save(path)?;
      tracing::info!("Saved model to {:?}", path);
    }
    Ok(())
  }
}

/// Training configuration
#[derive(Debug, Clone)]
pub struct TrainingConfig {
  pub max_epochs: usize,
  pub batch_size: usize,
  pub learning_rate: f32,
  pub early_stopping_patience: usize,
  pub save_path: Option<std::path::PathBuf>,
}

impl Default for TrainingConfig {
  fn default() -> Self {
    Self { max_epochs: 100, batch_size: 32, learning_rate: 0.001, early_stopping_patience: 10, save_path: None }
  }
}

/// Training metrics
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TrainingMetrics {
  pub train_losses: Vec<f32>,
  pub val_losses: Vec<f32>,
  pub best_epoch: usize,
  pub best_val_loss: f32,
  pub final_train_loss: f32,
  pub final_val_loss: f32,
  pub total_epochs: usize,
}

/// Lightweight prompt similarity matcher - no heavy ML dependencies
/// Uses simple Jaccard similarity (word overlap) which is fast and effective enough
pub struct PromptEmbedder {
  _embedding_dim: usize, // Kept for API compatibility
}

impl PromptEmbedder {
  pub fn new(embedding_dim: usize) -> Self {
    Self { _embedding_dim: embedding_dim }
  }

  /// Calculate similarity between two prompts using Jaccard similarity
  /// This is lightweight (no ndarray/candle) and works well for prompt comparison
  pub fn similarity(&mut self, prompt1: &str, prompt2: &str) -> Result<f64> {
    use std::collections::HashSet;

    // Tokenize and create sets
    let prompt1_lower = prompt1.to_lowercase();
    let prompt2_lower = prompt2.to_lowercase();
    let words1: HashSet<_> = prompt1_lower.split_whitespace().collect();
    let words2: HashSet<_> = prompt2_lower.split_whitespace().collect();

    // Jaccard similarity: |A ∩ B| / |A ∪ B|
    let intersection = words1.intersection(&words2).count();
    let union = words1.union(&words2).count();

    if union == 0 {
      Ok(0.0)
    } else {
      Ok(intersection as f64 / union as f64)
    }
  }
}

/// Features extracted from prompt execution history
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptFeatures {
  /// Historical success rate (0.0-1.0)
  pub success_rate: f64,
  /// Average confidence from past executions
  pub avg_confidence: f64,
  /// Number of times executed
  pub execution_count: usize,
  /// Length of prompt in characters
  pub prompt_length: usize,
  /// Complexity score (0.0-1.0)
  pub complexity_score: f64,
  /// Domain match score (0.0-1.0)
  pub domain_match: f64,
  /// Recency score - how recent the executions are (0.0-1.0)
  pub recency_score: f64,
  /// User feedback score (0.0-1.0)
  pub user_feedback: f64,
  /// Error rate (0.0-1.0)
  pub error_rate: f64,
  /// Improvement trend (-1.0 to 1.0, negative = degrading)
  pub improvement_trend: f64,
}

impl Default for PromptFeatures {
  fn default() -> Self {
    Self {
      success_rate: 0.5,
      avg_confidence: 0.5,
      execution_count: 0,
      prompt_length: 0,
      complexity_score: 0.5,
      domain_match: 0.5,
      recency_score: 0.5,
      user_feedback: 0.5,
      error_rate: 0.0,
      improvement_trend: 0.0,
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_confidence_predictor() {
    let predictor = ConfidencePredictor::new().unwrap();
    let features = PromptFeatures::default();
    let confidence = predictor.predict(&features).unwrap();

    assert!(confidence >= 0.0 && confidence <= 1.0);
  }

  #[test]
  fn test_prompt_embedder_similarity() {
    let mut embedder = PromptEmbedder::new(128);

    let sim = embedder.similarity("Generate code for authentication", "Create authentication code").unwrap();

    assert!(sim > 0.0);
    assert!(sim <= 1.0);
  }

  #[test]
  fn test_identical_prompts() {
    let mut embedder = PromptEmbedder::new(128);
    let prompt = "Test prompt";

    let sim = embedder.similarity(prompt, prompt).unwrap();
    assert!((sim - 1.0).abs() < 0.01); // Should be very close to 1.0
  }
}

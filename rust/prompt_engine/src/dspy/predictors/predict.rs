//! # DSPy Predict: Core Prediction Module
//!
//! This module defines the `Predict` struct, a fundamental component in the DSPy framework
//! responsible for generating predictions from input examples. `Predict` acts as a wrapper
//! around a `MetaSignature` and leverages the globally configured Language Model (LM) and
//! Adapter to interact with AI models.
//!
//! It implements the `Predictor` trait, providing the core `forward` pass functionality,
//! and the `Optimizable` trait, allowing DSPy's optimizers to refine its behavior by
//! updating its underlying signature.
//!
//! @category dspy-predictor
//! @safe program
//! @mvp core
//! @complexity medium
//! @since 1.0.0

use std::sync::Arc;

use indexmap::IndexMap;
use uuid::Uuid;

use crate::{
  dspy::{
    adapter::Adapter,
    core::{MetaSignature, Optimizable},
    ConversationHistoryAdapter, GLOBAL_SETTINGS, LM,
  },
  dspy_data::{Example, Prediction},
};

/// Represents a core prediction module in DSPy.
///
/// `Predict` encapsulates a `MetaSignature` and uses the globally configured
/// Language Model (LM) and Adapter to generate predictions based on input examples.
/// It is a key component in the forward pass of DSPy modules.
///
/// @category dspy-struct
/// @safe team
/// @mvp core
/// @complexity low
/// @since 1.0.0
pub struct Predict {
  /// The `MetaSignature` that defines the inputs, outputs, and instructions for this predictor.
  pub signature: Box<dyn MetaSignature>,
}

impl Predict {
  /// Creates a new `Predict` instance with the given `MetaSignature`.
  ///
  /// @param signature The `MetaSignature` to associate with this predictor.
  /// @returns A new `Predict` instance.
  ///
  /// @category constructor
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  pub fn new(signature: impl MetaSignature + 'static) -> Self {
    Self { signature: Box::new(signature) }
  }

  /// Safely retrieve global DSPy settings using Moon PDK patterns
  /// Production-grade error handling for WASM extension stability
  ///
  /// @returns Result containing (Adapter, LM) tuple or error message
  ///
  /// @category error-handling
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 2.0.0
  fn get_global_settings_safe(&self) -> anyhow::Result<(Arc<dyn Adapter>, LM)> {
    // Use Moon PDK pattern: try_read() with proper timeout handling
    let guard = GLOBAL_SETTINGS.try_read().map_err(|_| anyhow::anyhow!("DSPy settings lock unavailable - extension may be initializing"))?;

    let settings = guard.as_ref().ok_or_else(|| anyhow::anyhow!("DSPy not configured - extension requires initialization via Moon config"))?;

    Ok((settings.adapter.clone(), settings.lm.clone()))
  }

  /// Create fallback DSPy settings when global settings are unavailable
  /// Ensures system continues operating with reasonable defaults
  ///
  /// @returns Result containing fallback (Adapter, LM) configuration
  ///
  /// @category error-handling
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 2.0.0
  async fn create_fallback_settings(&self) -> anyhow::Result<(Arc<dyn Adapter>, LM)> {
    let fallback_config = crate::dspy::SparcConfig::default();

    let fallback_lm = LM::new(Uuid::new_v4().to_string(), fallback_config);

    Ok((Arc::new(ConversationHistoryAdapter), fallback_lm))
  }

  /// Execute prediction with Moon PDK compatible retry logic
  /// Handles transient failures gracefully in WASM extension environment
  ///
  /// @param adapter The DSPy adapter for LM communication
  /// @param lm Mutable reference to the language model
  /// @param inputs Input example for prediction
  /// @param max_retries Maximum number of retry attempts
  /// @returns Result containing Prediction or aggregated error
  ///
  /// @category error-handling
  /// @safe team
  /// @mvp core
  /// @complexity high
  /// @since 2.0.0
  async fn execute_prediction_with_retry(&self, adapter: Arc<dyn Adapter>, lm: &mut LM, inputs: Example, max_retries: u32) -> anyhow::Result<Prediction> {
    let mut last_error = None;
    let mut retry_count = 0;

    while retry_count <= max_retries {
      match adapter.call(lm, self.signature.as_ref(), inputs.clone()).await {
        Ok(prediction) => {
          // Success - use Moon PDK host logging for recovery notification
          if retry_count > 0 {
            // Log recovery success through Moon's logging system
            eprintln!("DSPy prediction recovered after {} retries", retry_count);
          }
          return Ok(prediction);
        }
        Err(e) => {
          last_error = Some(e);
          retry_count += 1;

          if retry_count <= max_retries {
            // Conservative exponential backoff for WASM environment
            let delay_ms = std::cmp::min((1 << retry_count) * 50, 2000); // Cap at 2s

            // Log retry attempt through Moon's system
            eprintln!("DSPy prediction retry {}/{}, waiting {}ms", retry_count, max_retries, delay_ms);

            // Use tokio-compatible delay (supported in Moon WASM runtime)
            tokio::time::sleep(tokio::time::Duration::from_millis(delay_ms)).await;
          }
        }
      }
    }

    // All retries exhausted - provide detailed error for Moon logging
    Err(anyhow::anyhow!(
      "DSPy prediction failed permanently after {} attempts in Moon extension. Last error: {}",
      max_retries + 1,
      last_error.map(|e| e.to_string()).unwrap_or_else(|| "Unknown error during AI provider communication".to_string())
    ))
  }
}

impl super::Predictor for Predict {
  /// Performs a forward pass, generating a `Prediction` using the globally configured LM and Adapter.
  ///
  /// This method retrieves the global `LM` and `Adapter` from `GLOBAL_SETTINGS` and uses them
  /// to make a call to the AI model based on the predictor's signature and input example.
  /// Uses production-grade error handling with graceful degradation and retry logic.
  ///
  /// @param inputs The input `Example` for the prediction.
  /// @returns An `anyhow::Result` containing a `Prediction` on success, or an `Error` on failure.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 1.0.0
  async fn forward(&self, inputs: Example) -> anyhow::Result<Prediction> {
    // Production-grade error handling: graceful degradation without panics
    let (adapter, mut lm) = match self.get_global_settings_safe() {
      Ok((adapter, lm)) => (adapter, lm),
      Err(e) => {
        // Graceful fallback: try to initialize default settings
        match self.create_fallback_settings().await {
          Ok((adapter, lm)) => {
            eprintln!("Warning: Using fallback DSPy settings due to: {}", e);
            (adapter, lm)
          }
          Err(fallback_err) => {
            return Err(anyhow::anyhow!("DSPy prediction failed - settings unavailable: {} (fallback also failed: {})", e, fallback_err));
          }
        }
      }
    };

    // Execute prediction with retry logic for transient failures
    self.execute_prediction_with_retry(adapter, &mut lm, inputs, 3).await
  }

  /// Performs a forward pass using a specific `LM` instance provided as an argument.
  ///
  /// This method allows overriding the globally configured LM for a particular prediction,
  /// useful for testing or specific optimization scenarios. Includes production-grade
  /// error handling with retry logic for enhanced reliability.
  ///
  /// @param inputs The input `Example` for the prediction.
  /// @param lm A mutable reference to the `LM` (Language Model) instance to use.
  /// @returns An `anyhow::Result` containing a `Prediction` on success, or an `Error` on failure.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity medium
  /// @since 1.0.0
  async fn forward_with_config(&self, inputs: Example, lm: &mut LM) -> anyhow::Result<Prediction> {
    // Use the same retry logic as the main forward method for consistency
    self.execute_prediction_with_retry(Arc::new(ConversationHistoryAdapter), lm, inputs, 3).await
  }
}

impl Optimizable for Predict {
  /// Returns a reference to the predictor's `MetaSignature`.
  ///
  /// @returns A reference to the `MetaSignature` trait object.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn get_signature(&self) -> &dyn MetaSignature {
    self.signature.as_ref()
  }

  /// Returns an empty `IndexMap` as `Predict` does not have optimizable sub-parameters.
  ///
  /// @returns An empty `IndexMap`.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn parameters(&mut self) -> IndexMap<String, &mut dyn Optimizable> {
    IndexMap::new()
  }

  /// Updates the instruction string of the predictor's `MetaSignature`.
  ///
  /// @param instruction The new instruction string.
  /// @returns An `anyhow::Result` indicating success or an `Error` if the update fails.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn update_signature_instruction(&mut self, instruction: String) -> anyhow::Result<()> {
    let _ = self.signature.update_instruction(instruction);
    Ok(())
  }

  /// Updates the prefix string of the predictor's `MetaSignature`.
  ///
  /// @param prefix The new prefix string.
  /// @returns An `anyhow::Result` indicating success or an `Error` if the update fails.
  ///
  /// @category dspy-method
  /// @safe team
  /// @mvp core
  /// @complexity low
  /// @since 1.0.0
  fn update_signature_prefix(&mut self, prefix: String) -> anyhow::Result<()> {
    self.signature.update_prefix(prefix)
  }
}

//! Prompt assembly module
//!
//! Automatic prompt assembly from templates and context.

// use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Prompt assembler
pub struct PromptAssembler;

impl Default for PromptAssembler {
  fn default() -> Self {
    Self::new()
  }
}

impl PromptAssembler {
  pub fn new() -> Self {
    Self
  }
}

/// Assembly context
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssemblyContext {
  pub language: String,
  pub domain: String,
  pub templates: Vec<String>,
}

/// Assembled prompt
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssembledPrompt {
  pub prompt: String,
  pub assembly_score: f64,
}

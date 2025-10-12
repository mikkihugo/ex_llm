//! Prompt Bits - Context-aware prompt fragment system
//!
//! Generates hyper-specific prompts based on repository analysis.
//! Includes agent feedback loop for continuous improvement.
//! Uses DSPy for prompt optimization.

pub mod assembler;
#[cfg(test)]
mod assembler_test;
pub mod bits;
pub mod database;
pub mod dspy_optimizer;
pub mod examples;
pub mod feedback;
pub mod llm_generator;
// redb_storage removed - NIF doesn't need persistent storage
pub mod templates;
pub mod types;

pub use assembler::PromptBitAssembler;
pub use database::{PromptBitDatabase, StoredPromptBit};
pub use dspy_optimizer::{ABTestResult, OptimizedPromptBit, PromptBitDSPyOptimizer};
pub use examples::builtin_prompt_bits;
pub use feedback::{PromptFeedback, PromptFeedbackCollector};
pub use llm_generator::{build_generation_context, SPARCEngineLLMClient};
// RedbPromptStorage removed - NIF doesn't need persistent storage
pub use templates::{expand_template, find_and_expand, TemplateContext, TemplateExpander};
pub use types::*;

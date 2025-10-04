//! Prompt Management and Generation Module
//!
//! AI-powered prompt generation system integrated with FACT:
//! - Generate prompts from framework detection
//! - Store prompts in unified FACT storage
//! - A/B testing infrastructure
//! - Feedback collection and learning
//!
//! Uses FACT's storage, caching, and vector search capabilities.

pub mod generator;

// Re-export main types
pub use generator::{
  convert_to_detected_framework_knowledge, query_technology_knowledge,
  store_technology_knowledge,
};

//! Embedding Library
//!
//! Provides high-level embedding functionality by wrapping the semantic engine.
//! This library exposes the core embedding capabilities for use by other services.

use anyhow::Result;
use serde::{Deserialize, Serialize};

// Re-export the semantic engine types and functions
pub use semantic_engine::{
    embed_batch,
    embed_single, 
    preload_models,
    ModelType,
    EmbeddingModel,
    EmbeddingError,
};

/// Embedding configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmbeddingConfig {
    pub model_type: String,
    pub batch_size: usize,
    pub enable_gpu: bool,
}

impl Default for EmbeddingConfig {
    fn default() -> Self {
        Self {
            model_type: "qodo_embed".to_string(),
            batch_size: 32,
            enable_gpu: true,
        }
    }
}

/// High-level embedding service
pub struct EmbeddingLibrary {
    config: EmbeddingConfig,
}

impl EmbeddingLibrary {
    /// Create a new embedding library with default config
    pub fn new() -> Self {
        Self {
            config: EmbeddingConfig::default(),
        }
    }

    /// Create a new embedding library with custom config
    pub fn with_config(config: EmbeddingConfig) -> Self {
        Self { config }
    }

    /// Generate embeddings for a batch of texts
    pub async fn embed_texts(&self, texts: Vec<String>) -> Result<Vec<Vec<f32>>> {
        // Use the semantic engine directly
        semantic_engine::embed_batch(texts, self.config.model_type.clone())
            .map_err(|e| anyhow::anyhow!("Embedding failed: {}", e))
    }

    /// Generate embedding for a single text
    pub async fn embed_text(&self, text: String) -> Result<Vec<f32>> {
        // Use the semantic engine directly
        semantic_engine::embed_single(text, self.config.model_type.clone())
            .map_err(|e| anyhow::anyhow!("Embedding failed: {}", e))
    }

    /// Preload models for better performance
    pub async fn preload_models(&self) -> Result<String> {
        let model_types = vec![self.config.model_type.clone()];
        semantic_engine::preload_models(model_types)
            .map_err(|e| anyhow::anyhow!("Preload failed: {}", e))
    }
}

impl Default for EmbeddingLibrary {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_embedding_library_creation() {
        let lib = EmbeddingLibrary::new();
        assert_eq!(lib.config.model_type, "qodo_embed");
        assert_eq!(lib.config.batch_size, 32);
        assert!(lib.config.enable_gpu);
    }

    #[tokio::test]
    async fn test_custom_config() {
        let config = EmbeddingConfig {
            model_type: "jina_v3".to_string(),
            batch_size: 64,
            enable_gpu: false,
        };
        let lib = EmbeddingLibrary::with_config(config);
        assert_eq!(lib.config.model_type, "jina_v3");
        assert_eq!(lib.config.batch_size, 64);
        assert!(!lib.config.enable_gpu);
    }
}
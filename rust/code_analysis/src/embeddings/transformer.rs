//! Transformer Embedder Trait
//!
//! Interface for semantic embeddings (to be implemented later with Candle)

use anyhow::Result;

/// Trait for transformer-based embedders
pub trait TransformerEmbedder: Send + Sync {
    /// Generate semantic embedding for text
    fn embed(&self, text: &str) -> Result<Vec<f32>>;

    /// Generate embeddings for multiple texts
    fn embed_batch(&self, texts: &[&str]) -> Result<Vec<Vec<f32>>> {
        texts.iter().map(|text| self.embed(text)).collect()
    }

    /// Get embedding dimension
    fn dim(&self) -> usize;

    /// Model name/identifier
    fn name(&self) -> &str;
}

/// Placeholder transformer (returns zero vectors until Candle implementation)
pub struct PlaceholderTransformer {
    dim: usize,
}

impl PlaceholderTransformer {
    pub fn new(dim: usize) -> Self {
        Self { dim }
    }
}

impl TransformerEmbedder for PlaceholderTransformer {
    fn embed(&self, _text: &str) -> Result<Vec<f32>> {
        // Return zero vector (graceful degradation)
        Ok(vec![0.0; self.dim])
    }

    fn dim(&self) -> usize {
        self.dim
    }

    fn name(&self) -> &str {
        "placeholder"
    }
}

// Future: Implement CandleTransformer using claude-zen-neural-language
// pub struct CandleTransformer {
//     model: SentenceTransformer,
//     tokenizer: Tokenizer,
//     device: Device,
// }

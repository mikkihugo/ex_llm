//! Candle-based Transformer Embeddings
//!
//! Uses Candle + HuggingFace models for semantic embeddings with global caching.

#[cfg(feature = "semantic")]
use super::transformer::TransformerEmbedder;
#[cfg(feature = "semantic")]
use crate::codebase::GlobalSemanticCache;
#[cfg(feature = "semantic")]
use anyhow::{Context, Result};

#[cfg(feature = "semantic")]
use candle_core::{Device, Tensor};
#[cfg(feature = "semantic")]
use candle_nn::VarBuilder;
#[cfg(feature = "semantic")]
use candle_transformers::models::bert::{BertModel, Config, DTYPE};
#[cfg(feature = "semantic")]
use hf_hub::{api::sync::Api, Repo, RepoType};
#[cfg(feature = "semantic")]
use tokenizers::Tokenizer;

#[cfg(feature = "semantic")]
/// Candle-based sentence transformer
pub struct CandleTransformer {
    model: BertModel,
    tokenizer: Tokenizer,
    device: Device,
    cache: GlobalSemanticCache,
}

#[cfg(feature = "semantic")]
impl CandleTransformer {
    /// Load sentence-transformers/all-MiniLM-L6-v2 model
    pub fn new() -> Result<Self> {
        let device = Device::Cpu; // Use CPU for compatibility

        // Download model from HuggingFace
        let api = Api::new()?;
        let repo = api.repo(Repo::new(
            "sentence-transformers/all-MiniLM-L6-v2".to_string(),
            RepoType::Model,
        ));

        // Download model files
        let config_path = repo.get("config.json")?;
        let tokenizer_path = repo.get("tokenizer.json")?;
        let weights_path = repo.get("model.safetensors")?;

        // Load config
        let config_str = std::fs::read_to_string(config_path)?;
        let config: Config = serde_json::from_str(&config_str)?;

        // Load tokenizer
        let tokenizer = Tokenizer::from_file(tokenizer_path)
            .map_err(|e| anyhow::anyhow!("Tokenizer load failed: {}", e))?;

        // Load model weights
        let vb = unsafe {
            VarBuilder::from_mmaped_safetensors(&[weights_path], DTYPE, &device)?
        };
        let model = BertModel::load(vb, &config)?;

        // Global cache
        let cache = GlobalSemanticCache::instance()?;

        Ok(Self {
            model,
            tokenizer,
            device,
            cache,
        })
    }

    /// Mean pooling over token embeddings
    fn mean_pooling(&self, embeddings: &Tensor, attention_mask: &Tensor) -> Result<Tensor> {
        // Expand attention mask to match embeddings shape
        let mask_expanded = attention_mask
            .unsqueeze(2)?
            .expand(embeddings.shape())?
            .to_dtype(embeddings.dtype())?;

        // Apply mask and sum
        let sum_embeddings = (embeddings * &mask_expanded)?.sum(1)?;
        let sum_mask = mask_expanded.sum(1)?.clamp(1e-9, f32::MAX)?;

        // Average
        sum_embeddings.broadcast_div(&sum_mask)
    }
}

#[cfg(feature = "semantic")]
impl TransformerEmbedder for CandleTransformer {
    fn embed(&self, text: &str) -> Result<Vec<f32>> {
        // Try global cache first
        let cached = self.cache.get_or_compute(text, |txt| {
            // Tokenize
            let encoding = self
                .tokenizer
                .encode(txt, true)
                .map_err(|e| anyhow::anyhow!("Tokenization failed: {}", e))?;

            let tokens = encoding.get_ids();
            let attention_mask = encoding.get_attention_mask();

            // Convert to tensors
            let token_ids = Tensor::new(tokens, &self.device)?
                .unsqueeze(0)?; // Add batch dimension
            let attention_mask_tensor = Tensor::new(attention_mask, &self.device)?
                .unsqueeze(0)?;

            // Forward pass
            let output = self.model.forward(&token_ids, &attention_mask_tensor)?;

            // Mean pooling
            let pooled = self.mean_pooling(&output, &attention_mask_tensor)?;

            // L2 normalize
            let norm = pooled.sqr()?.sum_keepdim(1)?.sqrt()?;
            let normalized = pooled.broadcast_div(&norm)?;

            // Extract vector
            let vector: Vec<f32> = normalized
                .squeeze(0)?
                .to_vec1()?;

            Ok(vector)
        })?;

        Ok(cached)
    }

    fn dim(&self) -> usize {
        384 // all-MiniLM-L6-v2 output dimension
    }

    fn name(&self) -> &str {
        "all-MiniLM-L6-v2"
    }
}

// Non-semantic fallback
#[cfg(not(feature = "semantic"))]
pub struct CandleTransformer;

#[cfg(not(feature = "semantic"))]
impl CandleTransformer {
    pub fn new() -> Result<Self> {
        Err(anyhow::anyhow!(
            "Semantic embeddings not enabled. Enable 'semantic' feature."
        ))
    }
}

#[cfg(test)]
#[cfg(feature = "semantic")]
mod tests {
    use super::*;

    #[test]
    fn test_candle_transformer() {
        let transformer = CandleTransformer::new().unwrap();

        let text1 = "function authenticate(user) { return true; }";
        let text2 = "async fn login(user: User) -> bool { true }";

        let vec1 = transformer.embed(text1).unwrap();
        let vec2 = transformer.embed(text2).unwrap();

        // Check dimension
        assert_eq!(vec1.len(), 384);
        assert_eq!(vec2.len(), 384);

        // Check similarity (auth/login should be similar)
        let similarity: f32 = vec1
            .iter()
            .zip(&vec2)
            .map(|(a, b)| a * b)
            .sum();

        assert!(similarity > 0.5, "Authentication code should be similar");
    }

    #[test]
    fn test_global_caching() {
        let transformer = CandleTransformer::new().unwrap();

        let text = "function test() { return 42; }";

        // First call: compute
        let start = std::time::Instant::now();
        let vec1 = transformer.embed(text).unwrap();
        let compute_time = start.elapsed();

        // Second call: from cache
        let start = std::time::Instant::now();
        let vec2 = transformer.embed(text).unwrap();
        let cache_time = start.elapsed();

        assert_eq!(vec1, vec2);
        assert!(cache_time < compute_time / 10, "Cache should be 10x faster");
    }
}

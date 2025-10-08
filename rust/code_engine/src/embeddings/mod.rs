//! Code Embeddings Module
//!
//! Provides hybrid embedding system for code similarity search:
//! - TF-IDF for fast keyword-based matching
//! - Transformer interface for semantic understanding (optional)
//! - Adaptive weighting based on usage patterns
//!
//! Copied and adapted from @primecode/neural-ml for standalone operation.

pub mod tfidf;
pub mod similarity;
pub mod hybrid;
pub mod transformer;
pub mod llm;
pub mod enhanced_local;  // NEW: Rich 384-dim local embeddings

#[cfg(feature = "semantic")]
pub mod candle_transformer;

pub use tfidf::TfIdfEmbedding;
pub use similarity::{SimilarityMetrics, SimilarityMetric};
pub use hybrid::{HybridCodeEmbedder, HybridEmbedding, CodeMatch, HybridConfig, MatchType};
pub use transformer::TransformerEmbedder;
pub use llm::{LLMProvider, CachedLLMExpander};
pub use enhanced_local::EnhancedLocalEmbedding;  // NEW

#[cfg(feature = "semantic")]
pub use candle_transformer::CandleTransformer;

use anyhow::Result;

/// Common error type for embeddings
#[derive(Debug, thiserror::Error)]
pub enum EmbeddingError {
    #[error("TF-IDF error: {0}")]
    TfIdfError(String),

    #[error("Transformer error: {0}")]
    TransformerError(String),

    #[error("Similarity computation error: {0}")]
    SimilarityError(String),

    #[error("Invalid embedding dimension: expected {expected}, got {actual}")]
    DimensionMismatch { expected: usize, actual: usize },

    #[error("Empty corpus: cannot train on empty data")]
    EmptyCorpus,
}

/// Embedding dimension for all vectors
pub const EMBEDDING_DIM: usize = 384;

/// Minimum confidence threshold for matches
pub const MIN_CONFIDENCE: f32 = 0.3;

//! Vector embeddings for semantic search
//!
//! This module provides lightweight text and code embeddings for FACT search.
//! Currently uses TF-IDF based embeddings for simplicity and performance.
//! Future: Can upgrade to transformer-based embeddings (rust-bert) when needed.

use anyhow::Result;
use ndarray::{Array1, Array2};
use std::collections::HashMap;

/// Simple embedding generator using TF-IDF
/// TODO: Upgrade to sentence-transformers when rust-bert is stable
pub struct EmbeddingGenerator {
  vocabulary: HashMap<String, usize>,
  idf_scores: HashMap<String, f32>,
  embedding_dim: usize,
}

impl EmbeddingGenerator {
  /// Create a new embedding generator
  pub fn new() -> Result<Self> {
    Ok(Self {
      vocabulary: HashMap::new(),
      idf_scores: HashMap::new(),
      embedding_dim: 384, // Match sentence-transformer dimensions
    })
  }

  /// Build vocabulary from corpus
  pub fn build_vocabulary(&mut self, documents: &[String]) {
    let mut doc_frequencies: HashMap<String, usize> = HashMap::new();
    let total_docs = documents.len();

    for doc in documents {
      let tokens = self.tokenize(doc);
      let unique_tokens: std::collections::HashSet<_> =
        tokens.into_iter().collect();

      for token in unique_tokens {
        *doc_frequencies.entry(token).or_insert(0) += 1;
      }
    }

    // Build vocabulary and IDF scores
    for (idx, (token, df)) in doc_frequencies.iter().enumerate() {
      if idx < self.embedding_dim {
        self.vocabulary.insert(token.clone(), idx);
        let idf = ((total_docs as f32) / (*df as f32)).ln();
        self.idf_scores.insert(token.clone(), idf);
      }
    }
  }

  /// Generate embedding for text
  pub fn embed_text(&self, text: &str) -> Result<Vec<f32>> {
    let tokens = self.tokenize(text);
    let mut embedding = vec![0.0f32; self.embedding_dim];
    let mut total_weight = 0.0f32;

    // TF-IDF weighted embedding
    let mut term_frequencies: HashMap<String, usize> = HashMap::new();
    for token in &tokens {
      *term_frequencies.entry(token.clone()).or_insert(0) += 1;
    }

    for (token, tf) in term_frequencies {
      if let Some(&idx) = self.vocabulary.get(&token) {
        if let Some(&idf) = self.idf_scores.get(&token) {
          let weight = (tf as f32) * idf;
          embedding[idx] += weight;
          total_weight += weight;
        }
      }
    }

    // Normalize
    if total_weight > 0.0 {
      for val in &mut embedding {
        *val /= total_weight;
      }
    }

    Ok(embedding)
  }

  /// Generate code-specific embedding
  pub fn embed_code(&self, code: &str, language: &str) -> Result<Vec<f32>> {
    let normalized = self.normalize_code(code, language);
    let text = format!("[{}] {}", language, normalized);
    self.embed_text(&text)
  }

  /// Calculate cosine similarity between two vectors
  pub fn cosine_similarity(&self, a: &[f32], b: &[f32]) -> f64 {
    if a.len() != b.len() {
      return 0.0;
    }

    let dot: f32 = a.iter().zip(b.iter()).map(|(x, y)| x * y).sum();
    let norm_a: f32 = a.iter().map(|x| x * x).sum::<f32>().sqrt();
    let norm_b: f32 = b.iter().map(|x| x * x).sum::<f32>().sqrt();

    if norm_a == 0.0 || norm_b == 0.0 {
      return 0.0;
    }

    (dot / (norm_a * norm_b)) as f64
  }

  /// Tokenize text into words
  fn tokenize(&self, text: &str) -> Vec<String> {
    text
      .to_lowercase()
      .split_whitespace()
      .filter(|s| s.len() > 2) // Skip short words
      .map(|s| s.trim_matches(|c: char| !c.is_alphanumeric()).to_string())
      .filter(|s| !s.is_empty())
      .collect()
  }

  /// Normalize code for embedding
  fn normalize_code(&self, code: &str, language: &str) -> String {
    let mut normalized = String::new();

    for line in code.lines() {
      let trimmed = line.trim();

      // Skip comments
      if language == "rust"
        && (trimmed.starts_with("//") || trimmed.starts_with("/*"))
      {
        continue;
      }
      if (language == "typescript" || language == "javascript")
        && (trimmed.starts_with("//") || trimmed.starts_with("/*"))
      {
        continue;
      }
      if language == "python" && trimmed.starts_with("#") {
        continue;
      }

      normalized.push_str(trimmed);
      normalized.push(' ');
    }

    normalized
  }
}

impl Default for EmbeddingGenerator {
  fn default() -> Self {
    Self::new().unwrap()
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_tokenize() {
    let embedder = EmbeddingGenerator::new().unwrap();
    let tokens = embedder.tokenize("Hello, world! This is a test.");
    assert!(tokens.contains(&"hello".to_string()));
    assert!(tokens.contains(&"world".to_string()));
    assert!(tokens.contains(&"test".to_string()));
  }

  #[test]
  fn test_cosine_similarity() {
    let embedder = EmbeddingGenerator::new().unwrap();
    let v1 = vec![1.0, 0.0, 0.0];
    let v2 = vec![1.0, 0.0, 0.0];
    let v3 = vec![0.0, 1.0, 0.0];

    assert!((embedder.cosine_similarity(&v1, &v2) - 1.0).abs() < 0.001);
    assert!((embedder.cosine_similarity(&v1, &v3) - 0.0).abs() < 0.001);
  }

  #[test]
  fn test_embed_text() {
    let mut embedder = EmbeddingGenerator::new().unwrap();

    // Build vocabulary
    let docs = vec![
      "authentication security login".to_string(),
      "database query search".to_string(),
      "api route endpoint".to_string(),
    ];
    embedder.build_vocabulary(&docs);

    let embedding = embedder.embed_text("authentication login").unwrap();
    assert_eq!(embedding.len(), 384);

    // Should have non-zero values for known words
    let sum: f32 = embedding.iter().sum();
    assert!(sum > 0.0);
  }

  #[test]
  fn test_normalize_code() {
    let embedder = EmbeddingGenerator::new().unwrap();

    let rust_code = r#"
      // This is a comment
      fn main() {
        println!("Hello");
      }
    "#;

    let normalized = embedder.normalize_code(rust_code, "rust");
    assert!(!normalized.contains("//"));
    assert!(normalized.contains("fn main"));
  }
}

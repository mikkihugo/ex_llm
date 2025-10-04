//! TF-IDF Text Embedding
//!
//! Copied from @primecode/neural-ml/pattern_recognition.rs
//! Simplified for code embedding use case.

use super::{EmbeddingError, EMBEDDING_DIM};
use anyhow::Result;
use std::collections::{HashMap, HashSet};

/// TF-IDF based text embedding model
pub struct TfIdfEmbedding {
    vocabulary: HashMap<String, usize>,
    idf_scores: HashMap<String, f32>,
    embedding_dim: usize,
    min_df: usize,
    max_df: f32,
}

impl TfIdfEmbedding {
    /// Create new TF-IDF embedding model
    pub fn new(embedding_dim: usize) -> Self {
        Self {
            vocabulary: HashMap::new(),
            idf_scores: HashMap::new(),
            embedding_dim,
            min_df: 1,      // Minimum document frequency
            max_df: 0.95,   // Maximum document frequency (95%)
        }
    }

    /// Create with default dimension
    pub fn default() -> Self {
        Self::new(EMBEDDING_DIM)
    }

    /// Fit the model on a corpus
    pub fn fit(&mut self, corpus: &[&str]) -> Result<()> {
        if corpus.is_empty() {
            return Err(EmbeddingError::EmptyCorpus.into());
        }

        // Build vocabulary
        let mut term_doc_count: HashMap<String, usize> = HashMap::new();
        let mut all_terms: HashSet<String> = HashSet::new();

        for document in corpus {
            let terms: HashSet<String> = self.tokenize(document).into_iter().collect();
            for term in &terms {
                *term_doc_count.entry(term.clone()).or_insert(0) += 1;
                all_terms.insert(term.clone());
            }
        }

        // Filter terms by document frequency
        let n_docs = corpus.len() as f32;
        self.vocabulary.clear();
        self.idf_scores.clear();

        for term in all_terms {
            let doc_freq = *term_doc_count.get(&term).unwrap_or(&0) as f32;

            // Filter by min/max document frequency
            if doc_freq >= self.min_df as f32 && doc_freq / n_docs <= self.max_df {
                if self.vocabulary.len() < self.embedding_dim {
                    let vocab_idx = self.vocabulary.len();
                    self.vocabulary.insert(term.clone(), vocab_idx);

                    // Compute IDF score: log(N / df)
                    let idf = (n_docs / doc_freq).ln();
                    self.idf_scores.insert(term, idf);
                }
            }
        }

        Ok(())
    }

    /// Generate embedding for text
    pub fn embed(&self, text: &str) -> Result<Vec<f32>> {
        let mut embedding = vec![0.0; self.embedding_dim];
        let tf_scores = self.compute_tf(text);

        for (term, tf_score) in tf_scores {
            if let (Some(&vocab_idx), Some(&idf_score)) =
                (self.vocabulary.get(&term), self.idf_scores.get(&term))
            {
                if vocab_idx < self.embedding_dim {
                    embedding[vocab_idx] = tf_score * idf_score;
                }
            }
        }

        // L2 normalize
        let norm = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 1e-10 {
            for val in &mut embedding {
                *val /= norm;
            }
        }

        Ok(embedding)
    }

    /// Generate embeddings for multiple texts
    pub fn embed_batch(&self, texts: &[&str]) -> Result<Vec<Vec<f32>>> {
        texts.iter().map(|text| self.embed(text)).collect()
    }

    /// Tokenize text into terms (code-aware)
    fn tokenize(&self, text: &str) -> Vec<String> {
        text
            // Split on whitespace and common code delimiters
            .split(|c: char| c.is_whitespace() || "(){}[]<>.,;:".contains(c))
            .map(|token| {
                // Handle camelCase and snake_case
                token
                    .to_lowercase()
                    .trim_matches(|c: char| !c.is_alphanumeric() && c != '_')
                    .to_string()
            })
            .filter(|token| !token.is_empty() && token.len() > 1)
            .collect()
    }

    /// Compute term frequency scores for document
    fn compute_tf(&self, document: &str) -> HashMap<String, f32> {
        let terms = self.tokenize(document);
        let mut tf_scores = HashMap::new();
        let total_terms = terms.len() as f32;

        if total_terms == 0.0 {
            return tf_scores;
        }

        for term in terms {
            *tf_scores.entry(term).or_insert(0.0) += 1.0;
        }

        // Normalize by document length
        for (_, score) in &mut tf_scores {
            *score /= total_terms;
        }

        tf_scores
    }

    /// Get vocabulary size
    pub fn vocab_size(&self) -> usize {
        self.vocabulary.len()
    }

    /// Get embedding dimension
    pub fn dim(&self) -> usize {
        self.embedding_dim
    }

    /// Check if model is trained
    pub fn is_trained(&self) -> bool {
        !self.vocabulary.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tfidf_basic() {
        let mut model = TfIdfEmbedding::new(10);

        let corpus = vec![
            "function authenticate user login",
            "function verify user credentials",
            "async handler login request",
        ];

        model.fit(&corpus).unwrap();
        assert!(model.is_trained());
        assert!(model.vocab_size() > 0);

        let embedding = model.embed("authenticate user").unwrap();
        assert_eq!(embedding.len(), 10);

        // Check normalization
        let norm: f32 = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-5 || norm == 0.0);
    }

    #[test]
    fn test_tokenization() {
        let model = TfIdfEmbedding::default();

        let tokens = model.tokenize("getUserById(user_id)");
        assert!(tokens.contains(&"getuserbyid".to_string()));
        assert!(tokens.contains(&"user_id".to_string()));
    }
}

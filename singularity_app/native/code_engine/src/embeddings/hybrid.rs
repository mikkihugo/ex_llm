//! Hybrid Code Embedder
//!
//! Combines TF-IDF (fast) with optional transformer (semantic) embeddings.
//! Can also use LLM for semantic expansion and disambiguation.

use super::{
    similarity::{SimilarityMetric, SimilarityMetrics},
    tfidf::TfIdfEmbedding,
    transformer::TransformerEmbedder,
    llm::CachedLLMExpander,
    EmbeddingError, EMBEDDING_DIM, MIN_CONFIDENCE,
};
use crate::codebase::metadata::FileAnalysis;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Hybrid embedding combining TF-IDF and semantic vectors
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HybridEmbedding {
    /// TF-IDF vector (keyword-based)
    pub tfidf: Vec<f32>,

    /// Semantic vector (optional, from transformer or LLM)
    pub semantic: Option<Vec<f32>>,

    /// Code file path
    pub file_path: String,

    /// Searchable text that was embedded
    pub text: String,
}

/// Code similarity match result
#[derive(Clone, Debug)]
pub struct CodeMatch {
    pub file_path: String,
    pub similarity: f32,
    pub confidence: f32,
    pub match_type: MatchType,
}

#[derive(Clone, Debug, PartialEq)]
pub enum MatchType {
    Exact,      // TF-IDF and semantic both high
    Keyword,    // TF-IDF high, semantic low/missing
    Semantic,   // Semantic high, TF-IDF low
    Weak,       // Both low but above threshold
}

/// Configuration for hybrid embedder
#[derive(Clone, Debug)]
pub struct HybridConfig {
    /// TF-IDF weight in combined score (0.0 - 1.0)
    pub tfidf_weight: f32,

    /// Semantic weight in combined score (0.0 - 1.0)
    pub semantic_weight: f32,

    /// Pre-filter factor (how many candidates to keep from TF-IDF stage)
    pub prefilter_factor: usize,

    /// Enable LLM semantic expansion
    pub enable_llm_expansion: bool,
}

impl Default for HybridConfig {
    fn default() -> Self {
        Self {
            tfidf_weight: 0.4,      // Structural/keyword
            semantic_weight: 0.6,   // Meaning
            prefilter_factor: 10,   // Search 10x candidates in stage 1
            enable_llm_expansion: false, // Off by default
        }
    }
}

/// Main hybrid code embedder
pub struct HybridCodeEmbedder {
    /// TF-IDF model (always available)
    tfidf: TfIdfEmbedding,

    /// Optional transformer model
    transformer: Option<Box<dyn TransformerEmbedder>>,

    /// Configuration
    config: HybridConfig,

    /// Stored embeddings (file_path -> embedding)
    pub embeddings: HashMap<String, HybridEmbedding>,

    /// LLM expander (optional)
    llm_expander: Option<CachedLLMExpander>,
}

impl HybridCodeEmbedder {
    /// Create new hybrid embedder
    pub fn new(config: HybridConfig) -> Self {
        // Initialize LLM expander if enabled
        let llm_expander = if config.enable_llm_expansion {
            Some(CachedLLMExpander::builtin()) // Default to built-in
        } else {
            None
        };

        Self {
            tfidf: TfIdfEmbedding::new(EMBEDDING_DIM),
            transformer: None,
            config,
            embeddings: HashMap::new(),
            llm_expander,
        }
    }

    /// Create with default configuration
    pub fn default() -> Self {
        Self::new(HybridConfig::default())
    }

    /// Set transformer model (optional)
    pub fn with_transformer(mut self, transformer: Box<dyn TransformerEmbedder>) -> Self {
        self.transformer = Some(transformer);
        self
    }

    /// Set LLM expander (replaces built-in)
    pub fn with_llm_expander(mut self, expander: CachedLLMExpander) -> Self {
        self.llm_expander = Some(expander);
        self
    }

    /// Learn from parsed code files
    pub fn learn_from_analyses(&mut self, analyses: &[FileAnalysis]) -> Result<()> {
        if analyses.is_empty() {
            return Err(EmbeddingError::EmptyCorpus.into());
        }

        // Extract searchable text from each file
        let texts: Vec<String> = analyses
            .iter()
            .map(|a| extract_searchable_text(a))
            .collect();

        // Train TF-IDF on code vocabulary
        let text_refs: Vec<&str> = texts.iter().map(|s| s.as_str()).collect();
        self.tfidf.fit(&text_refs)?;

        // Generate and store embeddings for all files
        for (analysis, text) in analyses.iter().zip(texts.iter()) {
            let embedding = self.embed_text(text, &analysis.path)?;
            self.embeddings.insert(analysis.path.clone(), embedding);
        }

        Ok(())
    }

    /// Generate hybrid embedding for text
    pub fn embed_text(&self, text: &str, file_path: &str) -> Result<HybridEmbedding> {
        // Always generate TF-IDF
        let tfidf_vec = self.tfidf.embed(text)?;

        // Optionally generate semantic embedding
        let semantic_vec = if let Some(transformer) = &self.transformer {
            Some(transformer.embed(text)?)
        } else {
            None
        };

        Ok(HybridEmbedding {
            tfidf: tfidf_vec,
            semantic: semantic_vec,
            file_path: file_path.to_string(),
            text: text.to_string(),
        })
    }

    /// Two-stage hybrid search
    pub fn search(&mut self, query: &str, limit: usize) -> Result<Vec<CodeMatch>> {
        // Optionally expand query with LLM
        let expanded_query = if self.config.enable_llm_expansion {
            self.expand_query_with_llm(query)?
        } else {
            query.to_string()
        };

        // Generate query embedding
        let query_embedding = self.embed_text(&expanded_query, "query")?;

        // Stage 1: TF-IDF fast pre-filter
        let prefilter_limit = limit * self.config.prefilter_factor;
        let candidates = self.tfidf_search(&query_embedding, prefilter_limit)?;

        // Stage 2: Semantic re-rank (if transformer available)
        let results = if self.transformer.is_some() {
            self.semantic_rerank(&query_embedding, &candidates, limit)?
        } else {
            // Just use TF-IDF results
            candidates.into_iter().take(limit).collect()
        };

        Ok(results)
    }

    /// Stage 1: Fast TF-IDF pre-filtering
    fn tfidf_search(&self, query: &HybridEmbedding, limit: usize) -> Result<Vec<CodeMatch>> {
        let mut matches = Vec::new();

        for (file_path, embedding) in &self.embeddings {
            let similarity = SimilarityMetrics::cosine_similarity(&query.tfidf, &embedding.tfidf)?;

            if similarity > MIN_CONFIDENCE {
                matches.push(CodeMatch {
                    file_path: file_path.clone(),
                    similarity,
                    confidence: similarity,
                    match_type: MatchType::Keyword,
                });
            }
        }

        // Sort by similarity descending
        matches.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap());
        matches.truncate(limit);

        Ok(matches)
    }

    /// Stage 2: Semantic re-ranking
    fn semantic_rerank(
        &self,
        query: &HybridEmbedding,
        candidates: &[CodeMatch],
        limit: usize,
    ) -> Result<Vec<CodeMatch>> {
        if query.semantic.is_none() {
            return Ok(candidates.to_vec());
        }

        let query_semantic = query.semantic.as_ref().unwrap();
        let mut reranked = Vec::new();

        for candidate in candidates {
            if let Some(embedding) = self.embeddings.get(&candidate.file_path) {
                if let Some(candidate_semantic) = &embedding.semantic {
                    // Compute hybrid score
                    let tfidf_sim =
                        SimilarityMetrics::cosine_similarity(&query.tfidf, &embedding.tfidf)?;
                    let semantic_sim =
                        SimilarityMetrics::cosine_similarity(query_semantic, candidate_semantic)?;

                    let combined_score = self.config.tfidf_weight * tfidf_sim
                        + self.config.semantic_weight * semantic_sim;

                    // Determine match type
                    let match_type = classify_match_type(tfidf_sim, semantic_sim);

                    reranked.push(CodeMatch {
                        file_path: candidate.file_path.clone(),
                        similarity: combined_score,
                        confidence: combined_score,
                        match_type,
                    });
                }
            }
        }

        // Sort by combined score
        reranked.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap());
        reranked.truncate(limit);

        Ok(reranked)
    }

    /// Expand query using LLM (optional enhancement)
    fn expand_query_with_llm(&mut self, query: &str) -> Result<String> {
        if let Some(expander) = &mut self.llm_expander {
            let expansions = expander.expand(query)?;
            Ok(format!("{} {}", query, expansions.join(" ")))
        } else {
            // Fallback to simple rules
            let expanded = expand_code_query(query);
            Ok(format!("{} {}", query, expanded.join(" ")))
        }
    }

    /// Get embedding for a file
    pub fn get_embedding(&self, file_path: &str) -> Option<&HybridEmbedding> {
        self.embeddings.get(file_path)
    }

    /// Number of indexed files
    pub fn indexed_count(&self) -> usize {
        self.embeddings.len()
    }

    /// Is transformer available?
    pub fn has_transformer(&self) -> bool {
        self.transformer.is_some()
    }
}

/// Extract searchable text from file analysis
fn extract_searchable_text(analysis: &FileAnalysis) -> String {
    let mut parts = Vec::new();

    // Add language
    parts.push(analysis.metadata.language.clone());

    // Add file name (without path)
    if let Some(filename) = analysis.path.split('/').last() {
        parts.push(filename.to_string());
    }

    // Add functions
    parts.extend(analysis.metadata.function_names.clone());

    // Add classes
    parts.extend(analysis.metadata.class_names.clone());

    // Add variables
    parts.extend(analysis.metadata.variable_names.clone());

    // Add imports
    parts.extend(analysis.metadata.imports.clone());

    parts.join(" ")
}

/// Classify match based on TF-IDF and semantic scores
fn classify_match_type(tfidf: f32, semantic: f32) -> MatchType {
    let high_threshold = 0.7;
    let low_threshold = 0.3;

    match (tfidf > high_threshold, semantic > high_threshold) {
        (true, true) => MatchType::Exact,
        (true, false) => MatchType::Keyword,
        (false, true) => MatchType::Semantic,
        _ if tfidf > low_threshold || semantic > low_threshold => MatchType::Weak,
        _ => MatchType::Weak,
    }
}

/// Simple code query expansion (can be enhanced with LLM)
fn expand_code_query(query: &str) -> Vec<String> {
    let mut expansions = Vec::new();

    // Common code synonyms
    let synonyms = HashMap::from([
        ("auth", vec!["authentication", "login", "signin", "verify"]),
        ("user", vec!["account", "profile", "person"]),
        ("get", vec!["fetch", "retrieve", "load", "read"]),
        ("set", vec!["update", "save", "write", "store"]),
        ("delete", vec!["remove", "destroy", "drop"]),
        ("create", vec!["add", "insert", "new", "make"]),
    ]);

    for word in query.split_whitespace() {
        let lower = word.to_lowercase();
        if let Some(syns) = synonyms.get(lower.as_str()) {
            expansions.extend(syns.iter().map(|s| s.to_string()));
        }
    }

    expansions
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_query_expansion() {
        let expanded = expand_code_query("get user auth");
        assert!(expanded.contains(&"authentication".to_string()));
        assert!(expanded.contains(&"fetch".to_string()));
    }

    #[test]
    fn test_match_classification() {
        assert_eq!(classify_match_type(0.8, 0.8), MatchType::Exact);
        assert_eq!(classify_match_type(0.8, 0.2), MatchType::Keyword);
        assert_eq!(classify_match_type(0.2, 0.8), MatchType::Semantic);
    }
}

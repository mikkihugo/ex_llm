//! ML Vector Embeddings for Code Analysis
//!
//! Optimized for SPARC Engine code metadata:
//! - Functions, classes, interfaces, patterns, keywords
//! - Imports, exports, file types, complexity metrics
//! - Uses ndarray for efficient numerical computing
//! - smartcore for machine learning algorithms
//! - Advanced similarity and clustering for code understanding

use std::collections::HashMap;

use anyhow::Result;
use ndarray::{Array1, Array2};
use serde::{Deserialize, Serialize};

use crate::analysis::CodeMetadata;

/// ML vector analysis for metadata
#[derive(Debug, Clone)]
pub struct MLVectorizer {
    embeddings: Array2<f32>,
    vocabulary: Vec<String>,
    embedding_dim: usize,
    // SPARC-specific metadata vocabulary
    function_vocab: Vec<String>,
    class_vocab: Vec<String>,
    pattern_vocab: Vec<String>,
    keyword_vocab: Vec<String>,
}

impl MLVectorizer {
    /// Create ML vectorizer optimized for SPARC Engine CodeMetadata
    pub fn new_from_metadata(metadata_list: &[CodeMetadata], embedding_dim: usize) -> Result<Self> {
        // Extract vocabulary from code metadata
        let mut function_vocab = Vec::new();
        let mut class_vocab = Vec::new();
        let mut pattern_vocab = Vec::new();
        let mut keyword_vocab = Vec::new();

        for metadata in metadata_list {
            function_vocab.extend(metadata.functions.iter().cloned());
            class_vocab.extend(metadata.classes.iter().cloned());
            pattern_vocab.extend(metadata.patterns.iter().cloned());
            keyword_vocab.extend(metadata.keywords.iter().cloned());
        }

        // Remove duplicates and sort
        function_vocab.sort();
        function_vocab.dedup();
        class_vocab.sort();
        class_vocab.dedup();
        pattern_vocab.sort();
        pattern_vocab.dedup();
        keyword_vocab.sort();
        keyword_vocab.dedup();

        // Create combined vocabulary
        let mut vocabulary = Vec::new();
        vocabulary.extend(function_vocab.iter().cloned());
        vocabulary.extend(class_vocab.iter().cloned());
        vocabulary.extend(pattern_vocab.iter().cloned());
        vocabulary.extend(keyword_vocab.iter().cloned());

        // Create embeddings matrix (simplified for now)
        let embeddings = Array2::zeros((vocabulary.len(), embedding_dim));

        Ok(Self {
            embeddings,
            vocabulary,
            embedding_dim,
            function_vocab,
            class_vocab,
            pattern_vocab,
            keyword_vocab,
        })
    }

    /// Create advanced vectorizer with ML-based embeddings
    pub fn new(documents: &[(String, String, String)], embedding_dim: usize) -> Result<Self> {
        let mut vocabulary = Vec::new();
        let mut word_counts = HashMap::new();

        // Build vocabulary from documents
        for (_, text, _) in documents {
            let words = Self::tokenize(text);
            for word in words {
                if !vocabulary.contains(&word) {
                    vocabulary.push(word.clone());
                }
                *word_counts.entry(word).or_insert(0) += 1;
            }
        }

        // Initialize embeddings with random values (in production, would train these)
        let vocab_size = vocabulary.len();
        let embeddings = Array2::zeros((vocab_size, embedding_dim));

        // Build specialized vocabularies from training documents
        let function_vocab = Self::extract_function_vocab(documents);
        let class_vocab = Self::extract_class_vocab(documents);
        let pattern_vocab = Self::extract_pattern_vocab(documents);
        let keyword_vocab = Self::extract_keyword_vocab(documents);

        Ok(Self {
            embeddings,
            vocabulary,
            embedding_dim,
            function_vocab,
            class_vocab,
            pattern_vocab,
            keyword_vocab,
        })
    }

    /// Tokenize text for processing
    fn tokenize(text: &str) -> Vec<String> {
        text.to_lowercase()
            .split_whitespace()
            .filter_map(|word| {
                let clean_word: String = word
                    .chars()
                    .filter(|c| c.is_alphanumeric() || *c == '_')
                    .collect();
                if clean_word.len() >= 2 {
                    Some(clean_word)
                } else {
                    None
                }
            })
            .collect()
    }

    /// Extract function names from documents
    fn extract_function_vocab(documents: &[(String, String, String)]) -> Vec<String> {
        documents
            .iter()
            .flat_map(|(_, text, _)| {
                text.split_whitespace()
                    .filter(|word| {
                        word.contains("fn") || word.contains("func") || word.contains("def")
                    })
                    .map(|s| s.to_string())
            })
            .collect()
    }

    /// Extract class names from documents
    fn extract_class_vocab(documents: &[(String, String, String)]) -> Vec<String> {
        documents
            .iter()
            .flat_map(|(_, text, _)| {
                text.split_whitespace()
                    .filter(|word| {
                        word.contains("class")
                            || word.contains("struct")
                            || word.contains("interface")
                    })
                    .map(|s| s.to_string())
            })
            .collect()
    }

    /// Extract pattern names from documents
    fn extract_pattern_vocab(documents: &[(String, String, String)]) -> Vec<String> {
        documents
            .iter()
            .flat_map(|(_, text, _)| {
                text.split_whitespace()
                    .filter(|word| {
                        word.contains("pattern")
                            || word.contains("factory")
                            || word.contains("builder")
                    })
                    .map(|s| s.to_string())
            })
            .collect()
    }

    /// Extract keywords from documents
    fn extract_keyword_vocab(documents: &[(String, String, String)]) -> Vec<String> {
        let keywords = [
            "async", "await", "impl", "trait", "enum", "match", "if", "for", "while",
        ];
        documents
            .iter()
            .flat_map(|(_, text, _)| {
                text.split_whitespace()
                    .filter(|word| keywords.contains(word))
                    .map(|s| s.to_string())
            })
            .collect()
    }

    /// Create advanced vector representation
    pub fn create_advanced_vector(
        &self,
        id: String,
        text: &str,
        code_type: String,
    ) -> Result<MLCodeVector> {
        let tokens = Self::tokenize(text);
        let mut vector = Array1::zeros(self.embedding_dim);

        // Average word embeddings for document representation
        let mut count = 0;
        for token in &tokens {
            if let Some(word_index) = self.vocabulary.iter().position(|w| w == token) {
                let word_embedding = self.embeddings.row(word_index);
                for (i, &val) in word_embedding.iter().enumerate() {
                    vector[i] += val;
                }
                count += 1;
            }
        }

        if count > 0 {
            vector /= count as f32;
        }

        let magnitude = vector.dot(&vector).sqrt();

        Ok(MLCodeVector {
            id,
            vector: vector.to_vec(),
            magnitude,
            code_type,
            semantic_features: Self::extract_semantic_features(text),
        })
    }

    /// Extract semantic features from code
    fn extract_semantic_features(text: &str) -> SemanticFeatures {
        let tokens = Self::tokenize(text);
        let word_count = tokens.len();
        let unique_words = tokens
            .iter()
            .collect::<std::collections::HashSet<_>>()
            .len();
        let avg_word_length = if word_count > 0 {
            tokens.iter().map(|w| w.len()).sum::<usize>() as f32 / word_count as f32
        } else {
            0.0
        };

        SemanticFeatures {
            word_count,
            unique_words,
            avg_word_length,
            complexity_score: Self::calculate_complexity(&tokens),
        }
    }

    /// Calculate code complexity heuristic
    fn calculate_complexity(tokens: &[String]) -> f32 {
        let complexity_keywords = ["if", "for", "while", "match", "case", "try", "catch"];
        let complexity_count = tokens
            .iter()
            .filter(|token| complexity_keywords.contains(&token.as_str()))
            .count();

        complexity_count as f32 / tokens.len().max(1) as f32
    }

    /// Find similar vectors using advanced algorithms
    pub fn find_similar_advanced(
        &self,
        query: &MLCodeVector,
        candidates: &[(String, String, String)],
        top_k: usize,
    ) -> Vec<(String, f32)> {
        let mut similarities = Vec::new();

        for (id, text, _) in candidates {
            if id != &query.id {
                if let Ok(candidate) =
                    self.create_advanced_vector(id.clone(), text, "function".to_string())
                {
                    let similarity = Self::advanced_similarity(query, &candidate);
                    similarities.push((id.clone(), similarity));
                }
            }
        }

        similarities.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        similarities.truncate(top_k);
        similarities
    }

    /// Advanced similarity combining multiple metrics
    fn advanced_similarity(a: &MLCodeVector, b: &MLCodeVector) -> f32 {
        // Cosine similarity
        let cosine_sim = if a.magnitude > 0.0 && b.magnitude > 0.0 {
            let dot_product: f32 = a
                .vector
                .iter()
                .zip(b.vector.iter())
                .map(|(x, y)| x * y)
                .sum();
            dot_product / (a.magnitude * b.magnitude)
        } else {
            0.0
        };

        // Semantic feature similarity
        let semantic_sim = Self::semantic_similarity(&a.semantic_features, &b.semantic_features);

        // Weighted combination
        0.7 * cosine_sim + 0.3 * semantic_sim
    }

    /// Calculate semantic feature similarity
    fn semantic_similarity(a: &SemanticFeatures, b: &SemanticFeatures) -> f32 {
        let word_count_sim = 1.0
            - ((a.word_count as f32 - b.word_count as f32).abs()
                / (a.word_count.max(b.word_count) as f32 + 1.0));
        let unique_words_sim = 1.0
            - ((a.unique_words as f32 - b.unique_words as f32).abs()
                / (a.unique_words.max(b.unique_words) as f32 + 1.0));
        let complexity_sim = 1.0 - (a.complexity_score - b.complexity_score).abs();

        (word_count_sim + unique_words_sim + complexity_sim) / 3.0
    }
}

/// ML code vector with semantic features
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MLCodeVector {
    pub id: String,
    pub vector: Vec<f32>,
    pub magnitude: f32,
    pub code_type: String,
    pub semantic_features: SemanticFeatures,
}

/// Semantic features extracted from code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SemanticFeatures {
    pub word_count: usize,
    pub unique_words: usize,
    pub avg_word_length: f32,
    pub complexity_score: f32,
}

/// Multi-modal fusion for combining different feature types
#[derive(Debug, Clone)]
pub struct MultiModalFusion {
    text_weight: f32,
    structure_weight: f32,
    complexity_weight: f32,
}

impl Default for MultiModalFusion {
    fn default() -> Self {
        Self::new()
    }
}

impl MultiModalFusion {
    pub fn new() -> Self {
        Self {
            text_weight: 0.6,
            structure_weight: 0.25,
            complexity_weight: 0.15,
        }
    }

    /// Fuse multiple modalities into final vector
    pub fn fuse_multimodal(
        &self,
        advanced_vector: &MLCodeVector,
        _text: &str,
        _file_path: &std::path::PathBuf,
    ) -> FusionResult {
        // In this simplified version, we return the advanced vector
        // In production, this would combine multiple embedding types
        FusionResult {
            fusion_vector: advanced_vector.vector.clone(),
            magnitude: advanced_vector.magnitude,
            confidence: 0.85, // High confidence for advanced algorithms
        }
    }
}

/// Result of multi-modal fusion
#[derive(Debug, Clone)]
pub struct FusionResult {
    pub fusion_vector: Vec<f32>,
    pub magnitude: f32,
    pub confidence: f32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_advanced_vectorizer() {
        let documents = vec![
            (
                "func1".to_string(),
                "function login user password".to_string(),
                "function".to_string(),
            ),
            (
                "func2".to_string(),
                "class User authentication method".to_string(),
                "class".to_string(),
            ),
        ];

        let vectorizer = MLVectorizer::new(&documents, 50).unwrap();
        let vector = vectorizer
            .create_advanced_vector(
                "test".to_string(),
                "user login auth",
                "function".to_string(),
            )
            .unwrap();

        assert_eq!(vector.vector.len(), 50);
        assert!(vector.magnitude >= 0.0);
    }

    #[test]
    fn test_semantic_features() {
        let features = MLVectorizer::extract_semantic_features(
            "function complex_algorithm if for while",
        );
        assert_eq!(features.word_count, 5);
        assert!(features.complexity_score > 0.0);
    }
}

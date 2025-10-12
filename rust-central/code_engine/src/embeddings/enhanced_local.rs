//! Enhanced Local Embeddings
//!
//! Rich 384-dimensional vectors combining:
//! - TF-IDF (keyword frequency)
//! - Code structure (complexity, nesting, size)
//! - N-grams (multi-word patterns)
//! - Code patterns (async, error handling, etc.)
//! - Language-specific features

use super::{tfidf::TfIdfEmbedding, EmbeddingError, EMBEDDING_DIM};
use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis};
use anyhow::Result;
use std::collections::HashMap;

/// Enhanced local embedding that combines multiple vector types
pub struct EnhancedLocalEmbedding {
    /// TF-IDF model (vocabulary-based)
    tfidf: TfIdfEmbedding,

    /// Dimension allocation
    dims: DimensionAllocation,
}

/// How 384 dimensions are allocated
#[derive(Clone, Debug)]
pub struct DimensionAllocation {
    pub tfidf_dims: usize,        // 256 dims: keyword frequency
    pub structural_dims: usize,    // 32 dims: code structure
    pub pattern_dims: usize,       // 32 dims: code patterns
    pub ngram_dims: usize,         // 32 dims: bi-grams
    pub language_dims: usize,      // 32 dims: language-specific
}

impl Default for DimensionAllocation {
    fn default() -> Self {
        Self {
            tfidf_dims: 256,
            structural_dims: 32,
            pattern_dims: 32,
            ngram_dims: 32,
            language_dims: 32,
        }
    }
}

impl EnhancedLocalEmbedding {
    /// Create new enhanced local embedder
    pub fn new() -> Self {
        let dims = DimensionAllocation::default();
        Self {
            tfidf: TfIdfEmbedding::new(dims.tfidf_dims),
            dims,
        }
    }

    /// Train on corpus
    pub fn fit(&mut self, analyses: &[FileAnalysis]) -> Result<()> {
        if analyses.is_empty() {
            return Err(EmbeddingError::EmptyCorpus.into());
        }

        // Extract text for TF-IDF
        let texts: Vec<String> = analyses
            .iter()
            .map(|a| extract_text_with_ngrams(a))
            .collect();

        let text_refs: Vec<&str> = texts.iter().map(|s| s.as_str()).collect();
        self.tfidf.fit(&text_refs)?;

        Ok(())
    }

    /// Generate enhanced 384-dim vector
    pub fn embed(&self, analysis: &FileAnalysis) -> Result<Vec<f32>> {
        let mut vector = Vec::with_capacity(EMBEDDING_DIM);

        // 1. TF-IDF features (256 dims)
        let text = extract_text_with_ngrams(analysis);
        let tfidf_vec = self.tfidf.embed(&text)?;
        vector.extend(&tfidf_vec);

        // 2. Structural features (32 dims)
        let structural = extract_structural_features(&analysis.metadata);
        vector.extend(&structural);

        // 3. Pattern features (32 dims)
        let patterns = extract_pattern_features(analysis);
        vector.extend(&patterns);

        // 4. N-gram features (32 dims)
        let ngrams = extract_ngram_features(analysis);
        vector.extend(&ngrams);

        // 5. Language-specific features (32 dims)
        let language = extract_language_features(&analysis.metadata);
        vector.extend(&language);

        // Ensure correct dimension
        vector.truncate(EMBEDDING_DIM);
        while vector.len() < EMBEDDING_DIM {
            vector.push(0.0);
        }

        // L2 normalize entire vector
        let norm = vector.iter().map(|x| x * x).sum::<f32>().sqrt();
        if norm > 1e-10 {
            for val in &mut vector {
                *val /= norm;
            }
        }

        Ok(vector)
    }
}

/// Extract text with n-grams for TF-IDF
fn extract_text_with_ngrams(analysis: &FileAnalysis) -> String {
    let mut parts = Vec::new();

    // Single tokens
    parts.push(analysis.metadata.language.clone());
    parts.extend(analysis.metadata.function_names.clone());
    parts.extend(analysis.metadata.class_names.clone());
    parts.extend(analysis.metadata.variable_names.clone());

    // Bi-grams from function names
    for name in &analysis.metadata.function_names {
        parts.extend(generate_bigrams(name));
    }

    parts.join(" ")
}

/// Generate bi-grams from identifier (camelCase/snake_case aware)
fn generate_bigrams(identifier: &str) -> Vec<String> {
    let tokens = tokenize_identifier(identifier);
    let mut bigrams = Vec::new();

    for window in tokens.windows(2) {
        bigrams.push(format!("{}_{}", window[0], window[1]));
    }

    bigrams
}

/// Tokenize identifier (handles camelCase, snake_case, kebab-case)
fn tokenize_identifier(identifier: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();

    for ch in identifier.chars() {
        if ch == '_' || ch == '-' {
            if !current.is_empty() {
                tokens.push(current.to_lowercase());
                current.clear();
            }
        } else if ch.is_uppercase() {
            if !current.is_empty() {
                tokens.push(current.to_lowercase());
                current.clear();
            }
            current.push(ch);
        } else {
            current.push(ch);
        }
    }

    if !current.is_empty() {
        tokens.push(current.to_lowercase());
    }

    tokens
}

/// Extract structural features (32 dims)
fn extract_structural_features(metadata: &CodebaseMetadata) -> Vec<f32> {
    vec![
        // Size features (normalized by log)
        (metadata.total_lines as f32).ln() / 15.0,           // 0
        (metadata.function_count as f32).ln() / 10.0,        // 1
        (metadata.class_count as f32).ln() / 8.0,            // 2
        (metadata.variable_names.len() as f32).ln() / 12.0,  // 3
        (metadata.imports.len() as f32).ln() / 10.0,         // 4

        // Complexity features (normalized 0-1)
        metadata.cyclomatic_complexity / 100.0,              // 5
        metadata.cognitive_complexity / 100.0,               // 6
        metadata.maintainability_index / 100.0,              // 7
        metadata.halstead_difficulty / 100.0,                // 8
        metadata.halstead_volume / 10000.0,                  // 9

        // Graph features
        metadata.pagerank_score,                             // 10
        metadata.centrality_score,                           // 11
        metadata.dependency_depth / 20.0,                    // 12

        // Code quality
        metadata.code_smells_count as f32 / 50.0,            // 13
        metadata.technical_debt_ratio,                       // 14
        metadata.duplication_percentage / 100.0,             // 15

        // Ratios
        if metadata.total_lines > 0 {
            metadata.function_count as f32 / metadata.total_lines as f32
        } else { 0.0 },                                      // 16

        if metadata.function_count > 0 {
            metadata.class_count as f32 / metadata.function_count as f32
        } else { 0.0 },                                      // 17

        // Fill remaining with zeros (extensible)
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,   // 18-27
        0.0, 0.0, 0.0, 0.0,                                  // 28-31
    ]
}

/// Extract code pattern features (32 dims)
fn extract_pattern_features(analysis: &FileAnalysis) -> Vec<f32> {
    let text = format!(
        "{} {} {}",
        analysis.metadata.function_names.join(" "),
        analysis.metadata.class_names.join(" "),
        analysis.metadata.imports.join(" ")
    ).to_lowercase();

    vec![
        // Async patterns
        if text.contains("async") { 1.0 } else { 0.0 },      // 0
        if text.contains("await") { 1.0 } else { 0.0 },      // 1
        if text.contains("promise") { 1.0 } else { 0.0 },    // 2

        // Error handling
        if text.contains("error") { 1.0 } else { 0.0 },      // 3
        if text.contains("try") { 1.0 } else { 0.0 },        // 4
        if text.contains("catch") { 1.0 } else { 0.0 },      // 5
        if text.contains("result") { 1.0 } else { 0.0 },     // 6

        // Authentication/Security
        if text.contains("auth") { 1.0 } else { 0.0 },       // 7
        if text.contains("login") { 1.0 } else { 0.0 },      // 8
        if text.contains("verify") { 1.0 } else { 0.0 },     // 9
        if text.contains("token") { 1.0 } else { 0.0 },      // 10

        // Database patterns
        if text.contains("query") { 1.0 } else { 0.0 },      // 11
        if text.contains("database") { 1.0 } else { 0.0 },   // 12
        if text.contains("repo") { 1.0 } else { 0.0 },       // 13

        // HTTP/API patterns
        if text.contains("request") { 1.0 } else { 0.0 },    // 14
        if text.contains("response") { 1.0 } else { 0.0 },   // 15
        if text.contains("handler") { 1.0 } else { 0.0 },    // 16
        if text.contains("route") { 1.0 } else { 0.0 },      // 17

        // Testing patterns
        if text.contains("test") { 1.0 } else { 0.0 },       // 18
        if text.contains("mock") { 1.0 } else { 0.0 },       // 19
        if text.contains("fixture") { 1.0 } else { 0.0 },    // 20

        // State management
        if text.contains("state") { 1.0 } else { 0.0 },      // 21
        if text.contains("store") { 1.0 } else { 0.0 },      // 22
        if text.contains("reducer") { 1.0 } else { 0.0 },    // 23

        // Fill remaining
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,              // 24-31
    ]
}

/// Extract n-gram features (32 dims)
fn extract_ngram_features(analysis: &FileAnalysis) -> Vec<f32> {
    let mut bigram_counts: HashMap<String, f32> = HashMap::new();

    // Count bi-grams from function names
    for name in &analysis.metadata.function_names {
        for bigram in generate_bigrams(name) {
            *bigram_counts.entry(bigram).or_insert(0.0) += 1.0;
        }
    }

    // Top 32 most common bi-grams (or zeros)
    let mut counts: Vec<f32> = bigram_counts.values().copied().collect();
    counts.sort_by(|a, b| b.partial_cmp(a).unwrap());
    counts.truncate(32);

    // Normalize
    if let Some(&max) = counts.first() {
        if max > 0.0 {
            counts.iter_mut().for_each(|v| *v /= max);
        }
    }

    while counts.len() < 32 {
        counts.push(0.0);
    }

    counts
}

/// Extract language-specific features (32 dims)
fn extract_language_features(metadata: &CodebaseMetadata) -> Vec<f32> {
    let lang = metadata.language.to_lowercase();
    let text = format!(
        "{} {}",
        metadata.function_names.join(" "),
        metadata.imports.join(" ")
    ).to_lowercase();

    vec![
        // Rust-specific
        if lang == "rust" && text.contains("lifetime") { 1.0 } else { 0.0 },    // 0
        if lang == "rust" && text.contains("borrow") { 1.0 } else { 0.0 },      // 1
        if lang == "rust" && text.contains("unsafe") { 1.0 } else { 0.0 },      // 2
        if lang == "rust" && text.contains("trait") { 1.0 } else { 0.0 },       // 3

        // TypeScript-specific
        if lang == "typescript" && text.contains("generic") { 1.0 } else { 0.0 }, // 4
        if lang == "typescript" && text.contains("interface") { 1.0 } else { 0.0 }, // 5
        if lang == "typescript" && text.contains("type") { 1.0 } else { 0.0 },    // 6

        // Python-specific
        if lang == "python" && text.contains("decorator") { 1.0 } else { 0.0 },  // 7
        if lang == "python" && text.contains("generator") { 1.0 } else { 0.0 },  // 8

        // JavaScript-specific
        if lang == "javascript" && text.contains("prototype") { 1.0 } else { 0.0 }, // 9
        if lang == "javascript" && text.contains("closure") { 1.0 } else { 0.0 },   // 10

        // Go-specific
        if lang == "go" && text.contains("goroutine") { 1.0 } else { 0.0 },     // 11
        if lang == "go" && text.contains("channel") { 1.0 } else { 0.0 },       // 12

        // Java-specific
        if lang == "java" && text.contains("annotation") { 1.0 } else { 0.0 },  // 13
        if lang == "java" && text.contains("reflection") { 1.0 } else { 0.0 },  // 14

        // Fill remaining
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,   // 15-24
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,                   // 25-31
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identifier_tokenization() {
        assert_eq!(
            tokenize_identifier("getUserById"),
            vec!["get", "user", "by", "id"]
        );
        assert_eq!(
            tokenize_identifier("user_auth_handler"),
            vec!["user", "auth", "handler"]
        );
    }

    #[test]
    fn test_bigram_generation() {
        let bigrams = generate_bigrams("getUserById");
        assert!(bigrams.contains(&"get_user".to_string()));
        assert!(bigrams.contains(&"user_by".to_string()));
        assert!(bigrams.contains(&"by_id".to_string()));
    }

    #[test]
    fn test_enhanced_embedding_dims() {
        let mut embedder = EnhancedLocalEmbedding::new();

        let analysis = FileAnalysis {
            path: "test.rs".to_string(),
            content_hash: "abc".to_string(),
            metadata: CodebaseMetadata {
                language: "rust".to_string(),
                total_lines: 100,
                function_count: 5,
                function_names: vec!["getUserById".to_string()],
                ..Default::default()
            },
        };

        embedder.fit(&[analysis.clone()]).unwrap();
        let vec = embedder.embed(&analysis).unwrap();

        assert_eq!(vec.len(), 384);

        // Check normalization
        let norm: f32 = vec.iter().map(|x| x * x).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-5 || norm == 0.0);
    }
}

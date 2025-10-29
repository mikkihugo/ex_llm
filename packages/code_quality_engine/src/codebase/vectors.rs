//! # Vector Analysis Module
//!
//! Consolidated vector capabilities for code analysis.
//! Integrates semantic vectors, embeddings, and similarity analysis.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Unified vector representation for code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeVector {
    /// Unique identifier for this vector
    pub id: String,
    /// The actual vector data
    pub vector: Vec<f32>,
    /// Cached magnitude for faster cosine similarity
    pub magnitude: f32,
    /// Type of code this vector represents
    pub code_type: String, // "function", "class", "module", "file"
    /// Source file path
    pub file_path: String,
    /// Additional metadata
    pub metadata: HashMap<String, String>,
}

impl CodeVector {
    /// Create a new code vector
    pub fn new(id: String, vector: Vec<f32>, code_type: String, file_path: String) -> Self {
        let magnitude = Self::calculate_magnitude(&vector);
        Self {
            id,
            vector,
            magnitude,
            code_type,
            file_path,
            metadata: HashMap::new(),
        }
    }

    /// Calculate vector magnitude
    fn calculate_magnitude(vector: &[f32]) -> f32 {
        vector.iter().map(|x| x * x).sum::<f32>().sqrt()
    }

    /// Calculate cosine similarity with another vector
    pub fn cosine_similarity(&self, other: &CodeVector) -> f32 {
        if self.magnitude == 0.0 || other.magnitude == 0.0 {
            return 0.0;
        }

        let dot_product: f32 = self
            .vector
            .iter()
            .zip(other.vector.iter())
            .map(|(a, b)| a * b)
            .sum();

        dot_product / (self.magnitude * other.magnitude)
    }
}

/// Vector similarity result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorSimilarity {
    /// Target code ID
    pub code_id: String,
    /// Similarity score (0.0 to 1.0)
    pub similarity_score: f32,
    /// Type of code
    pub code_type: String,
    /// File path
    pub file_path: String,
}

/// Vector store for managing code vectors
#[derive(Debug, Clone)]
pub struct VectorStore {
    /// Vectors indexed by ID
    vectors: HashMap<String, CodeVector>,
    /// Vectors indexed by file path
    file_vectors: HashMap<String, Vec<String>>, // file_path -> vector_ids
}

impl VectorStore {
    /// Create a new vector store
    pub fn new() -> Self {
        Self {
            vectors: HashMap::new(),
            file_vectors: HashMap::new(),
        }
    }

    /// Add a vector to the store
    pub fn add_vector(&mut self, vector: CodeVector) {
        let id = vector.id.clone();
        let file_path = vector.file_path.clone();

        // Add to main store
        self.vectors.insert(id.clone(), vector);

        // Add to file index
        self.file_vectors
            .entry(file_path)
            .or_default()
            .push(id);
    }

    /// Get a vector by ID
    pub fn get_vector(&self, id: &str) -> Option<&CodeVector> {
        self.vectors.get(id)
    }

    /// Get all vectors for a file
    pub fn get_file_vectors(&self, file_path: &str) -> Vec<&CodeVector> {
        self.file_vectors
            .get(file_path)
            .map(|ids| ids.iter().filter_map(|id| self.vectors.get(id)).collect())
            .unwrap_or_default()
    }

    /// Find similar vectors
    pub fn find_similar(
        &self,
        query_vector: &CodeVector,
        threshold: f32,
        limit: usize,
    ) -> Vec<VectorSimilarity> {
        let mut similarities: Vec<VectorSimilarity> = self
            .vectors
            .values()
            .filter(|v| v.id != query_vector.id) // Exclude self
            .map(|v| VectorSimilarity {
                code_id: v.id.clone(),
                similarity_score: query_vector.cosine_similarity(v),
                code_type: v.code_type.clone(),
                file_path: v.file_path.clone(),
            })
            .filter(|s| s.similarity_score >= threshold)
            .collect();

        // Sort by similarity score (highest first)
        similarities.sort_by(|a, b| b.similarity_score.partial_cmp(&a.similarity_score).unwrap());

        // Limit results
        similarities.truncate(limit);
        similarities
    }

    /// Get store statistics
    pub fn stats(&self) -> VectorStoreStats {
        let mut type_counts = HashMap::new();
        for vector in self.vectors.values() {
            *type_counts.entry(vector.code_type.clone()).or_insert(0) += 1;
        }

        VectorStoreStats {
            total_vectors: self.vectors.len(),
            total_files: self.file_vectors.len(),
            type_counts,
        }
    }
}

/// Vector store statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorStoreStats {
    /// Total number of vectors
    pub total_vectors: usize,
    /// Total number of files with vectors
    pub total_files: usize,
    /// Count by code type
    pub type_counts: HashMap<String, usize>,
}

/// Vectorizer for creating vectors from code
///
/// Provides TF-IDF based vectorization as a fast CPU fallback when embedding_engine
/// (GPU-accelerated transformer models) is not available or for quick local operations.
#[derive(Debug, Clone)]
pub struct CodeVectorizer {
    /// Vector dimensions
    pub dimensions: usize,
    /// Model type/name
    pub model_type: String,
    /// Vocabulary for TF-IDF mapping (word -> index)
    vocabulary: Vec<String>,
    /// IDF (Inverse Document Frequency) scores for each vocabulary term
    idf_scores: Vec<f32>,
}

impl CodeVectorizer {
    /// Create a new vectorizer with vocabulary
    pub fn new(dimensions: usize, model_type: String) -> Self {
        Self {
            dimensions,
            model_type,
            vocabulary: Vec::new(),
            idf_scores: Vec::new(),
        }
    }

    /// Build vocabulary and IDF scores from a corpus of documents
    ///
    /// This should be called during training/initialization with a representative
    /// corpus of code snippets. The vocabulary and IDF scores will be used for
    /// all subsequent vectorization operations.
    pub fn build_vocabulary(&mut self, documents: &[String]) {
        use std::collections::HashMap;

        if documents.is_empty() {
            return;
        }

        // Count document frequency for each term
        let mut term_document_count: HashMap<String, usize> = HashMap::new();
        let mut all_terms = std::collections::HashSet::new();

        for doc in documents {
            let terms: std::collections::HashSet<String> = doc
                .split_whitespace()
                .filter(|word| word.len() > 2) // Filter short words
                .map(|word| word.to_lowercase())
                .collect();

            for term in terms {
                all_terms.insert(term.clone());
                *term_document_count.entry(term).or_insert(0) += 1;
            }
        }

        // Build vocabulary (most frequent terms up to dimensions limit)
        let mut term_freq: Vec<(String, usize)> = term_document_count.into_iter().collect();
        term_freq.sort_by(|a, b| b.1.cmp(&a.1)); // Sort by frequency descending

        // Take top dimensions terms as vocabulary
        self.vocabulary = term_freq
            .into_iter()
            .take(self.dimensions)
            .map(|(term, _)| term)
            .collect();

        // Calculate IDF scores: log(total_docs / doc_freq)
        let total_docs = documents.len() as f32;
        self.idf_scores = Vec::new();

        for term in &self.vocabulary {
            let doc_freq = documents
                .iter()
                .filter(|doc| doc.to_lowercase().contains(term))
                .count() as f32;

            let idf = (total_docs / (1.0 + doc_freq)).ln() + 1.0; // +1 smoothing
            self.idf_scores.push(idf);
        }
    }

    /// Get the vocabulary size
    pub fn vocabulary_size(&self) -> usize {
        self.vocabulary.len()
    }

    /// Check if vocabulary is built
    pub fn has_vocabulary(&self) -> bool {
        !self.vocabulary.is_empty() && self.vocabulary.len() == self.idf_scores.len()
    }

    /// Create a vector from code content
    ///
    /// If vocabulary is built, uses proper TF-IDF weighting.
    /// Otherwise, falls back to hash-based vectorization.
    pub fn vectorize(&self, code_content: &str, code_type: &str) -> Result<CodeVector> {
        let vector = if self.has_vocabulary() {
            self.create_tfidf_vector(code_content)
        } else {
            self.create_simple_vector(code_content)
        };

        Ok(CodeVector::new(
            format!("{}:{}", code_type, self.hash_content(code_content)),
            vector,
            code_type.to_string(),
            "unknown".to_string(), // File path would be provided separately
        ))
    }

    /// Create a TF-IDF weighted vector using built vocabulary
    fn create_tfidf_vector(&self, content: &str) -> Vec<f32> {
        let mut vector = vec![0.0; self.vocabulary.len()];

        // Tokenize content
        let words: Vec<String> = content
            .split_whitespace()
            .filter(|word| word.len() > 2)
            .map(|word| word.to_lowercase())
            .collect();

        // Calculate term frequencies
        let mut term_freq = std::collections::HashMap::new();
        for word in &words {
            *term_freq.entry(word.clone()).or_insert(0) += 1;
        }

        // Apply TF-IDF weighting
        for (term, tf) in term_freq {
            if let Some(vocab_idx) = self.vocabulary.iter().position(|v| v == &term) {
                let idf = self.idf_scores[vocab_idx];
                // TF-IDF: (term_freq / total_terms) * IDF
                let tf_normalized = tf as f32 / words.len() as f32;
                vector[vocab_idx] = tf_normalized * idf;
            }
        }

        // Normalize vector
        let magnitude: f32 = vector.iter().map(|x| x * x).sum::<f32>().sqrt();
        if magnitude > 0.0 {
            for v in &mut vector {
                *v /= magnitude;
            }
        }

        vector
    }

    /// Create a semantic vector from content using hash-based approach (fallback)
    fn create_simple_vector(&self, content: &str) -> Vec<f32> {
        let mut vector = vec![0.0; self.dimensions];

        // Tokenize content into words
        let words: Vec<&str> = content
            .split_whitespace()
            .filter(|word| word.len() > 2) // Filter short words
            .collect();

        // Create word frequency map
        let mut word_freq = std::collections::HashMap::new();
        for word in &words {
            *word_freq.entry(word.to_lowercase()).or_insert(0) += 1;
        }

        // Convert to vector using hash-based indexing
        for (word, freq) in word_freq {
            let hash = self.hash_word(&word);
            let index = hash % self.dimensions;
            vector[index] += freq as f32;
        }

        // Apply TF-IDF-like weighting (log scaling)
        for v in &mut vector {
            if *v > 0.0 {
                *v = (1.0 + v.ln()).ln(); // Log scaling for better distribution
            }
        }

        // Normalize
        let magnitude: f32 = vector.iter().map(|x| x * x).sum::<f32>().sqrt();
        if magnitude > 0.0 {
            for v in &mut vector {
                *v /= magnitude;
            }
        }

        vector
    }

    /// Hash word for vector indexing
    fn hash_word(&self, word: &str) -> usize {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        word.hash(&mut hasher);
        hasher.finish() as usize
    }

    /// Hash content for ID generation
    fn hash_content(&self, content: &str) -> String {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        content.hash(&mut hasher);
        format!("{:x}", hasher.finish())
    }
}

impl Default for VectorStore {
    fn default() -> Self {
        Self::new()
    }
}

impl Default for CodeVectorizer {
    fn default() -> Self {
        Self::new(128, "simple".to_string())
    }
}

//! # Vector Analysis Module
//!
//! Consolidated vector capabilities for code analysis.
//! Integrates semantic vectors, embeddings, and similarity analysis.

use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use anyhow::Result;

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

    let dot_product: f32 = self.vector.iter()
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
    self.file_vectors.entry(file_path)
      .or_insert_with(Vec::new)
      .push(id);
  }

  /// Get a vector by ID
  pub fn get_vector(&self, id: &str) -> Option<&CodeVector> {
    self.vectors.get(id)
  }

  /// Get all vectors for a file
  pub fn get_file_vectors(&self, file_path: &str) -> Vec<&CodeVector> {
    self.file_vectors.get(file_path)
      .map(|ids| ids.iter().filter_map(|id| self.vectors.get(id)).collect())
      .unwrap_or_default()
  }

  /// Find similar vectors
  pub fn find_similar(&self, query_vector: &CodeVector, threshold: f32, limit: usize) -> Vec<VectorSimilarity> {
    let mut similarities: Vec<VectorSimilarity> = self.vectors.values()
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
#[derive(Debug, Clone)]
pub struct CodeVectorizer {
  /// Vector dimensions
  pub dimensions: usize,
  /// Model type/name
  pub model_type: String,
  /// Vocabulary for TF-IDF
  vocabulary: Vec<String>,
  /// IDF scores
  idf_scores: Vec<f32>,
}

impl CodeVectorizer {
  /// Create a new vectorizer
  pub fn new(dimensions: usize, model_type: String) -> Self {
    Self {
      dimensions,
      model_type,
      vocabulary: Vec::new(),
      idf_scores: Vec::new(),
    }
  }

  /// Create a vector from code content
  pub fn vectorize(&self, code_content: &str, code_type: &str) -> Result<CodeVector> {
    // For now, create a simple hash-based vector
    // In a real implementation, this would use proper embeddings
    let vector = self.create_simple_vector(code_content);
    
    Ok(CodeVector::new(
      format!("{}:{}", code_type, self.hash_content(code_content)),
      vector,
      code_type.to_string(),
      "unknown".to_string(), // File path would be provided separately
    ))
  }

  /// Create a semantic vector from content using TF-IDF-like approach
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
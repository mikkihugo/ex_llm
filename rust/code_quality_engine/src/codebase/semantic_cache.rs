//! Pure computation semantic embeddings cache
//!
//! This module provides pure computation functions for semantic embeddings.
//! All data is passed in via parameters and returned as results.
//! No I/O operations - designed for NIF usage.

use anyhow::Result;
use std::collections::HashMap;

/// Pure computation semantic cache
/// 
/// This struct holds cached embeddings in memory for the current computation.
/// No persistent storage - data is passed in via NIF parameters.
pub struct SemanticCache {
    /// In-memory cache of content hash -> embedding
    cache: HashMap<String, Vec<f32>>,
}

impl SemanticCache {
    /// Create new semantic cache
    pub fn new() -> Self {
        Self {
            cache: HashMap::new(),
        }
    }

    /// Get embedding from cache
    pub fn get(&self, content_hash: &str) -> Option<&Vec<f32>> {
        self.cache.get(content_hash)
    }

    /// Store embedding in cache
    pub fn store(&mut self, content_hash: String, embedding: Vec<f32>) {
        self.cache.insert(content_hash, embedding);
    }

    /// Check if content is cached
    pub fn is_cached(&self, content_hash: &str) -> bool {
        self.cache.contains_key(content_hash)
    }

    /// Get cache statistics
    pub fn stats(&self) -> CacheStats {
        CacheStats {
            cached_embeddings: self.cache.len(),
            memory_usage: self.cache.values()
                .map(|v| v.len() * 4) // 4 bytes per f32
                .sum(),
        }
    }
}

/// Cache statistics
#[derive(Debug, Clone)]
pub struct CacheStats {
    pub cached_embeddings: usize,
    pub memory_usage: usize,
}

impl Default for SemanticCache {
    fn default() -> Self {
        Self::new()
    }
}

//! Prompt caching module
//!
//! Caching and retrieval of optimized prompts.

use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Prompt cache
pub struct PromptCache {
    cache: HashMap<String, CacheEntry>,
}

impl Default for PromptCache {
    fn default() -> Self {
        Self::new()
    }
}

impl PromptCache {
    pub fn new() -> Self {
        Self {
            cache: HashMap::new(),
        }
    }

    pub fn store(&mut self, key: &str, entry: CacheEntry) -> Result<()> {
        self.cache.insert(key.to_string(), entry);
        Ok(())
    }

    pub fn get(&self, key: &str) -> Option<&CacheEntry> {
        self.cache.get(key)
    }
}

/// Cache entry
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CacheEntry {
    pub prompt: String,
    pub score: f64,
    pub timestamp: u64,
}

/// Cache statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub total_entries: u32,
    pub hit_rate: f64,
    pub avg_score: f64,
}

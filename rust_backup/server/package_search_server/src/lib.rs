//! Package Search Server
//!
//! Search, indexing and query interface.
//! Handles full-text search with Tantivy, semantic search with pgvector,
//! query processing, ranking, and search result aggregation.

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod search;
pub mod cache;
pub mod nats_service;

/// Search server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchConfig {
    pub index_path: String,
    pub cache_size: usize,
    pub max_results: usize,
    pub similarity_threshold: f32,
}

/// Package search server
pub struct PackageSearchServer {
    config: SearchConfig,
    search_index: search::VectorIndex,
    cache: cache::Cache,
}

impl PackageSearchServer {
    pub fn new(config: SearchConfig) -> Self {
        Self {
            config,
            search_index: search::VectorIndex::new(&config.index_path),
            cache: cache::Cache::with_capacity(config.cache_size),
        }
    }

    /// Index package data
    pub async fn index_package(&mut self, package_data: &PackageData) -> Result<()> {
        self.search_index.add_package(package_data).await?;
        Ok(())
    }

    /// Search packages
    pub async fn search(&self, query: &str, filters: &SearchFilters) -> Result<Vec<SearchResult>> {
        // Check cache first
        let cache_key = format!("{}:{}", query, serde_json::to_string(filters)?);
        if let Some(cached) = self.cache.get(&cache_key) {
            return Ok(cached);
        }

        // Perform search
        let results = self.search_index.search(query, filters).await?;
        
        // Cache results
        self.cache.put(cache_key, results.clone());
        
        Ok(results)
    }

    /// Get search statistics
    pub fn get_stats(&self) -> search::IndexStats {
        self.search_index.get_stats()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageData {
    pub package_name: String,
    pub ecosystem: String,
    pub version: String,
    pub description: String,
    pub code_snippets: Vec<String>,
    pub embeddings: Vec<Vec<f32>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchFilters {
    pub ecosystem: Option<String>,
    pub min_score: Option<f32>,
    pub max_results: Option<usize>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub package_name: String,
    pub ecosystem: String,
    pub version: String,
    pub score: f32,
    pub snippet: String,
}

impl Default for SearchConfig {
    fn default() -> Self {
        Self {
            index_path: "./data/search_index".to_string(),
            cache_size: 10000,
            max_results: 100,
            similarity_threshold: 0.7,
        }
    }
}

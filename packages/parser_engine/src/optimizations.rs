//! Performance optimizations for universal parser
//!
//! This module provides caching, parallel processing, memory management, and other
//! performance optimizations that are shared across all language parsers.

use std::{
  collections::HashMap,
  hash::{Hash, Hasher},
  sync::Arc,
  time::{Duration, Instant},
};

use anyhow::Result;
use dashmap::DashMap;
use lru::LruCache;
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;
use tracing::{debug, info};

use crate::{languages::ProgrammingLanguage, AnalysisResult};

/// Analysis cache for storing and retrieving analysis results
#[derive(Debug)]
pub struct AnalysisCache {
  /// LRU cache for analysis results
  cache: Arc<RwLock<LruCache<CacheKey, CacheEntry>>>,
  /// Cache statistics
  stats: Arc<RwLock<CacheStats>>,
  /// Whether caching is enabled
  enabled: bool,
}

/// Cache key for analysis results
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct CacheKey {
  /// Hash of the content
  content_hash: u64,
  /// Language being analyzed
  language: ProgrammingLanguage,
}

/// Cache entry with metadata
#[derive(Debug, Clone)]
struct CacheEntry {
  /// Cached analysis result
  result: AnalysisResult,
  /// When this entry was created
  #[allow(dead_code)]
  created_at: Instant,
  /// Number of times this entry has been accessed
  access_count: u64,
}

/// Cache statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
  /// Total cache hits
  pub hits: u64,
  /// Total cache misses
  pub misses: u64,
  /// Current cache size
  pub current_size: usize,
  /// Maximum cache size
  pub max_size: usize,
  /// Cache hit rate (0.0 to 1.0)
  pub hit_rate: f64,
}

impl Default for CacheStats {
  fn default() -> Self {
    Self { hits: 0, misses: 0, current_size: 0, max_size: 0, hit_rate: 0.0 }
  }
}

impl AnalysisCache {
  /// Create new analysis cache with specified capacity
  pub fn new(capacity: usize) -> Self {
    info!("Creating analysis cache with capacity: {}", capacity);

    Self {
      cache: Arc::new(RwLock::new(LruCache::new(std::num::NonZeroUsize::new(capacity).unwrap()))),
      stats: Arc::new(RwLock::new(CacheStats { max_size: capacity, ..Default::default() })),
      enabled: true,
    }
  }

  /// Create disabled cache (no caching)
  pub fn disabled() -> Self {
    Self {
      cache: Arc::new(RwLock::new(LruCache::new(std::num::NonZeroUsize::new(1).unwrap()))),
      stats: Arc::new(RwLock::new(CacheStats::default())),
      enabled: false,
    }
  }

  /// Get cached analysis result
  pub async fn get(&self, content: &str, language: &ProgrammingLanguage) -> Option<AnalysisResult> {
    if !self.enabled {
      return None;
    }

    let key = CacheKey { content_hash: Self::hash_content(content), language: *language };

    let mut cache = self.cache.write().await;
    let mut stats = self.stats.write().await;

    if let Some(entry) = cache.get_mut(&key) {
      // Update access statistics
      entry.access_count += 1;
      stats.hits += 1;
      stats.hit_rate = stats.hits as f64 / (stats.hits + stats.misses) as f64;

      debug!("Cache hit for {} content (language: {})", content.len(), language);

      Some(entry.result.clone())
    } else {
      stats.misses += 1;
      stats.hit_rate = stats.hits as f64 / (stats.hits + stats.misses) as f64;

      debug!("Cache miss for {} content (language: {})", content.len(), language);

      None
    }
  }

  /// Put analysis result in cache
  pub async fn put(&self, content: &str, language: &ProgrammingLanguage, result: AnalysisResult) {
    if !self.enabled {
      return;
    }

    let key = CacheKey { content_hash: Self::hash_content(content), language: *language };

    let entry = CacheEntry { result, created_at: Instant::now(), access_count: 0 };

    let mut cache = self.cache.write().await;
    let mut stats = self.stats.write().await;

    cache.put(key, entry);
    stats.current_size = cache.len();

    debug!("Cached analysis result for {} content (language: {})", content.len(), language);
  }

  /// Get cache statistics
  pub async fn stats(&self) -> HashMap<String, u64> {
    let stats = self.stats.read().await;
    let mut result = HashMap::new();

    result.insert("hits".to_string(), stats.hits);
    result.insert("misses".to_string(), stats.misses);
    result.insert("current_size".to_string(), stats.current_size as u64);
    result.insert("max_size".to_string(), stats.max_size as u64);
    result.insert("hit_rate_percent".to_string(), (stats.hit_rate * 100.0) as u64);

    result
  }

  /// Clear all cached entries
  pub async fn clear(&self) {
    let mut cache = self.cache.write().await;
    let mut stats = self.stats.write().await;

    cache.clear();
    stats.current_size = 0;
    stats.hits = 0;
    stats.misses = 0;
    stats.hit_rate = 0.0;

    info!("Cache cleared");
  }

  /// Hash content for cache key
  fn hash_content(content: &str) -> u64 {
    use std::collections::hash_map::DefaultHasher;

    let mut hasher = DefaultHasher::new();
    content.hash(&mut hasher);
    hasher.finish()
  }

  /// Clean expired entries (run periodically)
  pub async fn cleanup_expired(&self, _max_age: Duration) {
    if !self.enabled {
      return;
    }

    let cache = self.cache.write().await;
    let mut stats = self.stats.write().await;

    let _now = Instant::now();
    let _expired_keys: Vec<CacheKey> = Vec::new();

    // We can't iterate and modify at the same time with LruCache, so collect keys first
    // Note: This is a simplified cleanup - in practice, we'd need a more sophisticated approach
    let initial_size = cache.len();

    // For now, just update the current size
    stats.current_size = cache.len();

    if initial_size > stats.current_size {
      info!("Cache cleanup: removed {} expired entries", initial_size - stats.current_size);
    }
  }
}

/// Parallel analysis coordinator
#[derive(Debug)]
pub struct ParallelAnalyzer {
  /// Maximum number of concurrent analyses
  max_concurrency: usize,
  /// Semaphore for controlling concurrency
  semaphore: Arc<tokio::sync::Semaphore>,
}

impl ParallelAnalyzer {
  /// Create new parallel analyzer
  pub fn new(max_concurrency: usize) -> Self {
    Self { max_concurrency, semaphore: Arc::new(tokio::sync::Semaphore::new(max_concurrency)) }
  }

  /// Analyze multiple files in parallel
  pub async fn analyze_files<F, Fut>(&self, files: Vec<String>, analyzer: F) -> Vec<Result<AnalysisResult>>
  where
    F: Fn(String) -> Fut + Send + Sync + Clone + 'static,
    Fut: std::future::Future<Output = Result<AnalysisResult>> + Send + 'static,
  {
    let mut tasks = Vec::new();

    for file in files {
      let permit = self.semaphore.clone().acquire_owned().await.unwrap();
      let analyzer = analyzer.clone();

      let task = tokio::spawn(async move {
        let _permit = permit; // Keep permit alive for the duration of the task
        analyzer(file).await
      });

      tasks.push(task);
    }

    // Wait for all tasks to complete
    let mut results = Vec::new();
    for task in tasks {
      match task.await {
        Ok(result) => results.push(result),
        Err(join_error) => results.push(Err(anyhow::anyhow!("Task join error: {}", join_error))),
      }
    }

    results
  }

  /// Get maximum concurrency
  pub fn max_concurrency(&self) -> usize {
    self.max_concurrency
  }

  /// Get available permits
  pub fn available_permits(&self) -> usize {
    self.semaphore.available_permits()
  }
}

/// Memory manager for large file analysis
#[derive(Debug)]
pub struct MemoryCoordinator {
  /// Maximum memory usage (bytes)
  max_memory: usize,
  /// Current memory usage tracking
  current_usage: Arc<RwLock<usize>>,
  /// Memory usage by analysis type
  usage_by_type: Arc<DashMap<String, usize>>,
}

impl MemoryCoordinator {
  /// Create new memory manager
  pub fn new(max_memory: usize) -> Self {
    Self { max_memory, current_usage: Arc::new(RwLock::new(0)), usage_by_type: Arc::new(DashMap::new()) }
  }

  /// Reserve memory for analysis
  pub async fn reserve_memory(&self, amount: usize, analysis_type: &str) -> Result<MemoryReservation> {
    let mut current = self.current_usage.write().await;

    if *current + amount > self.max_memory {
      return Err(anyhow::anyhow!("Memory limit exceeded: requested {}, available {}", amount, self.max_memory - *current));
    }

    *current += amount;
    self.usage_by_type.entry(analysis_type.to_string()).and_modify(|e| *e += amount).or_insert(amount);

    debug!("Reserved {} bytes for {} (total: {} / {})", amount, analysis_type, *current, self.max_memory);

    Ok(MemoryReservation {
      amount,
      analysis_type: analysis_type.to_string(),
      manager: MemoryCoordinatorRef { current_usage: self.current_usage.clone(), usage_by_type: self.usage_by_type.clone() },
    })
  }

  /// Get current memory usage
  pub async fn current_usage(&self) -> usize {
    *self.current_usage.read().await
  }

  /// Get memory usage by analysis type
  pub async fn usage_by_type(&self) -> HashMap<String, usize> {
    self.usage_by_type.iter().map(|entry| (entry.key().clone(), *entry.value())).collect()
  }

  /// Get memory statistics
  pub async fn stats(&self) -> MemoryStats {
    let current = self.current_usage().await;
    let by_type = self.usage_by_type().await;

    MemoryStats {
      current_usage: current,
      max_memory: self.max_memory,
      usage_percentage: (current as f64 / self.max_memory as f64) * 100.0,
      usage_by_type: by_type,
    }
  }
}

/// Memory reservation that automatically releases when dropped
pub struct MemoryReservation {
  amount: usize,
  analysis_type: String,
  manager: MemoryCoordinatorRef,
}

#[derive(Clone)]
struct MemoryCoordinatorRef {
  current_usage: Arc<RwLock<usize>>,
  usage_by_type: Arc<DashMap<String, usize>>,
}

impl Drop for MemoryReservation {
  fn drop(&mut self) {
    let amount = self.amount;
    let analysis_type = self.analysis_type.clone();
    let current_usage = self.manager.current_usage.clone();
    let usage_by_type = self.manager.usage_by_type.clone();

    // Use blocking operations in drop (not ideal but necessary)
    tokio::task::spawn(async move {
      let mut current = current_usage.write().await;
      *current = current.saturating_sub(amount);

      usage_by_type.entry(analysis_type.clone()).and_modify(|e| *e = e.saturating_sub(amount));

      debug!("Released {} bytes for {}", amount, analysis_type);
    });
  }
}

/// Memory usage statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryStats {
  /// Current memory usage (bytes)
  pub current_usage: usize,
  /// Maximum allowed memory (bytes)
  pub max_memory: usize,
  /// Usage percentage (0.0 to 100.0)
  pub usage_percentage: f64,
  /// Memory usage by analysis type
  pub usage_by_type: HashMap<String, usize>,
}

/// Streaming analyzer for large files
#[derive(Debug)]
pub struct StreamingAnalyzer {
  /// Chunk size for streaming (bytes)
  chunk_size: usize,
  /// Overlap between chunks (bytes)
  overlap_size: usize,
}

impl StreamingAnalyzer {
  /// Create new streaming analyzer
  pub fn new(chunk_size: usize, overlap_size: usize) -> Self {
    Self { chunk_size, overlap_size }
  }

  /// Analyze large content in chunks
  pub async fn analyze_streaming<F, Fut>(&self, content: &str, analyzer: F) -> Result<Vec<AnalysisResult>>
  where
    F: Fn(String, usize) -> Fut + Send + Sync,
    Fut: std::future::Future<Output = Result<AnalysisResult>> + Send,
  {
    let content_len = content.len();

    if content_len <= self.chunk_size {
      // Content is small enough to analyze in one go
      let result = analyzer(content.to_string(), 0).await?;
      return Ok(vec![result]);
    }

    let mut results = Vec::new();
    let mut start = 0;
    let mut chunk_index = 0;

    while start < content_len {
      let end = std::cmp::min(start + self.chunk_size, content_len);
      let chunk = &content[start..end];

      debug!("Analyzing chunk {} (bytes {}-{})", chunk_index, start, end);

      let result = analyzer(chunk.to_string(), chunk_index).await?;
      results.push(result);

      // Move to next chunk with overlap
      start = end.saturating_sub(self.overlap_size);
      chunk_index += 1;

      // Prevent infinite loop
      if end == content_len {
        break;
      }
    }

    info!("Streaming analysis completed: {} chunks processed", results.len());
    Ok(results)
  }

  /// Get chunk size
  pub fn chunk_size(&self) -> usize {
    self.chunk_size
  }

  /// Get overlap size
  pub fn overlap_size(&self) -> usize {
    self.overlap_size
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use crate::languages::ProgrammingLanguage;

  #[tokio::test]
  async fn test_analysis_cache() {
    let cache = AnalysisCache::new(10);
    let language = ProgrammingLanguage::Rust;
    let content = "fn main() {}";

    // Initially empty
    assert!(cache.get(content, &language).await.is_none());

    // Create a dummy result
    let result = AnalysisResult {
      file_path: "test.rs".to_string(),
      language: language.to_string(),
      metrics: crate::CodeMetrics {
        lines_of_code: 1,
        lines_of_comments: 0,
        blank_lines: 0,
        total_lines: 1,
        functions: 0,
        classes: 0,
        complexity_score: 1.0,
      },
      singularity_metrics: None,
      tree_sitter_analysis: None,
      dependency_analysis: None,
      analysis_timestamp: chrono::Utc::now(),
    };

    // Put in cache
    cache.put(content, &language, result.clone()).await;

    // Should now be cached
    let cached = cache.get(content, &language).await;
    assert!(cached.is_some());
    assert_eq!(cached.unwrap().file_path, result.file_path);

    // Check stats
    let stats = cache.stats().await;
    assert_eq!(stats["hits"], 1);
    assert_eq!(stats["misses"], 1);
  }

  #[tokio::test]
  async fn test_parallel_analyzer() {
    let analyzer = ParallelAnalyzer::new(2);
    assert_eq!(analyzer.max_concurrency(), 2);
    assert_eq!(analyzer.available_permits(), 2);

    let files = vec!["file1.rs".to_string(), "file2.rs".to_string()];

    let results = analyzer
      .analyze_files(files, |file| async move {
        // Simulate analysis
        tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
        Ok(AnalysisResult {
          file_path: file,
          language: ProgrammingLanguage::Rust.to_string(),
          metrics: crate::CodeMetrics {
            lines_of_code: 1,
            lines_of_comments: 0,
            blank_lines: 0,
            total_lines: 1,
            functions: 0,
            classes: 0,
            complexity_score: 1.0,
          },
          singularity_metrics: None,
          tree_sitter_analysis: None,
          dependency_analysis: None,
          analysis_timestamp: chrono::Utc::now(),
        })
      })
      .await;

    assert_eq!(results.len(), 2);
    assert!(results[0].is_ok());
    assert!(results[1].is_ok());
  }

  #[tokio::test]
  async fn test_memory_manager() {
    let manager = MemoryCoordinator::new(1000);

    // Reserve memory
    let _reservation1 = manager.reserve_memory(300, "analysis1").await.unwrap();
    assert_eq!(manager.current_usage().await, 300);

    let _reservation2 = manager.reserve_memory(400, "analysis2").await.unwrap();
    assert_eq!(manager.current_usage().await, 700);

    // Try to exceed limit
    let result = manager.reserve_memory(400, "analysis3").await;
    assert!(result.is_err());

    // Memory should be released when reservations are dropped
    drop(_reservation1);
    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await; // Allow async drop to complete
  }

  #[tokio::test]
  async fn test_streaming_analyzer() {
    let analyzer = StreamingAnalyzer::new(10, 2);
    let content = "This is a test content that is longer than chunk size";

    let results = analyzer
      .analyze_streaming(content, |chunk, index| async move {
        Ok(AnalysisResult {
          file_path: format!("chunk_{}", index),
          language: ProgrammingLanguage::LanguageNotSupported.to_string(),
          metrics: crate::CodeMetrics {
            lines_of_code: chunk.lines().count() as u64,
            lines_of_comments: 0,
            blank_lines: 0,
            total_lines: chunk.lines().count() as u64,
            functions: 0,
            classes: 0,
            complexity_score: 1.0,
          },
          singularity_metrics: None,
          tree_sitter_analysis: None,
          dependency_analysis: None,
          analysis_timestamp: chrono::Utc::now(),
        })
      })
      .await
      .unwrap();

    // Should have multiple chunks for the long content
    assert!(results.len() > 1);
  }
}

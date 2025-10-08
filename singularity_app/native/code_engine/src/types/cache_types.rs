//! Cache-related types for analysis suite

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Global cache statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GlobalCacheStats {
  pub total_libraries: usize,
  pub cache_hit_rate: f64,
  pub total_cached_items: usize,
  pub cache_size_bytes: usize,
  pub last_updated: DateTime<Utc>,
}

impl GlobalCacheStats {
  pub fn new() -> Self {
    Self { total_libraries: 0, cache_hit_rate: 0.0, total_cached_items: 0, cache_size_bytes: 0, last_updated: Utc::now() }
  }
}

impl Default for GlobalCacheStats {
  fn default() -> Self {
    Self::new()
  }
}

//! Caching layer for smart package context
//!
//! Uses LRU cache with configurable TTL for each entry type.

use crate::types::PackageInfo;
use lru::LruCache;
use parking_lot::RwLock;
use std::num::NonZeroUsize;
use std::sync::Arc;
use std::time::{Duration, Instant};

/// Cache entry with TTL
#[derive(Debug, Clone)]
struct CacheEntry<T> {
    /// Cached value
    data: T,
    /// When the entry expires
    expires_at: Instant,
}

impl<T> CacheEntry<T> {
    /// Check if entry has expired
    fn is_expired(&self) -> bool {
        Instant::now() > self.expires_at
    }
}

/// Smart caching layer
pub struct Cache {
    /// Package info cache
    packages: Arc<RwLock<LruCache<String, CacheEntry<PackageInfo>>>>,
    /// Default TTL for package info
    package_ttl: Duration,
}

impl Cache {
    /// Create a new cache with default settings
    pub fn new() -> Self {
        let cache_size = NonZeroUsize::new(1000).unwrap();
        Self {
            packages: Arc::new(RwLock::new(LruCache::new(cache_size))),
            package_ttl: Duration::from_secs(3600), // 1 hour
        }
    }

    /// Create cache with custom TTL
    pub fn with_ttl(ttl: Duration) -> Self {
        let cache_size = NonZeroUsize::new(1000).unwrap();
        Self {
            packages: Arc::new(RwLock::new(LruCache::new(cache_size))),
            package_ttl: ttl,
        }
    }

    /// Get a cached package info
    pub fn get_package(&self, name: &str) -> Option<PackageInfo> {
        let mut cache = self.packages.write();
        if let Some(entry) = cache.get(name) {
            if !entry.is_expired() {
                return Some(entry.data.clone());
            } else {
                cache.pop(name);
            }
        }
        None
    }

    /// Store package info in cache
    pub fn set_package(&self, name: String, package: PackageInfo) {
        let entry = CacheEntry {
            data: package,
            expires_at: Instant::now() + self.package_ttl,
        };
        let mut cache = self.packages.write();
        cache.put(name, entry);
    }

    /// Clear the entire cache
    pub fn clear(&self) {
        self.packages.write().clear();
    }

    /// Get cache statistics
    pub fn stats(&self) -> CacheStats {
        let cache = self.packages.read();
        CacheStats {
            size: cache.len(),
            capacity: cache.cap().get(),
        }
    }
}

impl Default for Cache {
    fn default() -> Self {
        Self::new()
    }
}

/// Cache statistics
#[derive(Debug, Clone)]
pub struct CacheStats {
    /// Current number of entries
    pub size: usize,
    /// Cache capacity
    pub capacity: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_set_and_get() {
        let cache = Cache::new();
        let pkg = PackageInfo {
            name: "react".to_string(),
            ecosystem: crate::types::Ecosystem::Npm,
            version: "18.0.0".to_string(),
            description: Some("React library".to_string()),
            repository: None,
            documentation: None,
            homepage: None,
            license: None,
            dependents: None,
            downloads: None,
            quality_score: 85.0,
        };

        cache.set_package("react".to_string(), pkg.clone());
        let retrieved = cache.get_package("react").unwrap();
        assert_eq!(retrieved.name, "react");
    }

    #[test]
    fn test_cache_expiration() {
        let cache = Cache::with_ttl(Duration::from_millis(100));
        let pkg = PackageInfo {
            name: "test".to_string(),
            ecosystem: crate::types::Ecosystem::Npm,
            version: "1.0.0".to_string(),
            description: None,
            repository: None,
            documentation: None,
            homepage: None,
            license: None,
            dependents: None,
            downloads: None,
            quality_score: 50.0,
        };

        cache.set_package("test".to_string(), pkg);
        assert!(cache.get_package("test").is_some());

        // Wait for expiration
        std::thread::sleep(Duration::from_millis(150));
        assert!(cache.get_package("test").is_none());
    }
}

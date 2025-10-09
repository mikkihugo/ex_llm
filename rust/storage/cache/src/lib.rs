use anyhow::Result;
use moka::future::Cache;
use serde::{Deserialize, Serialize};
use std::time::Duration;

pub mod redis_cache;
pub mod memory_cache;
pub mod redb_cache;

/// Multi-tier cache strategy
pub struct CacheManager {
    memory: Cache<String, Vec<u8>>,
    redis: Option<redis::Client>,
}

impl CacheManager {
    pub fn new(max_capacity: u64, ttl: Duration) -> Self {
        let memory = Cache::builder()
            .max_capacity(max_capacity)
            .time_to_live(ttl)
            .build();

        Self {
            memory,
            redis: None,
        }
    }

    pub async fn get<T: for<'de> Deserialize<'de>>(&self, key: &str) -> Result<Option<T>> {
        // Try memory first
        if let Some(bytes) = self.memory.get(key).await {
            return Ok(Some(bincode::deserialize(&bytes)?));
        }

        // TODO: Try Redis if configured

        Ok(None)
    }

    pub async fn set<T: Serialize>(&self, key: String, value: &T) -> Result<()> {
        let bytes = bincode::serialize(value)?;

        // Store in memory
        self.memory.insert(key.clone(), bytes).await;

        // TODO: Store in Redis if configured

        Ok(())
    }
}

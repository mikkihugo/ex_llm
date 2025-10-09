//! PostgreSQL-based cache using UNLOGGED tables
//!
//! Redis-alternative that uses PostgreSQL's UNLOGGED tables for fast,
//! volatile caching with full SQL query support.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tokio_postgres::{Client, NoTls};

/// PostgreSQL cache client
pub struct PostgresCache {
    client: Client,
}

impl PostgresCache {
    /// Create new PostgreSQL cache client
    pub async fn new(database_url: &str) -> Result<Self> {
        let (client, connection) = tokio_postgres::connect(database_url, NoTls).await?;

        // Spawn connection handler
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                eprintln!("PostgreSQL connection error: {}", e);
            }
        });

        Ok(Self { client })
    }

    /// Get value from cache
    pub async fn get(&self, cache_key: &str) -> Result<Option<Value>> {
        let row = self
            .client
            .query_opt(
                "UPDATE package_cache
                 SET hit_count = hit_count + 1
                 WHERE cache_key = $1 AND expires_at > NOW()
                 RETURNING package_data",
                &[&cache_key],
            )
            .await?;

        match row {
            Some(row) => {
                let data: Value = row.get(0);
                Ok(Some(data))
            }
            None => Ok(None),
        }
    }

    /// Store value in cache with TTL
    pub async fn put(&self, cache_key: &str, value: &Value, ttl_seconds: i32) -> Result<()> {
        self.client
            .execute(
                "INSERT INTO package_cache (cache_key, package_data, expires_at)
                 VALUES ($1, $2, NOW() + INTERVAL '1 second' * $3)
                 ON CONFLICT (cache_key) DO UPDATE
                   SET package_data = EXCLUDED.package_data,
                       expires_at = EXCLUDED.expires_at,
                       created_at = NOW(),
                       hit_count = 0",
                &[&cache_key, &value, &ttl_seconds],
            )
            .await?;

        Ok(())
    }

    /// Fetch from cache or compute
    pub async fn fetch<F, Fut>(&self, cache_key: &str, compute_fn: F, ttl_seconds: i32) -> Result<Value>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = Result<Value>>,
    {
        // Try cache first
        if let Some(value) = self.get(cache_key).await? {
            return Ok(value);
        }

        // Compute and store
        let value = compute_fn().await?;
        self.put(cache_key, &value, ttl_seconds).await?;
        Ok(value)
    }

    /// Delete specific cache entry
    pub async fn delete(&self, cache_key: &str) -> Result<()> {
        self.client
            .execute("DELETE FROM package_cache WHERE cache_key = $1", &[&cache_key])
            .await?;
        Ok(())
    }

    /// Delete cache entries matching pattern
    pub async fn delete_pattern(&self, pattern: &str) -> Result<u64> {
        let count = self
            .client
            .execute("DELETE FROM package_cache WHERE cache_key LIKE $1", &[&pattern])
            .await?;
        Ok(count)
    }

    /// Get cache statistics
    pub async fn stats(&self) -> Result<CacheStats> {
        let row = self
            .client
            .query_one("SELECT * FROM cache_stats()", &[])
            .await?;

        Ok(CacheStats {
            total_entries: row.get(0),
            expired_entries: row.get(1),
            valid_entries: row.get(2),
            total_size_mb: row.get::<_, f64>(3),
            avg_hit_count: row.get::<_, f64>(4),
        })
    }

    /// Clean up expired entries
    pub async fn cleanup_expired(&self) -> Result<i32> {
        let row = self
            .client
            .query_one("SELECT cleanup_expired_cache()", &[])
            .await?;
        Ok(row.get(0))
    }
}

/// Cache statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub total_entries: i64,
    pub expired_entries: i64,
    pub valid_entries: i64,
    pub total_size_mb: f64,
    pub avg_hit_count: f64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_cache_operations() {
        let cache = PostgresCache::new("postgresql://localhost/singularity_test")
            .await
            .unwrap();

        // Test put and get
        let value = serde_json::json!({"test": "data"});
        cache.put("test_key", &value, 60).await.unwrap();

        let retrieved = cache.get("test_key").await.unwrap().unwrap();
        assert_eq!(retrieved, value);

        // Test delete
        cache.delete("test_key").await.unwrap();
        assert!(cache.get("test_key").await.unwrap().is_none());
    }

    #[tokio::test]
    async fn test_fetch() {
        let cache = PostgresCache::new("postgresql://localhost/singularity_test")
            .await
            .unwrap();

        let value = cache
            .fetch(
                "computed_key",
                || async { Ok(serde_json::json!({"computed": true})) },
                60,
            )
            .await
            .unwrap();

        assert_eq!(value["computed"], true);

        // Second fetch should come from cache
        let cached = cache.get("computed_key").await.unwrap().unwrap();
        assert_eq!(cached["computed"], true);
    }
}

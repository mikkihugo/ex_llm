//! Global Semantic Embeddings Cache
//!
//! Content-based semantic vector cache shared across ALL projects.
//! Same code text = same semantic vector, regardless of project.

use crate::paths::SPARCPaths;
use anyhow::Result;
use redb::{Database, ReadableTable, TableDefinition, ReadableTableMetadata};
use std::sync::Arc;

// Global semantic cache table (content_hash -> semantic_vector)
const SEMANTIC_VECTORS: TableDefinition<&str, &[u8]> = TableDefinition::new("semantic_vectors");

/// Global semantic embeddings cache (singleton per process)
pub struct GlobalSemanticCache {
    db: Arc<Database>,
}

impl GlobalSemanticCache {
    /// Get or create global cache instance
    pub fn instance() -> Result<Self> {
        let db_path = SPARCPaths::global_semantic_db()?;

        let db = Database::create(&db_path)?;

        // Initialize table
        let write_txn = db.begin_write()?;
        {
            let _ = write_txn.open_table(SEMANTIC_VECTORS)?;
        }
        write_txn.commit()?;

        Ok(Self { db: Arc::new(db) })
    }

    /// Store semantic vector (content-based key)
    pub fn store(&self, content_hash: &str, vector: &[f32]) -> Result<()> {
        let data = bincode::serialize(vector)?;

        let write_txn = self.db.begin_write()?;
        {
            let mut table = write_txn.open_table(SEMANTIC_VECTORS)?;
            table.insert(content_hash, data.as_slice())?;
        }
        write_txn.commit()?;

        Ok(())
    }

    /// Get semantic vector by content hash
    pub fn get(&self, content_hash: &str) -> Result<Option<Vec<f32>>> {
        let read_txn = self.db.begin_read()?;
        let table = read_txn.open_table(SEMANTIC_VECTORS)?;

        if let Some(data) = table.get(content_hash)? {
            let vector: Vec<f32> = bincode::deserialize(data.value())?;
            Ok(Some(vector))
        } else {
            Ok(None)
        }
    }

    /// Compute content hash for text
    pub fn hash_content(text: &str) -> String {
        let hash = seahash::hash(text.as_bytes());
        format!("{:x}", hash)
    }

    /// Get or compute semantic vector
    pub fn get_or_compute<F>(&self, text: &str, compute_fn: F) -> Result<Vec<f32>>
    where
        F: FnOnce(&str) -> Result<Vec<f32>>,
    {
        let content_hash = Self::hash_content(text);

        // Try to get from cache
        if let Some(vector) = self.get(&content_hash)? {
            return Ok(vector);
        }

        // Compute and store
        let vector = compute_fn(text)?;
        self.store(&content_hash, &vector)?;

        Ok(vector)
    }

    /// Get cache statistics
    pub fn stats(&self) -> Result<SemanticCacheStats> {
        let read_txn = self.db.begin_read()?;
        let table = read_txn.open_table(SEMANTIC_VECTORS)?;

        Ok(SemanticCacheStats {
            total_vectors: table.len()? as usize,
            db_path: SPARCPaths::global_semantic_db()?,
        })
    }

    /// Clear cache (for testing)
    pub fn clear(&self) -> Result<()> {
        let write_txn = self.db.begin_write()?;
        {
            let mut table = write_txn.open_table(SEMANTIC_VECTORS)?;
            for key in table
                .iter()?
                .map(|r| r.unwrap().0.value().to_string())
                .collect::<Vec<_>>()
            {
                table.remove(key.as_str())?;
            }
        }
        write_txn.commit()?;

        Ok(())
    }
}

/// Semantic cache statistics
#[derive(Debug, Clone)]
pub struct SemanticCacheStats {
    pub total_vectors: usize,
    pub db_path: std::path::PathBuf,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_global_cache() {
        let cache = GlobalSemanticCache::instance().unwrap();

        let text = "function authenticate(user) { return true; }";
        let hash = GlobalSemanticCache::hash_content(text);

        // First call: compute
        let vec1 = cache
            .get_or_compute(text, |_| Ok(vec![1.0, 2.0, 3.0]))
            .unwrap();

        // Second call: from cache
        let vec2 = cache.get(&hash).unwrap().unwrap();

        assert_eq!(vec1, vec2);
    }
}

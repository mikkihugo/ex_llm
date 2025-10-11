//! redb-based persistent storage for prompt bits
//!
//! redb is a simple, fast, embedded key-value database written in pure Rust.
//! Perfect for storing prompt bits with fast lookups and persistence.

use std::path::Path;

use anyhow::{Context, Result};
use redb::{Database, ReadableTable, TableDefinition};
use serde_json;

use super::database::*;

// Table definitions
const PROMPTS_TABLE: TableDefinition<&str, &str> = TableDefinition::new("prompts");
const INDEX_BY_TRIGGER: TableDefinition<&str, &str> = TableDefinition::new("index_trigger");
const INDEX_BY_CATEGORY: TableDefinition<&str, &str> = TableDefinition::new("index_category");
const METADATA_TABLE: TableDefinition<&str, &str> = TableDefinition::new("metadata");

/// redb-backed storage for prompt bits
pub struct RedbPromptStorage {
    db: Database,
}

impl RedbPromptStorage {
    /// Create or open a redb database at the given path
    pub fn new(path: impl AsRef<Path>) -> Result<Self> {
        let db = Database::create(path.as_ref()).context("Failed to create/open redb database")?;

        // Create tables
        let write_txn = db.begin_write()?;
        {
            write_txn.open_table(PROMPTS_TABLE)?;
            write_txn.open_table(INDEX_BY_TRIGGER)?;
            write_txn.open_table(INDEX_BY_CATEGORY)?;
            write_txn.open_table(METADATA_TABLE)?;
        }
        write_txn.commit()?;

        Ok(Self { db })
    }

    /// Store a prompt bit
    pub fn store(&self, bit: &StoredPromptBit) -> Result<()> {
        let write_txn = self.db.begin_write()?;

        {
            let mut prompts = write_txn.open_table(PROMPTS_TABLE)?;
            let mut trigger_index = write_txn.open_table(INDEX_BY_TRIGGER)?;
            let mut category_index = write_txn.open_table(INDEX_BY_CATEGORY)?;

            // Serialize the prompt bit
            let json = serde_json::to_string(bit)?;

            // Store in main table
            prompts.insert(bit.id.as_str(), json.as_str())?;

            // Store in trigger index
            let trigger_key = format!("{:?}", bit.trigger);
            let mut trigger_ids = self.get_index_ids(&trigger_key, &trigger_index)?;
            if !trigger_ids.contains(&bit.id) {
                trigger_ids.push(bit.id.clone());
            }
            trigger_index.insert(
                trigger_key.as_str(),
                serde_json::to_string(&trigger_ids)?.as_str(),
            )?;

            // Store in category index
            let category_key = format!("{:?}", bit.category);
            let mut category_ids = self.get_index_ids(&category_key, &category_index)?;
            if !category_ids.contains(&bit.id) {
                category_ids.push(bit.id.clone());
            }
            category_index.insert(
                category_key.as_str(),
                serde_json::to_string(&category_ids)?.as_str(),
            )?;
        }

        write_txn.commit()?;
        Ok(())
    }

    /// Get a prompt bit by ID
    pub fn get(&self, id: &str) -> Result<Option<StoredPromptBit>> {
        let read_txn = self.db.begin_read()?;
        let prompts = read_txn.open_table(PROMPTS_TABLE)?;

        let result = prompts.get(id)?;
        if let Some(json) = result {
            let bit: StoredPromptBit = serde_json::from_str(json.value())?;
            Ok(Some(bit))
        } else {
            Ok(None)
        }
    }

    /// Find prompt bits by trigger
    pub fn find_by_trigger(&self, trigger: &PromptBitTrigger) -> Result<Vec<StoredPromptBit>> {
        let trigger_key = format!("{:?}", trigger);
        let read_txn = self.db.begin_read()?;
        let trigger_index = read_txn.open_table(INDEX_BY_TRIGGER)?;
        let prompts = read_txn.open_table(PROMPTS_TABLE)?;

        let ids = self.get_index_ids(&trigger_key, &trigger_index)?;

        let mut bits = Vec::new();
        for id in ids {
            if let Some(json) = prompts.get(id.as_str())? {
                let bit: StoredPromptBit = serde_json::from_str(json.value())?;
                bits.push(bit);
            }
        }

        Ok(bits)
    }

    /// Find prompt bits by category
    pub fn find_by_category(&self, category: &PromptBitCategory) -> Result<Vec<StoredPromptBit>> {
        let category_key = format!("{:?}", category);
        let read_txn = self.db.begin_read()?;
        let category_index = read_txn.open_table(INDEX_BY_CATEGORY)?;
        let prompts = read_txn.open_table(PROMPTS_TABLE)?;

        let ids = self.get_index_ids(&category_key, &category_index)?;

        let mut bits = Vec::new();
        for id in ids {
            if let Some(json) = prompts.get(id.as_str())? {
                let bit: StoredPromptBit = serde_json::from_str(json.value())?;
                bits.push(bit);
            }
        }

        Ok(bits)
    }

    /// Get all prompt bits
    pub fn get_all(&self) -> Result<Vec<StoredPromptBit>> {
        let read_txn = self.db.begin_read()?;
        let prompts = read_txn.open_table(PROMPTS_TABLE)?;

        let mut bits = Vec::new();
        for item in prompts.iter()? {
            let (_, json) = item?;
            let bit: StoredPromptBit = serde_json::from_str(json.value())?;
            bits.push(bit);
        }

        Ok(bits)
    }

    /// Update usage statistics for a prompt bit
    pub fn update_usage_stats(&self, id: &str, success: bool) -> Result<()> {
        let write_txn = self.db.begin_write()?;

        {
            let mut prompts = write_txn.open_table(PROMPTS_TABLE)?;

            let json_data = prompts.get(id)?.map(|v| v.value().to_string());

            if let Some(json) = json_data {
                let mut bit: StoredPromptBit = serde_json::from_str(&json)?;

                bit.usage_count += 1;

                // Update success rate using weighted average
                if success {
                    bit.success_rate = (bit.success_rate * (bit.usage_count - 1) as f64 + 1.0)
                        / bit.usage_count as f64;
                } else {
                    bit.success_rate =
                        (bit.success_rate * (bit.usage_count - 1) as f64) / bit.usage_count as f64;
                }

                let updated_json = serde_json::to_string(&bit)?;
                prompts.insert(id, updated_json.as_str())?;
            }
        }

        write_txn.commit()?;
        Ok(())
    }

    /// Delete a prompt bit
    pub fn delete(&self, id: &str) -> Result<()> {
        let write_txn = self.db.begin_write()?;

        {
            let mut prompts = write_txn.open_table(PROMPTS_TABLE)?;
            prompts.remove(id)?;
            // Note: We're not cleaning up indices here for simplicity
            // In production, you'd want to remove from indices too
        }

        write_txn.commit()?;
        Ok(())
    }

    /// Store metadata (e.g., schema version, statistics)
    pub fn set_metadata(&self, key: &str, value: &str) -> Result<()> {
        let write_txn = self.db.begin_write()?;
        {
            let mut metadata = write_txn.open_table(METADATA_TABLE)?;
            metadata.insert(key, value)?;
        }
        write_txn.commit()?;
        Ok(())
    }

    /// Get metadata
    pub fn get_metadata(&self, key: &str) -> Result<Option<String>> {
        let read_txn = self.db.begin_read()?;
        let metadata = read_txn.open_table(METADATA_TABLE)?;

        let result = metadata.get(key)?;
        if let Some(value) = result {
            Ok(Some(value.value().to_string()))
        } else {
            Ok(None)
        }
    }

    // Helper function to get index IDs
    fn get_index_ids<T: ReadableTable<&'static str, &'static str>>(
        &self,
        key: &str,
        table: &T,
    ) -> Result<Vec<String>> {
        match table.get(key)? {
            Some(json) => {
                let ids: Vec<String> = serde_json::from_str(json.value())?;
                Ok(ids)
            }
            None => Ok(Vec::new()),
        }
    }
}

#[cfg(test)]
mod tests {
    use tempfile::tempdir;

    use super::*;

    #[test]
    fn test_store_and_retrieve() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.redb");
        let storage = RedbPromptStorage::new(&db_path).unwrap();

        let bit = StoredPromptBit {
            id: "test-001".to_string(),
            category: PromptBitCategory::Commands,
            trigger: PromptBitTrigger::Language("Rust".to_string()),
            content: "Test content".to_string(),
            metadata: PromptBitMetadata {
                confidence: 0.9,
                last_updated: chrono::Utc::now(),
                versions: vec!["1.0".to_string()],
                related_bits: vec![],
            },
            source: PromptBitSource::Builtin,
            created_at: chrono::Utc::now(),
            usage_count: 0,
            success_rate: 0.0,
        };

        storage.store(&bit).unwrap();

        let retrieved = storage.get("test-001").unwrap().unwrap();
        assert_eq!(retrieved.id, "test-001");
        assert_eq!(retrieved.content, "Test content");
    }

    #[test]
    fn test_find_by_trigger() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.redb");
        let storage = RedbPromptStorage::new(&db_path).unwrap();

        let bit = StoredPromptBit {
            id: "rust-001".to_string(),
            category: PromptBitCategory::Commands,
            trigger: PromptBitTrigger::Language("Rust".to_string()),
            content: "Rust test".to_string(),
            metadata: PromptBitMetadata {
                confidence: 0.9,
                last_updated: chrono::Utc::now(),
                versions: vec!["1.0".to_string()],
                related_bits: vec![],
            },
            source: PromptBitSource::Builtin,
            created_at: chrono::Utc::now(),
            usage_count: 0,
            success_rate: 0.0,
        };

        storage.store(&bit).unwrap();

        let results = storage
            .find_by_trigger(&PromptBitTrigger::Language("Rust".to_string()))
            .unwrap();

        assert_eq!(results.len(), 1);
        assert_eq!(results[0].id, "rust-001");
    }

    #[test]
    fn test_usage_stats() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.redb");
        let storage = RedbPromptStorage::new(&db_path).unwrap();

        let bit = StoredPromptBit {
            id: "stats-001".to_string(),
            category: PromptBitCategory::Commands,
            trigger: PromptBitTrigger::Language("Rust".to_string()),
            content: "Test".to_string(),
            metadata: PromptBitMetadata {
                confidence: 0.9,
                last_updated: chrono::Utc::now(),
                versions: vec!["1.0".to_string()],
                related_bits: vec![],
            },
            source: PromptBitSource::Builtin,
            created_at: chrono::Utc::now(),
            usage_count: 0,
            success_rate: 0.0,
        };

        storage.store(&bit).unwrap();

        // Record success
        storage.update_usage_stats("stats-001", true).unwrap();

        let updated = storage.get("stats-001").unwrap().unwrap();
        assert_eq!(updated.usage_count, 1);
        assert_eq!(updated.success_rate, 1.0);

        // Record failure
        storage.update_usage_stats("stats-001", false).unwrap();

        let updated = storage.get("stats-001").unwrap().unwrap();
        assert_eq!(updated.usage_count, 2);
        assert_eq!(updated.success_rate, 0.5);
    }
}

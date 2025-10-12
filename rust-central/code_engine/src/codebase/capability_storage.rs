//! Capability Storage - Analysis Results Storage
//!
//! Stores code capabilities (WHAT CODE CAN DO) in analysis-suite.
//! Uses existing CodebaseDatabase infrastructure.
//!
//! Architecture Decision:
//! ✅ Store in analysis-suite (analysis results from OUR codebase)
//! ❌ NOT in fact-system (external facts from GitHub/npm/CVE)

use super::capability::{CodeCapability, CapabilitySearchResult, CapabilityIndex};
use super::storage::CodebaseDatabase;
use anyhow::{Result, Context};
use redb::{TableDefinition, ReadableTable, ReadableTableMetadata};
use std::collections::HashMap;

// redb table for capabilities
const CAPABILITIES: TableDefinition<&str, &[u8]> = TableDefinition::new("capabilities");
const CAPABILITY_INDEX: TableDefinition<&str, &[u8]> = TableDefinition::new("capability_index");

/// Capability storage extending CodebaseDatabase
pub struct CapabilityStorage {
    /// Underlying codebase database
    db: CodebaseDatabase,

    /// In-memory index for fast lookups
    index: std::sync::Arc<std::sync::Mutex<CapabilityIndex>>,
}

impl CapabilityStorage {
    /// Create new capability storage for a project
    pub fn new(project_id: impl Into<String>) -> Result<Self> {
        let db = CodebaseDatabase::new(project_id)?;

        // Initialize capability tables if they don't exist
        let write_txn = db.db.begin_write()?;
        {
            let _ = write_txn.open_table(CAPABILITIES)?;
            let _ = write_txn.open_table(CAPABILITY_INDEX)?;
        }
        write_txn.commit()?;

        let mut storage = Self {
            db,
            index: std::sync::Arc::new(std::sync::Mutex::new(CapabilityIndex::new())),
        };

        // Load existing capabilities into index
        storage.rebuild_index()?;

        Ok(storage)
    }

    /// Store a single capability
    pub async fn store(&self, capability: CodeCapability) -> Result<()> {
        let id = capability.id.clone();
        let data = bincode::serialize(&capability)?;

        // Store in redb
        let write_txn = self.db.db.begin_write()?;
        {
            let mut table = write_txn.open_table(CAPABILITIES)?;
            table.insert(id.as_str(), data.as_slice())?;
        }
        write_txn.commit()?;

        // Update in-memory index
        let mut index = self.index.lock().unwrap();
        index.add(capability);

        Ok(())
    }

    /// Store batch of capabilities
    pub async fn store_batch(&self, capabilities: &[CodeCapability]) -> Result<()> {
        let write_txn = self.db.db.begin_write()?;
        {
            let mut table = write_txn.open_table(CAPABILITIES)?;

            for capability in capabilities {
                let data = bincode::serialize(capability)?;
                table.insert(capability.id.as_str(), data.as_slice())?;
            }
        }
        write_txn.commit()?;

        // Update in-memory index
        let mut index = self.index.lock().unwrap();
        for capability in capabilities {
            index.add(capability.clone());
        }

        Ok(())
    }

    /// Get capability by ID
    pub async fn get(&self, id: &str) -> Result<Option<CodeCapability>> {
        // Try index first
        {
            let index = self.index.lock().unwrap();
            if let Some(cap) = index.get(id) {
                return Ok(Some(cap.clone()));
            }
        }

        // Fall back to database
        let read_txn = self.db.db.begin_read()?;
        let table = read_txn.open_table(CAPABILITIES)?;

        if let Some(data) = table.get(id)? {
            let capability: CodeCapability = bincode::deserialize(data.value())?;
            Ok(Some(capability))
        } else {
            Ok(None)
        }
    }

    /// Get all capabilities
    pub async fn get_all(&self) -> Result<Vec<CodeCapability>> {
        let read_txn = self.db.db.begin_read()?;
        let table = read_txn.open_table(CAPABILITIES)?;

        let mut capabilities = Vec::new();
        for result in table.iter()? {
            let (_key, value) = result?;
            let capability: CodeCapability = bincode::deserialize(value.value())?;
            capabilities.push(capability);
        }

        Ok(capabilities)
    }

    /// Search capabilities by query string
    ///
    /// Currently uses simple text matching on name, documentation, and signature.
    /// Future enhancement: Use semantic embeddings for better relevance.
    pub async fn search(&self, query: &str) -> Result<Vec<CapabilitySearchResult>> {
        // Simple text search implementation
        let capabilities = self.get_all().await?;

        let mut results = Vec::new();
        for capability in capabilities {
            // Search in name, documentation, signature
            let search_text = format!(
                "{} {} {}",
                capability.name,
                capability.documentation,
                capability.signature
            ).to_lowercase();

            if search_text.contains(&query.to_lowercase()) {
                // Simple relevance score based on position
                let score = if capability.name.to_lowercase().contains(&query.to_lowercase()) {
                    1.0
                } else if capability.documentation.to_lowercase().contains(&query.to_lowercase()) {
                    0.7
                } else {
                    0.4
                };

                results.push(CapabilitySearchResult {
                    capability,
                    score,
                    match_reason: format!("Matched query: {}", query),
                });
            }
        }

        // Sort by relevance
        results.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());

        Ok(results)
    }

    /// Find capabilities by pattern (e.g., "Parser", "Analyzer")
    pub async fn find_by_pattern(&self, pattern: &str) -> Result<Vec<CodeCapability>> {
        let index = self.index.lock().unwrap();
        Ok(index.find_by_kind(pattern).into_iter().cloned().collect())
    }

    /// Find capabilities by crate name
    pub async fn find_by_crate(&self, crate_name: &str) -> Result<Vec<CodeCapability>> {
        let index = self.index.lock().unwrap();
        Ok(index.find_by_crate(crate_name).into_iter().cloned().collect())
    }

    /// Get statistics
    pub async fn stats(&self) -> Result<CapabilityStats> {
        let index = self.index.lock().unwrap();
        let all_caps = index.all();

        let by_kind: HashMap<String, usize> = all_caps
            .iter()
            .map(|c| format!("{:?}", c.kind))
            .fold(HashMap::new(), |mut acc, kind| {
                *acc.entry(kind).or_insert(0) += 1;
                acc
            });

        let by_crate: HashMap<String, usize> = all_caps
            .iter()
            .map(|c| c.location.crate_name.clone())
            .fold(HashMap::new(), |mut acc, crate_name| {
                *acc.entry(crate_name).or_insert(0) += 1;
                acc
            });

        Ok(CapabilityStats {
            total_capabilities: index.count(),
            by_kind,
            by_crate,
            with_embeddings: all_caps.iter().filter(|c| c.embedding.is_some()).count(),
            with_examples: all_caps.iter().filter(|c| !c.usage_examples.is_empty()).count(),
        })
    }

    /// Rebuild in-memory index from database
    fn rebuild_index(&mut self) -> Result<()> {
        let read_txn = self.db.db.begin_read()?;
        let table = read_txn.open_table(CAPABILITIES)?;

        let mut index = CapabilityIndex::new();
        for result in table.iter()? {
            let (_key, value) = result?;
            let capability: CodeCapability = bincode::deserialize(value.value())?;
            index.add(capability);
        }

        *self.index.lock().unwrap() = index;
        Ok(())
    }

    /// Clear all capabilities
    pub async fn clear_all(&self) -> Result<()> {
        let write_txn = self.db.db.begin_write()?;
        {
            let mut table = write_txn.open_table(CAPABILITIES)?;
            let keys: Vec<String> = table
                .iter()?
                .map(|r| r.unwrap().0.value().to_string())
                .collect();

            for key in keys {
                table.remove(key.as_str())?;
            }
        }
        write_txn.commit()?;

        // Clear index
        *self.index.lock().unwrap() = CapabilityIndex::new();

        Ok(())
    }
}

/// Capability storage statistics
#[derive(Debug, Clone)]
pub struct CapabilityStats {
    pub total_capabilities: usize,
    pub by_kind: HashMap<String, usize>,
    pub by_crate: HashMap<String, usize>,
    pub with_embeddings: usize,
    pub with_examples: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_capability_storage_create() {
        let storage = CapabilityStorage::new("test-project");
        assert!(storage.is_ok());
    }

    #[tokio::test]
    async fn test_store_and_retrieve_capability() {
        let storage = CapabilityStorage::new("test-store-retrieve").unwrap();

        let capability = CodeCapability::new(
            "test::parser",
            "Test Parser",
            CapabilityKind::Parser { language: "rust".to_string() },
            "fn parse() -> Result<()>",
            CapabilityLocation {
                crate_name: "test".to_string(),
                module_path: "test".to_string(),
                file_path: "test.rs".to_string(),
                line_range: (1, 10),
            },
        );

        // Store
        storage.store(capability.clone()).await.unwrap();

        // Retrieve
        let retrieved = storage.get("test::parser").await.unwrap();
        assert!(retrieved.is_some());
        assert_eq!(retrieved.unwrap().name, "Test Parser");
    }

    #[tokio::test]
    async fn test_search_capabilities() {
        let storage = CapabilityStorage::new("test-search").unwrap();

        let cap1 = CodeCapability::new(
            "parser::rust",
            "Rust Parser",
            CapabilityKind::Parser { language: "rust".to_string() },
            "fn parse_rust() -> Result<()>",
            CapabilityLocation {
                crate_name: "rust-parser".to_string(),
                module_path: "parser".to_string(),
                file_path: "src/lib.rs".to_string(),
                line_range: (1, 100),
            },
        ).with_documentation("Parses Rust source code");

        storage.store(cap1).await.unwrap();

        // Search
        let results = storage.search("rust").await.unwrap();
        assert!(!results.is_empty());
        assert_eq!(results[0].capability.name, "Rust Parser");
    }
}

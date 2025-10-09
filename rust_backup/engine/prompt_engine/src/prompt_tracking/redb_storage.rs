//! Unified redb storage for all prompt FACTs
//!
//! Everything goes into redb for performance and consistency.
//! Export to JSON only when needed for git tracking.

use super::types::*;
use anyhow::Result;
use redb::{Database, ReadableTable, TableDefinition};
use serde_json;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

/// Table definitions for redb - ALL data types now in redb
const EXECUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("executions");
const FEEDBACK_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("feedback");
const CONTEXT_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("contexts");
const EVOLUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("evolutions");
const CODE_INDEX_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("code_index");
const TECH_STACK_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("project_tech_stack");
const PATTERN_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("patterns");
const AB_TEST_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("ab_tests");
const INDEX_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("indexes");

/// Unified redb storage for prompt FACTs
pub struct UnifiedFactStorage {
    /// redb database for ALL data
    redb: Arc<Database>,

    /// Storage path (for exports)
    storage_path: PathBuf,

    /// In-memory cache for hot data
    cache: Arc<RwLock<LruCache>>,
}

impl UnifiedFactStorage {
    /// Create new unified storage
    pub fn new(storage_path: impl AsRef<Path>) -> Result<Self> {
        let storage_path = storage_path.as_ref();
        fs::create_dir_all(storage_path)?;

        // Single redb database for everything
        let redb_path = storage_path.join("prompt_facts.redb");
        let redb = Arc::new(Database::create(redb_path)?);

        // Initialize ALL tables
        let write_txn = redb.begin_write()?;
        write_txn.open_table(EXECUTION_TABLE)?;
        write_txn.open_table(FEEDBACK_TABLE)?;
        write_txn.open_table(CONTEXT_TABLE)?;
        write_txn.open_table(EVOLUTION_TABLE)?;
        write_txn.open_table(CODE_INDEX_TABLE)?;
        write_txn.open_table(TECH_STACK_TABLE)?;
        write_txn.open_table(PATTERN_TABLE)?;
        write_txn.open_table(AB_TEST_TABLE)?;
        write_txn.open_table(INDEX_TABLE)?;
        write_txn.commit()?;

        Ok(Self {
            redb,
            storage_path: storage_path.to_path_buf(),
            cache: Arc::new(RwLock::new(LruCache::new(1000))),
        })
    }

    /// Store any FACT type - ALL go to redb now
    pub async fn store(&self, fact: PromptFactType) -> Result<String> {
        let id = uuid::Uuid::new_v4().to_string();
        let data = bincode::serialize(&fact)?;

        let write_txn = self.redb.begin_write()?;

        // Store in appropriate table based on type
        match &fact {
            PromptFactType::PromptExecution(exec) => {
                let mut table = write_txn.open_table(EXECUTION_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "execution", &id, &exec.prompt_bit_id)?;
            }
            PromptFactType::PromptFeedback(feedback) => {
                let mut table = write_txn.open_table(FEEDBACK_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "feedback", &id, &feedback.prompt_bit_id)?;
            }
            PromptFactType::ContextSignature(context) => {
                let mut table = write_txn.open_table(CONTEXT_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "context", &id, &context.task_type)?;
            }
            PromptFactType::PromptEvolution(evolution) => {
                let mut table = write_txn.open_table(EVOLUTION_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "evolution", &id, &evolution.original_prompt_id)?;
            }
            PromptFactType::CodeIndex(index) => {
                let mut table = write_txn.open_table(CODE_INDEX_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "code", &id, &index.file_path)?;
            }
            PromptFactType::TechStack(stack) => {
                let mut table = write_txn.open_table(TECH_STACK_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "tech", &id, &stack.technology)?;
            }
            PromptFactType::CodePattern(pattern) => {
                let mut table = write_txn.open_table(PATTERN_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "pattern", &id, &pattern.pattern_type)?;
            }
            PromptFactType::ABTestResult(result) => {
                let mut table = write_txn.open_table(AB_TEST_TABLE)?;
                table.insert(id.as_str(), data.as_slice())?;
                self.update_index_txn(&write_txn, "abtest", &id, &result.variant_a_id)?;
            }
        }

        write_txn.commit()?;

        // Invalidate cache
        self.cache.write().await.invalidate_related(&id);

        Ok(id)
    }

    /// Update index within a transaction
    fn update_index_txn(
        &self,
        write_txn: &redb::WriteTransaction,
        category: &str,
        id: &str,
        key: &str
    ) -> Result<()> {
        let index_key = format!("{}:{}", category, key);

        // Get existing IDs
        let mut table = write_txn.open_table(INDEX_TABLE)?;
        let existing_ids = if let Some(data) = table.get(index_key.as_str())? {
            let ids: Vec<String> = bincode::deserialize(data.value())?;
            ids
        } else {
            Vec::new()
        };

        // Add new ID
        let mut ids = existing_ids;
        if !ids.contains(&id.to_string()) {
            ids.push(id.to_string());
        }

        // Store updated index
        let data = bincode::serialize(&ids)?;
        table.insert(index_key.as_str(), data.as_slice())?;

        Ok(())
    }

    /// Query FACTs - all from redb
    pub async fn query(&self, query: FactQuery) -> Result<Vec<PromptFactType>> {
        // Check cache first
        if let FactQuery::ById(ref id) = query {
            if let Some(cached) = self.cache.read().await.get(id) {
                return Ok(vec![cached.clone()]);
            }
        }

        match query {
            FactQuery::ById(id) => self.get_by_id(&id).await,
            FactQuery::PromptExecutions(prompt_id) => self.get_prompt_executions(&prompt_id).await,
            FactQuery::Similar(context) => self.find_similar_contexts(&context).await,
            FactQuery::RecentFeedback(duration) => self.get_recent_feedback(duration).await,
            FactQuery::HighPerformance(threshold) => self.get_high_performance(threshold).await,
            FactQuery::ByTechStack(techs) => self.get_by_project_tech_stack(techs).await,
            FactQuery::EvolutionHistory(prompt_id) => self.get_evolution_history(&prompt_id).await,
        }
    }

    /// Get FACT by ID from any table
    async fn get_by_id(&self, id: &str) -> Result<Vec<PromptFactType>> {
        let read_txn = self.redb.begin_read()?;

        // Try each table
        if let Some(data) = read_txn.open_table(EXECUTION_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(FEEDBACK_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(CODE_INDEX_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(TECH_STACK_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(PATTERN_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(EVOLUTION_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        if let Some(data) = read_txn.open_table(AB_TEST_TABLE)?.get(id)? {
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            return Ok(vec![fact]);
        }

        Ok(Vec::new())
    }

    /// Get all executions for a prompt
    async fn get_prompt_executions(&self, prompt_id: &str) -> Result<Vec<PromptFactType>> {
        self.get_by_index("execution", prompt_id).await
    }

    /// Get by tech stack
    async fn get_by_project_tech_stack(&self, techs: Vec<String>) -> Result<Vec<PromptFactType>> {
        let mut results = Vec::new();
        for tech in techs {
            let mut tech_results = self.get_by_index("tech", &tech).await?;
            results.append(&mut tech_results);
        }
        Ok(results)
    }

    /// Get evolution history
    async fn get_evolution_history(&self, prompt_id: &str) -> Result<Vec<PromptFactType>> {
        if prompt_id.is_empty() {
            // Get all evolutions
            let read_txn = self.redb.begin_read()?;
            let table = read_txn.open_table(EVOLUTION_TABLE)?;
            let mut results = Vec::new();

            for item in table.iter()? {
                let (_, data) = item?;
                let fact: PromptFactType = bincode::deserialize(data.value())?;
                results.push(fact);
            }

            Ok(results)
        } else {
            self.get_by_index("evolution", prompt_id).await
        }
    }

    /// Get by index
    async fn get_by_index(&self, category: &str, key: &str) -> Result<Vec<PromptFactType>> {
        let index_key = format!("{}:{}", category, key);
        let read_txn = self.redb.begin_read()?;
        let index_table = read_txn.open_table(INDEX_TABLE)?;

        if let Some(data) = index_table.get(index_key.as_str())? {
            let ids: Vec<String> = bincode::deserialize(data.value())?;
            let mut results = Vec::new();

            for id in ids {
                if let Ok(facts) = self.get_by_id(&id).await {
                    results.extend(facts);
                }
            }

            return Ok(results);
        }

        Ok(Vec::new())
    }

    /// Find similar contexts
    async fn find_similar_contexts(&self, target: &ContextSignatureFact) -> Result<Vec<PromptFactType>> {
        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(CONTEXT_TABLE)?;
        let mut results = Vec::new();

        for item in table.iter()? {
            let (_, data) = item?;
            let fact: PromptFactType = bincode::deserialize(data.value())?;

            if let PromptFactType::ContextSignature(context) = &fact {
                let similarity = self.calculate_similarity(context, target);
                if similarity > 0.7 {
                    results.push(fact);
                }
            }
        }

        Ok(results)
    }

    /// Calculate similarity between contexts
    fn calculate_similarity(&self, a: &ContextSignatureFact, b: &ContextSignatureFact) -> f64 {
        let a_set: std::collections::HashSet<_> = a.project_tech_stack.iter().collect();
        let b_set: std::collections::HashSet<_> = b.project_tech_stack.iter().collect();

        let intersection = a_set.intersection(&b_set).count();
        let union = a_set.union(&b_set).count();

        if union == 0 {
            0.0
        } else {
            intersection as f64 / union as f64
        }
    }

    /// Get recent feedback
    async fn get_recent_feedback(&self, duration: Duration) -> Result<Vec<PromptFactType>> {
        let cutoff = chrono::Utc::now() - chrono::Duration::from_std(duration)?;
        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(FEEDBACK_TABLE)?;
        let mut results = Vec::new();

        for item in table.iter()? {
            let (_, data) = item?;
            let fact: PromptFactType = bincode::deserialize(data.value())?;

            if let PromptFactType::PromptFeedback(ref feedback) = fact {
                if feedback.timestamp > cutoff {
                    results.push(fact);
                }
            }
        }

        Ok(results)
    }

    /// Get high-performance prompts
    async fn get_high_performance(&self, threshold: f64) -> Result<Vec<PromptFactType>> {
        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(EXECUTION_TABLE)?;
        let mut results = Vec::new();

        for item in table.iter()? {
            let (_, data) = item?;
            let fact: PromptFactType = bincode::deserialize(data.value())?;

            if let PromptFactType::PromptExecution(ref exec) = fact {
                if exec.success_rate >= threshold {
                    results.push(fact);
                }
            }
        }

        Ok(results)
    }

    /// Export to JSON for git tracking (on-demand)
    pub async fn export_to_json(&self, export_path: impl AsRef<Path>) -> Result<()> {
        let export_path = export_path.as_ref();
        fs::create_dir_all(export_path)?;

        let read_txn = self.redb.begin_read()?;

        // Export each table to JSON
        self.export_table(&read_txn, CODE_INDEX_TABLE, export_path.join("code_index.json"))?;
        self.export_table(&read_txn, TECH_STACK_TABLE, export_path.join("project_tech_stack.json"))?;
        self.export_table(&read_txn, PATTERN_TABLE, export_path.join("patterns.json"))?;
        self.export_table(&read_txn, EVOLUTION_TABLE, export_path.join("evolutions.json"))?;
        self.export_table(&read_txn, AB_TEST_TABLE, export_path.join("ab_tests.json"))?;

        Ok(())
    }

    /// Export a single table to JSON
    fn export_table(
        &self,
        read_txn: &redb::ReadTransaction,
        table_def: TableDefinition<&str, &[u8]>,
        output_path: PathBuf,
    ) -> Result<()> {
        let table = read_txn.open_table(table_def)?;
        let mut items = Vec::new();

        for item in table.iter()? {
            let (key, data) = item?;
            let fact: PromptFactType = bincode::deserialize(data.value())?;
            items.push((key.value().to_string(), fact));
        }

        let json = serde_json::to_string_pretty(&items)?;
        fs::write(output_path, json)?;

        Ok(())
    }

    /// Import from JSON (for restoring or migrating)
    pub async fn import_from_json(&self, import_path: impl AsRef<Path>) -> Result<()> {
        let import_path = import_path.as_ref();

        // Import each JSON file if it exists
        let files = [
            ("code_index.json", CODE_INDEX_TABLE),
            ("project_tech_stack.json", TECH_STACK_TABLE),
            ("patterns.json", PATTERN_TABLE),
            ("evolutions.json", EVOLUTION_TABLE),
            ("ab_tests.json", AB_TEST_TABLE),
        ];

        for (filename, _table_def) in files {
            let file_path = import_path.join(filename);
            if file_path.exists() {
                let json = fs::read_to_string(file_path)?;
                let items: Vec<(String, PromptFactType)> = serde_json::from_str(&json)?;

                for (_id, fact) in items {
                    self.store(fact).await?;
                }
            }
        }

        Ok(())
    }
}

/// Simple LRU cache
pub struct LruCache {
    cache: std::collections::HashMap<String, PromptFactType>,
    capacity: usize,
}

impl LruCache {
    pub fn new(capacity: usize) -> Self {
        Self {
            cache: std::collections::HashMap::new(),
            capacity,
        }
    }

    pub fn get(&self, key: &str) -> Option<&PromptFactType> {
        self.cache.get(key)
    }

    pub fn invalidate_related(&mut self, _key: &str) {
        // Simple implementation: clear cache when invalidated
        self.cache.clear();
    }
}
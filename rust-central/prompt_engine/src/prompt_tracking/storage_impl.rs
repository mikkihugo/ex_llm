//! Unified redb storage for prompt execution tracking with JSON export capability
//!
//! **Storage Location**: Uses centralized storage paths
//! - Global prompt tracking: `~/.cache/sparc-engine/global/prompt_tracking.redb`
//! - Global prompt bits: `~/.cache/sparc-engine/global/prompt_bits/`
//!
//! **Scope**: Cross-project prompt execution tracking only
//! - For per-project code analysis, use `analysis-suite::CodeStorage`
//! - For GitHub code snippets, use external `fact-system` package

use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    sync::Arc,
    time::Duration,
};

use anyhow::Result;
use redb::{Database, ReadableTable, TableDefinition};
use serde_json;
use tokio::sync::RwLock;

use super::types::*;

/// Table definitions for redb
const EXECUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("executions");
const FEEDBACK_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("feedback");
const CONTEXT_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("contexts");
const EVOLUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("evolutions");
const INDEX_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("indexes");

/// Prompt tracking storage system
#[derive(Clone)]
pub struct PromptTrackingStorage {
    /// redb for fast indexing
    redb: Arc<Database>,

    /// JSON directory for git-trackable data
    json_dir: PathBuf,

    /// In-memory cache for hot data
    cache: Arc<RwLock<LruCache>>,
}

impl PromptTrackingStorage {
    /// Create new prompt tracking storage using centralized global paths
    ///
    /// Uses standard storage locations:
    /// - `~/.cache/sparc-engine/global/prompt_tracking.redb`
    /// - `~/.cache/sparc-engine/global/prompt_bits/`
    pub fn new_global() -> Result<Self> {
        // Use standard global storage paths (matching SPARCPaths convention)
        let global_cache = dirs::cache_dir()
            .ok_or_else(|| anyhow::anyhow!("Could not find cache directory"))?
            .join("sparc-engine")
            .join("global");

        std::fs::create_dir_all(&global_cache)?;

        let redb_path = global_cache.join("prompt_tracking.redb");
        let json_dir = global_cache.join("prompt_bits");
        fs::create_dir_all(&json_dir)?;

        // Open redb database
        let redb = Arc::new(Database::create(redb_path)?);

        // Initialize tables
        let write_txn = redb.begin_write()?;
        write_txn.open_table(EXECUTION_TABLE)?;
        write_txn.open_table(FEEDBACK_TABLE)?;
        write_txn.open_table(CONTEXT_TABLE)?;
        write_txn.open_table(EVOLUTION_TABLE)?;
        write_txn.open_table(INDEX_TABLE)?;
        write_txn.commit()?;

        Ok(Self {
            redb,
            json_dir,
            cache: Arc::new(RwLock::new(LruCache::new(1000))),
        })
    }

    /// Create storage with custom path (for backward compatibility/testing)
    pub fn new(storage_path: impl AsRef<Path>) -> Result<Self> {
        let storage_path = storage_path.as_ref();

        // Create storage directories
        let redb_path = storage_path.join("prompt_facts.redb");
        let json_dir = storage_path.join("prompt_bits");
        fs::create_dir_all(&json_dir)?;

        // Open redb database
        let redb = Arc::new(Database::create(redb_path)?);

        // Initialize tables
        let write_txn = redb.begin_write()?;
        write_txn.open_table(EXECUTION_TABLE)?;
        write_txn.open_table(FEEDBACK_TABLE)?;
        write_txn.open_table(CONTEXT_TABLE)?;
        write_txn.open_table(EVOLUTION_TABLE)?;
        write_txn.open_table(INDEX_TABLE)?;
        write_txn.commit()?;

        Ok(Self {
            redb,
            json_dir,
            cache: Arc::new(RwLock::new(LruCache::new(1000))),
        })
    }

    /// Store a FACT
    pub async fn store(&self, fact: PromptFactType) -> Result<String> {
        let id = uuid::Uuid::new_v4().to_string();

        match fact {
            // Performance-critical: Use redb
            PromptFactType::PromptExecution(exec) => {
                self.store_execution(&id, exec).await?;
            }
            PromptFactType::PromptFeedback(feedback) => {
                self.store_feedback(&id, feedback).await?;
            }
            PromptFactType::ContextSignature(context) => {
                self.store_context(&id, context).await?;
            }

            // Git-trackable: Use JSON
            PromptFactType::PromptEvolution(evolution) => {
                self.store_evolution_both(&id, evolution).await?;
            }
            PromptFactType::ABTestResult(result) => {
                self.store_ab_test(&id, result).await?;
            }

            // Code/tech stack: JSON for visibility
            PromptFactType::CodeIndex(index) => {
                self.store_json(&id, "code_index", &index).await?;
            }
            PromptFactType::ProjectTechStack(stack) => {
                self.store_json(&id, "project_tech_stack", &stack).await?;
            }
            PromptFactType::LearnedCodePattern(pattern) => {
                self.store_json(&id, "patterns", &pattern).await?;
            }
            PromptFactType::DetectedFramework(framework) => {
                self.store_json(&id, "detected_framework", &framework)
                    .await?;
            }
        }

        // Invalidate cache
        self.cache.write().await.invalidate_related(&id);

        Ok(id)
    }

    /// Store execution in redb
    async fn store_execution(&self, id: &str, exec: PromptExecutionFact) -> Result<()> {
        let data = bincode::serialize(&exec)?;
        let write_txn = self.redb.begin_write()?;
        {
            let mut table = write_txn.open_table(EXECUTION_TABLE)?;
            table.insert(id, data.as_slice())?;
        }
        write_txn.commit()?;

        // Update index for fast lookups
        self.update_index("execution", id, &exec.prompt_id).await?;

        Ok(())
    }

    /// Store feedback in redb
    async fn store_feedback(&self, id: &str, feedback: PromptFeedbackFact) -> Result<()> {
        let data = bincode::serialize(&feedback)?;
        let write_txn = self.redb.begin_write()?;
        {
            let mut table = write_txn.open_table(FEEDBACK_TABLE)?;
            table.insert(id, data.as_slice())?;
        }
        write_txn.commit()?;

        // Update index
        self.update_index("feedback", id, &feedback.prompt_id)
            .await?;

        Ok(())
    }

    /// Store context signature in redb
    async fn store_context(&self, id: &str, context: ContextSignatureFact) -> Result<()> {
        let data = bincode::serialize(&context)?;
        let write_txn = self.redb.begin_write()?;
        {
            let mut table = write_txn.open_table(CONTEXT_TABLE)?;
            table.insert(id, data.as_slice())?;
        }
        write_txn.commit()?;

        // Store feature vector for ML matching
        self.update_index("context", id, &context.project_type)
            .await?;

        Ok(())
    }

    /// Store evolution in both redb (index) and JSON (visibility)
    async fn store_evolution_both(&self, id: &str, evolution: PromptEvolutionFact) -> Result<()> {
        // Store in redb for fast queries
        let data = bincode::serialize(&evolution)?;
        let write_txn = self.redb.begin_write()?;
        {
            let mut table = write_txn.open_table(EVOLUTION_TABLE)?;
            table.insert(id, data.as_slice())?;
        }
        write_txn.commit()?;

        // Also store in JSON for git tracking
        self.store_json(id, "evolutions", &evolution).await?;

        Ok(())
    }

    /// Store A/B test results in JSON
    async fn store_ab_test(&self, id: &str, result: ABTestResultFact) -> Result<()> {
        self.store_json(id, "ab_tests", &result).await
    }

    /// Store in JSON for git visibility
    async fn store_json<T: serde::Serialize>(
        &self,
        id: &str,
        category: &str,
        data: &T,
    ) -> Result<()> {
        let dir = self.json_dir.join(category);
        fs::create_dir_all(&dir)?;

        let file_path = dir.join(format!("{}.json", id));
        let json = serde_json::to_string_pretty(data)?;
        fs::write(file_path, json)?;

        Ok(())
    }

    /// Update index for fast lookups
    async fn update_index(&self, category: &str, id: &str, key: &str) -> Result<()> {
        let index_key = format!("{}:{}", category, key);

        // Get existing IDs for this key
        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(INDEX_TABLE)?;
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
        let write_txn = self.redb.begin_write()?;
        {
            let mut table = write_txn.open_table(INDEX_TABLE)?;
            let data = bincode::serialize(&ids)?;
            table.insert(index_key.as_str(), data.as_slice())?;
        }
        write_txn.commit()?;

        Ok(())
    }

    /// Query FACTs
    pub async fn query(&self, query: FactQuery) -> Result<Vec<PromptFactType>> {
        match query {
            FactQuery::ById(id) => self.get_by_id(&id).await,
            FactQuery::PromptExecutions(prompt_id) => self.get_prompt_executions(&prompt_id).await,
            FactQuery::Similar(context) => self.find_similar_contexts(&context).await,
            FactQuery::RecentFeedback(duration) => self.get_recent_feedback(duration).await,
            FactQuery::HighPerformance(threshold) => self.get_high_performance(threshold).await,
            _ => Ok(Vec::new()),
        }
    }

    /// Get FACT by ID
    async fn get_by_id(&self, id: &str) -> Result<Vec<PromptFactType>> {
        // Check cache first
        if let Some(cached) = self.cache.read().await.get(id) {
            return Ok(vec![cached.clone()]);
        }

        // Check redb tables
        let read_txn = self.redb.begin_read()?;

        // Try execution table
        if let Some(data) = read_txn.open_table(EXECUTION_TABLE)?.get(id)? {
            let exec: PromptExecutionFact = bincode::deserialize(data.value())?;
            return Ok(vec![PromptFactType::PromptExecution(exec)]);
        }

        // Try feedback table
        if let Some(data) = read_txn.open_table(FEEDBACK_TABLE)?.get(id)? {
            let feedback: PromptFeedbackFact = bincode::deserialize(data.value())?;
            return Ok(vec![PromptFactType::PromptFeedback(feedback)]);
        }

        // Try JSON storage
        for category in &[
            "code_index",
            "project_tech_stack",
            "patterns",
            "evolutions",
            "ab_tests",
        ] {
            let file_path = self.json_dir.join(category).join(format!("{}.json", id));
            if file_path.exists() {
                let json = fs::read_to_string(file_path)?;
                // Parse based on category
                match *category {
                    "code_index" => {
                        let data: CodeIndexFact = serde_json::from_str(&json)?;
                        return Ok(vec![PromptFactType::CodeIndex(data)]);
                    }
                    "project_tech_stack" => {
                        let data: ProjectTechStackFact = serde_json::from_str(&json)?;
                        return Ok(vec![PromptFactType::ProjectTechStack(data)]);
                    }
                    _ => {}
                }
            }
        }

        Ok(Vec::new())
    }

    /// Get all executions for a prompt
    async fn get_prompt_executions(&self, prompt_id: &str) -> Result<Vec<PromptFactType>> {
        let index_key = format!("execution:{}", prompt_id);

        let read_txn = self.redb.begin_read()?;
        let index_table = read_txn.open_table(INDEX_TABLE)?;

        if let Some(data) = index_table.get(index_key.as_str())? {
            let ids: Vec<String> = bincode::deserialize(data.value())?;
            let mut results = Vec::new();

            let exec_table = read_txn.open_table(EXECUTION_TABLE)?;
            for id in ids {
                if let Some(data) = exec_table.get(id.as_str())? {
                    let exec: PromptExecutionFact = bincode::deserialize(data.value())?;
                    results.push(PromptFactType::PromptExecution(exec));
                }
            }

            return Ok(results);
        }

        Ok(Vec::new())
    }

    /// Find similar contexts using feature vectors
    async fn find_similar_contexts(
        &self,
        target: &ContextSignatureFact,
    ) -> Result<Vec<PromptFactType>> {
        // This would use ML similarity matching on feature vectors
        // For now, simple implementation
        let mut results = Vec::new();

        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(CONTEXT_TABLE)?;

        for item in table.iter()? {
            let (_, data) = item?;
            let context: ContextSignatureFact = bincode::deserialize(data.value())?;

            // Simple similarity: matching tech stack
            let similarity = self.calculate_similarity(&context, target);
            if similarity > 0.7 {
                results.push(PromptFactType::ContextSignature(context));
            }
        }

        Ok(results)
    }

    /// Calculate similarity between contexts
    fn calculate_similarity(&self, a: &ContextSignatureFact, b: &ContextSignatureFact) -> f64 {
        // Simple Jaccard similarity on tech stacks
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
        let mut results = Vec::new();

        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(FEEDBACK_TABLE)?;

        for item in table.iter()? {
            let (_, data) = item?;
            let feedback: PromptFeedbackFact = bincode::deserialize(data.value())?;

            if feedback.timestamp > cutoff {
                results.push(PromptFactType::PromptFeedback(feedback));
            }
        }

        Ok(results)
    }

    /// Get high-performance prompts
    async fn get_high_performance(&self, threshold: f64) -> Result<Vec<PromptFactType>> {
        let mut results = Vec::new();

        let read_txn = self.redb.begin_read()?;
        let table = read_txn.open_table(EXECUTION_TABLE)?;

        for item in table.iter()? {
            let (_, data) = item?;
            let exec: PromptExecutionFact = bincode::deserialize(data.value())?;

            if exec.confidence_score >= threshold {
                results.push(PromptFactType::PromptExecution(exec));
            }
        }

        Ok(results)
    }
}

/// Simple LRU cache
#[derive(Clone)]
pub struct LruCache {
    cache: HashMap<String, PromptFactType>,
    capacity: usize,
}

impl LruCache {
    pub fn new(capacity: usize) -> Self {
        Self {
            cache: HashMap::new(),
            capacity, // Use capacity field
        }
    }

    pub fn get(&self, key: &str) -> Option<&PromptFactType> {
        self.cache.get(key)
    }

    /// Insert with capacity management
    pub fn insert(&mut self, key: String, value: PromptFactType) {
        // Use capacity field to manage cache size
        if self.cache.len() >= self.capacity {
            // Remove oldest entry (simple implementation)
            if let Some(oldest_key) = self.cache.keys().next().cloned() {
                self.cache.remove(&oldest_key);
            }
        }
        self.cache.insert(key, value);
    }

    /// Check if cache is at capacity
    pub fn is_at_capacity(&self) -> bool {
        self.cache.len() >= self.capacity // Use capacity field
    }

    /// Get current cache utilization
    pub fn utilization(&self) -> f64 {
        self.cache.len() as f64 / self.capacity as f64 // Use capacity field
    }

    pub fn invalidate_related(&mut self, _key: &str) {
        // Simple implementation: clear cache when invalidated
        // More sophisticated: only clear related entries
        self.cache.clear();
    }
}

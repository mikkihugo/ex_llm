//! Smart storage: Prompt definitions in JSON (editable/git), everything else in redb (fast)

use super::types::*;
use crate::prompt_bits::database::StoredPromptBit as PromptBit;
use anyhow::Result;
use redb::{Database, ReadableTable, TableDefinition};
use serde_json;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;

/// redb tables for performance-critical data
const EXECUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("executions");
const FEEDBACK_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("feedback");
const CONTEXT_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("contexts");
const EVOLUTION_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("evolutions");
const CODE_INDEX_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("code_index");
const TECH_STACK_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("project_tech_stack");
const PATTERN_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("patterns");
const AB_TEST_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("ab_tests");
const INDEX_TABLE: TableDefinition<&str, &[u8]> = TableDefinition::new("indexes");

/// Smart storage with optimal split
pub struct SmartFactStorage {
    /// redb for everything except prompt definitions
    redb: Arc<Database>,

    /// JSON directory for prompt definitions (editable/git-trackable)
    prompts_dir: PathBuf,

    /// Storage path
    storage_path: PathBuf,

    /// Cache
    cache: Arc<RwLock<LruCache>>,
}

impl SmartFactStorage {
    pub fn new(storage_path: impl AsRef<Path>) -> Result<Self> {
        let storage_path = storage_path.as_ref();
        fs::create_dir_all(storage_path)?;

        // Create prompts directory for JSON files
        let prompts_dir = storage_path.join("prompts");
        fs::create_dir_all(&prompts_dir)?;

        // Create subdirectories for organization
        fs::create_dir_all(prompts_dir.join("builtin"))?;
        fs::create_dir_all(prompts_dir.join("learned"))?;
        fs::create_dir_all(prompts_dir.join("custom"))?;

        // redb for performance data
        let redb_path = storage_path.join("prompt_facts.redb");
        let redb = Arc::new(Database::create(redb_path)?);

        // Initialize tables
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
            prompts_dir,
            storage_path: storage_path.to_path_buf(),
            cache: Arc::new(RwLock::new(LruCache::new(1000))),
        })
    }

    /// Store a prompt bit in JSON (editable/git-trackable)
    pub async fn store_prompt(&self, prompt: PromptBit) -> Result<String> {
        let category = match prompt.source.as_str() {
            "Builtin" => "builtin",
            "Learned" => "learned",
            _ => "custom",
        };

        let file_path = self.prompts_dir
            .join(category)
            .join(format!("{}.json", prompt.id));

        let json = serde_json::to_string_pretty(&prompt)?;
        fs::write(file_path, json)?;

        // Also index in redb for fast lookups
        self.index_prompt(&prompt).await?;

        Ok(prompt.id.clone())
    }

    /// Index prompt in redb for fast queries
    async fn index_prompt(&self, prompt: &PromptBit) -> Result<()> {
        let write_txn = self.redb.begin_write()?;
        let mut table = write_txn.open_table(INDEX_TABLE)?;

        // Index by trigger
        let trigger_key = format!("prompt_trigger:{:?}", prompt.trigger);
        let mut trigger_ids = if let Some(data) = table.get(trigger_key.as_str())? {
            bincode::deserialize::<Vec<String>>(data.value())?
        } else {
            Vec::new()
        };

        if !trigger_ids.contains(&prompt.id) {
            trigger_ids.push(prompt.id.clone());
            table.insert(trigger_key.as_str(), bincode::serialize(&trigger_ids)?.as_slice())?;
        }

        // Index by category
        let category_key = format!("prompt_category:{:?}", prompt.category);
        let mut category_ids = if let Some(data) = table.get(category_key.as_str())? {
            bincode::deserialize::<Vec<String>>(data.value())?
        } else {
            Vec::new()
        };

        if !category_ids.contains(&prompt.id) {
            category_ids.push(prompt.id.clone());
            table.insert(category_key.as_str(), bincode::serialize(&category_ids)?.as_slice())?;
        }

        write_txn.commit()?;
        Ok(())
    }

    /// Get prompt from JSON
    pub async fn get_prompt(&self, id: &str) -> Result<Option<PromptBit>> {
        // Check all categories
        for category in &["builtin", "learned", "custom"] {
            let file_path = self.prompts_dir.join(category).join(format!("{}.json", id));
            if file_path.exists() {
                let json = fs::read_to_string(file_path)?;
                let prompt: PromptBit = serde_json::from_str(&json)?;
                return Ok(Some(prompt));
            }
        }
        Ok(None)
    }

    /// List all prompts
    pub async fn list_prompts(&self) -> Result<Vec<PromptBit>> {
        let mut prompts = Vec::new();

        for category in &["builtin", "learned", "custom"] {
            let dir = self.prompts_dir.join(category);
            if dir.exists() {
                for entry in fs::read_dir(dir)? {
                    let entry = entry?;
                    if entry.path().extension().and_then(|s| s.to_str()) == Some("json") {
                        let json = fs::read_to_string(entry.path())?;
                        let prompt: PromptBit = serde_json::from_str(&json)?;
                        prompts.push(prompt);
                    }
                }
            }
        }

        Ok(prompts)
    }

    /// Store FACT (non-prompt data goes to redb)
    pub async fn store(&self, fact: PromptFactType) -> Result<String> {
        let id = uuid::Uuid::new_v4().to_string();
        let data = bincode::serialize(&fact)?;

        let write_txn = self.redb.begin_write()?;

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
        let mut table = write_txn.open_table(INDEX_TABLE)?;

        let mut ids = if let Some(data) = table.get(index_key.as_str())? {
            bincode::deserialize::<Vec<String>>(data.value())?
        } else {
            Vec::new()
        };

        if !ids.contains(&id.to_string()) {
            ids.push(id.to_string());
        }

        table.insert(index_key.as_str(), bincode::serialize(&ids)?.as_slice())?;
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
            FactQuery::ByTechStack(techs) => self.get_by_project_tech_stack(techs).await,
            FactQuery::EvolutionHistory(prompt_id) => self.get_evolution_history(&prompt_id).await,
        }
    }

    /// Get FACT by ID
    async fn get_by_id(&self, id: &str) -> Result<Vec<PromptFactType>> {
        let read_txn = self.redb.begin_read()?;

        // Check each table
        let tables = [
            EXECUTION_TABLE,
            FEEDBACK_TABLE,
            CONTEXT_TABLE,
            EVOLUTION_TABLE,
            CODE_INDEX_TABLE,
            TECH_STACK_TABLE,
            PATTERN_TABLE,
            AB_TEST_TABLE,
        ];

        for table_def in &tables {
            let table = read_txn.open_table(*table_def)?;
            if let Some(data) = table.get(id)? {
                let fact: PromptFactType = bincode::deserialize(data.value())?;
                return Ok(vec![fact]);
            }
        }

        Ok(Vec::new())
    }

    /// Get prompt executions
    async fn get_prompt_executions(&self, prompt_id: &str) -> Result<Vec<PromptFactType>> {
        self.get_by_index("execution", prompt_id).await
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

    /// Calculate similarity
    fn calculate_similarity(&self, a: &ContextSignatureFact, b: &ContextSignatureFact) -> f64 {
        let a_set: std::collections::HashSet<_> = a.project_tech_stack.iter().collect();
        let b_set: std::collections::HashSet<_> = b.project_tech_stack.iter().collect();

        let intersection = a_set.intersection(&b_set).count();
        let union = a_set.union(&b_set).count();

        if union == 0 { 0.0 } else { intersection as f64 / union as f64 }
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

    /// Get high performance prompts
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

    /// Get by tech stack
    async fn get_by_project_tech_stack(&self, techs: Vec<String>) -> Result<Vec<PromptFactType>> {
        let mut results = Vec::new();
        for tech in techs {
            results.extend(self.get_by_index("tech", &tech).await?);
        }
        Ok(results)
    }

    /// Get evolution history
    async fn get_evolution_history(&self, prompt_id: &str) -> Result<Vec<PromptFactType>> {
        if prompt_id.is_empty() {
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
        self.cache.clear();
    }
}
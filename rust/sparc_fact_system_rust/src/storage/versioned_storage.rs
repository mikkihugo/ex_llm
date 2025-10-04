//! Version-Aware redb + JSON Storage for FACT
//!
//! **Version Tracking:**
//! - Each framework version = separate entry
//! - Key: "fact:npm:nextjs:14.0.0", "fact:npm:nextjs:15.0.0"
//! - Query all versions, compare versions, track version changes
//!
//! **Architecture:**
//! - redb: Working database (fast queries, transactions, concurrent safe)
//! - JSON: Git-tracked exports (human readable, portable, shareable)
//!
//! **Performance:**
//! - redb reads: ~0.1ms (zero-copy)
//! - redb writes: ~0.5ms (ACID transactions)
//! - JSON exports: On-demand or periodic
//!
//! **Use Cases:**
//! - Query all Next.js versions: redb range query (~1ms)
//! - Compare Next.js 14 vs 15: Load both versions
//! - Track breaking changes: Version diffs
//! - Share knowledge: JSON exports in git
//! - A/B testing: redb transactions (atomic updates)

use super::semver::{SemVer, VersionMatch};
use super::{FactData, FactKey, FactStorage, StorageStats};
use anyhow::{Context, Result};
use redb::{Database, ReadableTable, TableDefinition};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::SystemTime;
use tokio::fs;

// Table definitions for different fact types
const FRAMEWORKS_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("frameworks");
const PROMPTS_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("prompts");
const GITHUB_SNIPPETS_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("github_snippets");
const AB_TESTS_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("ab_tests");
const FEEDBACK_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("feedback");

/// Version-aware redb + JSON storage for FACT data
///
/// Each framework version is stored separately, enabling:
/// - Version-specific code examples
/// - Breaking change tracking
/// - Migration guides between versions
pub struct VersionedFactStorage {
  /// redb database for fast queries
  db: Arc<Database>,
  /// Directory for JSON exports (git-tracked)
  export_dir: PathBuf,
  /// Enable automatic JSON exports
  auto_export: bool,
}

impl VersionedFactStorage {
  /// Create new version-aware storage
  ///
  /// # Arguments
  /// * `db_path` - Path to redb database file
  /// * `export_dir` - Directory for JSON exports (should be in git)
  /// * `auto_export` - Automatically export to JSON on every write
  pub async fn new(
    db_path: impl AsRef<Path>,
    export_dir: impl AsRef<Path>,
    auto_export: bool,
  ) -> Result<Self> {
    let db_path = db_path.as_ref();
    let export_dir = export_dir.as_ref().to_path_buf();

    // Create database
    let db = Database::create(db_path).with_context(|| {
      format!("Failed to create redb at {}", db_path.display())
    })?;

    // Initialize all tables
    let write_txn = db
      .begin_write()
      .context("Failed to begin write transaction")?;
    {
      write_txn.open_table(FRAMEWORKS_TABLE)?;
      write_txn.open_table(PROMPTS_TABLE)?;
      write_txn.open_table(GITHUB_SNIPPETS_TABLE)?;
      write_txn.open_table(AB_TESTS_TABLE)?;
      write_txn.open_table(FEEDBACK_TABLE)?;
    }
    write_txn.commit()?;

    // Create export directory
    fs::create_dir_all(&export_dir).await.with_context(|| {
      format!("Failed to create export dir: {}", export_dir.display())
    })?;

    log::info!("Initialized version-aware FACT storage:");
    log::info!("  Database: {}", db_path.display());
    log::info!("  Exports: {}", export_dir.display());
    log::info!("  Auto-export: {}", auto_export);

    Ok(Self {
      db: Arc::new(db),
      export_dir,
      auto_export,
    })
  }

  /// Create standard storage in global cache directory
  ///
  /// Uses standardized paths:
  /// - Database: ~/.cache/sparc-engine/global/tech_knowledge.redb
  /// - Exports: ~/.cache/sparc-engine/global/knowledge/
  pub async fn new_global() -> Result<Self> {
    let cache_dir = dirs::cache_dir()
      .context("Failed to get cache directory")?
      .join("sparc-engine")
      .join("global");

    fs::create_dir_all(&cache_dir).await?;

    let db_path = cache_dir.join("tech_knowledge.redb");
    let export_dir = cache_dir.join("knowledge");

    Self::new(db_path, export_dir, false).await
  }

  /// Create per-project storage
  ///
  /// Uses standardized paths:
  /// - Database: ~/.cache/sparc-engine/<project-id>/tech_knowledge.redb
  /// - Exports: ~/.cache/sparc-engine/<project-id>/knowledge/
  pub async fn new_for_project(project_id: &str) -> Result<Self> {
    let cache_dir = dirs::cache_dir()
      .context("Failed to get cache directory")?
      .join("sparc-engine")
      .join(project_id);

    fs::create_dir_all(&cache_dir).await?;

    let db_path = cache_dir.join("tech_knowledge.redb");
    let export_dir = cache_dir.join("knowledge");

    Self::new(db_path, export_dir, false).await
  }

  /// Export a fact to JSON (git-trackable)
  pub async fn export_to_json(
    &self,
    key: &FactKey,
    data: &FactData,
  ) -> Result<()> {
    let json = serde_json::to_string_pretty(data)?;

    let export_path = self
      .export_dir
      .join(&key.ecosystem)
      .join(&key.tool)
      .join(format!("{}.json", key.version));

    // Create parent directories
    if let Some(parent) = export_path.parent() {
      fs::create_dir_all(parent).await?;
    }

    fs::write(&export_path, json).await.with_context(|| {
      format!("Failed to write JSON export: {}", export_path.display())
    })?;

    log::debug!("Exported to JSON: {}", export_path.display());
    Ok(())
  }

  /// Import from JSON
  pub async fn import_from_json(
    &self,
    key: &FactKey,
  ) -> Result<Option<FactData>> {
    let export_path = self
      .export_dir
      .join(&key.ecosystem)
      .join(&key.tool)
      .join(format!("{}.json", key.version));

    if !export_path.exists() {
      return Ok(None);
    }

    let json = fs::read_to_string(&export_path).await?;
    let data: FactData = serde_json::from_str(&json)?;
    Ok(Some(data))
  }

  /// Query all versions of a specific tool
  ///
  /// # Example
  /// ```ignore
  /// let versions = storage.get_tool_versions("npm", "nextjs").await?;
  /// // Returns: ["14.0.0", "14.1.0", "15.0.0"]
  /// ```
  pub async fn get_tool_versions(
    &self,
    ecosystem: &str,
    tool: &str,
  ) -> Result<Vec<String>> {
    let prefix = format!("fact:{}:{}:", ecosystem, tool);
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let mut versions = Vec::new();
    for item in table.range(prefix.as_str()..)? {
      let (key_bytes, _) = item?;
      let key_str = key_bytes.value();

      if !key_str.starts_with(&prefix) {
        break;
      }

      let key = FactKey::from_storage_key(key_str)?;
      versions.push(key.version);
    }

    Ok(versions)
  }

  /// Compare two versions of a framework
  ///
  /// Returns both FactData objects for comparison
  pub async fn compare_versions(
    &self,
    ecosystem: &str,
    tool: &str,
    version1: &str,
    version2: &str,
  ) -> Result<(FactData, FactData)> {
    let key1 = FactKey::new(
      tool.to_string(),
      version1.to_string(),
      ecosystem.to_string(),
    );
    let key2 = FactKey::new(
      tool.to_string(),
      version2.to_string(),
      ecosystem.to_string(),
    );

    let data1 = self
      .get_fact(&key1)
      .await?
      .with_context(|| format!("Version {} not found", version1))?;
    let data2 = self
      .get_fact(&key2)
      .await?
      .with_context(|| format!("Version {} not found", version2))?;

    Ok((data1, data2))
  }

  /// Get latest version of a tool using semantic versioning
  pub async fn get_latest_version(
    &self,
    ecosystem: &str,
    tool: &str,
  ) -> Result<Option<(String, FactData)>> {
    let versions = self.get_tool_versions(ecosystem, tool).await?;

    if versions.is_empty() {
      return Ok(None);
    }

    // Parse and sort versions using semantic versioning
    let mut parsed_versions: Vec<(String, SemVer)> = versions
      .iter()
      .filter_map(|v| SemVer::parse(v).ok().map(|semver| (v.clone(), semver)))
      .collect();

    parsed_versions.sort_by(|(_, a), (_, b)| a.cmp(b));

    if let Some((latest_str, _)) = parsed_versions.last() {
      let key = FactKey::new(
        tool.to_string(),
        latest_str.clone(),
        ecosystem.to_string(),
      );
      let data = self.get_fact(&key).await?;
      Ok(data.map(|d| (latest_str.clone(), d)))
    } else {
      Ok(None)
    }
  }

  /// Get fact with semantic version fallback
  ///
  /// Tries to find exact version match, then falls back to less specific patterns.
  ///
  /// # Example
  /// ```ignore
  /// // Query "14.1.0" → Try 14.1.0 → Try 14.1.x → Try 14.x.x
  /// let data = storage.get_with_fallback("npm", "nextjs", "14.1.0").await?;
  /// ```
  pub async fn get_with_fallback(
    &self,
    ecosystem: &str,
    tool: &str,
    version: &str,
  ) -> Result<Option<(FactData, VersionMatch)>> {
    let query_version = SemVer::parse(version).map_err(|e| {
      anyhow::anyhow!("Invalid version format '{}': {}", version, e)
    })?;

    // Get all available versions for this tool
    let available_versions = self.get_tool_versions(ecosystem, tool).await?;

    // Try each fallback pattern
    for (idx, pattern) in query_version.fallback_patterns().iter().enumerate() {
      let pattern_str = pattern.to_string();
      let is_exact = idx == 0;

      // Check if any available version matches this pattern
      for available in &available_versions {
        if let Ok(available_semver) = SemVer::parse(available) {
          if available_semver.matches(pattern) {
            let key = FactKey::new(
              tool.to_string(),
              available.clone(),
              ecosystem.to_string(),
            );
            if let Some(data) = self.get_fact(&key).await? {
              return Ok(Some((
                data,
                VersionMatch {
                  version: available.clone(),
                  specificity: pattern.specificity(),
                  is_exact,
                },
              )));
            }
          }
        }
      }
    }

    Ok(None)
  }

  /// Query versions matching a semantic version pattern
  ///
  /// # Example
  /// ```ignore
  /// // Query "14" → Returns all 14.x.x versions
  /// let matches = storage.query_versions("npm", "nextjs", "14").await?;
  ///
  /// // Query "14.1" → Returns all 14.1.x versions
  /// let matches = storage.query_versions("npm", "nextjs", "14.1").await?;
  /// ```
  pub async fn query_versions(
    &self,
    ecosystem: &str,
    tool: &str,
    pattern: &str,
  ) -> Result<Vec<(String, FactData)>> {
    let query_pattern = SemVer::parse(pattern).map_err(|e| {
      anyhow::anyhow!("Invalid version pattern '{}': {}", pattern, e)
    })?;

    let available_versions = self.get_tool_versions(ecosystem, tool).await?;
    let mut matches = Vec::new();

    for version in available_versions {
      if let Ok(version_semver) = SemVer::parse(&version) {
        if version_semver.matches(&query_pattern) {
          let key = FactKey::new(
            tool.to_string(),
            version.clone(),
            ecosystem.to_string(),
          );
          if let Some(data) = self.get_fact(&key).await? {
            matches.push((version, data));
          }
        }
      }
    }

    // Sort by semver
    matches.sort_by(|(a, _), (b, _)| {
      let a_semver = SemVer::parse(a).unwrap();
      let b_semver = SemVer::parse(b).unwrap();
      a_semver.cmp(&b_semver)
    });

    Ok(matches)
  }

  /// Export all facts to JSON
  pub async fn export_all_to_json(&self) -> Result<usize> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let mut count = 0;
    for item in table.iter()? {
      let (key_bytes, value_bytes) = item?;
      let key_str = key_bytes.value();
      let data: FactData = bincode::deserialize(value_bytes.value())?;
      let key = FactKey::from_storage_key(key_str)?;

      self.export_to_json(&key, &data).await?;
      count += 1;
    }

    log::info!("Exported {} facts to JSON", count);
    Ok(count)
  }
}

#[async_trait::async_trait]
impl FactStorage for VersionedFactStorage {
  async fn store_fact(&self, key: &FactKey, data: &FactData) -> Result<()> {
    let storage_key = key.storage_key();
    let bytes = bincode::serialize(data)?;

    // Store in redb
    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(FRAMEWORKS_TABLE)?;
      table.insert(storage_key.as_str(), bytes.as_slice())?;
    }
    write_txn.commit()?;

    // Auto-export to JSON if enabled
    if self.auto_export {
      self.export_to_json(key, data).await?;
    }

    Ok(())
  }

  async fn get_fact(&self, key: &FactKey) -> Result<Option<FactData>> {
    let storage_key = key.storage_key();

    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let result = table.get(storage_key.as_str())?;
    if let Some(bytes) = result {
      let data: FactData = bincode::deserialize(bytes.value())?;
      Ok(Some(data))
    } else {
      Ok(None)
    }
  }

  async fn exists(&self, key: &FactKey) -> Result<bool> {
    let storage_key = key.storage_key();

    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let result = table.get(storage_key.as_str())?.is_some();
    Ok(result)
  }

  async fn delete_fact(&self, key: &FactKey) -> Result<()> {
    let storage_key = key.storage_key();

    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(FRAMEWORKS_TABLE)?;
      table.remove(storage_key.as_str())?;
    }
    write_txn.commit()?;

    Ok(())
  }

  async fn list_tools(&self, ecosystem: &str) -> Result<Vec<FactKey>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let prefix = format!("fact:{}:", ecosystem);
    let mut results = Vec::new();

    for item in table.range(prefix.as_str()..)? {
      let (key_bytes, _) = item?;
      let key_str = key_bytes.value();

      if !key_str.starts_with(&prefix) {
        break;
      }

      results.push(FactKey::from_storage_key(key_str)?);
    }

    Ok(results)
  }

  async fn search_tools(&self, prefix: &str) -> Result<Vec<FactKey>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let search_prefix = format!("fact:{}", prefix);
    let mut results = Vec::new();

    for item in table.range(search_prefix.as_str()..)? {
      let (key_bytes, _) = item?;
      let key_str = key_bytes.value();

      if !key_str.starts_with(&search_prefix) {
        break;
      }

      results.push(FactKey::from_storage_key(key_str)?);
    }

    Ok(results)
  }

  async fn stats(&self) -> Result<StorageStats> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let mut ecosystems: HashMap<String, u64> = HashMap::new();
    let mut total_entries = 0;
    let mut total_size_bytes = 0;

    for item in table.iter()? {
      let (key_bytes, value_bytes) = item?;
      let key_str = key_bytes.value();
      let key = FactKey::from_storage_key(key_str)?;

      *ecosystems.entry(key.ecosystem).or_insert(0) += 1;
      total_entries += 1;
      total_size_bytes += value_bytes.value().len() as u64;
    }

    Ok(StorageStats {
      total_entries,
      total_size_bytes,
      ecosystems,
      last_compaction: None,
    })
  }

  async fn search_by_tags(&self, _tags: &[String]) -> Result<Vec<FactKey>> {
    // TODO: Implement tag-based search
    // For now, return empty - would need secondary index
    Ok(Vec::new())
  }

  async fn get_all_facts(&self) -> Result<Vec<(FactKey, FactData)>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FRAMEWORKS_TABLE)?;

    let mut results = Vec::new();

    for item in table.iter()? {
      let (key_bytes, value_bytes) = item?;
      let key_str = key_bytes.value();
      let key = FactKey::from_storage_key(key_str)?;
      let data: FactData = bincode::deserialize(value_bytes.value())?;

      results.push((key, data));
    }

    Ok(results)
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::TempDir;

  fn create_test_data(tool: &str, version: &str, ecosystem: &str) -> FactData {
    FactData {
      tool: tool.to_string(),
      version: version.to_string(),
      ecosystem: ecosystem.to_string(),
      documentation: format!("{} {} framework", tool, version),
      snippets: vec![],
      examples: vec![],
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![],
      dependencies: vec![],
      tags: vec!["react".to_string(), "ssr".to_string()],
      last_updated: SystemTime::now(),
      source: "test".to_string(),
      code_index: None,
      detected_framework: None,
      prompt_templates: vec![],
      quick_starts: vec![],
      migration_guides: vec![],
      usage_patterns: vec![],
      cli_commands: vec![],
      semantic_embedding: None,
      code_embedding: None,
      graph_embedding: None,
      relationships: vec![],
      usage_stats: Default::default(),
      execution_history: vec![],
      learning_data: Default::default(),
    }
  }

  #[tokio::test]
  async fn test_redb_storage() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.redb");
    let export_dir = temp_dir.path().join("exports");

    let storage = VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap();

    let key = FactKey::new(
      "nextjs".to_string(),
      "14.0.0".to_string(),
      "npm".to_string(),
    );

    let data = create_test_data("nextjs", "14.0.0", "npm");

    // Test store
    storage.store_fact(&key, &data).await.unwrap();

    // Test retrieve
    let retrieved = storage.get_fact(&key).await.unwrap();
    assert!(retrieved.is_some());
    assert_eq!(retrieved.unwrap().tool, "nextjs");

    // Test exists
    assert!(storage.exists(&key).await.unwrap());

    // Test JSON export
    storage.export_to_json(&key, &data).await.unwrap();
    let export_path = temp_dir
      .path()
      .join("exports")
      .join("npm")
      .join("nextjs")
      .join("14.0.0.json");
    assert!(export_path.exists());
  }

  #[tokio::test]
  async fn test_version_fallback() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_fallback.redb");
    let export_dir = temp_dir.path().join("exports");

    let storage = VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap();

    // Store multiple versions
    let versions = vec!["14.0.0", "14.1.0", "14.1.5", "14.2.0", "15.0.0"];
    for version in versions {
      let key = FactKey::new(
        "nextjs".to_string(),
        version.to_string(),
        "npm".to_string(),
      );
      let data = create_test_data("nextjs", version, "npm");
      storage.store_fact(&key, &data).await.unwrap();
    }

    // Test exact match
    let result = storage
      .get_with_fallback("npm", "nextjs", "14.1.5")
      .await
      .unwrap();
    assert!(result.is_some());
    let (data, version_match) = result.unwrap();
    assert_eq!(data.version, "14.1.5");
    assert!(version_match.is_exact);
    assert_eq!(version_match.specificity, 3);

    // Test fallback from non-existent patch to minor
    let result = storage
      .get_with_fallback("npm", "nextjs", "14.1.3")
      .await
      .unwrap();
    assert!(result.is_some());
    let (data, version_match) = result.unwrap();
    // Should find any 14.1.x version
    assert!(data.version.starts_with("14.1"));
    assert!(!version_match.is_exact);
    assert!(version_match.specificity <= 2);

    // Test fallback from non-existent minor to major
    let result = storage
      .get_with_fallback("npm", "nextjs", "14.5.0")
      .await
      .unwrap();
    assert!(result.is_some());
    let (data, version_match) = result.unwrap();
    // Should find any 14.x.x version
    assert!(data.version.starts_with("14."));
    assert!(!version_match.is_exact);
    assert!(version_match.specificity <= 1);

    // Test fallback with major version only
    let result = storage
      .get_with_fallback("npm", "nextjs", "14")
      .await
      .unwrap();
    assert!(result.is_some());
    let (data, _) = result.unwrap();
    assert!(data.version.starts_with("14."));
  }

  #[tokio::test]
  async fn test_query_versions() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_query.redb");
    let export_dir = temp_dir.path().join("exports");

    let storage = VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap();

    // Store multiple versions
    let versions = vec!["14.0.0", "14.1.0", "14.1.5", "14.2.0", "15.0.0"];
    for version in versions {
      let key = FactKey::new(
        "nextjs".to_string(),
        version.to_string(),
        "npm".to_string(),
      );
      let data = create_test_data("nextjs", version, "npm");
      storage.store_fact(&key, &data).await.unwrap();
    }

    // Query all 14.x.x versions
    let matches = storage.query_versions("npm", "nextjs", "14").await.unwrap();
    assert_eq!(matches.len(), 4); // 14.0.0, 14.1.0, 14.1.5, 14.2.0
    assert!(matches.iter().all(|(v, _)| v.starts_with("14.")));

    // Query all 14.1.x versions
    let matches = storage
      .query_versions("npm", "nextjs", "14.1")
      .await
      .unwrap();
    assert_eq!(matches.len(), 2); // 14.1.0, 14.1.5
    assert!(matches.iter().all(|(v, _)| v.starts_with("14.1.")));

    // Query exact version
    let matches = storage
      .query_versions("npm", "nextjs", "14.1.0")
      .await
      .unwrap();
    assert_eq!(matches.len(), 1);
    assert_eq!(matches[0].0, "14.1.0");
  }

  #[tokio::test]
  async fn test_get_latest_version_semver() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_latest.redb");
    let export_dir = temp_dir.path().join("exports");

    let storage = VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap();

    // Store versions in random order
    let versions = vec!["14.2.0", "14.0.0", "15.0.0", "14.1.0", "14.1.5"];
    for version in versions {
      let key = FactKey::new(
        "nextjs".to_string(),
        version.to_string(),
        "npm".to_string(),
      );
      let data = create_test_data("nextjs", version, "npm");
      storage.store_fact(&key, &data).await.unwrap();
    }

    // Get latest should return 15.0.0 (not 14.2.0 from string sort)
    let result = storage.get_latest_version("npm", "nextjs").await.unwrap();
    assert!(result.is_some());
    let (version, _) = result.unwrap();
    assert_eq!(version, "15.0.0");
  }

  #[tokio::test]
  async fn test_get_tool_versions() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_versions.redb");
    let export_dir = temp_dir.path().join("exports");

    let storage = VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap();

    // Store multiple versions
    let versions = vec!["14.0.0", "14.1.0", "15.0.0"];
    for version in versions {
      let key = FactKey::new(
        "nextjs".to_string(),
        version.to_string(),
        "npm".to_string(),
      );
      let data = create_test_data("nextjs", version, "npm");
      storage.store_fact(&key, &data).await.unwrap();
    }

    // Get all versions
    let found_versions =
      storage.get_tool_versions("npm", "nextjs").await.unwrap();
    assert_eq!(found_versions.len(), 3);
    assert!(found_versions.contains(&"14.0.0".to_string()));
    assert!(found_versions.contains(&"14.1.0".to_string()));
    assert!(found_versions.contains(&"15.0.0".to_string()));
  }
}

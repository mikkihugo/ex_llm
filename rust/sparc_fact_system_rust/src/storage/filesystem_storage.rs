//! Filesystem-based FACT storage using global directory.
//!
//! Uses global ~/.primecode/facts/ directory for shared facts across projects.
//! Facts are public information so global storage makes sense.

use super::{FactData, FactKey, FactStorage, StorageConfig, StorageStats};
use anyhow::{Context, Result};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::SystemTime;
use tokio::fs;
use tokio::sync::Mutex;

/// Filesystem-based FACT storage with split-brain protection.
pub struct FilesystemFactStorage {
  /// Global facts directory (~/.primecode/facts/)
  facts_dir: PathBuf,
  /// Process-level mutex to prevent concurrent writes to same files
  write_mutex: Arc<Mutex<()>>,
}

impl FilesystemFactStorage {
  /// Creates filesystem-based fact storage with global directory.
  ///
  /// # Errors
  /// Returns an error if the facts directory cannot be created
  pub async fn new(config: StorageConfig) -> Result<Self> {
    let facts_dir = PathBuf::from(&config.global_facts_dir);

    // Ensure the facts directory exists
    fs::create_dir_all(&facts_dir).await.with_context(|| {
      format!("Failed to create facts directory: {}", facts_dir.display())
    })?;

    log::info!(
      "Initialized global facts storage at: {}",
      facts_dir.display()
    );

    Ok(Self {
      facts_dir,
      write_mutex: Arc::new(Mutex::new(())),
    })
  }

  /// Get file path for a fact key
  fn get_fact_file_path(&self, key: &FactKey) -> PathBuf {
    // Store facts as: ~/.primecode/facts/ecosystem/tool/version.bin
    self
      .facts_dir
      .join(&key.ecosystem)
      .join(&key.tool)
      .join(format!("{}.bin", key.version))
  }

  /// Get directory path for tool versions
  #[allow(dead_code)]
  fn get_tool_dir_path(&self, ecosystem: &str, tool: &str) -> PathBuf {
    self.facts_dir.join(ecosystem).join(tool)
  }

  /// Get directory path for ecosystem
  fn get_ecosystem_dir_path(&self, ecosystem: &str) -> PathBuf {
    self.facts_dir.join(ecosystem)
  }

  /// Atomic file write with temp file and rename (prevents split-brain)
  async fn atomic_write(&self, file_path: &PathBuf, data: &[u8]) -> Result<()> {
    // Create temp file in same directory for atomic rename
    let temp_path = file_path.with_extension("tmp");

    // Write to temp file first
    fs::write(&temp_path, data).await.with_context(|| {
      format!("Failed to write temp file: {}", temp_path.display())
    })?;

    // Atomic rename (atomic on most filesystems)
    fs::rename(&temp_path, file_path).await.with_context(|| {
      format!("Failed to rename temp file to: {}", file_path.display())
    })?;

    Ok(())
  }
}

#[async_trait::async_trait]
impl FactStorage for FilesystemFactStorage {
  async fn store_fact(&self, key: &FactKey, data: &FactData) -> Result<()> {
    // ✅ SOLUTION: Process-level mutex prevents concurrent writes
    let _guard = self.write_mutex.lock().await;

    let file_path = self.get_fact_file_path(key);

    // Ensure parent directory exists (safe under mutex)
    if let Some(parent) = file_path.parent() {
      fs::create_dir_all(parent).await.with_context(|| {
        format!("Failed to create directory: {}", parent.display())
      })?;
    }

    // Serialize fact data using bincode for efficiency
    let serialized =
      bincode::serialize(data).context("Failed to serialize fact data")?;

    // ✅ SOLUTION: Atomic write prevents corruption
    self.atomic_write(&file_path, &serialized).await?;

    log::debug!(
      "Stored fact: {} at {}",
      key.storage_key(),
      file_path.display()
    );
    Ok(())
  }

  async fn get_fact(&self, key: &FactKey) -> Result<Option<FactData>> {
    let file_path = self.get_fact_file_path(key);

    // ✅ SOLUTION: Atomic read - check existence and read in one operation
    match fs::read(&file_path).await {
      Ok(data) => {
        let fact_data = bincode::deserialize(&data)
          .context("Failed to deserialize fact data")?;

        log::debug!(
          "Retrieved fact: {} from {}",
          key.storage_key(),
          file_path.display()
        );
        Ok(Some(fact_data))
      }
      Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
        // File doesn't exist
        Ok(None)
      }
      Err(e) => {
        // Other error
        Err(e).with_context(|| {
          format!("Failed to read fact file: {}", file_path.display())
        })
      }
    }
  }

  async fn exists(&self, key: &FactKey) -> Result<bool> {
    let file_path = self.get_fact_file_path(key);
    Ok(file_path.exists())
  }

  async fn delete_fact(&self, key: &FactKey) -> Result<()> {
    // ✅ SOLUTION: Process-level mutex prevents concurrent deletes
    let _guard = self.write_mutex.lock().await;

    let file_path = self.get_fact_file_path(key);

    // ✅ SOLUTION: Atomic delete - try to remove, ignore if not found
    match fs::remove_file(&file_path).await {
      Ok(()) => {
        log::debug!(
          "Deleted fact: {} at {}",
          key.storage_key(),
          file_path.display()
        );
      }
      Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
        // File already deleted, that's fine
        log::debug!(
          "Fact already deleted: {} at {}",
          key.storage_key(),
          file_path.display()
        );
      }
      Err(e) => {
        return Err(e).with_context(|| {
          format!("Failed to delete fact file: {}", file_path.display())
        });
      }
    }

    Ok(())
  }

  async fn list_tools(&self, ecosystem: &str) -> Result<Vec<FactKey>> {
    let ecosystem_dir = self.get_ecosystem_dir_path(ecosystem);
    let mut tools = Vec::new();

    if !ecosystem_dir.exists() {
      return Ok(tools);
    }

    let mut entries =
      fs::read_dir(&ecosystem_dir).await.with_context(|| {
        format!(
          "Failed to read ecosystem directory: {}",
          ecosystem_dir.display()
        )
      })?;

    while let Some(entry) = entries.next_entry().await? {
      let path = entry.path();
      if path.is_dir() {
        let tool_name = path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("")
          .to_string();

        // Get all versions for this tool
        if let Ok(mut version_entries) = fs::read_dir(&path).await {
          while let Some(version_entry) = version_entries.next_entry().await? {
            let version_path = version_entry.path();
            if let Some(file_name) =
              version_path.file_name().and_then(|n| n.to_str())
            {
              if std::path::Path::new(file_name)
                .extension()
                .is_some_and(|ext| ext.eq_ignore_ascii_case("bin"))
              {
                let version =
                  file_name.strip_suffix(".bin").unwrap_or("").to_string();
                tools.push(FactKey::new(
                  tool_name.clone(),
                  version,
                  ecosystem.to_string(),
                ));
              }
            }
          }
        }
      }
    }

    Ok(tools)
  }

  async fn search_tools(&self, prefix: &str) -> Result<Vec<FactKey>> {
    let mut matching_tools = Vec::new();

    // Search through all ecosystems
    if !self.facts_dir.exists() {
      return Ok(matching_tools);
    }

    let mut ecosystem_entries = fs::read_dir(&self.facts_dir).await?;

    while let Some(ecosystem_entry) = ecosystem_entries.next_entry().await? {
      let ecosystem_path = ecosystem_entry.path();
      if ecosystem_path.is_dir() {
        let ecosystem_name = ecosystem_path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("")
          .to_string();

        let tools = self.list_tools(&ecosystem_name).await?;
        for tool in tools {
          if tool.tool.starts_with(prefix) {
            matching_tools.push(tool);
          }
        }
      }
    }

    Ok(matching_tools)
  }

  async fn stats(&self) -> Result<StorageStats> {
    let mut total_entries = 0u64;
    let mut total_size_bytes = 0u64;
    let mut ecosystems = HashMap::new();

    if !self.facts_dir.exists() {
      return Ok(StorageStats {
        total_entries: 0,
        total_size_bytes: 0,
        ecosystems,
        last_compaction: None,
      });
    }

    let mut ecosystem_entries = fs::read_dir(&self.facts_dir).await?;

    while let Some(ecosystem_entry) = ecosystem_entries.next_entry().await? {
      let ecosystem_path = ecosystem_entry.path();
      if ecosystem_path.is_dir() {
        let ecosystem_name = ecosystem_path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("")
          .to_string();

        let tools = self.list_tools(&ecosystem_name).await?;
        let ecosystem_count = tools.len() as u64;

        ecosystems.insert(ecosystem_name, ecosystem_count);
        total_entries += ecosystem_count;

        // Calculate size for this ecosystem
        for tool in tools {
          let file_path = self.get_fact_file_path(&tool);
          if let Ok(metadata) = file_path.metadata() {
            total_size_bytes += metadata.len();
          }
        }
      }
    }

    Ok(StorageStats {
      total_entries,
      total_size_bytes,
      ecosystems,
      last_compaction: Some(SystemTime::now()),
    })
  }

  // ========== NEW METHODS FOR EXTENDED SEARCH ==========

  async fn search_by_tags(&self, tags: &[String]) -> Result<Vec<FactKey>> {
    let mut matching_keys = Vec::new();
    let base_dir = &self.facts_dir;

    // Walk through all ecosystems
    let mut entries = fs::read_dir(&base_dir).await?;
    while let Some(ecosystem_entry) = entries.next_entry().await? {
      let ecosystem_path = ecosystem_entry.path();
      if !ecosystem_path.is_dir() {
        continue;
      }

      let ecosystem = ecosystem_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string();

      // Walk through all tools in ecosystem
      let mut tool_entries = fs::read_dir(&ecosystem_path).await?;
      while let Some(tool_entry) = tool_entries.next_entry().await? {
        let tool_path = tool_entry.path();
        if !tool_path.is_dir() {
          continue;
        }

        let tool = tool_path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("")
          .to_string();

        // Walk through all versions
        let mut version_entries = fs::read_dir(&tool_path).await?;
        while let Some(version_entry) = version_entries.next_entry().await? {
          let version_path = version_entry.path();
          if let Some(file_name) =
            version_path.file_name().and_then(|n| n.to_str())
          {
            if std::path::Path::new(file_name)
              .extension()
              .is_some_and(|ext| ext.eq_ignore_ascii_case("bin"))
            {
              let version = file_name.trim_end_matches(".bin").to_string();
              let key = FactKey::new(tool.clone(), version, ecosystem.clone());

              // Read fact and check tags
              if let Ok(Some(fact)) = self.get_fact(&key).await {
                // Check if any requested tags match
                if tags.iter().any(|tag| fact.tags.contains(tag)) {
                  matching_keys.push(key);
                }
              }
            }
          }
        }
      }
    }

    Ok(matching_keys)
  }

  async fn get_all_facts(&self) -> Result<Vec<(FactKey, FactData)>> {
    let mut all_facts = Vec::new();
    let base_dir = &self.facts_dir;

    // Walk through all ecosystems
    let mut entries = fs::read_dir(&base_dir).await?;
    while let Some(ecosystem_entry) = entries.next_entry().await? {
      let ecosystem_path = ecosystem_entry.path();
      if !ecosystem_path.is_dir() {
        continue;
      }

      let ecosystem = ecosystem_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("")
        .to_string();

      // Walk through all tools in ecosystem
      let mut tool_entries = fs::read_dir(&ecosystem_path).await?;
      while let Some(tool_entry) = tool_entries.next_entry().await? {
        let tool_path = tool_entry.path();
        if !tool_path.is_dir() {
          continue;
        }

        let tool = tool_path
          .file_name()
          .and_then(|n| n.to_str())
          .unwrap_or("")
          .to_string();

        // Walk through all versions
        let mut version_entries = fs::read_dir(&tool_path).await?;
        while let Some(version_entry) = version_entries.next_entry().await? {
          let version_path = version_entry.path();
          if let Some(file_name) =
            version_path.file_name().and_then(|n| n.to_str())
          {
            if std::path::Path::new(file_name)
              .extension()
              .is_some_and(|ext| ext.eq_ignore_ascii_case("bin"))
            {
              let version = file_name.trim_end_matches(".bin").to_string();
              let key = FactKey::new(tool.clone(), version, ecosystem.clone());

              if let Ok(Some(fact)) = self.get_fact(&key).await {
                all_facts.push((key, fact));
              }
            }
          }
        }
      }
    }

    Ok(all_facts)
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::tempdir;

  #[tokio::test]
  async fn test_filesystem_storage() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let config = StorageConfig {
      global_facts_dir: temp_dir.path().to_string_lossy().to_string(),
    };

    let storage = FilesystemFactStorage::new(config)
      .await
      .expect("Failed to create storage");

    let key = FactKey::new(
      "phoenix".to_string(),
      "1.7.0".to_string(),
      "beam".to_string(),
    );

    let fact_data = FactData {
      tool: "phoenix".to_string(),
      version: "1.7.0".to_string(),
      ecosystem: "beam".to_string(),
      documentation: "Phoenix web framework".to_string(),
      snippets: vec![],
      examples: vec![],
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![],
      dependencies: vec![],
      tags: vec!["web".to_string(), "framework".to_string()],
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
    };

    // Test store and retrieve
    storage
      .store_fact(&key, &fact_data)
      .await
      .expect("Failed to store fact");
    assert!(storage
      .exists(&key)
      .await
      .expect("Failed to check existence"));

    let retrieved = storage
      .get_fact(&key)
      .await
      .expect("Failed to get fact")
      .expect("Fact not found");
    assert_eq!(retrieved.tool, "phoenix");
    assert_eq!(retrieved.version, "1.7.0");

    // Test list tools
    let tools = storage
      .list_tools("beam")
      .await
      .expect("Failed to list tools");
    assert_eq!(tools.len(), 1);
    assert_eq!(tools[0].tool, "phoenix");

    // Test stats
    let stats = storage.stats().await.expect("Failed to get stats");
    assert_eq!(stats.total_entries, 1);
    assert_eq!(stats.ecosystems.get("beam"), Some(&1));
  }

  #[tokio::test]
  async fn test_concurrent_operations() {
    let temp_dir = tempdir().expect("Failed to create temp directory");
    let config = StorageConfig {
      global_facts_dir: temp_dir.path().to_string_lossy().to_string(),
    };
    let storage = Arc::new(
      FilesystemFactStorage::new(config)
        .await
        .expect("Failed to create storage"),
    );

    let key = FactKey::new(
      "cargo".to_string(),
      "1.0.0".to_string(),
      "rust".to_string(),
    );

    let fact_data = FactData {
      tool: "cargo".to_string(),
      version: "1.0.0".to_string(),
      ecosystem: "rust".to_string(),
      documentation: "Cargo package manager".to_string(),
      snippets: vec![],
      examples: vec![],
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![],
      dependencies: vec![],
      tags: vec!["package-manager".to_string()],
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
    };

    // ✅ TEST: Concurrent writes should not corrupt data
    let mut handles = Vec::new();
    for i in 0..10 {
      let storage_clone = storage.clone();
      let key_clone = key.clone();
      let mut fact_data_clone = fact_data.clone();
      fact_data_clone.documentation =
        format!("Cargo package manager iteration {}", i);

      handles.push(tokio::spawn(async move {
        storage_clone.store_fact(&key_clone, &fact_data_clone).await
      }));
    }

    // Wait for all writes to complete
    for handle in handles {
      assert!(handle.await.expect("Task failed").is_ok());
    }

    // ✅ VERIFY: Data should be consistent (last write wins)
    let retrieved = storage.get_fact(&key).await.expect("Failed to get fact");
    assert!(retrieved.is_some());

    // All writes should succeed without corruption
    println!("✅ Concurrent operations test passed - no split-brain detected");
  }
}

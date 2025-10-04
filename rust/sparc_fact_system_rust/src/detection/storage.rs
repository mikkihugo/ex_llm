use redb::{Database, ReadableTable, TableDefinition};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::Arc;

// Table definition for technology cache
const TECHNOLOGY_TABLE: TableDefinition<&str, &[u8]> =
  TableDefinition::new("technologies");

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TechnologyCache {
  pub project_path: String,
  pub technologies: Vec<String>, // Just technology names
  pub detected_at: String,       // Simple timestamp string
}

#[derive(Clone)]
pub struct TechnologyStorage {
  db: Arc<Database>,
}

impl TechnologyStorage {
  /// Create new framework storage using local cache directory (per-project cache)
  ///
  /// **Purpose**: Fast per-project framework detection cache
  /// **Location**: `~/.cache/fact-tools/<project-id>/framework_cache.redb`
  ///
  /// Note: Global cross-project learning goes to `prompt_facts.redb` via PromptTrackingStorage
  pub fn new_for_project(project_id: &str) -> Result<Self, String> {
    let cache_dir = dirs::cache_dir()
      .ok_or_else(|| "Failed to get cache directory".to_string())?
      .join("fact-tools")
      .join(project_id);
    std::fs::create_dir_all(&cache_dir)
      .map_err(|e| format!("Failed to create cache directory: {}", e))?;

    let db_path = cache_dir.join("framework_cache.redb");

    let db = Arc::new(
      Database::create(db_path)
        .map_err(|e| format!("Failed to create database: {}", e))?,
    );

    // Initialize table
    let write_txn = db
      .begin_write()
      .map_err(|e| format!("Failed to begin write transaction: {}", e))?;
    {
      let _table = write_txn
        .open_table(TECHNOLOGY_TABLE)
        .map_err(|e| format!("Failed to open table: {}", e))?;
    }
    write_txn
      .commit()
      .map_err(|e| format!("Failed to commit transaction: {}", e))?;

    Ok(Self { db })
  }

  /// Create new framework storage with custom path (for backward compatibility)
  pub fn new(storage_path: impl AsRef<Path>) -> Result<Self, String> {
    let storage_path = storage_path.as_ref();
    std::fs::create_dir_all(storage_path)
      .map_err(|e| format!("Failed to create storage directory: {}", e))?;

    let db_path = storage_path.join(".framework_cache.redb");
    let db = Arc::new(
      Database::create(db_path)
        .map_err(|e| format!("Failed to create database: {}", e))?,
    );

    // Initialize table
    let write_txn = db
      .begin_write()
      .map_err(|e| format!("Failed to begin write transaction: {}", e))?;
    {
      let _table = write_txn
        .open_table(TECHNOLOGY_TABLE)
        .map_err(|e| format!("Failed to open table: {}", e))?;
    }
    write_txn
      .commit()
      .map_err(|e| format!("Failed to commit transaction: {}", e))?;

    Ok(Self { db })
  }

  /// Get global cache directory for framework detection
  pub fn get_global_cache_directory() -> Result<PathBuf, String> {
    let cache_dir = dirs::cache_dir()
      .ok_or_else(|| "Failed to get cache directory".to_string())?
      .join("fact-tools")
      .join("global");
    std::fs::create_dir_all(&cache_dir)
      .map_err(|e| format!("Failed to create global cache directory: {}", e))?;
    Ok(cache_dir)
  }

  /// Save detected technologies to redb (per-project cache)
  pub async fn save_frameworks(
    &self,
    project_path: &str,
    frameworks: Vec<String>,
  ) -> Result<(), String> {
    let cache = TechnologyCache {
      project_path: project_path.to_string(),
      technologies: frameworks,
      detected_at: chrono::Utc::now().to_rfc3339(),
    };

    let data = bincode::serialize(&cache)
      .map_err(|e| format!("Failed to serialize: {}", e))?;

    let write_txn = self
      .db
      .begin_write()
      .map_err(|e| format!("Failed to begin write transaction: {}", e))?;
    {
      let mut table = write_txn
        .open_table(TECHNOLOGY_TABLE)
        .map_err(|e| format!("Failed to open table: {}", e))?;
      table
        .insert(project_path, &*data)
        .map_err(|e| format!("Failed to insert data: {}", e))?;
    }
    write_txn
      .commit()
      .map_err(|e| format!("Failed to commit transaction: {}", e))?;

    Ok(())
  }

  /// Load previously detected technologies from redb (per-project cache)
  pub async fn load_frameworks(
    &self,
    project_path: &str,
  ) -> Result<Option<TechnologyCache>, String> {
    let read_txn = self
      .db
      .begin_read()
      .map_err(|e| format!("Failed to begin read transaction: {}", e))?;
    let table = read_txn
      .open_table(TECHNOLOGY_TABLE)
      .map_err(|e| format!("Failed to open table: {}", e))?;

    let result = table
      .get(project_path)
      .map_err(|e| format!("Failed to get data: {}", e))?;
    
    if let Some(data) = result {
      let cache: TechnologyCache = bincode::deserialize(data.value())
        .map_err(|e| format!("Failed to deserialize: {}", e))?;
      Ok(Some(cache))
    } else {
      Ok(None)
    }
  }

  /// Get all cached projects
  pub async fn get_all_projects(&self) -> Result<Vec<String>, String> {
    let read_txn = self
      .db
      .begin_read()
      .map_err(|e| format!("Failed to begin read transaction: {}", e))?;
    let table = read_txn
      .open_table(TECHNOLOGY_TABLE)
      .map_err(|e| format!("Failed to open table: {}", e))?;

    let mut projects = Vec::new();
    for result in table
      .iter()
      .map_err(|e| format!("Failed to iterate table: {}", e))?
    {
      let (key, _) = result.map_err(|e| format!("Failed to get key: {}", e))?;
      projects.push(key.value().to_string());
    }

    Ok(projects)
  }
}

#[cfg(test)]
mod tests {
  use super::*;
  use tempfile::TempDir;

  #[tokio::test]
  async fn test_save_and_load_frameworks() {
    let temp_dir = TempDir::new().unwrap();
    let storage = FrameworkStorage::new(temp_dir.path()).unwrap();

    let frameworks = vec!["Rust".to_string(), "Express.js".to_string()];
    storage
      .save_frameworks("/test/project", frameworks.clone())
      .await
      .unwrap();

    let loaded = storage.load_frameworks("/test/project").await.unwrap();
    assert!(loaded.is_some());

    let cache = loaded.unwrap();
    assert_eq!(cache.frameworks, frameworks);
    assert_eq!(cache.project_path, "/test/project");
  }
}

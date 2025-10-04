//! Persistent storage layer for codebase analysis data using redb
//!
//! Uses redb (embedded key-value store) for persistent codebase analysis storage.
//! Paths managed by SPARCPaths - no hardcoded paths allowed.

use crate::codebase::metadata::{CodebaseMetadata, FileAnalysis, CodebaseAnalysis};
use crate::codebase::vectors::CodeVector;
use crate::embeddings::{HybridCodeEmbedder, HybridEmbedding, HybridConfig, CodeMatch};
use crate::paths::SPARCPaths;
use anyhow::{Result, Context};
use redb::{Database, ReadableTable, TableDefinition};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

// redb table definitions
const FILE_ANALYSES: TableDefinition<&str, &[u8]> = TableDefinition::new("file_analyses");
const METADATA_CACHE: TableDefinition<&str, &[u8]> = TableDefinition::new("metadata_cache");
const TIMESTAMPS: TableDefinition<&str, u64> = TableDefinition::new("timestamps");
const VECTORS: TableDefinition<&str, &[u8]> = TableDefinition::new("vectors");
const FILE_VECTORS: TableDefinition<&str, &[u8]> = TableDefinition::new("file_vectors");
const GRAPH_NODES: TableDefinition<&str, &[u8]> = TableDefinition::new("graph_nodes");
const GRAPH_EDGES: TableDefinition<&str, &[u8]> = TableDefinition::new("graph_edges");
const FILE_DEPENDENCIES: TableDefinition<&str, &[u8]> = TableDefinition::new("file_dependencies");
// NEW: Embedding tables
const EMBEDDINGS: TableDefinition<&str, &[u8]> = TableDefinition::new("embeddings");
const TFIDF_MODEL: TableDefinition<&str, &[u8]> = TableDefinition::new("tfidf_model");

/// Persistent codebase database using redb
/// Automatically persists to ~/.cache/sparc-engine/<project-id>/code_storage.redb
pub struct CodebaseDatabase {
  pub(crate) db: Arc<Database>,
  project_id: String,
  /// Hybrid code embedder for semantic search
  embedder: Arc<Mutex<Option<HybridCodeEmbedder>>>,
}

impl CodebaseDatabase {
  /// Create new codebase database for a project
  pub fn new(project_id: impl Into<String>) -> Result<Self> {
    let project_id = project_id.into();
    let db_path = SPARCPaths::project_code_storage(&project_id)?;

    let db = Database::create(&db_path)
      .context(format!("Failed to create database at {:?}", db_path))?;

    // Initialize tables
    let write_txn = db.begin_write()?;
    {
      let _ = write_txn.open_table(FILE_ANALYSES)?;
      let _ = write_txn.open_table(METADATA_CACHE)?;
      let _ = write_txn.open_table(TIMESTAMPS)?;
      let _ = write_txn.open_table(VECTORS)?;
      let _ = write_txn.open_table(FILE_VECTORS)?;
      let _ = write_txn.open_table(GRAPH_NODES)?;
      let _ = write_txn.open_table(GRAPH_EDGES)?;
      let _ = write_txn.open_table(FILE_DEPENDENCIES)?;
      let _ = write_txn.open_table(EMBEDDINGS)?;
      let _ = write_txn.open_table(TFIDF_MODEL)?;
    }
    write_txn.commit()?;

    Ok(Self {
      db: Arc::new(db),
      project_id,
      embedder: Arc::new(Mutex::new(None)),
    })
  }

  /// Store file analysis (persistent)
  pub fn store_file_analysis(&self, analysis: FileAnalysis) -> Result<()> {
    let path = analysis.path.clone();
    let data = bincode::serialize(&analysis)?;

    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(FILE_ANALYSES)?;
      table.insert(path.as_str(), data.as_slice())?;

      let mut timestamps = write_txn.open_table(TIMESTAMPS)?;
      timestamps.insert(path.as_str(), chrono::Utc::now().timestamp() as u64)?;
    }
    write_txn.commit()?;

    Ok(())
  }

  /// Get file analysis (from persistent storage)
  pub fn get_file_analysis(&self, path: &str) -> Result<Option<FileAnalysis>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FILE_ANALYSES)?;

    if let Some(data) = table.get(path)? {
      let analysis: FileAnalysis = bincode::deserialize(data.value())?;
      Ok(Some(analysis))
    } else {
      Ok(None)
    }
  }

  /// Get all file analyses
  pub fn get_all_analyses(&self) -> Result<HashMap<String, FileAnalysis>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(FILE_ANALYSES)?;

    let mut analyses = HashMap::new();
    for result in table.iter()? {
      let (key, value) = result?;
      let path = key.value().to_string();
      let analysis: FileAnalysis = bincode::deserialize(value.value())?;
      analyses.insert(path, analysis);
    }

    Ok(analyses)
  }

  /// Store code metadata (persistent)
  pub fn store_metadata(&self, path: String, metadata: CodebaseMetadata) -> Result<()> {
    let data = bincode::serialize(&metadata)?;

    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(METADATA_CACHE)?;
      table.insert(path.as_str(), data.as_slice())?;

      let mut timestamps = write_txn.open_table(TIMESTAMPS)?;
      timestamps.insert(path.as_str(), chrono::Utc::now().timestamp() as u64)?;
    }
    write_txn.commit()?;

    Ok(())
  }

  /// Get code metadata
  pub fn get_metadata(&self, path: &str) -> Result<Option<CodebaseMetadata>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(METADATA_CACHE)?;

    if let Some(data) = table.get(path)? {
      let metadata: CodebaseMetadata = bincode::deserialize(data.value())?;
      Ok(Some(metadata))
    } else {
      Ok(None)
    }
  }

  /// Check if file is cached and up-to-date
  pub fn is_cached(&self, path: &str, content_hash: &str) -> Result<bool> {
    if let Some(analysis) = self.get_file_analysis(path)? {
      Ok(analysis.content_hash == content_hash)
    } else {
      Ok(false)
    }
  }

  /// Store vector (persistent)
  pub fn store_vector(&self, id: String, vector: CodeVector) -> Result<()> {
    let data = bincode::serialize(&vector)?;

    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(VECTORS)?;
      table.insert(id.as_str(), data.as_slice())?;
    }
    write_txn.commit()?;

    Ok(())
  }

  /// Get all vectors
  pub fn get_all_vectors(&self) -> Result<HashMap<String, CodeVector>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(VECTORS)?;

    let mut vectors = HashMap::new();
    for result in table.iter()? {
      let (key, value) = result?;
      let id = key.value().to_string();
      let vector: CodeVector = bincode::deserialize(value.value())?;
      vectors.insert(id, vector);
    }

    Ok(vectors)
  }

  /// Generate comprehensive codebase analysis
  pub fn generate_codebase_analysis(&self) -> Result<CodebaseAnalysis> {
    let files = self.get_all_analyses()?;
    let mut total_files = 0;
    let mut total_lines = 0;
    let mut total_functions = 0;
    let mut total_classes = 0;
    let mut languages = HashMap::new();

    for analysis in files.values() {
      total_files += 1;
      total_lines += analysis.metadata.total_lines;
      total_functions += analysis.metadata.function_count;
      total_classes += analysis.metadata.class_count;

      let lang_count = languages.entry(analysis.metadata.language.clone()).or_insert(0);
      *lang_count += 1;
    }

    Ok(CodebaseAnalysis {
      files,
      total_files,
      total_lines,
      total_functions,
      total_classes,
      languages,
      analyzed_at: chrono::Utc::now().timestamp() as u64,
    })
  }

  /// Get database statistics
  pub fn get_stats(&self) -> Result<DatabaseStats> {
    let read_txn = self.db.begin_read()?;

    let files_table = read_txn.open_table(FILE_ANALYSES)?;
    let cache_table = read_txn.open_table(METADATA_CACHE)?;
    let timestamps_table = read_txn.open_table(TIMESTAMPS)?;
    let vectors_table = read_txn.open_table(VECTORS)?;

    let total_files = files_table.len()?;
    let cached_metadata = cache_table.len()?;
    let total_timestamps = timestamps_table.len()?;

    let mut last_updated = 0u64;
    for result in timestamps_table.iter()? {
      let (_key, value) = result?;
      if value.value() > last_updated {
        last_updated = value.value();
      }
    }

    Ok(DatabaseStats {
      total_files: total_files as usize,
      cached_metadata: cached_metadata as usize,
      total_timestamps: total_timestamps as usize,
      total_vectors: vectors_table.len()? as usize,
      last_updated,
      db_path: SPARCPaths::project_code_storage(&self.project_id)?,
    })
  }

  /// Clear all data (for testing/reset)
  pub fn clear_all(&self) -> Result<()> {
    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(FILE_ANALYSES)?;
      for key in table.iter()?.map(|r| r.unwrap().0.value().to_string()).collect::<Vec<_>>() {
        table.remove(key.as_str())?;
      }

      let mut table = write_txn.open_table(METADATA_CACHE)?;
      for key in table.iter()?.map(|r| r.unwrap().0.value().to_string()).collect::<Vec<_>>() {
        table.remove(key.as_str())?;
      }

      let mut table = write_txn.open_table(TIMESTAMPS)?;
      for key in table.iter()?.map(|r| r.unwrap().0.value().to_string()).collect::<Vec<_>>() {
        table.remove(key.as_str())?;
      }

      let mut table = write_txn.open_table(VECTORS)?;
      for key in table.iter()?.map(|r| r.unwrap().0.value().to_string()).collect::<Vec<_>>() {
        table.remove(key.as_str())?;
      }

      let mut table = write_txn.open_table(EMBEDDINGS)?;
      for key in table.iter()?.map(|r| r.unwrap().0.value().to_string()).collect::<Vec<_>>() {
        table.remove(key.as_str())?;
      }
    }
    write_txn.commit()?;

    // Clear embedder
    *self.embedder.lock().unwrap() = None;

    Ok(())
  }

  // === EMBEDDING OPERATIONS ===

  /// Initialize embeddings from stored analyses
  pub fn initialize_embeddings(&self, config: Option<HybridConfig>) -> Result<()> {
    let config = config.unwrap_or_default();
    let mut embedder = HybridCodeEmbedder::new(config);

    // Get all analyses
    let analyses_map = self.get_all_analyses()?;
    let analyses: Vec<FileAnalysis> = analyses_map.into_values().collect();

    if analyses.is_empty() {
      return Ok(()); // Nothing to learn from
    }

    // Learn from analyses
    embedder.learn_from_analyses(&analyses)?;

    // Store embeddings
    for (path, embedding) in embedder.embeddings.iter() {
      self.store_embedding(path, embedding)?;
    }

    // Store embedder
    *self.embedder.lock().unwrap() = Some(embedder);

    Ok(())
  }

  /// Store embedding (persistent)
  pub fn store_embedding(&self, file_path: &str, embedding: &HybridEmbedding) -> Result<()> {
    let data = bincode::serialize(embedding)?;

    let write_txn = self.db.begin_write()?;
    {
      let mut table = write_txn.open_table(EMBEDDINGS)?;
      table.insert(file_path, data.as_slice())?;
    }
    write_txn.commit()?;

    Ok(())
  }

  /// Get embedding for a file
  pub fn get_embedding(&self, file_path: &str) -> Result<Option<HybridEmbedding>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(EMBEDDINGS)?;

    if let Some(data) = table.get(file_path)? {
      let embedding: HybridEmbedding = bincode::deserialize(data.value())?;
      Ok(Some(embedding))
    } else {
      Ok(None)
    }
  }

  /// Get all embeddings
  pub fn get_all_embeddings(&self) -> Result<HashMap<String, HybridEmbedding>> {
    let read_txn = self.db.begin_read()?;
    let table = read_txn.open_table(EMBEDDINGS)?;

    let mut embeddings = HashMap::new();
    for result in table.iter()? {
      let (key, value) = result?;
      let path = key.value().to_string();
      let embedding: HybridEmbedding = bincode::deserialize(value.value())?;
      embeddings.insert(path, embedding);
    }

    Ok(embeddings)
  }

  /// Search code using semantic embeddings
  pub fn search_code(&self, query: &str, limit: usize) -> Result<Vec<CodeMatch>> {
    // Ensure embedder is initialized
    {
      let embedder_guard = self.embedder.lock().unwrap();
      if embedder_guard.is_none() {
        drop(embedder_guard);
        self.initialize_embeddings(None)?;
      }
    }

    // Search
    let mut embedder_guard = self.embedder.lock().unwrap();
    let embedder = embedder_guard.as_mut().unwrap();
    embedder.search(query, limit)
  }

  /// Search with LLM expansion enabled
  pub fn search_code_with_llm(&self, query: &str, limit: usize) -> Result<Vec<CodeMatch>> {
    // Initialize with LLM enabled
    {
      let embedder_guard = self.embedder.lock().unwrap();
      if embedder_guard.is_none() {
        drop(embedder_guard);
        let mut config = HybridConfig::default();
        config.enable_llm_expansion = true;
        self.initialize_embeddings(Some(config))?;
      }
    }

    self.search_code(query, limit)
  }

  /// Rebuild embeddings (after adding new files)
  pub fn rebuild_embeddings(&self) -> Result<()> {
    // Clear existing embedder
    *self.embedder.lock().unwrap() = None;

    // Re-initialize
    self.initialize_embeddings(None)
  }

  /// Check if embeddings are initialized
  pub fn has_embeddings(&self) -> bool {
    self.embedder.lock().unwrap().is_some()
  }

  /// Get embedding statistics
  pub fn embedding_stats(&self) -> Result<EmbeddingStats> {
    let embeddings = self.get_all_embeddings()?;

    let total = embeddings.len();
    let with_semantic = embeddings.values()
      .filter(|e| e.semantic.is_some())
      .count();

    let embedder_guard = self.embedder.lock().unwrap();
    let has_transformer = embedder_guard.as_ref()
      .map(|e| e.has_transformer())
      .unwrap_or(false);

    Ok(EmbeddingStats {
      total_embeddings: total,
      with_semantic_vectors: with_semantic,
      has_transformer,
      is_initialized: embedder_guard.is_some(),
    })
  }
}

impl Default for CodebaseDatabase {
  fn default() -> Self {
    Self::new("default-project").expect("Failed to create default database")
  }
}

/// Database statistics
#[derive(Debug, Clone)]
pub struct DatabaseStats {
  pub total_files: usize,
  pub cached_metadata: usize,
  pub total_timestamps: usize,
  pub total_vectors: usize,
  pub last_updated: u64,
  pub db_path: std::path::PathBuf,
}

/// Embedding statistics
#[derive(Debug, Clone)]
pub struct EmbeddingStats {
  pub total_embeddings: usize,
  pub with_semantic_vectors: usize,
  pub has_transformer: bool,
  pub is_initialized: bool,
}

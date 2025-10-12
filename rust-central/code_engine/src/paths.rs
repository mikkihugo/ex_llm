//! Centralized Path Provider for Analysis Suite
//!
//! Copied from sparc-engine to avoid circular dependency.
//! Provides canonical paths for storage locations.

use std::path::PathBuf;

use anyhow::{anyhow, Result};

/// Storage paths utility
pub struct SPARCPaths;

impl SPARCPaths {
  /// Base cache directory: ~/.cache/sparc-engine
  pub fn cache_root() -> Result<PathBuf> {
    let path = dirs::cache_dir().ok_or_else(|| anyhow!("Could not find cache directory"))?.join("sparc-engine");

    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  // ========================================================================
  // Global Cross-Project Storage
  // ========================================================================

  /// Global cross-project cache: ~/.cache/sparc-engine/global
  pub fn global_cache() -> Result<PathBuf> {
    let path = Self::cache_root()?.join("global");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Global libraries cache: ~/.cache/sparc-engine/global/libraries.redb
  pub fn global_libraries_db() -> Result<PathBuf> {
    Ok(Self::global_cache()?.join("libraries.redb"))
  }

  /// Global patterns cache: ~/.cache/sparc-engine/global/patterns.redb
  pub fn global_patterns_db() -> Result<PathBuf> {
    Ok(Self::global_cache()?.join("patterns.redb"))
  }

  /// Global models cache: ~/.cache/sparc-engine/global/models.redb
  pub fn global_models_db() -> Result<PathBuf> {
    Ok(Self::global_cache()?.join("models.redb"))
  }

  /// Global semantic embeddings: ~/.cache/sparc-engine/global/semantic.redb
  /// Content-based cache: same code text = same vector (reusable across projects!)
  pub fn global_semantic_db() -> Result<PathBuf> {
    Ok(Self::global_cache()?.join("semantic.redb"))
  }

  // ========================================================================
  // Per-Project Storage
  // ========================================================================

  /// Per-project storage root: ~/.cache/sparc-engine/<project-id>
  pub fn project_storage(project_id: &str) -> Result<PathBuf> {
    let path = Self::cache_root()?.join(project_id);
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Per-project code storage: ~/.cache/sparc-engine/<project-id>/code_storage.redb
  pub fn project_code_storage(project_id: &str) -> Result<PathBuf> {
    Ok(Self::project_storage(project_id)?.join("code_storage.redb"))
  }

  /// Per-project analysis cache: ~/.cache/sparc-engine/<project-id>/analysis_cache.redb
  pub fn project_analysis_cache(project_id: &str) -> Result<PathBuf> {
    Ok(Self::project_storage(project_id)?.join("analysis_cache.redb"))
  }

  /// Per-project framework cache: ~/.cache/sparc-engine/<project-id>/framework_cache.redb
  pub fn project_framework_cache(project_id: &str) -> Result<PathBuf> {
    Ok(Self::project_storage(project_id)?.join("framework_cache.redb"))
  }

  /// Per-project search index: ~/.cache/sparc-engine/<project-id>/search.idx
  pub fn project_search_index(project_id: &str) -> Result<PathBuf> {
    Ok(Self::project_storage(project_id)?.join("search.idx"))
  }

  // ========================================================================
  // Session Storage
  // ========================================================================

  /// Per-project sessions root: ~/.cache/sparc-engine/<project-id>/sessions
  pub fn project_sessions(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_storage(project_id)?.join("sessions");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session phases: ~/.cache/sparc-engine/<project-id>/sessions/phases
  pub fn session_phases(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("phases");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session inputs: ~/.cache/sparc-engine/<project-id>/sessions/inputs
  pub fn session_inputs(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("inputs");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session outputs: ~/.cache/sparc-engine/<project-id>/sessions/outputs
  pub fn session_outputs(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("outputs");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session responses: ~/.cache/sparc-engine/<project-id>/sessions/responses
  pub fn session_responses(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("responses");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session artifacts: ~/.cache/sparc-engine/<project-id>/sessions/artifacts
  pub fn session_artifacts(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("artifacts");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session debug: ~/.cache/sparc-engine/<project-id>/sessions/debug
  pub fn session_debug(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("debug");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session calls: ~/.cache/sparc-engine/<project-id>/sessions/calls
  pub fn session_calls(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("calls");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  /// Session vector index: ~/.cache/sparc-engine/<project-id>/sessions/vector_index
  pub fn session_vector_index(project_id: &str) -> Result<PathBuf> {
    let path = Self::project_sessions(project_id)?.join("vector_index");
    std::fs::create_dir_all(&path)?;
    Ok(path)
  }

  // ========================================================================
  // Project ID Resolution
  // ========================================================================

  /// Get project ID from current directory or .sparc-engine.toml
  /// Falls back to hashed directory path if no config found
  pub fn current_project_id() -> Result<String> {
    // Try to read .sparc-engine.toml
    let current_dir = std::env::current_dir()?;
    let config_path = current_dir.join(".sparc-engine.toml");

    if config_path.exists() {
      // TODO: Parse TOML and extract project_id
      // For now, use hashed path
    }

    // Fallback: hash of current directory path
    let hash = seahash::hash(current_dir.to_string_lossy().as_bytes());
    Ok(format!("project-{:x}", hash))
  }
}

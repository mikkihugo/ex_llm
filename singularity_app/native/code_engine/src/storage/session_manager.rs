//! Project Session Management for Codebase Analysis
//!
//! **Storage Location**: Uses `SPARCPaths::project_sessions()` for all paths
//! - `~/.cache/sparc-engine/<project-id>/sessions/`
//!
//! Enables debugging, resumption, and development continuity.

use std::{
  collections::HashMap,
  fs,
  path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Project session storage manager
pub struct SessionCoordinator {
  base_path: PathBuf,
}

/// Session data for a phase execution
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhaseSession {
  pub project_id: String,
  pub phase: String,
  pub timestamp: DateTime<Utc>,
  pub input_prompt: String,
  pub provider: String,
  pub model: String,
  pub raw_response: Option<String>,
  pub processed_output: Option<String>,
  pub execution_duration_ms: Option<u64>,
  pub success: bool,
  pub error_message: Option<String>,
  pub call_ids: Vec<String>, // Track individual calls made during this phase
}

/// Individual call record
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CallRecord {
  pub call_id: String,
  pub project_id: String,
  pub phase: Option<String>,
  pub timestamp: DateTime<Utc>,
  pub provider: String,
  pub model: String,
  pub input_prompt: String,
  pub raw_response: Option<String>,
  pub processed_output: Option<String>,
  pub execution_duration_ms: Option<u64>,
  pub success: bool,
  pub error_message: Option<String>,
  pub context: HashMap<String, serde_json::Value>, // Additional context data
}

/// Complete project session state
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectSession {
  pub project_id: String,
  pub project_data: Option<serde_json::Value>, // Serialized project data
  pub created_at: DateTime<Utc>,
  pub last_updated: DateTime<Utc>,
  pub current_phase: String,
  pub completed_phases: Vec<String>,
  pub phase_sessions: HashMap<String, PhaseSession>,
  pub working_directory: PathBuf,
}

impl SessionCoordinator {
  /// Create new session manager (uses SPARCPaths for storage)
  pub fn new() -> Self {
    // Note: base_path is unused, kept for backward compatibility
    Self { base_path: PathBuf::from("/tmp/sparc-codebase-deprecated") }
  }

  /// Get session directory for a project (uses SPARCPaths)
  pub fn project_session_path(&self, project_id: &str) -> PathBuf {
    // Use centralized paths - ignore errors for backward compat
    crate::paths::SPARCPaths::project_sessions(project_id).unwrap_or_else(|_| self.base_path.join(project_id))
  }

  /// Initialize session directory structure for a project using SPARCPaths
  pub fn initialize_project_session(&self, project_id: &str, working_directory: &Path) -> Result<PathBuf> {
    // Use centralized SPARCPaths for session storage
    let session_path = crate::paths::SPARCPaths::project_sessions(project_id)?;

    // Create directory structure using SPARCPaths
    crate::paths::SPARCPaths::session_phases(project_id)?;
    crate::paths::SPARCPaths::session_inputs(project_id)?;
    crate::paths::SPARCPaths::session_outputs(project_id)?;
    crate::paths::SPARCPaths::session_responses(project_id)?;
    crate::paths::SPARCPaths::session_artifacts(project_id)?;
    crate::paths::SPARCPaths::session_debug(project_id)?;
    crate::paths::SPARCPaths::session_vector_index(project_id)?;
    crate::paths::SPARCPaths::session_calls(project_id)?;

    // Store working directory reference
    let working_dir_file = session_path.join("working_directory.txt");
    fs::write(&working_dir_file, working_directory.to_string_lossy().as_bytes())?;

    println!("📁 Initialized session directory: {}", session_path.display());
    println!("🔗 Working directory: {}", working_directory.display());
    Ok(session_path)
  }

  /// Save project session state
  pub fn save_project_session(&self, session: &ProjectSession) -> Result<()> {
    let session_path = self.project_session_path(&session.project_id);
    let session_file = session_path.join("session.json");

    let session_json = serde_json::to_string_pretty(session).context("Failed to serialize project session")?;

    fs::write(&session_file, session_json).context("Failed to write project session file")?;

    println!("💾 Saved project session: {}", session_file.display());
    Ok(())
  }

  /// Load project session state
  pub fn load_project_session(&self, project_id: &str) -> Result<Option<ProjectSession>> {
    let session_file = self.project_session_path(project_id).join("session.json");

    if !session_file.exists() {
      return Ok(None);
    }

    let session_json = fs::read_to_string(&session_file).context("Failed to read project session file")?;

    let session: ProjectSession = serde_json::from_str(&session_json).context("Failed to deserialize project session")?;

    println!("📂 Loaded project session: {}", session_file.display());
    Ok(Some(session))
  }

  /// Save phase execution session
  pub fn save_phase_session(&self, phase_session: &PhaseSession) -> Result<()> {
    let session_path = self.project_session_path(&phase_session.project_id);

    // Save phase-specific data
    let phase_file = session_path.join("phases").join(format!("{}.json", phase_session.phase));
    let phase_json = serde_json::to_string_pretty(phase_session)?;
    fs::write(&phase_file, phase_json)?;

    // Save input prompt
    let input_file = session_path.join("inputs").join(format!("{}.txt", phase_session.phase));
    fs::write(&input_file, &phase_session.input_prompt)?;

    // Save raw response if available
    if let Some(response) = &phase_session.raw_response {
      let response_file = session_path.join("responses").join(format!("{}_raw.txt", phase_session.phase));
      fs::write(&response_file, response)?;
    }

    // Save processed output if available
    if let Some(output) = &phase_session.processed_output {
      let output_file = session_path.join("outputs").join(format!("{}.txt", phase_session.phase));
      fs::write(&output_file, output)?;
    }

    // Create debug info
    let debug_info = format!(
      "=== Phase Execution Debug Info ===\n\
             Project ID: {}\n\
             Phase: {}\n\
             Timestamp: {}\n\
             Provider: {}\n\
             Model: {}\n\
             Execution Duration: {:?}ms\n\
             Success: {}\n\
             Error: {:?}\n\
             \n\
             === Input Prompt ===\n\
             {}\n\
             \n\
             === Raw Response ===\n\
             {}\n\
             \n\
             === Processed Output ===\n\
             {}\n",
      phase_session.project_id,
      phase_session.phase,
      phase_session.timestamp,
      phase_session.provider,
      phase_session.model,
      phase_session.execution_duration_ms,
      phase_session.success,
      phase_session.error_message,
      phase_session.input_prompt,
      phase_session.raw_response.as_deref().unwrap_or("N/A"),
      phase_session.processed_output.as_deref().unwrap_or("N/A")
    );

    let debug_file = session_path.join("debug").join(format!("{}_debug.txt", phase_session.phase));
    fs::write(&debug_file, debug_info)?;

    println!("💾 Saved phase session: {}", phase_file.display());
    Ok(())
  }

  /// Load phase session
  pub fn load_phase_session(&self, project_id: &str, phase: &str) -> Result<Option<PhaseSession>> {
    let session_path = self.project_session_path(project_id);
    let phase_file = session_path.join("phases").join(format!("{}.json", phase));

    if !phase_file.exists() {
      return Ok(None);
    }

    let phase_json = fs::read_to_string(&phase_file)?;
    let phase_session: PhaseSession = serde_json::from_str(&phase_json)?;

    Ok(Some(phase_session))
  }

  /// Save individual call record
  pub fn save_call_record(&self, call_record: &CallRecord) -> Result<()> {
    let session_path = self.project_session_path(&call_record.project_id);
    let call_file = session_path.join("calls").join(format!("{}.json", call_record.call_id));

    let call_json = serde_json::to_string_pretty(call_record)?;
    fs::write(&call_file, call_json)?;

    println!("📞 Saved call record: {}", call_file.display());
    Ok(())
  }

  /// Load call record
  pub fn load_call_record(&self, project_id: &str, call_id: &str) -> Result<Option<CallRecord>> {
    let session_path = self.project_session_path(project_id);
    let call_file = session_path.join("calls").join(format!("{}.json", call_id));

    if !call_file.exists() {
      return Ok(None);
    }

    let call_json = fs::read_to_string(&call_file)?;
    let call_record: CallRecord = serde_json::from_str(&call_json)?;

    Ok(Some(call_record))
  }

  /// Get all phase sessions for a project
  pub fn get_phase_sessions(&self, project_id: &str) -> Result<Vec<PhaseSession>> {
    let session_path = self.project_session_path(project_id);
    let phases_dir = session_path.join("phases");

    if !phases_dir.exists() {
      return Ok(vec![]);
    }

    let mut sessions = Vec::new();
    for entry in fs::read_dir(&phases_dir)? {
      let entry = entry?;
      if let Some(file_name) = entry.file_name().to_str() {
        if file_name.ends_with(".json") {
          let phase_name = file_name.trim_end_matches(".json");
          if let Some(session) = self.load_phase_session(project_id, phase_name)? {
            sessions.push(session);
          }
        }
      }
    }

    // Sort by timestamp
    sessions.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
    Ok(sessions)
  }

  /// Get all call records for a project
  pub fn get_call_records(&self, project_id: &str) -> Result<Vec<CallRecord>> {
    let session_path = self.project_session_path(project_id);
    let calls_dir = session_path.join("calls");

    if !calls_dir.exists() {
      return Ok(vec![]);
    }

    let mut records = Vec::new();
    for entry in fs::read_dir(&calls_dir)? {
      let entry = entry?;
      if let Some(file_name) = entry.file_name().to_str() {
        if file_name.ends_with(".json") {
          let call_id = file_name.trim_end_matches(".json");
          if let Some(record) = self.load_call_record(project_id, call_id)? {
            records.push(record);
          }
        }
      }
    }

    // Sort by timestamp
    records.sort_by(|a, b| a.timestamp.cmp(&b.timestamp));
    Ok(records)
  }

  /// Clean up old session data
  pub fn cleanup_old_sessions(&self, max_age_days: u64) -> Result<()> {
    let cutoff_time = Utc::now() - chrono::Duration::days(max_age_days as i64);

    if !self.base_path.exists() {
      return Ok(());
    }

    for entry in fs::read_dir(&self.base_path)? {
      let entry = entry?;
      if entry.file_type()?.is_dir() {
        let project_id = entry.file_name().to_string_lossy().to_string();

        // Check if session is old
        if let Some(session) = self.load_project_session(&project_id)? {
          if session.last_updated < cutoff_time {
            println!("🗑️ Cleaning up old session: {}", project_id);
            fs::remove_dir_all(entry.path())?;
          }
        }
      }
    }

    Ok(())
  }

  /// Get session statistics
  pub fn get_session_stats(&self) -> Result<SessionStats> {
    let mut total_projects = 0;
    let mut total_phases = 0;
    let mut total_calls = 0;
    let mut total_size_bytes = 0;

    if self.base_path.exists() {
      for entry in fs::read_dir(&self.base_path)? {
        let entry = entry?;
        if entry.file_type()?.is_dir() {
          total_projects += 1;

          let project_id = entry.file_name().to_string_lossy().to_string();

          // Count phases
          let phases_dir = entry.path().join("phases");
          if phases_dir.exists() {
            for phase_entry in fs::read_dir(&phases_dir)? {
              if phase_entry?.file_type()?.is_file() {
                total_phases += 1;
              }
            }
          }

          // Count calls
          let calls_dir = entry.path().join("calls");
          if calls_dir.exists() {
            for call_entry in fs::read_dir(&calls_dir)? {
              if call_entry?.file_type()?.is_file() {
                total_calls += 1;
              }
            }
          }

          // Calculate size
          total_size_bytes += self.calculate_directory_size(&entry.path())?;
        }
      }
    }

    Ok(SessionStats { total_projects, total_phases, total_calls, total_size_mb: total_size_bytes as f64 / (1024.0 * 1024.0) })
  }

  /// Calculate directory size recursively
  fn calculate_directory_size(&self, path: &Path) -> Result<u64> {
    let mut size = 0;

    if path.is_file() {
      if let Ok(metadata) = path.metadata() {
        size += metadata.len();
      }
    } else if path.is_dir() {
      for entry in fs::read_dir(path)? {
        let entry = entry?;
        size += self.calculate_directory_size(&entry.path())?;
      }
    }

    Ok(size)
  }
}

/// Session statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionStats {
  pub total_projects: usize,
  pub total_phases: usize,
  pub total_calls: usize,
  pub total_size_mb: f64,
}

impl Default for SessionCoordinator {
  fn default() -> Self {
    Self::new()
  }
}

#[cfg(test)]
mod tests {
  use tempfile::TempDir;

  use super::*;

  #[test]
  fn test_session_manager_creation() {
    let manager = SessionCoordinator::new();
    assert!(manager.base_path.ends_with("sparc-codebase"));
  }

  #[test]
  fn test_project_session_lifecycle() {
    let temp_dir = TempDir::new().unwrap();
    let manager = SessionCoordinator::new();

    let project_id = "test-project";
    let working_dir = temp_dir.path();

    // Initialize session
    let session_path = manager.initialize_project_session(project_id, working_dir).unwrap();
    assert!(session_path.exists());

    // Create and save session
    let session = ProjectSession {
      project_id: project_id.to_string(),
      project_data: None,
      created_at: Utc::now(),
      last_updated: Utc::now(),
      current_phase: "test".to_string(),
      completed_phases: vec![],
      phase_sessions: HashMap::new(),
      working_directory: working_dir.to_path_buf(),
    };

    manager.save_project_session(&session).unwrap();

    // Load session
    let loaded = manager.load_project_session(project_id).unwrap();
    assert!(loaded.is_some());
    assert_eq!(loaded.unwrap().project_id, project_id);
  }
}

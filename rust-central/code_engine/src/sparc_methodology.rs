//! SPARC Methodology - Stub for code_analysis
//!
//! Lightweight stub to satisfy code_analysis dependencies.
//! SPARC = Specification, Pseudocode, Architecture, Refinement, Completion

use serde::{Deserialize, Serialize};

/// Project complexity level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ProjectComplexity {
    Simple,
    Moderate,
    Complex,
}

/// SPARC methodology project wrapper
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SPARCProject {
    project_id: String,
    project_name: String,
    category: String,
    enabled: bool,
}

impl SPARCProject {
    /// Create a new SPARC project
    pub fn new(project_id: String, project_name: String, category: String, _complexity: ProjectComplexity) -> Result<Self, String> {
        Ok(Self {
            project_id,
            project_name,
            category,
            enabled: true,
        })
    }

    /// Check if SPARC is enabled
    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    /// Get project name
    pub fn project_name(&self) -> &str {
        &self.project_name
    }
}

impl Default for SPARCProject {
    fn default() -> Self {
        Self::new("default".to_string())
    }
}

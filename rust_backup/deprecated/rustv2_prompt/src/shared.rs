//! Shared data types for DSPy engine-server communication

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
    pub name: String,
    pub version: String,
    pub last_updated: String,
}

impl Default for TemplateMetadata {
    fn default() -> Self {
        Self {
            name: String::new(),
            version: "1.0.0".to_string(),
            last_updated: chrono::Utc::now().to_rfc3339(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateSyncRequest {
    pub template_name: String,
}

impl TemplateSyncRequest {
    pub fn new(template_name: &str) -> Self {
        Self { template_name: template_name.to_string() }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineStats {
    pub template_name: String,
    pub usage_count: u32,
    pub performance_score: f64,
}

impl Default for EngineStats {
    fn default() -> Self {
        Self {
            template_name: String::new(),
            usage_count: 0,
            performance_score: 0.0,
        }
    }
}
//! Template Loader Module
//! Handles loading and syncing DSPy templates

use anyhow::Result;
use serde_json::Value;
use crate::shared::{TemplateMetadata, TemplateSyncRequest};

/// NATS subject constants
pub const NATS_TEMPLATE_SYNC: &str = "dspy.template.sync";

pub struct TemplateLoader {
    pub local_templates: std::collections::HashMap<String, Value>,
}

impl TemplateLoader {
    pub fn new() -> Self {
        Self {
            local_templates: std::collections::HashMap::new(),
        }
    }

    /// Load template from local cache or global source
    pub fn load_template(&self, template_name: &str) -> Result<Value> {
        if let Some(template) = self.local_templates.get(template_name) {
            Ok(template.clone())
        } else {
            // In real implementation, would fetch from global registry
            Err(anyhow::anyhow!("Template {} not found", template_name))
        }
    }

    /// Request template sync from central server via NATS
    pub fn request_template_sync(&self, template_name: &str) -> Result<TemplateMetadata> {
        // Placeholder for NATS communication
        // Real implementation would publish to NATS_TEMPLATE_SYNC
        Ok(TemplateMetadata {
            name: template_name.to_string(),
            version: "1.0.0".to_string(),
            last_updated: chrono::Utc::now().to_rfc3339(),
        })
    }

    /// Store template locally
    pub fn store_template(&mut self, name: String, template: Value) {
        self.local_templates.insert(name, template);
    }
}

impl Default for TemplateLoader {
    fn default() -> Self {
        Self::new()
    }
}

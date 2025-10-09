//! Global Template Registry
//! Manages global templates, versioning, and sync

use std::collections::HashMap;
use crate::shared::TemplateMetadata;

pub struct TemplateRegistry {
    pub templates: HashMap<String, TemplateMetadata>,
}

impl TemplateRegistry {
    pub fn new() -> Self {
        Self {
            templates: HashMap::new(),
        }
    }

    /// Register a new template
    pub fn register_template(&mut self, metadata: TemplateMetadata) {
        self.templates.insert(metadata.name.clone(), metadata);
    }

    /// Get template metadata
    pub fn get_template_metadata(&self, name: &str) -> Option<TemplateMetadata> {
        self.templates.get(name).cloned()
    }

    /// List all templates
    pub fn list_templates(&self) -> Vec<String> {
        self.templates.keys().cloned().collect()
    }

    /// Update template version
    pub fn update_template_version(&mut self, name: &str, version: String) {
        if let Some(metadata) = self.templates.get_mut(name) {
            metadata.version = version;
            metadata.last_updated = chrono::Utc::now().to_rfc3339();
        }
    }
}

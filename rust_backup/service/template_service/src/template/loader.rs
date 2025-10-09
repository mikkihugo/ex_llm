//! Template loader with composition support
//!
//! Handles loading templates with:
//! - Inheritance (extends)
//! - Composition (compose bits)
//! - Workflows (multi-phase SPARC)

use super::Template;
use anyhow::{Context, Result};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};

/// Template loader with composition support
pub struct TemplateLoader {
    /// Base directory for templates
    templates_dir: PathBuf,
    /// Cache of loaded templates
    cache: HashMap<String, Template>,
}

impl TemplateLoader {
    /// Create a new template loader
    pub fn new(templates_dir: impl Into<PathBuf>) -> Self {
        Self {
            templates_dir: templates_dir.into(),
            cache: HashMap::new(),
        }
    }

    /// Load a template with full composition resolution
    pub fn load(&mut self, template_path: &str) -> Result<Template> {
        // Check cache first
        if let Some(cached) = self.cache.get(template_path) {
            return Ok(cached.clone());
        }

        // Load the base template
        let mut template = self.load_raw(template_path)?;

        // Resolve inheritance (extends)
        if let Some(ref parent_path) = template.extends.clone() {
            let parent = self.load(parent_path)?;
            template = self.merge_with_parent(template, parent)?;
        }

        // Load and compose bits
        if let Some(ref compose_paths) = template.compose.clone() {
            let bits_content = self.load_bits(compose_paths)?;
            template = self.apply_bits(template, bits_content)?;
        }

        // Load workflows
        if let Some(ref workflow_paths) = template.workflows.clone() {
            let workflows = self.load_workflows(workflow_paths)?;
            template.metadata.tags.push("sparc".to_string());
            // Store workflow info in metadata or extend Template struct
        }

        // Cache the resolved template
        self.cache.insert(template_path.to_string(), template.clone());

        Ok(template)
    }

    /// Load a template from disk without resolving composition
    fn load_raw(&self, template_path: &str) -> Result<Template> {
        let full_path = self.templates_dir.join(template_path);

        let content = fs::read_to_string(&full_path)
            .with_context(|| format!("Failed to read template: {}", template_path))?;

        let template: Template = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse template JSON: {}", template_path))?;

        Ok(template)
    }

    /// Load markdown bits
    fn load_bits(&self, bit_paths: &[String]) -> Result<Vec<String>> {
        let mut bits = Vec::new();

        for bit_path in bit_paths {
            let full_path = self.templates_dir.join(bit_path);
            let content = fs::read_to_string(&full_path)
                .with_context(|| format!("Failed to read bit: {}", bit_path))?;
            bits.push(content);
        }

        Ok(bits)
    }

    /// Load workflow templates
    fn load_workflows(&mut self, workflow_paths: &[String]) -> Result<Vec<Template>> {
        let mut workflows = Vec::new();

        for workflow_path in workflow_paths {
            let workflow = self.load(workflow_path)?;
            workflows.push(workflow);
        }

        Ok(workflows)
    }

    /// Merge template with parent (inheritance)
    fn merge_with_parent(&self, mut child: Template, parent: Template) -> Result<Template> {
        // Child overrides parent, but inherits missing fields

        // Inherit name and description if not set
        if child.name.is_empty() {
            child.name = parent.name;
        }
        if child.description.is_empty() {
            child.description = parent.description;
        }

        // Merge metadata tags
        for tag in parent.metadata.tags {
            if !child.metadata.tags.contains(&tag) {
                child.metadata.tags.push(tag);
            }
        }

        // Inherit AI signature if not set
        if child.ai_signature.is_none() {
            child.ai_signature = parent.ai_signature;
        }

        // Prepend parent template content if child has content
        if let Some(ref mut child_content) = child.template_content {
            if let Some(parent_content) = parent.template_content {
                *child_content = format!("{}\n\n{}", parent_content, child_content);
            }
        } else {
            child.template_content = parent.template_content;
        }

        // Merge compose bits
        if let Some(parent_compose) = parent.compose {
            let child_compose = child.compose.get_or_insert_with(Vec::new);
            for bit in parent_compose {
                if !child_compose.contains(&bit) {
                    child_compose.push(bit);
                }
            }
        }

        Ok(child)
    }

    /// Apply bits to template content
    fn apply_bits(&self, mut template: Template, bits: Vec<String>) -> Result<Template> {
        if let Some(ref mut content) = template.template_content {
            // Prepend bits as context/guidance
            let bits_section = bits.join("\n\n---\n\n");
            *content = format!(
                "<!-- COMPOSABLE BITS -->\n{}\n\n<!-- TEMPLATE -->\n{}",
                bits_section, content
            );
        }

        Ok(template)
    }

    /// Clear the cache
    pub fn clear_cache(&mut self) {
        self.cache.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_loader_creation() {
        let loader = TemplateLoader::new("templates");
        assert_eq!(loader.templates_dir, PathBuf::from("templates"));
    }

    #[test]
    fn test_cache() {
        let mut loader = TemplateLoader::new("templates");
        assert_eq!(loader.cache.len(), 0);

        loader.clear_cache();
        assert_eq!(loader.cache.len(), 0);
    }
}

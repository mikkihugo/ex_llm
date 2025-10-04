//! Cognitive template system for FACT

use crate::engine::{
  Aggregation, Analysis, Filter, Operation, ProcessingStep, Transform,
};
use ahash::AHashMap;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

// Include the generated AI templates
include!(concat!(env!("OUT_DIR"), "/ai_templates.rs"));

/// AI signature for code generation (simplified for JSON serialization)
/// This is a simplified version that can be converted to the full MetaSignature
/// when used with the prompt-engine crate
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiSignature {
  /// Signature name
  pub name: String,
  
  /// Input fields and their descriptions
  pub inputs: std::collections::HashMap<String, String>,
  
  /// Output fields and their descriptions
  pub outputs: std::collections::HashMap<String, String>,
  
  /// Instruction for the LLM
  pub instruction: String,
}

impl AiSignature {
  /// Convert to a full DSPy MetaSignature when prompt-engine is available
  pub fn to_metasignature(&self) -> prompt_engine::dspy::InstructionGenerator {
    // Convert AiSignature to InstructionGenerator MetaSignature
    prompt_engine::dspy::InstructionGenerator {
      current_instruction: self.instruction.clone(),
      optimized_instruction: self.instruction.clone(),
    }
  }
}

/// A cognitive template for processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
  /// Unique template identifier
  pub id: String,

  /// Human-readable name
  pub name: String,

  /// Template description
  pub description: String,

  /// Processing steps
  pub steps: Vec<ProcessingStep>,

  /// Template metadata
  pub metadata: TemplateMetadata,
  
  /// AI signature for code generation (optional)
  pub ai_signature: Option<AiSignature>,
  
  /// Template content (for code generation templates)
  pub template_content: Option<String>,
}

/// Template metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMetadata {
  /// Template version
  pub version: String,

  /// Template author
  pub author: String,

  /// Creation date
  pub created_at: String,

  /// Last modified date
  pub updated_at: String,

  /// Tags for categorization
  pub tags: Vec<String>,

  /// Performance characteristics
  pub performance: PerformanceProfile,
}

/// Performance profile for a template
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceProfile {
  /// Average execution time in milliseconds
  pub avg_execution_time_ms: f64,

  /// Memory usage in bytes
  pub memory_usage_bytes: usize,

  /// Complexity rating (1-10)
  pub complexity: u8,
}

/// Registry for managing templates
pub struct RegistryTemplate {
  templates: Arc<RwLock<AHashMap<String, Template>>>,
}

impl RegistryTemplate {
  /// Create a new template registry
  #[must_use]
  pub fn new() -> Self {
    let registry = Self {
      templates: Arc::new(RwLock::new(AHashMap::new())),
    };

    // Load default templates
    registry.load_default_templates();

    registry
  }

  /// Register a template
  pub fn register(&self, template: Template) {
    self.templates.write().insert(template.id.clone(), template);
  }

  /// Get a template by ID
  #[must_use]
  pub fn get(&self, id: &str) -> Option<Template> {
    self.templates.read().get(id).cloned()
  }

  /// List all template IDs
  #[must_use]
  pub fn list(&self) -> Vec<String> {
    self.templates.read().keys().cloned().collect()
  }

  /// Remove a template
  #[must_use]
  pub fn remove(&self, id: &str) -> Option<Template> {
    self.templates.write().remove(id)
  }

  /// Load AI templates from generated code
  fn load_ai_templates(&self) {
    // Register all AI templates
    for template in get_ai_templates() {
      self.register(template);
    }
  }

  /// Load default templates
  #[allow(clippy::too_many_lines)]
  fn load_default_templates(&self) {
    // Load generated AI templates
    self.load_ai_templates();
    // Analysis template
    self.register(Template {
      id: "analysis-basic".to_string(),
      name: "Basic Analysis".to_string(),
      description: "Performs basic statistical and pattern analysis"
        .to_string(),
      steps: vec![
        ProcessingStep {
          name: "normalize".to_string(),
          operation: Operation::Transform(Transform::Normalize),
        },
        ProcessingStep {
          name: "analyze".to_string(),
          operation: Operation::Analyze(Analysis::Statistical),
        },
        ProcessingStep {
          name: "expand".to_string(),
          operation: Operation::Transform(Transform::Expand),
        },
      ],
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "FACT Team".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: vec!["analysis".to_string(), "statistics".to_string()],
        performance: PerformanceProfile {
          avg_execution_time_ms: 50.0,
          memory_usage_bytes: 1024 * 1024, // 1MB
          complexity: 3,
        },
      },
      ai_signature: None,
      template_content: None,
    });

    // CodePattern detection template
    self.register(Template {
      id: "pattern-detection".to_string(),
      name: "CodePattern Detection".to_string(),
      description: "Detects patterns in structured data".to_string(),
      steps: vec![
        ProcessingStep {
          name: "normalize".to_string(),
          operation: Operation::Transform(Transform::Normalize),
        },
        ProcessingStep {
          name: "pattern-analysis".to_string(),
          operation: Operation::Analyze(Analysis::CodePattern),
        },
        ProcessingStep {
          name: "semantic-enrichment".to_string(),
          operation: Operation::Analyze(Analysis::Semantic),
        },
      ],
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "FACT Team".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: vec![
          "pattern".to_string(),
          "detection".to_string(),
          "ai".to_string(),
        ],
        performance: PerformanceProfile {
          avg_execution_time_ms: 75.0,
          memory_usage_bytes: 2 * 1024 * 1024, // 2MB
          complexity: 5,
        },
      },
      ai_signature: None,
      template_content: None,
    });

    // Data aggregation template
    self.register(Template {
      id: "data-aggregation".to_string(),
      name: "Data Aggregation".to_string(),
      description: "Aggregates numerical data with various operations"
        .to_string(),
      steps: vec![
        ProcessingStep {
          name: "filter-numbers".to_string(),
          operation: Operation::Filter(Filter::Range {
            min: 0.0,
            max: 1_000_000.0,
          }),
        },
        ProcessingStep {
          name: "sum".to_string(),
          operation: Operation::Aggregate(Aggregation::Sum),
        },
        ProcessingStep {
          name: "average".to_string(),
          operation: Operation::Aggregate(Aggregation::Average),
        },
        ProcessingStep {
          name: "count".to_string(),
          operation: Operation::Aggregate(Aggregation::Count),
        },
      ],
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "FACT Team".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: vec![
          "aggregation".to_string(),
          "numerical".to_string(),
          "statistics".to_string(),
        ],
        performance: PerformanceProfile {
          avg_execution_time_ms: 25.0,
          memory_usage_bytes: 512 * 1024, // 512KB
          complexity: 2,
        },
      },
      ai_signature: None,
      template_content: None,
    });

    // Quick transform template
    self.register(Template {
      id: "quick-transform".to_string(),
      name: "Quick Transform".to_string(),
      description: "Fast data transformation for caching".to_string(),
      steps: vec![
        ProcessingStep {
          name: "compress".to_string(),
          operation: Operation::Transform(Transform::Compress),
        },
        ProcessingStep {
          name: "normalize".to_string(),
          operation: Operation::Transform(Transform::Normalize),
        },
      ],
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "FACT Team".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: vec![
          "transform".to_string(),
          "fast".to_string(),
          "cache".to_string(),
        ],
        performance: PerformanceProfile {
          avg_execution_time_ms: 10.0,
          memory_usage_bytes: 256 * 1024, // 256KB
          complexity: 1,
        },
      },
      ai_signature: None,
      template_content: None,
    });

    // Tool knowledge storage template
    self.register(Template {
      id: "tool-knowledge-storage".to_string(),
      name: "Tool Knowledge Storage".to_string(),
      description: "Store tool knowledge data in FACT database".to_string(),
      steps: vec![ProcessingStep {
        name: "store-knowledge".to_string(),
        operation: Operation::Transform(Transform::Normalize), // Placeholder - will be handled specially
      }],
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "FACT Team".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: vec![
          "storage".to_string(),
          "knowledge".to_string(),
          "tool".to_string(),
        ],
        performance: PerformanceProfile {
          avg_execution_time_ms: 10.0,
          memory_usage_bytes: 1024 * 10, // 10KB
          complexity: 1,
        },
      },
      ai_signature: None,
      template_content: None,
    });
  }

  /// Search templates by tags
  #[must_use]
  pub fn search_by_tags(&self, tags: &[String]) -> Vec<Template> {
    self
      .templates
      .read()
      .values()
      .filter(|template| {
        tags.iter().any(|tag| template.metadata.tags.contains(tag))
      })
      .cloned()
      .collect()
  }

  /// Get templates sorted by performance
  ///
  /// # Panics
  /// Panics if the performance comparison fails (should not happen in normal operation)
  #[must_use]
  pub fn get_by_performance(&self, max_complexity: u8) -> Vec<Template> {
    let mut templates: Vec<_> = self
      .templates
      .read()
      .values()
      .filter(|t| t.metadata.performance.complexity <= max_complexity)
      .cloned()
      .collect();

    templates.sort_by(|a, b| {
      a.metadata
        .performance
        .avg_execution_time_ms
        .partial_cmp(&b.metadata.performance.avg_execution_time_ms)
        .unwrap()
    });

    templates
  }
}

impl Default for RegistryTemplate {
  fn default() -> Self {
    Self::new()
  }
}

/// Builder for creating templates
pub struct TemplateBuilder {
  id: String,
  name: String,
  description: String,
  steps: Vec<ProcessingStep>,
  tags: Vec<String>,
  ai_signature: Option<AiSignature>,
  template_content: Option<String>,
}

impl TemplateBuilder {
  /// Create a new template builder
  pub fn new(id: impl Into<String>) -> Self {
    Self {
      id: id.into(),
      name: String::new(),
      description: String::new(),
      steps: Vec::new(),
      tags: Vec::new(),
      ai_signature: None,
      template_content: None,
    }
  }

  /// Set the template name
  #[must_use]
  pub fn name(mut self, name: impl Into<String>) -> Self {
    self.name = name.into();
    self
  }

  /// Set the template description
  #[must_use]
  pub fn description(mut self, description: impl Into<String>) -> Self {
    self.description = description.into();
    self
  }

  /// Add a processing step
  #[must_use]
  pub fn add_step(mut self, step: ProcessingStep) -> Self {
    self.steps.push(step);
    self
  }

  /// Add a tag
  #[must_use]
  pub fn add_tag(mut self, tag: impl Into<String>) -> Self {
    self.tags.push(tag.into());
    self
  }

  /// Set AI signature
  #[must_use]
  pub fn ai_signature(mut self, signature: AiSignature) -> Self {
    self.ai_signature = Some(signature);
    self
  }

  /// Set template content
  #[must_use]
  pub fn template_content(mut self, content: impl Into<String>) -> Self {
    self.template_content = Some(content.into());
    self
  }

  /// Build the template
  #[must_use]
  pub fn build(self) -> Template {
    Template {
      id: self.id,
      name: self.name,
      description: self.description,
      steps: self.steps,
      metadata: TemplateMetadata {
        version: "1.0.0".to_string(),
        author: "Custom".to_string(),
        created_at: chrono::Utc::now().to_rfc3339(),
        updated_at: chrono::Utc::now().to_rfc3339(),
        tags: self.tags,
        performance: PerformanceProfile {
          avg_execution_time_ms: 0.0,
          memory_usage_bytes: 0,
          complexity: 5,
        },
      },
      ai_signature: self.ai_signature,
      template_content: self.template_content,
    }
  }
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn test_template_registry() {
    let registry = RegistryTemplate::new();

    // Check default templates are loaded
    assert!(registry.get("analysis-basic").is_some());
    assert!(registry.get("pattern-detection").is_some());
    assert!(registry.get("data-aggregation").is_some());
    assert!(registry.get("quick-transform").is_some());

    // Test listing
    let templates = registry.list();
    assert!(templates.len() >= 4);
  }

  #[test]
  fn test_template_builder() {
    let template = TemplateBuilder::new("custom-template")
      .name("Custom Template")
      .description("A custom template for testing")
      .add_tag("custom")
      .add_tag("test")
      .add_step(ProcessingStep {
        name: "normalize".to_string(),
        operation: Operation::Transform(Transform::Normalize),
      })
      .build();

    assert_eq!(template.id, "custom-template");
    assert_eq!(template.name, "Custom Template");
    assert_eq!(template.steps.len(), 1);
    assert_eq!(template.metadata.tags.len(), 2);
  }

  #[test]
  fn test_search_by_tags() {
    let registry = RegistryTemplate::new();

    let analysis_templates =
      registry.search_by_tags(&[String::from("analysis")]);
    assert!(!analysis_templates.is_empty());

    let pattern_templates = registry.search_by_tags(&[String::from("pattern")]);
    assert!(!pattern_templates.is_empty());
  }
}

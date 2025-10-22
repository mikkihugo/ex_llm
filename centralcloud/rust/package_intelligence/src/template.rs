//! Template types for package intelligence

use serde::{Deserialize, Serialize};

/// Registry template for package analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryTemplate {
    pub id: String,
    pub name: String,
    pub content: String,
    pub version: String,
}

impl RegistryTemplate {
    pub fn new() -> Self {
        Self {
            id: String::new(),
            name: String::new(),
            content: String::new(),
            version: String::new(),
        }
    }

    /// Convert RegistryTemplate to Template
    pub fn to_template(&self) -> Template {
        Template {
            id: self.id.clone(),
            name: self.name.clone(),
            content: self.content.clone(),
            steps: vec![], // RegistryTemplate doesn't have steps, so empty
        }
    }
}

impl Default for RegistryTemplate {
    fn default() -> Self {
        Self::new()
    }
}

/// Template for processing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
    pub id: String,
    pub name: String,
    pub content: String,
    pub steps: Vec<ProcessingStep>,
}

/// Processing step
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessingStep {
    pub operation: Operation,
}

/// Operation types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Operation {
    Transform(Transform),
    Analyze(Analysis),
    Filter(Filter),
    Aggregate(Aggregation),
    Generate(Generation),
}

/// Transform operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transform {
    pub transform_type: String,
    pub parameters: serde_json::Value,
}

/// Analysis operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Analysis {
    pub analysis_type: String,
    pub parameters: serde_json::Value,
}

/// Filter operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Filter {
    pub filter_type: String,
    pub parameters: serde_json::Value,
}

/// Aggregation operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Aggregation {
    pub aggregation_type: String,
    pub parameters: serde_json::Value,
}

/// Generation operation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Generation {
    pub generation_type: String,
    pub parameters: serde_json::Value,
}

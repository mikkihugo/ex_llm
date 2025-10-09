//! Common metadata interface for all language parsers
//!
//! This module defines a common interface that all language parsers can implement
//! to provide consistent metadata to the SPARC engine for prompt generation.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Common metadata interface that all language parsers implement
pub trait DocumentationMetadataProvider {
    /// Get graph nodes from the parsed code
    fn get_graph_nodes(&self) -> Vec<String>;

    /// Get graph edges from the parsed code
    fn get_graph_edges(&self) -> Vec<GraphEdge>;

    /// Get vector embeddings from the parsed code
    fn get_vector_embeddings(&self) -> Vec<String>;

    /// Get dependencies from the parsed code
    fn get_dependencies(&self) -> Vec<String>;

    /// Get related items from the parsed code
    fn get_related_items(&self) -> Vec<String>;

    /// Get categories from the parsed code
    fn get_categories(&self) -> Vec<String>;

    /// Get safety levels from the parsed code
    fn get_safety_levels(&self) -> Vec<String>;

    /// Get MVP status from the parsed code
    fn get_mvp_status(&self) -> Vec<String>;

    /// Get complexity levels from the parsed code
    fn get_complexity_levels(&self) -> Vec<String>;

    /// Get versions from the parsed code
    fn get_versions(&self) -> Vec<String>;

    /// Get function signatures from the parsed code
    fn get_function_signatures(&self) -> Vec<FunctionSignature>;

    /// Get language-specific metadata
    fn get_language_specific(&self) -> HashMap<String, String>;
}

/// Graph edge relationship between nodes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub from: String,
    pub to: String,
    pub relationship_type: Option<String>,
}

/// Function signature information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionSignature {
    pub name: String,
    pub inputs: Vec<String>,
    pub outputs: Vec<String>,
    pub description: String,
    pub language: String,
}

/// Common metadata structure that can be used by SPARC
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommonDocumentationMetadata {
    pub graph_nodes: Vec<String>,
    pub graph_edges: Vec<GraphEdge>,
    pub vector_embeddings: Vec<String>,
    pub dependencies: Vec<String>,
    pub related_items: Vec<String>,
    pub categories: Vec<String>,
    pub safety_levels: Vec<String>,
    pub mvp_status: Vec<String>,
    pub complexity_levels: Vec<String>,
    pub versions: Vec<String>,
    pub function_signatures: Vec<FunctionSignature>,
    pub language_specific: HashMap<String, String>,
}

impl CommonDocumentationMetadata {
    /// Create empty metadata
    pub fn new() -> Self {
        Self {
            graph_nodes: Vec::new(),
            graph_edges: Vec::new(),
            vector_embeddings: Vec::new(),
            dependencies: Vec::new(),
            related_items: Vec::new(),
            categories: Vec::new(),
            safety_levels: Vec::new(),
            mvp_status: Vec::new(),
            complexity_levels: Vec::new(),
            versions: Vec::new(),
            function_signatures: Vec::new(),
            language_specific: HashMap::new(),
        }
    }

    /// Convert from a metadata provider
    pub fn from_provider<T: DocumentationMetadataProvider>(provider: &T) -> Self {
        Self {
            graph_nodes: provider.get_graph_nodes(),
            graph_edges: provider.get_graph_edges(),
            vector_embeddings: provider.get_vector_embeddings(),
            dependencies: provider.get_dependencies(),
            related_items: provider.get_related_items(),
            categories: provider.get_categories(),
            safety_levels: provider.get_safety_levels(),
            mvp_status: provider.get_mvp_status(),
            complexity_levels: provider.get_complexity_levels(),
            versions: provider.get_versions(),
            function_signatures: provider.get_function_signatures(),
            language_specific: provider.get_language_specific(),
        }
    }
}

impl Default for CommonDocumentationMetadata {
    fn default() -> Self {
        Self::new()
    }
}
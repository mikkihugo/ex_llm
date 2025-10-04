//! Feature Extractor Trait and Types
//!
//! Common interface for extracting features from code across languages

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Feature type classification
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum FeatureType {
    Function,
    Struct,
    Enum,
    Trait,
    Impl,
    Constant,
    Module,
}

/// Extracted feature from code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtractedFeature {
    /// Feature name
    pub name: String,

    /// Feature type
    pub feature_type: FeatureType,

    /// Is public?
    pub is_public: bool,

    /// Documentation
    pub documentation: Option<String>,

    /// Source location
    pub file_path: String,
    pub line_number: Option<usize>,

    /// Function signature (if applicable)
    pub signature: Option<String>,

    /// Module path (e.g., "crate::module::submodule")
    pub module_path: String,

    /// Additional metadata
    pub metadata: serde_json::Value,
}

/// Trait for extracting features from source code
pub trait FeatureExtractor {
    /// Extract features from source code
    fn extract_features(&self, source: &str, file_path: &Path) -> Result<Vec<ExtractedFeature>>;

    /// Get extractor name
    fn name(&self) -> &str;
}

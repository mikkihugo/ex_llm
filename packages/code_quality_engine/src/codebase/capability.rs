//! Code Capability Model - SAFe 6.0 Aligned
//!
//! Represents WHAT CODE CAN DO rather than what it IS.
//! Aligns with SAFe 6.0 terminology where Capabilities are customer-facing features.
//!
//! Architecture Decision:
//! - ✅ Store in analysis-suite (analysis results)
//! - ❌ NOT in fact-system (external facts only)

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// What a piece of code CAN DO
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeCapability {
    /// Unique identifier (e.g., "rust_parser::parse_rust_file")
    pub id: String,

    /// Human-readable name (e.g., "Parse Rust Files")
    pub name: String,

    /// What this capability provides
    pub kind: CapabilityKind,

    /// Function signature or struct definition
    pub signature: String,

    /// Documentation explaining what it does
    pub documentation: String,

    /// Where this capability lives
    pub location: CapabilityLocation,

    /// What other capabilities this depends on
    pub dependencies: Vec<String>,

    /// Examples of how to use this capability
    pub usage_examples: Vec<String>,

    /// Semantic embedding for search (384-dim for transformers)
    pub embedding: Option<Vec<f32>>,

    /// Metadata for filtering/categorization
    pub metadata: CapabilityMetadata,
}

/// Types of code capabilities - what code CAN DO
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum CapabilityKind {
    /// Parsing capability (e.g., "parse TypeScript")
    Parser { language: String },

    /// Analysis capability (e.g., "detect code smells")
    Analyzer { analysis_type: String },

    /// Transformation capability (e.g., "refactor code")
    Transformer { transformation_type: String },

    /// Storage capability (e.g., "store embeddings")
    Storage { storage_type: String },

    /// Search capability (e.g., "semantic code search")
    Search { search_type: String },

    /// Generation capability (e.g., "generate code")
    Generator { generation_type: String },

    /// Coordination capability (e.g., "orchestrate analysis")
    Coordinator { coordination_type: String },

    /// Integration capability (e.g., "integrate with Git")
    Integration { integration_type: String },
}

/// Where a capability lives in the codebase
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilityLocation {
    /// Crate name (e.g., "rust-parser")
    pub crate_name: String,

    /// Module path (e.g., "parser::rust")
    pub module_path: String,

    /// File path (e.g., "crates/rust-parser/src/lib.rs")
    pub file_path: String,

    /// Line number range
    pub line_range: (usize, usize),
}

/// Capability metadata for SAFe 6.0 alignment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilityMetadata {
    /// When this was analyzed
    pub analyzed_at: u64,

    /// Version of the code
    pub version: Option<String>,

    /// Maturity level (experimental, beta, stable)
    pub maturity: MaturityLevel,

    /// Performance characteristics
    pub performance: PerformanceProfile,

    /// Testing status
    pub test_coverage: Option<f32>,

    /// SAFe enabler type (if this is infrastructure)
    pub enabler_type: Option<EnablerType>,
}

/// Maturity level of a capability
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum MaturityLevel {
    /// Experimental - may change
    Experimental,

    /// Beta - mostly stable
    Beta,

    /// Stable - production ready
    Stable,

    /// Deprecated - being phased out
    Deprecated,
}

/// Performance profile for capability execution
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PerformanceProfile {
    /// Average execution time in milliseconds
    pub avg_time_ms: Option<f32>,

    /// Memory usage estimate in MB
    pub memory_mb: Option<f32>,

    /// Whether this is async
    pub is_async: bool,

    /// Blocking behavior
    pub blocks_on: Option<String>,
}

/// SAFe 6.0 Enabler Type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum EnablerType {
    /// Architectural enabler (foundational infrastructure)
    Architectural,

    /// Infrastructure enabler (platforms, tools)
    Infrastructure,

    /// Exploration enabler (research, spikes)
    Exploration,

    /// Compliance enabler (security, regulations)
    Compliance,
}

/// Search result for capability queries
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapabilitySearchResult {
    /// The capability
    pub capability: CodeCapability,

    /// Relevance score (0.0 to 1.0)
    pub score: f32,

    /// Why this matched (for explainability)
    pub match_reason: String,
}

impl CodeCapability {
    /// Create a new capability
    pub fn new(
        id: impl Into<String>,
        name: impl Into<String>,
        kind: CapabilityKind,
        signature: impl Into<String>,
        location: CapabilityLocation,
    ) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            kind,
            signature: signature.into(),
            documentation: String::new(),
            location,
            dependencies: Vec::new(),
            usage_examples: Vec::new(),
            embedding: None,
            metadata: CapabilityMetadata::default(),
        }
    }

    /// Add documentation
    pub fn with_documentation(mut self, docs: impl Into<String>) -> Self {
        self.documentation = docs.into();
        self
    }

    /// Add dependencies
    pub fn with_dependencies(mut self, deps: Vec<String>) -> Self {
        self.dependencies = deps;
        self
    }

    /// Add usage examples
    pub fn with_examples(mut self, examples: Vec<String>) -> Self {
        self.usage_examples = examples;
        self
    }

    /// Set embedding for semantic search
    pub fn with_embedding(mut self, embedding: Vec<f32>) -> Self {
        self.embedding = Some(embedding);
        self
    }
}

impl Default for CapabilityMetadata {
    fn default() -> Self {
        Self {
            analyzed_at: chrono::Utc::now().timestamp() as u64,
            version: None,
            maturity: MaturityLevel::Beta,
            performance: PerformanceProfile::default(),
            test_coverage: None,
            enabler_type: None,
        }
    }
}

/// Capability index for fast lookups
#[derive(Debug, Default)]
pub struct CapabilityIndex {
    /// All capabilities by ID
    by_id: HashMap<String, CodeCapability>,

    /// Capabilities by kind
    by_kind: HashMap<String, Vec<String>>,

    /// Capabilities by crate
    by_crate: HashMap<String, Vec<String>>,
}

impl CapabilityIndex {
    pub fn new() -> Self {
        Self::default()
    }

    /// Add capability to index
    pub fn add(&mut self, capability: CodeCapability) {
        let id = capability.id.clone();
        let kind_key = format!("{:?}", capability.kind);
        let crate_name = capability.location.crate_name.clone();

        // Index by ID
        self.by_id.insert(id.clone(), capability);

        // Index by kind
        self.by_kind.entry(kind_key).or_default().push(id.clone());

        // Index by crate
        self.by_crate.entry(crate_name).or_default().push(id);
    }

    /// Get capability by ID
    pub fn get(&self, id: &str) -> Option<&CodeCapability> {
        self.by_id.get(id)
    }

    /// Find capabilities by kind
    pub fn find_by_kind(&self, kind_pattern: &str) -> Vec<&CodeCapability> {
        self.by_kind
            .iter()
            .filter(|(k, _)| k.contains(kind_pattern))
            .flat_map(|(_, ids)| ids.iter().filter_map(|id| self.by_id.get(id)))
            .collect()
    }

    /// Find capabilities by crate
    pub fn find_by_crate(&self, crate_name: &str) -> Vec<&CodeCapability> {
        self.by_crate
            .get(crate_name)
            .map(|ids| ids.iter().filter_map(|id| self.by_id.get(id)).collect())
            .unwrap_or_default()
    }

    /// Get all capabilities
    pub fn all(&self) -> Vec<&CodeCapability> {
        self.by_id.values().collect()
    }

    /// Count capabilities
    pub fn count(&self) -> usize {
        self.by_id.len()
    }
}

use std::collections::HashMap;

use anyhow::Result;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

use crate::types::types::{
    CodeComplexity, CodeElementCategory, CodeElementType, CodeLifecycleStage, CodeOwnership,
    CodeRiskLevel,
};

pub struct AnalysisAgentCapabilities {
    /// Can detect duplicate field names
    pub duplicate_detection: bool,
    /// Can suggest better naming conventions
    pub naming_suggestions: bool,
    /// Can analyze code structure
    pub structure_analysis: bool,
    /// Can find unused code
    pub unused_code_detection: bool,
    /// Can suggest refactoring
    pub refactoring_suggestions: bool,
}

/// Code analysis agent trait
#[async_trait]
pub trait CodeAnalysisAgent {
    /// Analyze code for duplicates and suggest improvements
    async fn analyze_code(
        &self,
        code: &str,
        context: &CodeContext,
    ) -> Result<CodeAnalysisResult, String>;

    /// Check if a field name would create duplicates
    async fn check_field_name(
        &self,
        name: &str,
        context: &CodeContext,
    ) -> Result<NameCheckResult, String>;

    /// Check if a function name would create duplicates
    async fn check_function_name(
        &self,
        name: &str,
        context: &CodeContext,
    ) -> Result<NameCheckResult, String>;

    /// Get suggestions for better naming
    async fn suggest_names(
        &self,
        base_name: &str,
        context: &CodeContext,
    ) -> Result<Vec<String>, String>;

    /// Find all duplicates in the codebase
    async fn find_duplicates(&self, context: &CodeContext) -> Result<Vec<DuplicateInfo>, String>;
}

/// Context for code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeContext {
    pub code_context_module_path: String,
    pub code_context_code_module: String, // Technical module (e.g., "audit", "routing", "config")
    pub code_context_purpose: String,
    pub code_context_current_struct: Option<String>,
    pub code_context_current_function: Option<String>,
    pub code_context_agent_id: String,
    /// Category of the code element being analyzed
    pub category: CodeElementCategory,
    /// Language/framework context
    pub language: String, // e.g., "rust", "typescript", "python"
    /// Owning crate or package scope
    pub crate_name: Option<String>,
    /// Framework or library context
    pub framework: Option<String>, // e.g., "tokio", "serde", "async-trait"
    /// SPARC phase context for storing phase-specific data
    pub sparc_phase: Option<String>, // e.g., "specification", "architecture", "completion"
    /// Additional context for AI understanding
    pub ai_context: CodeUnderstandingContext,
}

/// Additional context to help AI understand code better
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeUnderstandingContext {
    /// What this code does in plain English
    pub human_description: String,
    /// Key concepts this code relates to
    pub related_concepts: Vec<String>,
    /// Dependencies this code has
    pub dependencies: Vec<String>,
    /// Performance characteristics
    pub performance_notes: Option<String>,
    /// Security considerations
    pub security_notes: Option<String>,
    /// Testing requirements
    pub testing_requirements: Option<String>,
    /// Code lifecycle stage
    pub lifecycle_stage: CodeLifecycleStage,
    /// Code ownership
    pub ownership: CodeOwnership,
    /// Code complexity level
    pub complexity: CodeComplexity,
    /// Risk level for changes
    pub risk_level: CodeRiskLevel,
    /// Last modified date
    pub last_modified: Option<String>,
    /// Author information
    pub author: Option<String>,
    /// Change frequency (how often this code changes)
    pub change_frequency: Option<String>,
    /// Business impact if this code breaks
    pub business_impact: Option<String>,
}

impl Default for CodeUnderstandingContext {
    fn default() -> Self {
        Self {
            human_description: "Code element".to_string(),
            related_concepts: Vec::new(),
            dependencies: Vec::new(),
            performance_notes: None,
            security_notes: None,
            testing_requirements: None,
            lifecycle_stage: CodeLifecycleStage::Development,
            ownership: CodeOwnership::CoreTeam,
            complexity: CodeComplexity::Simple,
            risk_level: CodeRiskLevel::Low,
            last_modified: None,
            author: None,
            change_frequency: None,
            business_impact: None,
        }
    }
}

/// Result of code analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeAnalysisResult {
    pub duplicates_found: Vec<DuplicateInfo>,
    pub naming_issues: Vec<NamingIssue>,
    pub unused_code: Vec<UnusedCodeInfo>,
    pub refactoring_suggestions: Vec<RefactoringSuggestion>,
    pub overall_score: f64,
    /// Complexity score (0.0-1.0, higher means more complex)
    #[serde(default)]
    pub complexity_score: f64,
    /// List of analyzed functions for deeper analysis
    #[serde(default)]
    pub functions: Vec<FunctionMetadata>,
    /// Detected dependencies
    #[serde(default)]
    pub dependencies: Vec<String>,
}

/// Information about a duplicate
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateInfo {
    pub duplicate_name: String,
    pub duplicate_type_name: String, // "field", "function", "struct", "enum"
    pub duplicate_locations: Vec<CodeLocation>,
    pub duplicate_severity: DuplicateSeverity,
    pub duplicate_suggestion: String,
    /// Category of the duplicate element
    pub duplicate_category: CodeElementCategory,
    /// Type of the duplicate element
    pub duplicate_element_type: CodeElementType,
    /// Language context
    pub language: String,
    /// Crate or package scope (if available)
    pub crate_scope: Option<String>,
}

/// Information about a naming issue
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingIssue {
    pub name: String,
    pub issue_type: String,
    pub description: String,
    pub suggestion: String,
    pub severity: NamingSeverity,
}

/// Information about unused code
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnusedCodeInfo {
    pub unused_code_name: String,
    pub unused_code_type_name: String,
    pub unused_code_location: CodeLocation,
    pub unused_code_reason: String,
}

/// Refactoring suggestion
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactoringSuggestion {
    pub refactoring_description: String,
    pub refactoring_benefit: String,
    pub refactoring_effort: RefactoringEffort,
    pub priority: RefactoringPriority,
}

/// Function metadata for analysis
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionMetadata {
    pub function_name: String,
    pub function_module_path: String,
    pub function_type: String,
    pub function_code_module: String,
    pub function_purpose: String,
    pub function_line_start: usize,
    pub function_line_end: usize,
    pub function_parameters: Vec<String>,
    pub function_return_type: Option<String>,
    pub function_complexity_score: f64,
}

impl Default for FunctionMetadata {
    fn default() -> Self {
        Self {
            function_name: String::new(),
            function_module_path: String::new(),
            function_type: "function".to_string(),
            function_code_module: String::new(),
            function_purpose: String::new(),
            function_line_start: 0,
            function_line_end: 0,
            function_parameters: Vec::new(),
            function_return_type: None,
            function_complexity_score: 0.0,
        }
    }
}

/// Code location information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeLocation {
    pub file_path: String,
    pub line_number: usize,
    pub column_number: usize,
    pub context: String,
    pub line_start: usize,
    pub line_end: usize,
}

/// Severity levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DuplicateSeverity {
    High,
    Medium,
    Low,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum NamingSeverity {
    High,
    Medium,
    Low,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactoringEffort {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactoringPriority {
    Low,
    Medium,
    High,
    Critical,
}

/// Result of a name check
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum NameCheckResult {
    Unique,
    Conflict {
        name: String,
        language: String,
        crate_scope: Option<String>,
        conflicting_locations: Vec<CodeLocation>,
        suggestion: String,
        severity: DuplicateSeverity,
    },
    BadCodePattern {
        name: String,
        issue: String,
        suggestion: String,
    },
}

fn sanitize_snake_identifier(input: &str) -> String {
    let mut ident = String::new();
    for ch in input.chars() {
        if ch.is_alphanumeric() {
            ident.push(ch.to_ascii_lowercase());
        } else if !ident.ends_with('_') {
            ident.push('_');
        }
    }
    ident.trim_matches('_').to_string()
}

fn sanitize_pascal_identifier(input: &str) -> String {
    input
        .split(|c: char| !c.is_alphanumeric())
        .filter(|segment| !segment.is_empty())
        .map(|segment| {
            let mut chars = segment.chars();
            match chars.next() {
                Some(first) => {
                    first.to_ascii_uppercase().to_string() + &chars.as_str().to_ascii_lowercase()
                }
                None => String::new(),
            }
        })
        .collect::<String>()
}

pub fn build_snake_prefix(crate_name: Option<&str>, module_prefix: &str) -> String {
    let mut parts = String::new();
    if let Some(crate_name) = crate_name {
        let sanitized = sanitize_snake_identifier(crate_name);
        if !sanitized.is_empty() {
            parts.push_str(&sanitized);
            parts.push('_');
        }
    }
    parts.push_str(module_prefix);
    parts
}

pub fn build_pascal_prefix(crate_name: Option<&str>, module_prefix: &str) -> String {
    let mut parts = String::new();
    if let Some(crate_name) = crate_name {
        let sanitized = sanitize_pascal_identifier(crate_name);
        if !sanitized.is_empty() {
            parts.push_str(&sanitized);
        }
    }
    parts.push_str(module_prefix);
    parts
}

/// Context for struct definitions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StructContext {
    pub struct_name: String,
    pub struct_module_path: String,
    pub struct_fields: Vec<String>,
    pub struct_purpose: String,
}

/// Context for function definitions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionContext {
    pub function_name: String,
    pub function_module_path: String,
    pub function_parameters: Vec<String>,
    pub function_return_type: Option<String>,
    pub function_purpose: String,
}

/// Registry of all code elements in the project
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryCode {
    /// All struct names with their contexts
    pub structs: HashMap<String, Vec<StructContext>>,
    /// All function names with their contexts
    pub functions: HashMap<String, Vec<FunctionContext>>,
}

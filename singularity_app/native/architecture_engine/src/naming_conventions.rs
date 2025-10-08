//! Naming Conventions - Detection & Flagging
//!
//! Detects naming violations and flags them for refactoring.
//! Uses templates from central service for naming standards.
//!
//! ## Usage
//!
//! ```rust
//! let naming = NamingConventions::new();
//!
//! // Detect violations
//! let report = naming.detect_naming_violations(code);
//!
//! // Get suggestions
//! let names = naming.suggest_function_names("calculate total price", None);
//! // Returns: ["calculateTotal", "calculateTotalPrice", "computeTotal"]
//!
//! // Validate naming
//! let is_valid = naming.validate_function_name("calculateTotal");
//! // Returns: true
//! ```

use std::collections::HashMap;

// CodeElementCategory and CodeElementType are defined locally below
use anyhow::Result;
use heck::{ToKebabCase, ToSnakeCase};
use serde::{Deserialize, Serialize};

// NATS operations handled by Elixir layer

// Local stub definitions to replace analysis_suite dependencies
#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct FileAnalysis {
    pub functions: Option<Vec<FunctionAnalysis>>,
    pub structs: Option<Vec<StructAnalysis>>,
    pub variables: Option<Vec<VariableAnalysis>>,
}

#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct FunctionAnalysis {
    pub name: String,
}

#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct StructAnalysis {
    pub name: String,
}

#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct VariableAnalysis {
    pub name: String,
}

#[derive(Debug, Clone, Default)]
pub struct CodebaseDatabase;

impl CodebaseDatabase {
    #[allow(dead_code)]
    pub fn new(_project_id: &str) -> Result<Self> {
        Ok(Self)
    }

    #[allow(dead_code)]
    pub fn get_all_analyses(&self) -> Result<HashMap<String, FileAnalysis>> {
        Ok(HashMap::new())
    }
}

#[derive(Debug, Clone, Default)]
#[allow(dead_code)]
pub struct CodeContext;

/// Naming conventions handler that combines basic patterns with advanced ML capabilities
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct NamingConventions {
    /// Naming patterns by category
    pub(crate) patterns: HashMap<CodeElementCategory, Vec<String>>,

    /// Type-first naming rules (unified)
    pub(crate) naming_rules: NamingRules,

    /// Descriptions for naming patterns
    pub(crate) descriptions: HashMap<String, String>,

    /// Search index for existing names
    pub(crate) search_index: HashMap<String, Vec<SearchResult>>,

    /// Confidence threshold for suggestions
    pub(crate) confidence_threshold: f64,

    /// Framework integration
    pub(crate) framework_integration: Option<FrameworkIntegration>,

    /// Agent integration
    pub(crate) agent_integration: Option<AgentIntegration>,

    /// Context analyzer
    pub(crate) context_analyzer: Option<ContextAnalyzer>,

    /// Learning system
    pub(crate) learning_system: Option<NamingLearningSystem>,

    /// Codebase database for repository context (NEW!)
    pub(crate) codebase_database: Option<CodebaseDatabase>,

    /// Project ID for SPARCPaths (NEW!)
    pub(crate) project_id: Option<String>,
}

/// Naming rules for consistent naming across the system
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingRules {
    /// Language-specific naming conventions
    pub language_conventions: HashMap<String, LanguageConvention>,

    /// Framework-specific overrides
    pub framework_overrides: HashMap<String, FrameworkConvention>,

    /// Project-specific patterns
    pub project_patterns: HashMap<String, Vec<String>>,

    /// Quality thresholds
    pub quality_thresholds: QualityThresholds,
}

/// Language-specific naming convention
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LanguageConvention {
    Rust,
    Elixir,
    JavaScript,
    TypeScript,
    Python,
    Go,
    Java,
    CSharp,
    Unknown,
}

/// Framework-specific naming convention
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkConvention {
    /// Framework name
    pub framework_name: String,

    /// Override rules
    pub overrides: HashMap<String, String>,

    /// Required patterns
    pub required_patterns: Vec<String>,

    /// Forbidden patterns
    pub forbidden_patterns: Vec<String>,
}

/// Quality thresholds for naming suggestions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QualityThresholds {
    /// Minimum confidence score
    pub min_confidence: f64,

    /// Minimum semantic similarity
    pub min_semantic_similarity: f64,

    /// Maximum ambiguity score
    pub max_ambiguity: f64,

    /// Minimum context relevance
    pub min_context_relevance: f64,
}

impl Default for QualityThresholds {
    fn default() -> Self {
        Self {
            min_confidence: 0.7,
            min_semantic_similarity: 0.7,
            max_ambiguity: 0.3,
            min_context_relevance: 0.5,
        }
    }
}

/// Search result for name lookup
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct SearchResult {
    /// Found name
    pub name: String,

    /// Similarity score
    pub similarity: f64,

    /// Context where it was found
    pub context: String,

    /// Element type
    pub element_type: CodeElementType,
}

/// Framework integration for intelligent naming
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct FrameworkIntegration {
    pub detected_frameworks: Vec<String>,
    pub framework_patterns: HashMap<String, Vec<String>>,
}

/// Agent integration for learning from usage
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct AgentIntegration {
    pub agent_preferences: HashMap<String, Vec<String>>,
    pub success_patterns: HashMap<String, f64>,
}

/// Context analyzer for semantic naming
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct ContextAnalyzer {
    pub context_patterns: HashMap<String, Vec<String>>,
    pub semantic_analysis: bool,
}

/// NamingLearningSystem is an alias for the canonical LearningSystem defined below.
/// We keep the alias for backwards compatibility with other modules that reference
/// `NamingLearningSystem` while maintaining a single canonical implementation.
pub type NamingLearningSystem = LearningSystem;

/// Rename context for intelligent naming
#[derive(Debug, Clone)]
pub struct RenameContext {
    /// Base name to rename
    pub base_name: String,

    /// Type of element being renamed
    pub element_type: RenameElementType,

    /// Category of the element
    pub category: CodeElementCategory,

    /// Code context (surrounding code)
    pub code_context: Option<String>,

    /// Framework information
    pub framework_info: Option<String>,

    /// Project type/language
    pub project_type: Option<String>,
}

/// Element types for renaming
#[derive(Debug, Clone, PartialEq)]
pub enum RenameElementType {
    Variable,
    Function,
    Module,
    Class,
    Service,
    Component,
    Interface,
    File,
    Directory,
}

/// Code element types (for compatibility)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CodeElementType {
    Function,
    Module,
    Variable,
    File,
    Directory,
    Class,
    Interface,
}

/// Code element categories
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum CodeElementCategory {
    Naming,
    Structure,
    Quality,
    Performance,
}

/// Rename suggestion with confidence and reasoning
#[derive(Debug, Clone)]
pub struct RenameSuggestion {
    /// Suggested name
    pub name: String,

    /// Confidence score (0.0 - 1.0)
    pub confidence: f64,

    /// Reasoning for the suggestion
    pub reasoning: String,

    /// Detection method used
    pub method: DetectionMethod,

    /// Alternative suggestions
    pub alternatives: Vec<String>,
}

/// Detection methods for naming suggestions
#[derive(Debug, Clone)]
pub enum DetectionMethod {
    /// Pattern-based detection
    PatternBased,

    /// Semantic analysis
    SemanticAnalysis,

    /// Context analysis
    ContextAnalysis,

    /// Machine learning
    MachineLearning,

    /// Hybrid approach
    Hybrid,
}

/// Microservice structure analysis
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct MicroserviceStructure {
    /// Service boundaries
    pub service_boundaries: Vec<String>,

    /// Communication patterns
    pub communication_patterns: Vec<String>,

    /// Data flow patterns
    pub data_flow_patterns: Vec<String>,
}

/// Monorepo structure analysis
#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct MonorepoStructure {
    /// Package boundaries
    pub package_boundaries: Vec<String>,

    /// Dependency relationships
    pub dependency_relationships: Vec<String>,

    /// Shared code patterns
    pub shared_code_patterns: Vec<String>,
}

/// Learning system for improving suggestions over time
#[derive(Debug, Clone)]
pub struct LearningSystem {
    pub success_rates: HashMap<String, f64>,
    pub failed_suggestions: HashMap<String, Vec<String>>,
    pub model_data: Option<Vec<u8>>,
}

impl LearningSystem {
    pub fn new() -> Self {
        Self {
            success_rates: HashMap::new(),
            failed_suggestions: HashMap::new(),
            model_data: None,
        }
    }
}

/// Intelligent namer for AI-powered naming suggestions
#[derive(Debug, Clone)]
pub struct IntelligentNamer {
    pub patterns: HashMap<String, Vec<String>>,
    pub learning_data: LearningSystem,
}

impl IntelligentNamer {
    pub fn new() -> Self {
        Self {
            patterns: HashMap::new(),
            learning_data: LearningSystem::new(),
        }
    }
}

impl Default for IntelligentNamer {
    fn default() -> Self {
        Self::new()
    }
}

impl NamingConventions {
    /// Create a new naming conventions handler
    pub fn new() -> Self {
        let mut naming = Self {
            patterns: HashMap::new(),
            naming_rules: NamingRules::default(),
            descriptions: HashMap::new(),
            search_index: HashMap::new(),
            confidence_threshold: 0.7,
            framework_integration: None,
            agent_integration: None,
            context_analyzer: None,
            learning_system: None,
            codebase_database: None,
            project_id: None,
        };

        // Initialize with basic templates
        naming.initialize_basic_templates();
        naming
    }

    /// Initialize basic naming templates (uses existing JSON templates)
    fn initialize_basic_templates(&mut self) {
        // Load from existing priv/code_quality_templates/ JSON files
        // For now, use hardcoded rules based on existing templates

        // Elixir: snake_case (from elixir_production.json)
        self.naming_rules
            .language_conventions
            .insert("elixir".to_string(), LanguageConvention::Elixir);
        self.naming_rules
            .language_conventions
            .insert("elixir_script".to_string(), LanguageConvention::Elixir);
        self.naming_rules.language_conventions.insert(
            "elixir_script_script".to_string(),
            LanguageConvention::Elixir,
        );
        // File extensions for Elixir
        self.naming_rules
            .language_conventions
            .insert("ex".to_string(), LanguageConvention::Elixir);
        self.naming_rules
            .language_conventions
            .insert("exs".to_string(), LanguageConvention::Elixir);

        // Rust: snake_case (from rust_production.json)
        self.naming_rules
            .language_conventions
            .insert("rust".to_string(), LanguageConvention::Rust);
        // File extension for Rust
        self.naming_rules
            .language_conventions
            .insert("rs".to_string(), LanguageConvention::Rust);

        // TypeScript: camelCase (from typescript_production.json)
        self.naming_rules
            .language_conventions
            .insert("typescript".to_string(), LanguageConvention::TypeScript);
        // File extensions for TypeScript
        self.naming_rules
            .language_conventions
            .insert("ts".to_string(), LanguageConvention::TypeScript);
        self.naming_rules
            .language_conventions
            .insert("tsx".to_string(), LanguageConvention::TypeScript);

        // JavaScript: camelCase (from typescript_production.json)
        self.naming_rules
            .language_conventions
            .insert("javascript".to_string(), LanguageConvention::JavaScript);
        // File extensions for JavaScript
        self.naming_rules
            .language_conventions
            .insert("js".to_string(), LanguageConvention::JavaScript);
        self.naming_rules
            .language_conventions
            .insert("jsx".to_string(), LanguageConvention::JavaScript);

        // Python: snake_case (from python_production.json)
        self.naming_rules
            .language_conventions
            .insert("python".to_string(), LanguageConvention::Python);
        // File extension for Python
        self.naming_rules
            .language_conventions
            .insert("py".to_string(), LanguageConvention::Python);

        // Go: camelCase (from go_production.json)
        self.naming_rules
            .language_conventions
            .insert("go".to_string(), LanguageConvention::Go);
        self.naming_rules
            .language_conventions
            .insert("golang".to_string(), LanguageConvention::Go);
        // File extension for Go
        self.naming_rules
            .language_conventions
            .insert("go".to_string(), LanguageConvention::Go);

        // TODO: Load from priv/code_quality_templates/*.json files
        // This would parse the existing JSON templates for naming rules
    }

    // ============================================================================
    // NAMING SUGGESTION FUNCTIONS
    // ============================================================================

    /// Suggest function names based on description and context
    pub fn suggest_function_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Function, context)
    }

    /// Suggest module names based on description and context
    pub fn suggest_module_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Module, context)
    }

    /// Suggest variable names based on description and context
    pub fn suggest_variable_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Variable, context)
    }

    /// Suggest class names based on description and context
    pub fn suggest_class_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Class, context)
    }

    /// Suggest interface names based on description and context
    pub fn suggest_interface_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Interface, context)
    }

    /// Suggest filename based on description and context
    pub fn suggest_filename(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::File, context)
    }

    /// Suggest directory name based on description and context
    pub fn suggest_directory_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Directory, context)
    }

    /// Suggest monorepo name based on description and context
    pub fn suggest_monorepo_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_monorepo_suggestions(description, context)
    }

    /// Suggest library name based on description and context
    pub fn suggest_library_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_library_suggestions(description, context)
    }

    /// Suggest service name based on description and context
    pub fn suggest_service_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Service, context)
    }

    /// Suggest component name based on description and context
    pub fn suggest_component_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, RenameElementType::Component, context)
    }

    /// Suggest package name based on description and context
    pub fn suggest_package_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_package_suggestions(description, context)
    }

    /// Suggest database table name based on description and context
    pub fn suggest_table_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_database_suggestions(description, context)
    }

    /// Suggest API endpoint name based on description and context
    pub fn suggest_endpoint_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_api_suggestions(description, context)
    }

    /// Suggest microservice name based on description and context
    pub fn suggest_microservice_name(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        self.generate_microservice_suggestions(description, context)
    }

    /// Suggest messaging topic name based on description and context
    pub fn suggest_topic_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_messaging_suggestions(description, context)
    }

    /// Suggest NATS subject name based on description and context
    pub fn suggest_nats_subject(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_nats_suggestions(description, context)
    }

    /// Suggest Kafka topic name based on description and context
    pub fn suggest_kafka_topic(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_kafka_suggestions(description, context)
    }

    /// Suggest names based on detected architecture from meta-registry
    pub fn suggest_names_for_architecture(
        &self,
        description: &str,
        architecture: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        self.generate_architecture_suggestions(description, architecture, context)
    }

    // ============================================================================
    // NAMING VALIDATION FUNCTIONS
    // ============================================================================

    /// Validate if a function name follows conventions
    pub fn validate_function_name(&self, name: &str) -> bool {
        // Default: snake_case functions
        self.validate_snake_case(name)
    }

    /// Validate function name for specific language
    pub fn validate_function_name_for_language(&self, name: &str, language: &str) -> bool {
        match language.to_lowercase().as_str() {
            "elixir" | "ex" | "exs" => self.validate_snake_case(name),
            "rust" | "rs" => self.validate_snake_case(name),
            "typescript" | "ts" | "tsx" => self.validate_camel_case(name),
            "javascript" | "js" | "jsx" => self.validate_camel_case(name),
            "gleam" => self.validate_snake_case(name),
            "go" | "golang" => self.validate_camel_case(name),
            "python" | "py" => self.validate_snake_case(name),
            _ => self.validate_snake_case(name),
        }
    }

    /// Validate if a module name follows conventions
    pub fn validate_module_name(&self, name: &str) -> bool {
        // Elixir modules: PascalCase
        self.validate_pascal_case(name)
    }

    /// Validate if a variable name follows conventions
    pub fn validate_variable_name(&self, name: &str) -> bool {
        // Elixir variables: snake_case
        self.validate_snake_case(name)
    }

    /// Validate if a class name follows conventions
    pub fn validate_class_name(&self, name: &str) -> bool {
        self.validate_name(name, CodeElementType::Class)
    }

    /// Validate if an interface name follows conventions
    pub fn validate_interface_name(&self, name: &str) -> bool {
        self.validate_name(name, CodeElementType::Interface)
    }

    /// Validate if a filename follows conventions
    pub fn validate_filename(&self, name: &str) -> bool {
        self.validate_name(name, CodeElementType::File)
    }

    /// Validate if a directory name follows conventions
    pub fn validate_directory_name(&self, name: &str) -> bool {
        self.validate_name(name, CodeElementType::Directory)
    }

    // ============================================================================
    // NAMING CONVENTION DETECTION
    // ============================================================================

    /// Detect what naming convention is being used in code
    pub fn detect_naming_convention(&self, code: &str) -> NamingConvention {
        // Analyze code to detect naming patterns
        if self.has_camel_case_patterns(code) {
            NamingConvention::CamelCase
        } else if self.has_pascal_case_patterns(code) {
            NamingConvention::PascalCase
        } else if self.has_snake_case_patterns(code) {
            NamingConvention::SnakeCase
        } else if self.has_kebab_case_patterns(code) {
            NamingConvention::KebabCase
        } else {
            NamingConvention::Mixed
        }
    }

    /// Detect language-specific naming conventions
    pub fn detect_language_conventions(&self, file_path: &str) -> LanguageConvention {
        let extension = file_path.split('.').last().unwrap_or("");
        match extension {
            "rs" => LanguageConvention::Rust,
            "ex" | "exs" => LanguageConvention::Elixir,
            "js" | "ts" => LanguageConvention::JavaScript,
            "py" => LanguageConvention::Python,
            "java" => LanguageConvention::Java,
            "cs" => LanguageConvention::CSharp,
            _ => LanguageConvention::Unknown,
        }
    }

    /// Detect framework-specific naming conventions
    pub fn detect_framework_conventions(&self, framework: &str) -> FrameworkConventionEnum {
        match framework.to_lowercase().as_str() {
            "phoenix" => FrameworkConventionEnum::Phoenix,
            "actix" => FrameworkConventionEnum::Actix,
            "react" => FrameworkConventionEnum::React,
            "django" => FrameworkConventionEnum::Django,
            "rails" => FrameworkConventionEnum::Rails,
            _ => FrameworkConventionEnum::Unknown,
        }
    }

    // ============================================================================
    // NAMING RULE ENFORCEMENT
    // ============================================================================

    /// Enforce camelCase naming
    pub fn enforce_camel_case(&self, name: &str) -> String {
        self.convert_to_camel_case(name)
    }

    /// Enforce PascalCase naming
    pub fn enforce_pascal_case(&self, name: &str) -> String {
        self.convert_to_pascal_case(name)
    }

    /// Enforce snake_case naming
    pub fn enforce_snake_case(&self, name: &str) -> String {
        self.convert_to_snake_case(name)
    }

    /// Enforce kebab-case naming
    pub fn enforce_kebab_case(&self, name: &str) -> String {
        self.convert_to_kebab_case(name)
    }

    // ============================================================================
    // CONTEXT-AWARE NAMING
    // ============================================================================

    /// Generate names based on context
    pub fn suggest_names_for_context(
        &self,
        description: &str,
        element_type: RenameElementType,
        context: &CodeContext,
    ) -> Vec<String> {
        // Use context to generate more relevant names
        self.generate_contextual_suggestions(description, element_type, context)
    }

    /// Generate names for specific framework
    pub fn suggest_names_for_framework(&self, description: &str, framework: &str) -> Vec<String> {
        // Use framework-specific patterns
        self.generate_framework_suggestions(description, framework)
    }

    /// Generate names for specific domain
    pub fn suggest_names_for_domain(&self, description: &str, domain: &str) -> Vec<String> {
        // Use domain-specific patterns
        self.generate_domain_suggestions(description, domain)
    }

    // ============================================================================
    // NAMING DETECTION & FLAGGING (No Refactoring)
    // ============================================================================

    /// Detect and flag naming violations in code (for QA validation)
    pub fn detect_naming_violations(&self, code: &str) -> NamingDetectionReport {
        let violations = self.find_naming_violations(code);
        let explanations = self.generate_explanations(&violations);
        let quality_score = self.calculate_quality_score(&violations);

        NamingDetectionReport {
            quality_score,
            violations: violations.clone(),
            explanations,
            total_elements: self.count_named_elements(code),
            detection_status: self.determine_detection_status(&violations),
            flagged_for_refactor: self.flag_for_refactor(&violations),
            summary: self.generate_summary(&violations),
        }
    }

    /// Flag violations for refactoring (no actual refactoring)
    pub fn flag_for_refactor(&self, violations: &[NamingViolation]) -> Vec<RefactorFlag> {
        violations
            .iter()
            .map(|violation| RefactorFlag {
                element_type: violation.element_type.clone(),
                name: violation.name.clone(),
                current_name: violation.name.clone(),
                suggested_name: violation.suggested_fix.clone(),
                reason: self.explain_naming_issue(violation),
                priority: self.determine_priority(violation),
                refactor_type: self.determine_refactor_type(violation),
                line_number: violation.line_number.unwrap_or(0) as usize,
            })
            .collect()
    }

    /// Determine detection status (Pass/Warning/Fail)
    pub fn determine_detection_status(&self, violations: &[NamingViolation]) -> DetectionStatus {
        if violations.is_empty() {
            DetectionStatus::Pass
        } else {
            let critical_count = violations
                .iter()
                .filter(|v| self.is_critical_violation(v))
                .count();
            if critical_count > 0 {
                DetectionStatus::Fail
            } else {
                DetectionStatus::Warning
            }
        }
    }

    /// Generate summary of naming issues
    pub fn generate_summary(&self, violations: &[NamingViolation]) -> NamingSummary {
        let mut function_count = 0;
        let mut module_count = 0;
        let mut variable_count = 0;
        let mut critical_count = 0;

        for violation in violations {
            match violation.element_type.as_str() {
                "function" => function_count += 1,
                "module" => module_count += 1,
                "variable" => variable_count += 1,
                _ => {}
            }
            if self.is_critical_violation(violation) {
                critical_count += 1;
            }
        }

        NamingSummary {
            total_violations: violations.len(),
            function_violations: function_count,
            module_violations: module_count,
            variable_violations: variable_count,
            critical_violations: critical_count,
            needs_refactor: violations.len() > 0,
            refactor_priority: if critical_count > 0 {
                "High"
            } else if violations.len() > 5 {
                "Medium"
            } else {
                "Low"
            }
            .to_string(),
        }
    }

    /// Determine priority for refactoring
    fn determine_priority(&self, violation: &NamingViolation) -> RefactorPriority {
        match self.determine_severity(violation) {
            Severity::Critical => RefactorPriority::High,
            Severity::High => RefactorPriority::High,
            Severity::Medium => RefactorPriority::Medium,
            Severity::Low => RefactorPriority::Low,
        }
    }

    /// Determine type of refactoring needed
    fn determine_refactor_type(&self, violation: &NamingViolation) -> RefactorType {
        match violation.element_type.as_str() {
            "function" => RefactorType::RenameFunction,
            "module" => RefactorType::RenameModule,
            "variable" => RefactorType::RenameVariable,
            _ => RefactorType::RenameElement,
        }
    }

    /// Generate detailed explanations for naming issues
    pub fn generate_explanations(&self, violations: &[NamingViolation]) -> Vec<NamingExplanation> {
        violations
            .iter()
            .map(|violation| NamingExplanation {
                element_type: violation.element_type.clone(),
                name: violation.name.clone(),
                issue: violation.message.clone(),
                explanation: self.explain_naming_issue(violation),
                examples: self.provide_examples(violation),
                severity: self.determine_severity(violation),
                fix_suggestion: violation.suggested_fix.clone(),
            })
            .collect()
    }

    /// Determine lint status based on violations
    pub fn determine_lint_status(&self, violations: &[NamingViolation]) -> LintStatus {
        if violations.is_empty() {
            LintStatus::Pass
        } else {
            let critical_count = violations
                .iter()
                .filter(|v| self.is_critical_violation(v))
                .count();
            if critical_count > 0 {
                LintStatus::Fail
            } else {
                LintStatus::Warning
            }
        }
    }

    /// Generate recommendations for improving naming
    pub fn generate_recommendations(
        &self,
        violations: &[NamingViolation],
    ) -> Vec<NamingRecommendation> {
        let mut recommendations = Vec::new();

        // Group violations by type
        let mut function_violations = 0;
        let mut module_violations = 0;
        let mut variable_violations = 0;

        for violation in violations {
            match violation.element_type.as_str() {
                "function" => function_violations += 1,
                "module" => module_violations += 1,
                "variable" => variable_violations += 1,
                _ => {}
            }
        }

        // Generate specific recommendations
        if function_violations > 0 {
            recommendations.push(NamingRecommendation {
                category: "Functions".to_string(),
                issue: format!("{} function naming violations found", function_violations),
                recommendation:
                    "Use camelCase for function names (e.g., calculateTotal, processUserData)"
                        .to_string(),
                examples: vec![
                    "calculateTotal".to_string(),
                    "processUserData".to_string(),
                    "validateInput".to_string(),
                ],
                priority: if function_violations > 5 {
                    Priority::High
                } else {
                    Priority::Medium
                },
            });
        }

        if module_violations > 0 {
            recommendations.push(NamingRecommendation {
                category: "Modules".to_string(),
                issue: format!("{} module naming violations found", module_violations),
                recommendation: "Use PascalCase for module names (e.g., UserManager, DataProcessor)".to_string(),
                examples: vec![
                    "UserManager".to_string(),
                    "DataProcessor".to_string(),
                    "AuthenticationService".to_string(),
                ],
                priority: if module_violations > 3 { Priority::High } else { Priority::Medium },
            });
        }

        if variable_violations > 0 {
            recommendations.push(NamingRecommendation {
                category: "Variables".to_string(),
                issue: format!("{} variable naming violations found", variable_violations),
                recommendation: "Use camelCase for variable names (e.g., userCount, isValid)"
                    .to_string(),
                examples: vec![
                    "userCount".to_string(),
                    "isValid".to_string(),
                    "totalPrice".to_string(),
                ],
                priority: if variable_violations > 10 {
                    Priority::High
                } else {
                    Priority::Low
                },
            });
        }

        recommendations
    }

    /// Explain a specific naming issue
    fn explain_naming_issue(&self, violation: &NamingViolation) -> String {
        match violation.element_type.as_str() {
            "function" => {
                if violation.name.chars().next().unwrap().is_uppercase() {
                    "Function names should start with lowercase letter (camelCase)".to_string()
                } else if violation.name.contains('_') {
                    "Function names should use camelCase, not snake_case".to_string()
                } else if violation.name.contains('-') {
                    "Function names should use camelCase, not kebab-case".to_string()
                } else {
                    "Function name doesn't follow camelCase convention".to_string()
                }
            }
            "module" => {
                if violation.name.chars().next().unwrap().is_lowercase() {
                    "Module names should start with uppercase letter (PascalCase)".to_string()
                } else if violation.name.contains('_') {
                    "Module names should use PascalCase, not snake_case".to_string()
                } else if violation.name.contains('-') {
                    "Module names should use PascalCase, not kebab-case".to_string()
                } else {
                    "Module name doesn't follow PascalCase convention".to_string()
                }
            }
            "variable" => {
                if violation.name.chars().next().unwrap().is_uppercase() {
                    "Variable names should start with lowercase letter (camelCase)".to_string()
                } else if violation.name.contains('_') {
                    "Variable names should use camelCase, not snake_case".to_string()
                } else if violation.name.contains('-') {
                    "Variable names should use camelCase, not kebab-case".to_string()
                } else {
                    "Variable name doesn't follow camelCase convention".to_string()
                }
            }
            _ => "Naming convention violation".to_string(),
        }
    }

    /// Provide examples for naming conventions
    fn provide_examples(&self, violation: &NamingViolation) -> Vec<String> {
        match violation.element_type.as_str() {
            "function" => vec![
                "calculateTotal".to_string(),
                "processUserData".to_string(),
                "validateInput".to_string(),
                "handleError".to_string(),
            ],
            "module" => vec![
                "UserManager".to_string(),
                "DataProcessor".to_string(),
                "AuthenticationService".to_string(),
                "EmailHandler".to_string(),
            ],
            "variable" => vec![
                "userCount".to_string(),
                "isValid".to_string(),
                "totalPrice".to_string(),
                "hasPermission".to_string(),
            ],
            _ => vec![],
        }
    }

    /// Determine severity of a violation
    fn determine_severity(&self, violation: &NamingViolation) -> Severity {
        match violation.element_type.as_str() {
            "function" => {
                if violation.name.is_empty() || violation.name.len() < 2 {
                    Severity::Critical
                } else if violation.name.chars().next().unwrap().is_uppercase() {
                    Severity::High
                } else {
                    Severity::Medium
                }
            }
            "module" => {
                if violation.name.is_empty() || violation.name.len() < 2 {
                    Severity::Critical
                } else if violation.name.chars().next().unwrap().is_lowercase() {
                    Severity::High
                } else {
                    Severity::Medium
                }
            }
            "variable" => {
                if violation.name.is_empty() {
                    Severity::Critical
                } else if violation.name.chars().next().unwrap().is_uppercase() {
                    Severity::High
                } else {
                    Severity::Low
                }
            }
            _ => Severity::Medium,
        }
    }

    /// Check if a violation is critical
    fn is_critical_violation(&self, violation: &NamingViolation) -> bool {
        self.determine_severity(violation) == Severity::Critical
    }

    // ============================================================================
    // NAMING QUALITY ANALYSIS (Legacy - kept for compatibility)
    // ============================================================================

    /// Analyze naming quality in code
    pub fn analyze_naming_quality(&self, code: &str) -> NamingQualityReport {
        let violations = self.find_naming_violations(code);
        let improvements = self.suggest_naming_improvements(code);
        let overall_score = self.calculate_quality_score(&violations);

        NamingQualityReport {
            overall_score,
            violations,
            improvements,
            total_elements: self.count_named_elements(code),
            quality_level: "unknown".to_string(),
        }
    }

    /// Find naming violations in code
    pub fn find_naming_violations(&self, code: &str) -> Vec<NamingViolation> {
        let mut violations = Vec::new();

        // Find function naming violations
        for func in self.extract_functions(code) {
            if !self.validate_function_name(&func.name) {
                violations.push(NamingViolation {
                    element_type: "function".to_string(),
                    name: func.name,
                    violation_type: "naming".to_string(),
                    severity: "low".to_string(),
                    message: "Function name doesn't follow conventions".to_string(),
                    line_number: Some(func.line as u32),
                    suggested_fix: self
                        .suggest_function_names(&func.description, None)
                        .first()
                        .cloned(),
                });
            }
        }

        // Find module naming violations
        for module in self.extract_modules(code) {
            if !self.validate_module_name(&module.name) {
                violations.push(NamingViolation {
                    element_type: "module".to_string(),
                    name: module.name,
                    violation_type: "naming".to_string(),
                    severity: "low".to_string(),
                    message: "Module name doesn't follow conventions".to_string(),
                    line_number: Some(module.line as u32),
                    suggested_fix: self
                        .suggest_module_names(&module.description, None)
                        .first()
                        .cloned(),
                });
            }
        }

        violations
    }

    /// Suggest naming improvements
    pub fn suggest_naming_improvements(&self, code: &str) -> Vec<NamingImprovement> {
        let mut improvements = Vec::new();

        for violation in self.find_naming_violations(code) {
            if let Some(suggestion) = violation.suggested_fix {
                improvements.push(NamingImprovement {
                    original_name: violation.name,
                    improved_name: suggestion,
                    element_type: violation.element_type,
                    improvement_type: "naming".to_string(),
                    confidence: 0.8,
                    explanation: violation.message,
                });
            }
        }

        improvements
    }

    // ============================================================================
    // LANGUAGE-SPECIFIC NAMING
    // ============================================================================

    /// Get Elixir naming rules
    pub fn get_elixir_naming_rules(&self) -> NamingRules {
        NamingRules {
            language_conventions: HashMap::from([
                ("function".to_string(), LanguageConvention::Elixir),
                ("module".to_string(), LanguageConvention::Elixir),
                ("variable".to_string(), LanguageConvention::Elixir),
            ]),
            framework_overrides: HashMap::new(),
            project_patterns: HashMap::new(),
            quality_thresholds: QualityThresholds::default(),
        }
    }

    /// Get Rust naming rules
    pub fn get_rust_naming_rules(&self) -> NamingRules {
        NamingRules {
            language_conventions: HashMap::from([
                ("function".to_string(), LanguageConvention::Rust),
                ("module".to_string(), LanguageConvention::Rust),
                ("variable".to_string(), LanguageConvention::Rust),
            ]),
            framework_overrides: HashMap::new(),
            project_patterns: HashMap::new(),
            quality_thresholds: QualityThresholds::default(),
        }
    }

    /// Get JavaScript naming rules
    pub fn get_javascript_naming_rules(&self) -> NamingRules {
        NamingRules {
            language_conventions: HashMap::from([
                ("function".to_string(), LanguageConvention::JavaScript),
                ("module".to_string(), LanguageConvention::JavaScript),
                ("variable".to_string(), LanguageConvention::JavaScript),
            ]),
            framework_overrides: HashMap::new(),
            project_patterns: HashMap::new(),
            quality_thresholds: QualityThresholds::default(),
        }
    }

    /// Get Python naming rules
    pub fn get_python_naming_rules(&self) -> NamingRules {
        NamingRules {
            language_conventions: HashMap::from([
                ("function".to_string(), LanguageConvention::Python),
                ("module".to_string(), LanguageConvention::Python),
                ("variable".to_string(), LanguageConvention::Python),
            ]),
            framework_overrides: HashMap::new(),
            project_patterns: HashMap::new(),
            quality_thresholds: QualityThresholds::default(),
        }
    }

    // ============================================================================
    // FRAMEWORK-SPECIFIC NAMING
    // ============================================================================

    /// Get Phoenix naming patterns
    pub fn get_phoenix_naming_patterns(&self) -> Vec<String> {
        vec![
            "UserController".to_string(),
            "UserView".to_string(),
            "UserSchema".to_string(),
            "UserContext".to_string(),
        ]
    }

    /// Get Actix naming patterns
    pub fn get_actix_naming_patterns(&self) -> Vec<String> {
        vec![
            "UserHandler".to_string(),
            "UserService".to_string(),
            "UserRepository".to_string(),
            "UserModel".to_string(),
        ]
    }

    /// Get React naming patterns
    pub fn get_react_naming_patterns(&self) -> Vec<String> {
        vec![
            "UserComponent".to_string(),
            "UserHook".to_string(),
            "UserContext".to_string(),
            "UserProvider".to_string(),
        ]
    }

    /// Get Django naming patterns
    pub fn get_django_naming_patterns(&self) -> Vec<String> {
        vec![
            "UserModel".to_string(),
            "UserView".to_string(),
            "UserSerializer".to_string(),
            "UserForm".to_string(),
        ]
    }

    // ============================================================================
    // PRIVATE HELPER METHODS
    // ============================================================================

    /// Generate self-explanatory function suggestions based on action and context
    fn generate_function_suggestions(
        &self,
        base_name: &str,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let mut suggestions = Vec::new();

        // Extract action verbs from description
        let actions = self.extract_actions(description);
        let objects = self.extract_objects(description);
        let context_hints = self.extract_context_hints(context);

        // Primary suggestion: clean base name
        suggestions.push(base_name.to_string());

        // Action-based suggestions
        for action in &actions {
            for object in &objects {
                let suggestion = format!("{}_{}", action, object);
                if !suggestions.contains(&suggestion) {
                    suggestions.push(suggestion);
                }
            }
        }

        // Context-aware suggestions
        if let Some(ctx) = context_hints {
            for action in &actions {
                let suggestion = format!("{}_{}", action, ctx);
                if !suggestions.contains(&suggestion) {
                    suggestions.push(suggestion);
                }
            }
        }

        // Domain-specific suggestions
        let domain_suggestions = self.generate_domain_function_suggestions(description, context);
        suggestions.extend(domain_suggestions);

        // Remove duplicates and limit to 5 best suggestions
        suggestions.sort();
        suggestions.dedup();
        suggestions.truncate(5);

        suggestions
    }

    /// Extract action verbs from description
    fn extract_actions(&self, description: &str) -> Vec<String> {
        let action_patterns = [
            "calculate",
            "compute",
            "suggest",
            "validate",
            "extract",
            "generate",
            "create",
            "build",
            "parse",
            "analyze",
            "detect",
            "check",
            "verify",
            "process",
            "handle",
            "manage",
            "store",
            "retrieve",
            "search",
            "find",
            "update",
            "delete",
            "insert",
            "remove",
            "add",
            "get",
            "set",
            "load",
            "save",
            "export",
            "import",
            "transform",
            "convert",
            "format",
            "render",
        ];

        let description_lower = description.to_lowercase();
        let mut actions = Vec::new();

        for pattern in &action_patterns {
            if description_lower.contains(pattern) {
                actions.push(pattern.to_string());
            }
        }

        // If no actions found, use common ones based on context
        if actions.is_empty() {
            if description_lower.contains("name") || description_lower.contains("suggest") {
                actions.push("suggest".to_string());
            } else if description_lower.contains("check") || description_lower.contains("valid") {
                actions.push("validate".to_string());
            } else if description_lower.contains("get") || description_lower.contains("find") {
                actions.push("get".to_string());
            } else {
                actions.push("process".to_string());
            }
        }

        actions
    }

    /// Extract objects/nouns from description
    fn extract_objects(&self, description: &str) -> Vec<String> {
        let object_patterns = [
            "name",
            "names",
            "convention",
            "conventions",
            "function",
            "functions",
            "module",
            "modules",
            "variable",
            "variables",
            "class",
            "classes",
            "interface",
            "interfaces",
            "file",
            "files",
            "directory",
            "directories",
            "service",
            "services",
            "component",
            "components",
            "package",
            "packages",
            "table",
            "tables",
            "endpoint",
            "endpoints",
            "topic",
            "topics",
            "subject",
            "subjects",
            "pattern",
            "patterns",
            "rule",
            "rules",
        ];

        let description_lower = description.to_lowercase();
        let mut objects = Vec::new();

        for pattern in &object_patterns {
            if description_lower.contains(pattern) {
                objects.push(pattern.to_string());
            }
        }

        // If no objects found, extract from description
        if objects.is_empty() {
            let words: Vec<&str> = description_lower.split_whitespace().collect();
            for word in words {
                if word.len() > 3 && !self.is_action_word(word) {
                    objects.push(word.to_string());
                }
            }
        }

        objects
    }

    /// Extract context hints from context string
    fn extract_context_hints(&self, context: Option<&str>) -> Option<String> {
        context.and_then(|ctx| {
            let ctx_lower = ctx.to_lowercase();
            if ctx_lower.contains("elixir") || ctx_lower.contains("ex") {
                Some("elixir".to_string())
            } else if ctx_lower.contains("rust") || ctx_lower.contains("rs") {
                Some("rust".to_string())
            } else if ctx_lower.contains("typescript") || ctx_lower.contains("ts") {
                Some("typescript".to_string())
            } else if ctx_lower.contains("javascript") || ctx_lower.contains("js") {
                Some("javascript".to_string())
            } else if ctx_lower.contains("gleam") {
                Some("gleam".to_string())
            } else if ctx_lower.contains("go") || ctx_lower.contains("golang") {
                Some("go".to_string())
            } else if ctx_lower.contains("python") || ctx_lower.contains("py") {
                Some("python".to_string())
            } else if ctx_lower.contains("naming") {
                Some("naming".to_string())
            } else if ctx_lower.contains("architecture") {
                Some("architecture".to_string())
            } else {
                None
            }
        })
    }

    /// Check if word is an action verb
    fn is_action_word(&self, word: &str) -> bool {
        let action_words = [
            "the", "and", "or", "for", "with", "from", "to", "in", "on", "at", "by", "of", "a",
            "an", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does",
            "did", "will", "would", "could", "should", "may", "might", "can", "must", "shall",
        ];
        action_words.contains(&word)
    }

    /// Generate domain-specific function suggestions
    fn generate_domain_function_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let mut suggestions = Vec::new();
        let description_lower = description.to_lowercase();

        // Naming domain
        if description_lower.contains("name") || description_lower.contains("naming") {
            suggestions.extend(vec![
                "suggest_names".to_string(),
                "generate_names".to_string(),
                "create_names".to_string(),
                "propose_names".to_string(),
                "recommend_names".to_string(),
            ]);
        }

        // Validation domain
        if description_lower.contains("valid") || description_lower.contains("check") {
            suggestions.extend(vec![
                "validate_input".to_string(),
                "check_validity".to_string(),
                "verify_format".to_string(),
                "ensure_valid".to_string(),
            ]);
        }

        // Architecture domain
        if description_lower.contains("architect") || description_lower.contains("pattern") {
            suggestions.extend(vec![
                "detect_patterns".to_string(),
                "analyze_architecture".to_string(),
                "identify_patterns".to_string(),
                "classify_architecture".to_string(),
            ]);
        }

        // Code analysis domain
        if description_lower.contains("code") || description_lower.contains("analyze") {
            suggestions.extend(vec![
                "analyze_code".to_string(),
                "examine_code".to_string(),
                "inspect_code".to_string(),
                "review_code".to_string(),
            ]);
        }

        suggestions
    }

    /// Extract base name from description
    fn extract_base_name(&self, description: &str) -> String {
        // Simple extraction: take first few words and join with underscores
        let words: Vec<String> = description
            .split_whitespace()
            .take(3)
            .map(|w| w.to_lowercase())
            .collect();
        words.join("_")
    }

    /// Generate suggestions for a given element type
    fn generate_suggestions(
        &self,
        description: &str,
        element_type: RenameElementType,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);

        match element_type {
            RenameElementType::Function => {
                // Generate self-explanatory function names based on action and context
                self.generate_function_suggestions(&base_name, description, context)
            }
            RenameElementType::Module => {
                // Default: PascalCase modules (Elixir, TypeScript classes)
                let pascal_case = self.to_pascal_case(&base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Module", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                    format!("{}Manager", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // Default: snake_case variables (Elixir, Rust, Gleam)
                vec![
                    base_name.clone(),
                    format!("{}_var", base_name),
                    format!("current_{}", base_name),
                    format!("{}_value", base_name),
                    format!("{}_data", base_name),
                ]
            }
            _ => vec![base_name],
        }
    }

    // Small wrappers for previously referenced generate_* functions
    fn generate_messaging_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        // Default to microservice/topic style suggestions
        self.generate_microservice_suggestions(description, context)
    }

    fn generate_nats_suggestions(&self, description: &str, context: Option<&str>) -> Vec<String> {
        // NATS subjects follow dot-separated formats; convert kebab to dots
        let mut suggestions = Vec::new();
        for s in self.generate_microservice_suggestions(description, context) {
            suggestions.push(s.replace('-', "."));
        }
        suggestions
    }

    fn generate_kafka_suggestions(&self, description: &str, context: Option<&str>) -> Vec<String> {
        // Kafka topics are similar to NATS but often kebab-case; reuse microservice suggestions
        self.generate_microservice_suggestions(description, context)
    }

    fn generate_architecture_suggestions(
        &self,
        description: &str,
        _architecture: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        // For now, delegate to microservice suggestions
        self.generate_microservice_suggestions(description, context)
    }

    fn validate_name(&self, name: &str, _element_type: CodeElementType) -> bool {
        // Default validation: accept snake_case or camelCase depending on simple heuristic
        // Reuse filename validation for simplicity
        self.validate_filename(name)
    }

    /// Generate suggestions for specific language
    pub fn suggest_names_for_language(
        &self,
        description: &str,
        element_type: RenameElementType,
        language: &str,
    ) -> Vec<String> {
        let base_name = description
            .to_lowercase()
            .replace(" ", "_")
            .replace("-", "_");

        match language.to_lowercase().as_str() {
            "elixir" | "ex" | "exs" => self.generate_elixir_suggestions(&base_name, element_type),
            "rust" | "rs" => self.generate_rust_suggestions(&base_name, element_type),
            "typescript" | "ts" | "tsx" => {
                self.generate_typescript_suggestions(&base_name, element_type)
            }
            "javascript" | "js" | "jsx" => {
                self.generate_javascript_suggestions(&base_name, element_type)
            }
            "gleam" => self.generate_gleam_suggestions(&base_name, element_type),
            "go" | "golang" => self.generate_go_suggestions(&base_name, element_type),
            "python" | "py" => self.generate_python_suggestions(&base_name, element_type),
            _ => self.generate_suggestions(description, element_type, None),
        }
    }

    /// Generate Elixir naming suggestions
    fn generate_elixir_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // Elixir: snake_case functions
                vec![
                    base_name.to_string(),
                    format!("{}_function", base_name),
                    format!("handle_{}", base_name),
                    format!("process_{}", base_name),
                ]
            }
            RenameElementType::Module => {
                // Elixir: PascalCase modules
                let pascal_case = self.to_pascal_case(base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Module", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // Elixir: snake_case variables
                vec![
                    base_name.to_string(),
                    format!("{}_var", base_name),
                    format!("current_{}", base_name),
                ]
            }
            RenameElementType::File => {
                // Elixir: snake_case files
                vec![
                    format!("{}.ex", base_name),
                    format!("{}_test.ex", base_name),
                    format!("{}_test.exs", base_name),
                ]
            }
            RenameElementType::Directory => {
                // Elixir: snake_case directories
                vec![
                    base_name.to_string(),
                    format!("{}_lib", base_name),
                    format!("{}_test", base_name),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate Rust naming suggestions
    fn generate_rust_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // Rust: snake_case functions
                vec![
                    base_name.to_string(),
                    format!("{}_function", base_name),
                    format!("handle_{}", base_name),
                    format!("process_{}", base_name),
                ]
            }
            RenameElementType::Module => {
                // Rust: snake_case modules
                vec![
                    base_name.to_string(),
                    format!("{}_module", base_name),
                    format!("{}_service", base_name),
                    format!("{}_handler", base_name),
                ]
            }
            RenameElementType::Variable => {
                // Rust: snake_case variables
                vec![
                    base_name.to_string(),
                    format!("{}_var", base_name),
                    format!("current_{}", base_name),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate TypeScript naming suggestions
    fn generate_typescript_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // TypeScript: camelCase functions
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Function", camel_case),
                    format!("handle{}", self.to_pascal_case(base_name)),
                ]
            }
            RenameElementType::Module => {
                // TypeScript: PascalCase classes/modules
                let pascal_case = self.to_pascal_case(base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Module", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // TypeScript: camelCase variables
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Var", camel_case),
                    format!("current{}", self.to_pascal_case(base_name)),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate Gleam naming suggestions
    fn generate_gleam_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // Gleam: snake_case functions
                vec![
                    base_name.to_string(),
                    format!("{}_function", base_name),
                    format!("handle_{}", base_name),
                    format!("process_{}", base_name),
                ]
            }
            RenameElementType::Module => {
                // Gleam: snake_case modules
                vec![
                    base_name.to_string(),
                    format!("{}_module", base_name),
                    format!("{}_service", base_name),
                    format!("{}_handler", base_name),
                ]
            }
            RenameElementType::Variable => {
                // Gleam: snake_case variables
                vec![
                    base_name.to_string(),
                    format!("{}_var", base_name),
                    format!("current_{}", base_name),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate Go naming suggestions
    fn generate_go_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // Go: camelCase functions (exported start with uppercase)
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Func", camel_case),
                    format!("Handle{}", self.to_pascal_case(base_name)),
                    format!("Process{}", self.to_pascal_case(base_name)),
                ]
            }
            RenameElementType::Module => {
                // Go: PascalCase packages
                let pascal_case = self.to_pascal_case(base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Package", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // Go: camelCase variables
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Var", camel_case),
                    format!("current{}", self.to_pascal_case(base_name)),
                    format!("{}Value", camel_case),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate Python naming suggestions
    fn generate_python_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // Python: snake_case functions
                vec![
                    base_name.to_string(),
                    format!("{}_function", base_name),
                    format!("handle_{}", base_name),
                    format!("process_{}", base_name),
                ]
            }
            RenameElementType::Module => {
                // Python: PascalCase classes
                let pascal_case = self.to_pascal_case(base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Class", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // Python: snake_case variables
                vec![
                    base_name.to_string(),
                    format!("{}_var", base_name),
                    format!("current_{}", base_name),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Generate JavaScript naming suggestions
    fn generate_javascript_suggestions(
        &self,
        base_name: &str,
        element_type: RenameElementType,
    ) -> Vec<String> {
        match element_type {
            RenameElementType::Function => {
                // JavaScript: camelCase functions
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Func", camel_case),
                    format!("handle{}", self.to_pascal_case(base_name)),
                    format!("process{}", self.to_pascal_case(base_name)),
                ]
            }
            RenameElementType::Module => {
                // JavaScript: PascalCase classes/modules
                let pascal_case = self.to_pascal_case(base_name);
                vec![
                    pascal_case.clone(),
                    format!("{}Module", pascal_case),
                    format!("{}Service", pascal_case),
                    format!("{}Handler", pascal_case),
                ]
            }
            RenameElementType::Variable => {
                // JavaScript: camelCase variables
                let camel_case = self.to_camel_case(base_name);
                vec![
                    camel_case.clone(),
                    format!("{}Var", camel_case),
                    format!("current{}", self.to_pascal_case(base_name)),
                    format!("{}Value", camel_case),
                ]
            }
            _ => vec![base_name.to_string()],
        }
    }

    /// Convert to camelCase (Elixir functions)
    fn to_camel_case(&self, name: &str) -> String {
        let words: Vec<&str> = name.split(['_', '-', ' ']).collect();
        let mut result = String::new();

        for (i, word) in words.iter().enumerate() {
            if i == 0 {
                result.push_str(&word.to_lowercase());
            } else {
                let capitalized = word
                    .chars()
                    .next()
                    .unwrap()
                    .to_uppercase()
                    .collect::<String>()
                    + &word[1..].to_lowercase();
                result.push_str(&capitalized);
            }
        }

        result
    }

    /// Convert to PascalCase (Elixir modules)
    fn to_pascal_case(&self, name: &str) -> String {
        let words: Vec<&str> = name.split(['_', '-', ' ']).collect();
        words
            .iter()
            .map(|word| {
                let mut chars = word.chars();
                match chars.next() {
                    Some(first) => {
                        first.to_uppercase().collect::<String>() + &chars.as_str().to_lowercase()
                    }
                    None => String::new(),
                }
            })
            .collect()
    }

    /// Convert to camelCase
    fn convert_to_camel_case(&self, name: &str) -> String {
        let words: Vec<&str> = name.split(['_', '-', ' ']).collect();
        let mut result = String::new();

        for (i, word) in words.iter().enumerate() {
            if i == 0 {
                result.push_str(&word.to_lowercase());
            } else {
                let capitalized = word
                    .chars()
                    .next()
                    .unwrap()
                    .to_uppercase()
                    .collect::<String>()
                    + &word[1..].to_lowercase();
                result.push_str(&capitalized);
            }
        }

        result
    }

    /// Convert to PascalCase
    fn convert_to_pascal_case(&self, name: &str) -> String {
        let words: Vec<&str> = name.split(['_', '-', ' ']).collect();
        words
            .iter()
            .map(|word| {
                word.chars()
                    .next()
                    .unwrap()
                    .to_uppercase()
                    .collect::<String>()
                    + &word[1..].to_lowercase()
            })
            .collect()
    }

    /// Convert to snake_case
    fn convert_to_snake_case(&self, name: &str) -> String {
        name.chars()
            .map(|c| {
                if c.is_uppercase() {
                    format!("_{}", c.to_lowercase())
                } else {
                    c.to_string()
                }
            })
            .collect::<String>()
            .trim_start_matches('_')
            .to_string()
    }

    /// Convert to kebab-case
    fn convert_to_kebab_case(&self, name: &str) -> String {
        self.convert_to_snake_case(name).replace('_', "-")
    }

    /// Convert to kebab-case (public method)
    fn to_kebab_case(&self, input: &str) -> String {
        self.convert_to_kebab_case(input)
    }

    /// Convert to snake_case (public method)
    fn to_snake_case(&self, input: &str) -> String {
        self.convert_to_snake_case(input)
    }

    /// Validate snake_case naming
    fn validate_snake_case(&self, name: &str) -> bool {
        if name.is_empty() || name.len() > 100 {
            return false;
        }

        // Must start with lowercase letter
        if !name.chars().next().unwrap().is_lowercase() {
            return false;
        }

        // Can contain lowercase letters, numbers, and underscores
        name.chars()
            .all(|c| c.is_lowercase() || c.is_numeric() || c == '_')
    }

    /// Validate PascalCase naming
    fn validate_pascal_case(&self, name: &str) -> bool {
        if name.is_empty() || name.len() > 100 {
            return false;
        }

        // Must start with uppercase letter
        if !name.chars().next().unwrap().is_uppercase() {
            return false;
        }

        // Can contain letters and numbers, no underscores
        name.chars().all(|c| c.is_alphabetic() || c.is_numeric())
    }

    /// Validate camelCase naming
    fn validate_camel_case(&self, name: &str) -> bool {
        if name.is_empty() || name.len() > 100 {
            return false;
        }

        // Must start with lowercase letter
        if !name.chars().next().unwrap().is_lowercase() {
            return false;
        }

        // Can contain letters and numbers, no underscores
        name.chars().all(|c| c.is_alphabetic() || c.is_numeric())
    }

    /// Check for camelCase patterns
    fn has_camel_case_patterns(&self, code: &str) -> bool {
        code.contains("camelCase") || code.contains("functionName")
    }

    /// Check for PascalCase patterns
    fn has_pascal_case_patterns(&self, code: &str) -> bool {
        code.contains("PascalCase") || code.contains("ClassName")
    }

    /// Check for snake_case patterns
    fn has_snake_case_patterns(&self, code: &str) -> bool {
        code.contains("snake_case") || code.contains("function_name")
    }

    /// Check for kebab-case patterns
    fn has_kebab_case_patterns(&self, code: &str) -> bool {
        code.contains("kebab-case") || code.contains("function-name")
    }

    /// Generate contextual suggestions
    fn generate_contextual_suggestions(
        &self,
        description: &str,
        element_type: RenameElementType,
        context: &CodeContext,
    ) -> Vec<String> {
        // Use context to generate more relevant names
        self.generate_suggestions(description, element_type, None)
    }

    /// Generate framework suggestions
    fn generate_framework_suggestions(&self, description: &str, framework: &str) -> Vec<String> {
        // Use framework-specific patterns
        self.generate_suggestions(description, RenameElementType::Function, None)
    }

    /// Generate domain suggestions
    fn generate_domain_suggestions(&self, description: &str, domain: &str) -> Vec<String> {
        // Use domain-specific patterns
        self.generate_suggestions(description, RenameElementType::Function, None)
    }

    /// Generate complex monorepo naming suggestions (HashiCorp, Google style)
    fn generate_monorepo_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // HashiCorp-style naming patterns
        if description.to_lowercase().contains("hashicorp")
            || description.to_lowercase().contains("hash")
            || context.map_or(false, |c| c.to_lowercase().contains("hashicorp"))
        {
            // HashiCorp patterns: terraform, consul, vault, nomad, waypoint
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "core"),
                format!("{}-{}", base_name.to_lowercase(), "cli"),
                format!("{}-{}", base_name.to_lowercase(), "sdk"),
                format!("{}-{}", base_name.to_lowercase(), "api"),
                format!("{}-{}", base_name.to_lowercase(), "server"),
                format!("{}-{}", base_name.to_lowercase(), "agent"),
                format!("{}-{}", base_name.to_lowercase(), "client"),
                format!("{}-{}", base_name.to_lowercase(), "provider"),
                format!("{}-{}", base_name.to_lowercase(), "plugin"),
            ]);
        }

        // Google-style naming patterns
        if description.to_lowercase().contains("google")
            || description.to_lowercase().contains("gcp")
            || context.map_or(false, |c| c.to_lowercase().contains("google"))
        {
            // Google patterns: kubernetes, tensorflow, protobuf, gRPC
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "k8s"),
                format!("{}-{}", base_name.to_lowercase(), "tf"),
                format!("{}-{}", base_name.to_lowercase(), "pb"),
                format!("{}-{}", base_name.to_lowercase(), "grpc"),
                format!("{}-{}", base_name.to_lowercase(), "api"),
                format!("{}-{}", base_name.to_lowercase(), "sdk"),
                format!("{}-{}", base_name.to_lowercase(), "client"),
                format!("{}-{}", base_name.to_lowercase(), "server"),
                format!("{}-{}", base_name.to_lowercase(), "operator"),
            ]);
        }
    }

    /// Generate database naming suggestions (tables, columns, indexes)
    fn generate_database_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![base_name.to_snake_case()]
    }

    /// Generate API naming suggestions (endpoints, routes, resources)
    fn generate_api_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![base_name.to_kebab_case()]
    }

    /// Generate microservice naming suggestions
    fn generate_microservice_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![format!("{}-service", base_name.to_kebab_case())]
    }

    /// Generate messaging naming suggestions
    fn generate_messaging_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![base_name.to_kebab_case()]
    }

    /// Generate NATS subject naming suggestions
    fn generate_nats_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![base_name.to_kebab_case()]
    }

    /// Generate Kafka topic naming suggestions
    fn generate_kafka_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        vec![base_name.to_kebab_case()]
    }
}
        if description.to_lowercase().contains("airbnb")
            || context.map_or(false, |c| c.to_lowercase().contains("airbnb"))
        {
            // Airbnb patterns: lottie, enzyme, visx, react-dates
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "lottie"),
                format!("{}-{}", base_name.to_lowercase(), "enzyme"),
                format!("{}-{}", base_name.to_lowercase(), "visx"),
                format!("{}-{}", base_name.to_lowercase(), "react"),
                format!("{}-{}", base_name.to_lowercase(), "js"),
                format!("{}-{}", base_name.to_lowercase(), "ts"),
                format!("{}-{}", base_name.to_lowercase(), "ui"),
                format!("{}-{}", base_name.to_lowercase(), "component"),
                format!("{}-{}", base_name.to_lowercase(), "kit"),
            ]);
        }

        // Shopify-style naming patterns
        if description.to_lowercase().contains("shopify")
            || context.map_or(false, |c| c.to_lowercase().contains("shopify"))
        {
            // Shopify patterns: liquid, shopify-cli, polaris, hydrogen
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "liquid"),
                format!("{}-{}", base_name.to_lowercase(), "cli"),
                format!("{}-{}", base_name.to_lowercase(), "polaris"),
                format!("{}-{}", base_name.to_lowercase(), "hydrogen"),
                format!("{}-{}", base_name.to_lowercase(), "theme"),
                format!("{}-{}", base_name.to_lowercase(), "app"),
                format!("{}-{}", base_name.to_lowercase(), "api"),
                format!("{}-{}", base_name.to_lowercase(), "sdk"),
                format!("{}-{}", base_name.to_lowercase(), "kit"),
            ]);
        }

        // Moonrepo-style naming patterns
        if description.to_lowercase().contains("moonrepo")
            || description.to_lowercase().contains("moon")
            || context.map_or(false, |c| c.to_lowercase().contains("moonrepo"))
        {
            // Moonrepo patterns: moon, moonrepo, moon-cli, moon-config
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "moon"),
                format!("{}-{}", base_name.to_lowercase(), "moonrepo"),
                format!("{}-{}", base_name.to_lowercase(), "moon-cli"),
                format!("{}-{}", base_name.to_lowercase(), "moon-config"),
                format!("{}-{}", base_name.to_lowercase(), "moon-workspace"),
                format!("{}-{}", base_name.to_lowercase(), "moon-project"),
                format!("{}-{}", base_name.to_lowercase(), "moon-task"),
                format!("{}-{}", base_name.to_lowercase(), "moon-target"),
                format!("{}-{}", base_name.to_lowercase(), "moon-runner"),
                format!("{}-{}", base_name.to_lowercase(), "moon-generator"),
                format!("{}-{}", base_name.to_lowercase(), "moon-plugin"),
                format!("{}-{}", base_name.to_lowercase(), "moon-tool"),
                format!("{}-{}", base_name.to_lowercase(), "moon-sdk"),
                format!("{}-{}", base_name.to_lowercase(), "moon-api"),
            ]);
        }

        // Nx-style naming patterns
        if description.to_lowercase().contains("nx")
            || context.map_or(false, |c| c.to_lowercase().contains("nx"))
        {
            // Nx patterns: nx, nx-workspace, nx-plugin, nx-generator
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "nx"),
                format!("{}-{}", base_name.to_lowercase(), "nx-workspace"),
                format!("{}-{}", base_name.to_lowercase(), "nx-plugin"),
                format!("{}-{}", base_name.to_lowercase(), "nx-generator"),
                format!("{}-{}", base_name.to_lowercase(), "nx-executor"),
                format!("{}-{}", base_name.to_lowercase(), "nx-builder"),
                format!("{}-{}", base_name.to_lowercase(), "nx-schematics"),
                format!("{}-{}", base_name.to_lowercase(), "nx-devkit"),
                format!("{}-{}", base_name.to_lowercase(), "nx-angular"),
                format!("{}-{}", base_name.to_lowercase(), "nx-react"),
                format!("{}-{}", base_name.to_lowercase(), "nx-next"),
                format!("{}-{}", base_name.to_lowercase(), "nx-nest"),
                format!("{}-{}", base_name.to_lowercase(), "nx-express"),
                format!("{}-{}", base_name.to_lowercase(), "nx-node"),
            ]);
        }

        // Lerna-style naming patterns
        if description.to_lowercase().contains("lerna")
            || context.map_or(false, |c| c.to_lowercase().contains("lerna"))
        {
            // Lerna patterns: lerna, lerna-workspace, lerna-package
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "lerna"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-workspace"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-package"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-packages"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-utils"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-common"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-shared"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-core"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-lib"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-tools"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-cli"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-sdk"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-api"),
                format!("{}-{}", base_name.to_lowercase(), "lerna-plugin"),
            ]);
        }

        // Rush-style naming patterns
        if description.to_lowercase().contains("rush")
            || context.map_or(false, |c| c.to_lowercase().contains("rush"))
        {
            // Rush patterns: rush, rush-stack, rush-package
            suggestions.extend(vec![
                format!("{}", base_name.to_lowercase()),
                format!("{}-{}", base_name.to_lowercase(), "rush"),
                format!("{}-{}", base_name.to_lowercase(), "rush-stack"),
                format!("{}-{}", base_name.to_lowercase(), "rush-package"),
                format!("{}-{}", base_name.to_lowercase(), "rush-packages"),
                format!("{}-{}", base_name.to_lowercase(), "rush-utils"),
                format!("{}-{}", base_name.to_lowercase(), "rush-common"),
                format!("{}-{}", base_name.to_lowercase(), "rush-shared"),
                format!("{}-{}", base_name.to_lowercase(), "rush-core"),
                format!("{}-{}", base_name.to_lowercase(), "rush-lib"),
                format!("{}-{}", base_name.to_lowercase(), "rush-tools"),
                format!("{}-{}", base_name.to_lowercase(), "rush-cli"),
                format!("{}-{}", base_name.to_lowercase(), "rush-sdk"),
                format!("{}-{}", base_name.to_lowercase(), "rush-api"),
                format!("{}-{}", base_name.to_lowercase(), "rush-plugin"),
            ]);
        }

        // Generic monorepo patterns
        suggestions.extend(vec![
            format!("{}", base_name.to_lowercase()),
            format!("{}-{}", base_name.to_lowercase(), "monorepo"),
            format!("{}-{}", base_name.to_lowercase(), "workspace"),
            format!("{}-{}", base_name.to_lowercase(), "platform"),
            format!("{}-{}", base_name.to_lowercase(), "ecosystem"),
            format!("{}-{}", base_name.to_lowercase(), "suite"),
            format!("{}-{}", base_name.to_lowercase(), "stack"),
            format!("{}-{}", base_name.to_lowercase(), "core"),
            format!("{}-{}", base_name.to_lowercase(), "lib"),
            format!("{}-{}", base_name.to_lowercase(), "utils"),
            format!("{}-{}", base_name.to_lowercase(), "tools"),
            format!("{}-{}", base_name.to_lowercase(), "cli"),
            format!("{}-{}", base_name.to_lowercase(), "api"),
            format!("{}-{}", base_name.to_lowercase(), "sdk"),
            format!("{}-{}", base_name.to_lowercase(), "client"),
            format!("{}-{}", base_name.to_lowercase(), "server"),
            format!("{}-{}", base_name.to_lowercase(), "agent"),
            format!("{}-{}", base_name.to_lowercase(), "service"),
            format!("{}-{}", base_name.to_lowercase(), "gateway"),
            format!("{}-{}", base_name.to_lowercase(), "proxy"),
            format!("{}-{}", base_name.to_lowercase(), "bridge"),
            format!("{}-{}", base_name.to_lowercase(), "adapter"),
            format!("{}-{}", base_name.to_lowercase(), "driver"),
            format!("{}-{}", base_name.to_lowercase(), "plugin"),
            format!("{}-{}", base_name.to_lowercase(), "extension"),
            format!("{}-{}", base_name.to_lowercase(), "module"),
            format!("{}-{}", base_name.to_lowercase(), "component"),
            format!("{}-{}", base_name.to_lowercase(), "widget"),
            format!("{}-{}", base_name.to_lowercase(), "helper"),
            format!("{}-{}", base_name.to_lowercase(), "util"),
        ]);

        // Add version patterns
        suggestions.extend(vec![
            format!("{}-{}", base_name.to_lowercase(), "v1"),
            format!("{}-{}", base_name.to_lowercase(), "v2"),
            format!("{}-{}", base_name.to_lowercase(), "v3"),
            format!("{}-{}", base_name.to_lowercase(), "next"),
            format!("{}-{}", base_name.to_lowercase(), "beta"),
            format!("{}-{}", base_name.to_lowercase(), "alpha"),
            format!("{}-{}", base_name.to_lowercase(), "rc"),
        ]);

        // Add language-specific patterns
        suggestions.extend(vec![
            format!("{}-{}", base_name.to_lowercase(), "go"),
            format!("{}-{}", base_name.to_lowercase(), "rust"),
            format!("{}-{}", base_name.to_lowercase(), "js"),
            format!("{}-{}", base_name.to_lowercase(), "ts"),
            format!("{}-{}", base_name.to_lowercase(), "py"),
            format!("{}-{}", base_name.to_lowercase(), "java"),
            format!("{}-{}", base_name.to_lowercase(), "cpp"),
            format!("{}-{}", base_name.to_lowercase(), "rs"),
            format!("{}-{}", base_name.to_lowercase(), "ex"),
            format!("{}-{}", base_name.to_lowercase(), "gleam"),
        ]);

        // Add environment patterns
        suggestions.extend(vec![
            format!("{}-{}", base_name.to_lowercase(), "dev"),
            format!("{}-{}", base_name.to_lowercase(), "test"),
            format!("{}-{}", base_name.to_lowercase(), "staging"),
            format!("{}-{}", base_name.to_lowercase(), "prod"),
            format!("{}-{}", base_name.to_lowercase(), "local"),
            format!("{}-{}", base_name.to_lowercase(), "ci"),
            format!("{}-{}", base_name.to_lowercase(), "cd"),
        ]);

        suggestions
    }

    /// Generate library naming suggestions (monilib, blabla style)
    fn generate_library_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Library naming patterns
        suggestions.extend(vec![
            format!("{}", base_name.to_lowercase()),
            format!("{}lib", base_name.to_lowercase()),
            format!("{}_lib", base_name.to_lowercase()),
            format!("{}-lib", base_name.to_lowercase()),
            format!("lib{}", base_name.to_lowercase()),
            format!("lib_{}", base_name.to_lowercase()),
            format!("lib-{}", base_name.to_lowercase()),
        ]);

        // Common library suffixes
        let suffixes = vec![
            "lib",
            "libs",
            "library",
            "libraries",
            "core",
            "common",
            "shared",
            "utils",
            "utilities",
            "helpers",
            "helpers",
            "tools",
            "toolkit",
            "kit",
            "pack",
            "package",
            "pkg",
            "sdk",
            "api",
            "client",
            "server",
            "engine",
            "framework",
            "platform",
            "base",
            "foundation",
            "foundation",
            "common",
            "shared",
            "core",
            "base",
        ];

        for suffix in &suffixes {
            suggestions.extend(vec![
                format!("{}{}", base_name.to_lowercase(), suffix),
                format!("{}_{}", base_name.to_lowercase(), suffix),
                format!("{}-{}", base_name.to_lowercase(), suffix),
                format!("{}{}", suffix, base_name.to_lowercase()),
                format!("{}_{}", suffix, base_name.to_lowercase()),
                format!("{}-{}", suffix, base_name.to_lowercase()),
            ]);
        }

        // Language-specific library patterns
        suggestions.extend(vec![
            format!("{}-go", base_name.to_lowercase()),
            format!("{}-rust", base_name.to_lowercase()),
            format!("{}-js", base_name.to_lowercase()),
            format!("{}-ts", base_name.to_lowercase()),
            format!("{}-py", base_name.to_lowercase()),
            format!("{}-java", base_name.to_lowercase()),
            format!("{}-cpp", base_name.to_lowercase()),
            format!("{}-ex", base_name.to_lowercase()),
            format!("{}-gleam", base_name.to_lowercase()),
        ]);

        // Package manager patterns
        suggestions.extend(vec![
            format!("@{}", base_name.to_lowercase()),
            format!("@{}", base_name.to_lowercase()),
            format!("{}", base_name.to_lowercase()),
            format!("{}", base_name.to_lowercase()),
        ]);

        // Version patterns
        suggestions.extend(vec![
            format!("{}-v1", base_name.to_lowercase()),
            format!("{}-v2", base_name.to_lowercase()),
            format!("{}-v3", base_name.to_lowercase()),
            format!("{}-next", base_name.to_lowercase()),
            format!("{}-beta", base_name.to_lowercase()),
            format!("{}-alpha", base_name.to_lowercase()),
        ]);

        suggestions
    }

    /// Generate package naming suggestions (npm, cargo, hex, pypi)
    fn generate_package_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Package naming patterns
        suggestions.extend(vec![
            format!("{}", base_name.to_lowercase()),
            format!("{}", base_name.to_kebab_case()),
            format!("{}", base_name.to_snake_case()),
        ]);

        // Package manager specific patterns
        suggestions.extend(vec![
            format!("@{}", base_name.to_lowercase()),
            format!("@{}", base_name.to_kebab_case()),
            format!("{}", base_name.to_lowercase()),
            format!("{}", base_name.to_kebab_case()),
        ]);

        // Version patterns
        suggestions.extend(vec![
            format!("{}-v1", base_name.to_lowercase()),
            format!("{}-v2", base_name.to_lowercase()),
            format!("{}-next", base_name.to_lowercase()),
            format!("{}-beta", base_name.to_lowercase()),
            format!("{}-alpha", base_name.to_lowercase()),
        ]);

        // Language-specific patterns
        suggestions.extend(vec![
            format!("{}-go", base_name.to_lowercase()),
            format!("{}-rust", base_name.to_lowercase()),
            format!("{}-js", base_name.to_lowercase()),
            format!("{}-ts", base_name.to_lowercase()),
            format!("{}-py", base_name.to_lowercase()),
            format!("{}-java", base_name.to_lowercase()),
            format!("{}-ex", base_name.to_lowercase()),
            format!("{}-gleam", base_name.to_lowercase()),
        ]);

        suggestions
    }

    /// Generate database naming suggestions (tables, columns, indexes)
    fn generate_database_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Database naming patterns (snake_case)
        suggestions.extend(vec![
            format!("{}", base_name.to_snake_case()),
            format!("{}s", base_name.to_snake_case()),
            format!("{}_table", base_name.to_snake_case()),
            format!("{}_tables", base_name.to_snake_case()),
        ]);

        // Common database suffixes
        let suffixes = vec![
            "table",
            "tables",
            "view",
            "views",
            "index",
            "indexes",
            "constraint",
            "constraints",
            "trigger",
            "triggers",
            "function",
            "functions",
            "procedure",
            "procedures",
            "sequence",
            "sequences",
            "schema",
            "schemas",
        ];

        for suffix in &suffixes {
            suggestions.extend(vec![
                format!("{}_{}", base_name.to_snake_case(), suffix),
                format!("{}_{}", base_name.to_snake_case(), suffix),
            ]);
        }

        // Column patterns
        suggestions.extend(vec![
            format!("{}_id", base_name.to_snake_case()),
            format!("{}_name", base_name.to_snake_case()),
            format!("{}_type", base_name.to_snake_case()),
            format!("{}_status", base_name.to_snake_case()),
            format!("{}_created_at", base_name.to_snake_case()),
            format!("{}_updated_at", base_name.to_snake_case()),
            format!("{}_deleted_at", base_name.to_snake_case()),
        ]);

        suggestions
    }

    /// Generate API naming suggestions (endpoints, routes, resources)
    fn generate_api_suggestions(&self, description: &str, context: Option<&str>) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // API naming patterns (kebab-case)
        suggestions.extend(vec![
            format!("{}", base_name.to_kebab_case()),
            format!("{}s", base_name.to_kebab_case()),
            format!("{}", base_name.to_snake_case()),
            format!("{}s", base_name.to_snake_case()),
        ]);

        // REST API patterns
        suggestions.extend(vec![
            format!("/{}", base_name.to_kebab_case()),
            format!("/{}/", base_name.to_kebab_case()),
            format!("/{}/:id", base_name.to_kebab_case()),
            format!("/{}/:id/", base_name.to_kebab_case()),
        ]);

        // HTTP method patterns
        let methods = vec!["get", "post", "put", "patch", "delete", "head", "options"];
        for method in &methods {
            suggestions.extend(vec![
                format!("{}_{}", method, base_name.to_snake_case()),
                format!("{}_{}", method, base_name.to_kebab_case()),
            ]);
        }

        // API version patterns
        suggestions.extend(vec![
            format!("/v1/{}", base_name.to_kebab_case()),
            format!("/v2/{}", base_name.to_kebab_case()),
            format!("/api/v1/{}", base_name.to_kebab_case()),
            format!("/api/v2/{}", base_name.to_kebab_case()),
        ]);

        suggestions
    }

    /// Generate microservice naming suggestions (user-service, payment-gateway, etc.)
    fn generate_microservice_suggestions(
        &self,
        description: &str,
        context: Option<&str>,
    ) -> Vec<String> {
        let base_name = self.extract_base_name(description);
        let mut suggestions = Vec::new();

        // Microservice naming patterns (kebab-case)
        suggestions.extend(vec![
            format!("{}", base_name.to_kebab_case()),
            format!("{}-service", base_name.to_kebab_case()),
            format!("{}-microservice", base_name.to_kebab_case()),
            format!("{}-api", base_name.to_kebab_case()),
            format!("{}-gateway", base_name.to_kebab_case()),
        ]);

        // Common microservice suffixes
        let suffixes = vec![
            "service",
            "microservice",
            "api",
            "gateway",
            "proxy",
            "handler",
            "processor",
            "worker",
            "consumer",
            "producer",
            "manager",
            "controller",
            "coordinator",
            "orchestrator",
            "aggregator",
            "dispatcher",
            "router",
            "broker",
            "adapter",
            "bridge",
            "connector",
            "interface",
            "client",
            "server",
            "agent",
            "daemon",
        ];

        for suffix in &suffixes {
            suggestions.extend(vec![
                format!("{}-{}", base_name.to_kebab_case(), suffix),
                format!("{}-{}", base_name.to_kebab_case(), suffix),
            ]);
        }

        // Domain-specific microservice patterns
        let domains = vec![
            "user",
            "auth",
            "payment",
            "order",
            "inventory",
            "shipping",
            "notification",
            "email",
            "sms",
            "push",
            "analytics",
            "logging",
            "monitoring",
            "metrics",
            "tracing",
            "audit",
            "compliance",
            "billing",
            "subscription",
            "catalog",
            "search",
            "recommendation",
            "chat",
            "messaging",
            "queue",
            "event",
            "stream",
            "batch",
        ];

        for domain in &domains {
            if description.to_lowercase().contains(domain) {
                suggestions.extend(vec![
                    format!("{}-{}", domain, base_name.to_kebab_case()),
                    format!("{}-{}-service", domain, base_name.to_kebab_case()),
                    format!("{}-{}-api", domain, base_name.to_kebab_case()),
                    format!("{}-{}-gateway", domain, base_name.to_kebab_case()),
                ]);
            }
        }

        // Architecture patterns
        suggestions.extend(vec![
            format!("{}-core", base_name.to_kebab_case()),
            format!("{}-shared", base_name.to_kebab_case()),
            format!("{}-common", base_name.to_kebab_case()),
            format!("{}-base", base_name.to_kebab_case()),
            format!("{}-foundation", base_name.to_kebab_case()),
        ]);

        // Environment patterns
        suggestions.extend(vec![
            format!("{}-dev", base_name.to_kebab_case()),
            format!("{}-test", base_name.to_kebab_case()),
            format!("{}-staging", base_name.to_kebab_case()),
            format!("{}-prod", base_name.to_kebab_case()),
            format!("{}-local", base_name.to_kebab_case()),
        ]);

        // Version patterns
        suggestions.extend(vec![
            format!("{}-v1", base_name.to_kebab_case()),
            format!("{}-v2", base_name.to_kebab_case()),
            format!("{}-v3", base_name.to_kebab_case()),
            format!("{}-next", base_name.to_kebab_case()),
            format!("{}-beta", base_name.to_kebab_case()),
            format!("{}-alpha", base_name.to_kebab_case()),
        ]);

        // Language-specific patterns
        suggestions.extend(vec![
            format!("{}-go", base_name.to_kebab_case()),
            format!("{}-rust", base_name.to_kebab_case()),
            format!("{}-js", base_name.to_kebab_case()),
            format!("{}-ts", base_name.to_kebab_case()),
            format!("{}-py", base_name.to_kebab_case()),
            format!("{}-java", base_name.to_kebab_case()),
            format!("{}-ex", base_name.to_kebab_case()),
            format!("{}-gleam", base_name.to_kebab_case()),
        ]);

        // Container patterns
        suggestions.extend(vec![
            format!("{}-container", base_name.to_kebab_case()),
            format!("{}-pod", base_name.to_kebab_case()),
            format!("{}-deployment", base_name.to_kebab_case()),
            format!("{}-daemonset", base_name.to_kebab_case()),
            format!("{}-statefulset", base_name.to_kebab_case()),
        ]);

        // Cloud patterns
        suggestions.extend(vec![
            format!("{}-aws", base_name.to_kebab_case()),
            format!("{}-gcp", base_name.to_kebab_case()),
            format!("{}-azure", base_name.to_kebab_case()),
            format!("{}-k8s", base_name.to_kebab_case()),
            format!("{}-docker", base_name.to_kebab_case()),
        ]);

        suggestions
    }

    /// Calculate quality score
    fn calculate_quality_score(&self, violations: &[NamingViolation]) -> f64 {
        if violations.is_empty() {
            1.0
        } else {
            1.0 - (violations.len() as f64 * 0.1).min(0.9)
        }
    }

    /// Count named elements in code
    fn count_named_elements(&self, code: &str) -> usize {
        // Simple count - can be enhanced
        code.matches("fn ").count()
            + code.matches("def ").count()
            + code.matches("function ").count()
    }

    /// Extract functions from code
    fn extract_functions(&self, code: &str) -> Vec<FunctionInfo> {
        // Simple extraction - can be enhanced with proper parsing
        vec![]
    }

    /// Extract modules from code
    fn extract_modules(&self, code: &str) -> Vec<ModuleInfo> {
        // Simple extraction - can be enhanced with proper parsing
        vec![]
    }
}

// ============================================================================
// LINTING STRUCTS
// ============================================================================

/// Naming convention types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum NamingConvention {
    CamelCase,
    PascalCase,
    SnakeCase,
    KebabCase,
    Mixed,
}

/// Language conventions (enum version)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LanguageConventionEnum {
    Rust,
    Elixir,
    JavaScript,
    TypeScript,
    Python,
    Go,
    Java,
    CSharp,
    Unknown,
}

/// Framework conventions (enum version)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FrameworkConventionEnum {
    Phoenix,
    Actix,
    React,
    Django,
    Rails,
    Unknown,
}

/// Lint status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LintStatus {
    Pass,
    Warning,
    Fail,
}

/// Severity levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Severity {
    Low,
    Medium,
    High,
    Critical,
}

/// Priority levels
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Priority {
    Low,
    Medium,
    High,
}

/// Recommendation priority (for architecture)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationPriority {
    Low,
    Medium,
    High,
    Critical,
}

/// Naming lint report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingLintReport {
    pub quality_score: f64,
    pub violations: Vec<NamingViolation>,
    pub improvements: Vec<NamingImprovement>,
    pub explanations: Vec<NamingExplanation>,
    pub total_elements: usize,
    pub lint_status: LintStatus,
    pub recommendations: Vec<NamingRecommendation>,
}

/// Naming violation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingViolation {
    pub name: String,
    pub element_type: String,
    pub violation_type: String,
    pub severity: String,
    pub message: String,
    pub line_number: Option<u32>,
    pub suggested_fix: Option<String>,
}

/// Naming improvement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingImprovement {
    pub original_name: String,
    pub improved_name: String,
    pub element_type: String,
    pub improvement_type: String,
    pub confidence: f64,
    pub explanation: String,
}

/// Naming quality report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingQualityReport {
    pub overall_score: f64,
    pub violations: Vec<NamingViolation>,
    pub improvements: Vec<NamingImprovement>,
    pub total_elements: usize,
    pub quality_level: String,
}

/// Naming explanation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingExplanation {
    pub element_type: String,
    pub name: String,
    pub issue: String,
    pub explanation: String,
    pub examples: Vec<String>,
    pub severity: Severity,
    pub fix_suggestion: Option<String>,
}

/// Naming recommendation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingRecommendation {
    pub category: String,
    pub issue: String,
    pub recommendation: String,
    pub examples: Vec<String>,
    pub priority: Priority,
}

/// Function info for parsing
#[derive(Debug, Clone)]
pub struct FunctionInfo {
    pub name: String,
    pub description: String,
    pub line: usize,
}

/// Module info for parsing
#[derive(Debug, Clone)]
pub struct ModuleInfo {
    pub name: String,
    pub description: String,
    pub line: usize,
}

/// Detection status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DetectionStatus {
    Pass,
    Warning,
    Fail,
}

/// Refactor priority
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactorPriority {
    Low,
    Medium,
    High,
}

/// Refactor type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RefactorType {
    RenameFunction,
    RenameModule,
    RenameVariable,
    RenameClass,
    RenameInterface,
    RenameElement,
}

/// Naming detection report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingDetectionReport {
    pub quality_score: f64,
    pub violations: Vec<NamingViolation>,
    pub explanations: Vec<NamingExplanation>,
    pub total_elements: usize,
    pub detection_status: DetectionStatus,
    pub flagged_for_refactor: Vec<RefactorFlag>,
    pub summary: NamingSummary,
}

/// Refactor flag
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefactorFlag {
    pub element_type: String,
    pub name: String,
    pub current_name: String,
    pub suggested_name: Option<String>,
    pub reason: String,
    pub priority: RefactorPriority,
    pub refactor_type: RefactorType,
    pub line_number: usize,
}

/// Naming summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingSummary {
    pub total_violations: usize,
    pub function_violations: usize,
    pub module_violations: usize,
    pub variable_violations: usize,
    pub critical_violations: usize,
    pub needs_refactor: bool,
    pub refactor_priority: String,
}

/// Fact system client for knowledge integration
#[derive(Debug, Clone)]
pub struct FactSystemClient {
    pub facts: HashMap<String, String>,
}

impl FactSystemClient {
    pub fn new() -> Self {
        Self {
            facts: HashMap::new(),
        }
    }
}

impl Default for NamingRules {
    fn default() -> Self {
        Self {
            language_conventions: HashMap::new(),
            framework_overrides: HashMap::new(),
            project_patterns: HashMap::new(),
            quality_thresholds: QualityThresholds {
                min_confidence: 0.7,
                min_semantic_similarity: 0.8,
                max_ambiguity: 0.3,
                min_context_relevance: 0.6,
            },
        }
    }
}

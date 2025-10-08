//! Architecture Engine - Meta-registry, Naming, and Architecture Analysis
//!
//! Comprehensive architecture management system for:
//! - Meta-registry of all repositories
//! - Intelligent naming suggestions and validation
//! - Architecture pattern detection and analysis
//! - Standards enforcement and violation detection
//!
//! ## Core Modules
//!
//! - **Naming Conventions** - Smart naming suggestions and validation
//! - **Architecture Patterns** - Pattern detection and analysis
//! - **Standards Enforcement** - Violation detection and compliance
//! - **Meta-Registry** - Repository management and tracking
//!
//! ## Usage
//!
//! ```rust
//! use architecture_engine::{NamingConventions, ArchitecturalPatternDetector};
//!
//! let naming = NamingConventions::new();
//! let suggestions = naming.suggest_function_names("calculate total price");
//!
//! let detector = ArchitecturalPatternDetector::new();
//! let patterns = detector.detect_patterns(codebase_path).await?;
//! ```

pub mod architecture;
pub mod code_evolution;
pub mod naming_conventions;
pub mod naming_core;
pub mod naming_languages;
pub mod naming_suggestions;
pub mod naming_service;
pub mod patterns;
pub mod technology_detection;

// Re-exports for naming
pub use naming_conventions::{
    CodeElementCategory, CodeElementType, DetectionStatus, FrameworkConvention, FunctionInfo,
    LanguageConvention, LintStatus, ModuleInfo, NamingConvention, NamingConventions,
    NamingDetectionReport, NamingExplanation, NamingLintReport, NamingRecommendation,
    NamingSummary, Priority, RefactorFlag, RefactorPriority, RefactorType, Severity,
};
pub use naming_service::{evaluate_name, NamingEvaluation};

// Re-exports for architecture
pub use architecture::{
    ArchitecturalPatternAnalysis, ArchitecturalPatternType, ArchitectureAnalysisPattern,
    ArchitectureMetadata, ArchitectureRecommendation, ArchitectureViolation, PatternComponent,
    PatternLocation, PatternRelationship,
};

// Import the types we need for NIFs (already imported above)

// NIF functions for Elixir
use rustler::{Error, NifStruct};

#[derive(NifStruct)]
#[module = "Singularity.ArchitectureEngine.NamingEvaluation"]
struct NifNamingEvaluation {
    name: String,
    element_type: String,
    language: Option<String>,
    is_valid: bool,
    messages: Vec<String>,
    suggestions: Vec<String>,
}

/// NIF: Suggest function names
#[rustler::nif]
fn suggest_function_names(
    description: String,
    context: Option<String>,
) -> Result<Vec<String>, Error> {
    let naming = NamingConventions::new();
    Ok(naming.suggest_function_names(&description, context.as_deref()))
}

/// NIF: Suggest module names
#[rustler::nif]
fn suggest_module_names(
    description: String,
    context: Option<String>,
) -> Result<Vec<String>, Error> {
    let naming = NamingConventions::new();
    Ok(naming.suggest_module_names(&description, context.as_deref()))
}

/// NIF: Suggest variable names
#[rustler::nif]
fn suggest_variable_names(
    description: String,
    context: Option<String>,
) -> Result<Vec<String>, Error> {
    let naming = NamingConventions::new();
    Ok(naming.suggest_variable_names(&description, context.as_deref()))
}

/// NIF: Validate naming convention
#[rustler::nif]
fn validate_naming_convention(name: String, element_type: String) -> Result<bool, Error> {
    let naming = NamingConventions::new();
    let result = match element_type.as_str() {
        "function" => naming.validate_function_name(&name),
        "module" => naming.validate_module_name(&name),
        "variable" => naming.validate_variable_name(&name),
        "class" => naming.validate_class_name(&name),
        "interface" => naming.validate_interface_name(&name),
        "file" => naming.validate_filename(&name),
        "directory" => naming.validate_directory_name(&name),
        _ => false, // Or return an error for unknown types
    };
    Ok(result)
}

#[rustler::nif(name = "evaluate_name")]
fn evaluate_name_nif(
    name: String,
    element_type: String,
    language: Option<String>,
    description: Option<String>,
) -> NifNamingEvaluation {
    let element = parse_code_element_type(&element_type);
    let evaluation = naming_service::evaluate_name(
        &name,
        element.clone(),
        language.as_deref(),
        description.as_deref(),
    );

    NifNamingEvaluation {
        name: evaluation.name,
        element_type: format_code_element_type(&element),
        language: evaluation.language,
        is_valid: evaluation.is_valid,
        messages: evaluation.messages,
        suggestions: evaluation.suggestions,
    }
}

/// NIF: Suggest monorepo names
#[rustler::nif]
fn suggest_monorepo_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_monorepo_name(&description, context.as_deref())
}

/// NIF: Suggest library names
#[rustler::nif]
fn suggest_library_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_library_name(&description, context.as_deref())
}

/// NIF: Suggest service names
#[rustler::nif]
fn suggest_service_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_service_name(&description, context.as_deref())
}

/// NIF: Suggest component names
#[rustler::nif]
fn suggest_component_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_component_name(&description, context.as_deref())
}

/// NIF: Suggest package names
#[rustler::nif]
fn suggest_package_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_package_name(&description, context.as_deref())
}

/// NIF: Suggest table names
#[rustler::nif]
fn suggest_table_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_table_name(&description, context.as_deref())
}

/// NIF: Suggest endpoint names
#[rustler::nif]
fn suggest_endpoint_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_endpoint_name(&description, context.as_deref())
}

/// NIF: Suggest microservice names
#[rustler::nif]
fn suggest_microservice_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_microservice_name(&description, context.as_deref())
}

/// NIF: Suggest topic names
#[rustler::nif]
fn suggest_topic_name(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_topic_name(&description, context.as_deref())
}

/// NIF: Suggest NATS subject names
#[rustler::nif]
fn suggest_nats_subject(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_nats_subject(&description, context.as_deref())
}

/// NIF: Suggest Kafka topic names
#[rustler::nif]
fn suggest_kafka_topic(description: String, context: Option<String>) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_kafka_topic(&description, context.as_deref())
}

/// NIF: Suggest names based on architecture
#[rustler::nif]
fn suggest_names_for_architecture(
    description: String,
    architecture: String,
    context: Option<String>,
) -> Vec<String> {
    let naming = NamingConventions::new();
    naming.suggest_names_for_architecture(&description, &architecture, context.as_deref())
}

fn parse_code_element_type(value: &str) -> CodeElementType {
    match value.to_lowercase().as_str() {
        "function" => CodeElementType::Function,
        "module" => CodeElementType::Module,
        "variable" => CodeElementType::Variable,
        "file" => CodeElementType::File,
        "directory" => CodeElementType::Directory,
        "class" => CodeElementType::Class,
        "interface" => CodeElementType::Interface,
        _ => CodeElementType::Function,
    }
}

fn format_code_element_type(element: &CodeElementType) -> String {
    match element {
        CodeElementType::Function => "function",
        CodeElementType::Module => "module",
        CodeElementType::Variable => "variable",
        CodeElementType::File => "file",
        CodeElementType::Directory => "directory",
        CodeElementType::Class => "class",
        CodeElementType::Interface => "interface",
    }
    .to_string()
}

// Rustler NIF initialization
rustler::init!(
    "Elixir.Singularity.ArchitectureEngine",
    [
        suggest_function_names,
        suggest_module_names,
        suggest_variable_names,
        validate_naming_convention,
        suggest_monorepo_name,
        suggest_library_name,
        suggest_service_name,
        suggest_component_name,
        suggest_package_name,
        suggest_table_name,
        suggest_endpoint_name,
        suggest_microservice_name,
        suggest_topic_name,
        suggest_nats_subject,
        suggest_kafka_topic,
        suggest_names_for_architecture,
        evaluate_name_nif
    ]
);

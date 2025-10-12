pub mod intelligent_namer;

use rustler::Error;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

// Re-export the intelligent namer
pub use intelligent_namer::{
    IntelligentNamer, RenameContext, RenameElementType, RenameSuggestion,
    DetectionMethod, NamingRules
};

// Local type definitions for code analysis
// TODO: Integrate with analysis_suite crate when available
#[derive(Debug, Clone, PartialEq)]
pub enum CodeElementCategory {
    BusinessLogic,
    Infrastructure,
    SystemIntegration,
    Configuration,
}

#[derive(Debug, Clone, PartialEq)]
pub enum CodeElementType {
    Variable,
    Function,
    Module,
    Class,
    Interface,
}

// Rustler NIF initialization
rustler::init!("Elixir.Singularity.IntelligentNamerNif");

/// NIF-compatible suggestion structure
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.IntelligentNamerNif.Suggestion"]
pub struct NifSuggestion {
    pub name: String,
    pub confidence: f64,
    pub reasoning: String,
    pub method: String,
    pub alternatives: Vec<String>,
}

/// NIF-compatible rename context
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifMap)]
pub struct NifRenameContext {
    pub base_name: String,
    pub element_type: String,
    pub context: Option<String>,
    pub language: Option<String>,
    pub framework: Option<String>,
}

/// NIF-compatible naming patterns
#[derive(Debug, Clone, Serialize, Deserialize, rustler::NifStruct)]
#[module = "Singularity.IntelligentNamerNif.NamingPatterns"]
pub struct NifNamingPatterns {
    pub language: String,
    pub conventions: HashMap<String, String>,
    pub examples: Vec<String>,
}

/// Suggest better names for a code element
#[rustler::nif]
fn suggest_names(context: NifRenameContext) -> Result<Vec<NifSuggestion>, Error> {
    // Create intelligent namer instance
    let namer = IntelligentNamer::new();

    // Convert NIF context to internal RenameContext
    let element_type = match context.element_type.as_str() {
        "variable" => RenameElementType::Variable,
        "function" => RenameElementType::Function,
        "module" => RenameElementType::Module,
        "class" => RenameElementType::Class,
        "service" => RenameElementType::Service,
        "component" => RenameElementType::Component,
        "interface" => RenameElementType::Interface,
        "file" => RenameElementType::File,
        "directory" => RenameElementType::Directory,
        _ => RenameElementType::Variable,
    };

    let rename_ctx = RenameContext {
        base_name: context.base_name,
        element_type: element_type.clone(),
        category: default_category_for(&element_type),
        code_context: None, // TODO: Add code context
        framework_info: context.framework,
        project_type: context.language,
    };

    // Get suggestions (sync version for now)
    let suggestions = futures::executor::block_on(async {
        namer.suggest_names(&rename_ctx).await
    }).map_err(|e| Error::Term(Box::new(format!("Namer error: {}", e))))?;

    // Convert to NIF suggestions
    let nif_suggestions = suggestions
        .into_iter()
        .map(|s| NifSuggestion {
            name: s.name,
            confidence: s.confidence,
            reasoning: s.reasoning,
            method: format!("{:?}", s.method),
            alternatives: s.alternatives,
        })
        .collect();

    Ok(nif_suggestions)
}

/// Validate a name against conventions
#[rustler::nif]
fn validate_name(name: String, element_type: String) -> Result<bool, Error> {
    let namer = IntelligentNamer::new();

    let elem_type = map_string_to_code_element_type(&element_type);

    Ok(namer.validate_name(&name, elem_type))
}

/// Get naming patterns for a language
#[rustler::nif]
fn get_naming_patterns(language: String, framework: Option<String>) -> Result<NifNamingPatterns, Error> {
    // Build patterns based on language
    let conventions = match language.as_str() {
        "elixir" => {
            let mut map = HashMap::new();
            map.insert("module".to_string(), "PascalCase".to_string());
            map.insert("function".to_string(), "snake_case".to_string());
            map.insert("variable".to_string(), "snake_case".to_string());
            map.insert("predicate".to_string(), "ends_with_?".to_string());
            map.insert("bang".to_string(), "ends_with_!".to_string());

            if let Some(fw) = framework.as_ref() {
                if fw == "phoenix" {
                    map.insert("context".to_string(), "PascalCase + Context".to_string());
                    map.insert("controller".to_string(), "PascalCase + Controller".to_string());
                }
            }

            map
        },
        "rust" => {
            let mut map = HashMap::new();
            map.insert("module".to_string(), "snake_case".to_string());
            map.insert("function".to_string(), "snake_case".to_string());
            map.insert("variable".to_string(), "snake_case".to_string());
            map.insert("struct".to_string(), "PascalCase".to_string());
            map.insert("trait".to_string(), "PascalCase".to_string());
            map
        },
        "typescript" | "javascript" => {
            let mut map = HashMap::new();
            map.insert("class".to_string(), "PascalCase".to_string());
            map.insert("function".to_string(), "camelCase".to_string());
            map.insert("variable".to_string(), "camelCase".to_string());
            map.insert("constant".to_string(), "UPPER_SNAKE_CASE".to_string());
            map
        },
        _ => HashMap::new(),
    };

    let examples = vec![
        "user_session".to_string(),
        "process_data".to_string(),
        "SessionCache".to_string(),
    ];

    Ok(NifNamingPatterns {
        language,
        conventions,
        examples,
    })
}

fn default_category_for(element_type: &RenameElementType) -> CodeElementCategory {
    match element_type {
        RenameElementType::Service | RenameElementType::Component | RenameElementType::Class => {
            CodeElementCategory::BusinessLogic
        }
        RenameElementType::Function => CodeElementCategory::BusinessLogic,
        RenameElementType::Variable => CodeElementCategory::Infrastructure,
        RenameElementType::Module => CodeElementCategory::Infrastructure,
        RenameElementType::Interface => CodeElementCategory::SystemIntegration,
        RenameElementType::File | RenameElementType::Directory => CodeElementCategory::Configuration,
    }
}

fn map_string_to_code_element_type(type_name: &str) -> CodeElementType {
    match type_name {
        "variable" => CodeElementType::Variable,
        "function" => CodeElementType::Function,
        "module" => CodeElementType::Module,
        "class" => CodeElementType::Class,
        "service" => CodeElementType::Class,
        "component" => CodeElementType::Class,
        "interface" => CodeElementType::Interface,
        "file" => CodeElementType::Module,
        "directory" => CodeElementType::Module,
        _ => CodeElementType::Function,
    }
}

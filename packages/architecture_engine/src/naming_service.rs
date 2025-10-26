use crate::naming_conventions::NamingConventions;
use crate::naming_core::CodeElementType;
use crate::naming_languages::LanguageConvention;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingEvaluation {
    pub name: String,
    pub element_type: CodeElementType,
    pub language: Option<String>,
    pub is_valid: bool,
    pub messages: Vec<String>,
    pub suggestions: Vec<String>,
}

pub fn evaluate_name(
    name: &str,
    element_type: CodeElementType,
    language: Option<&str>,
    description: Option<&str>,
) -> NamingEvaluation {
    let naming = NamingConventions::new();
    let lang_lower = language.map(|l| l.to_lowercase());

    let is_valid = match element_type {
        CodeElementType::Function => match lang_lower.as_deref() {
            Some(lang) => naming.validate_function_name_for_language(name, lang),
            None => naming.validate_function_name(name),
        },
        CodeElementType::Variable => naming.validate_variable_name(name),
        CodeElementType::Module => naming.validate_module_name(name),
        CodeElementType::File => naming.validate_filename(name),
        CodeElementType::Directory => naming.validate_directory_name(name),
        CodeElementType::Class => naming.validate_class_name(name),
        CodeElementType::Interface => naming.validate_interface_name(name),
        CodeElementType::Struct => naming.validate_class_name(name), // Structs follow class naming
        CodeElementType::Enum => naming.validate_class_name(name), // Enums follow class naming
        CodeElementType::Trait => naming.validate_interface_name(name), // Traits follow interface naming
        CodeElementType::Constant => naming.validate_variable_name(name), // Constants follow variable naming
        CodeElementType::Field => naming.validate_variable_name(name), // Fields follow variable naming
        CodeElementType::Method => naming.validate_function_name(name), // Methods follow function naming
        CodeElementType::Property => naming.validate_variable_name(name), // Properties follow variable naming
    };

    let mut messages = Vec::new();
    let mut suggestions = Vec::new();

    if !is_valid {
        if let Some(lang) = lang_lower.as_deref() {
            if let Some(hint) = expected_case_hint(&naming, element_type, lang) {
                messages.push(hint);
            }
        }

        if messages.is_empty() {
            messages.push("Name does not follow established naming conventions".to_string());
        }

        let generated_description = description
            .map(|d| d.to_string())
            .unwrap_or_else(|| name_to_description(name));
        suggestions = suggestions_for(&naming, element_type, &generated_description);
    }

    NamingEvaluation {
        name: name.to_string(),
        element_type,
        language: language.map(|l| l.to_string()),
        is_valid,
        messages,
        suggestions,
    }
}

fn suggestions_for(
    naming: &NamingConventions,
    element_type: CodeElementType,
    description: &str,
) -> Vec<String> {
    match element_type {
        CodeElementType::Function => naming.suggest_function_names(description, None),
        CodeElementType::Module => naming.suggest_module_names(description, None),
        CodeElementType::Variable => naming.suggest_variable_names(description, None),
        CodeElementType::Class => naming.suggest_class_names(description, None),
        CodeElementType::Interface => naming.suggest_interface_names(description, None),
        CodeElementType::File => naming.suggest_filename(description, None),
        CodeElementType::Directory => naming.suggest_directory_name(description, None),
        CodeElementType::Struct => naming.suggest_class_names(description, None), // Structs follow class naming
        CodeElementType::Enum => naming.suggest_class_names(description, None), // Enums follow class naming
        CodeElementType::Trait => naming.suggest_interface_names(description, None), // Traits follow interface naming
        CodeElementType::Constant => naming.suggest_variable_names(description, None), // Constants follow variable naming
        CodeElementType::Field => naming.suggest_variable_names(description, None), // Fields follow variable naming
        CodeElementType::Method => naming.suggest_function_names(description, None), // Methods follow function naming
        CodeElementType::Property => naming.suggest_variable_names(description, None), // Properties follow variable naming
    }
}

fn expected_case_hint(
    _naming: &NamingConventions,
    element_type: CodeElementType,
    language: &str,
) -> Option<String> {
    // Get language convention based on language string
    let convention = match language.to_lowercase().as_str() {
        "elixir" => Some(LanguageConvention::Elixir),
        "rust" => Some(LanguageConvention::Rust),
        "typescript" => Some(LanguageConvention::TypeScript),
        "javascript" => Some(LanguageConvention::JavaScript),
        "gleam" => Some(LanguageConvention::Gleam),
        "python" => Some(LanguageConvention::Python),
        "go" => Some(LanguageConvention::Go),
        _ => None,
    };

    let descriptor = match convention {
        Some(LanguageConvention::Elixir)
        | Some(LanguageConvention::Python)
        | Some(LanguageConvention::Rust) => "snake_case",
        Some(LanguageConvention::JavaScript)
        | Some(LanguageConvention::TypeScript)
        | Some(LanguageConvention::Go) => "camelCase",
        // Removed Java and CSharp - not needed
        _ => return None,
    };

    let element = match element_type {
        CodeElementType::Function => "function",
        CodeElementType::Module => "module",
        CodeElementType::Variable => "variable",
        CodeElementType::File => "file",
        CodeElementType::Directory => "directory",
        CodeElementType::Class => "class",
        CodeElementType::Interface => "interface",
        CodeElementType::Struct => "struct",
        CodeElementType::Enum => "enum",
        CodeElementType::Trait => "trait",
        CodeElementType::Constant => "constant",
        CodeElementType::Field => "field",
        CodeElementType::Method => "method",
        CodeElementType::Property => "property",
    };

    Some(format!(
        "{} names should follow {} for language '{}'.",
        element, descriptor, language
    ))
}

fn name_to_description(name: &str) -> String {
    if name.is_empty() {
        return String::new();
    }

    let mut description = String::new();
    let mut last_was_lower = false;

    for ch in name.chars() {
        if ch == '_' || ch == '-' {
            description.push(' ');
            last_was_lower = false;
        } else if ch.is_uppercase() {
            if last_was_lower {
                description.push(' ');
            }
            description.push(ch.to_ascii_lowercase());
            last_was_lower = false;
        } else {
            description.push(ch);
            last_was_lower = true;
        }
    }

    description.trim().to_string()
}

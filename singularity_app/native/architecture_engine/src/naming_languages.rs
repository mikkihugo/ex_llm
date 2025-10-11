//! Language-Specific Naming Module
//! 
//! Handles naming conventions for different programming languages.
//! Pure analysis - no I/O operations.

use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use heck::ToSnakeCase;

/// Language-specific naming conventions
pub struct LanguageNaming {
    /// Language conventions mapping
    pub(crate) conventions: HashMap<LanguageConvention, LanguageRules>,
}

impl LanguageNaming {
    /// Create a new language naming handler
    pub fn new() -> Self {
        let mut conventions = HashMap::new();
        
        // Initialize language-specific rules
        conventions.insert(LanguageConvention::Elixir, LanguageRules::elixir());
        conventions.insert(LanguageConvention::Rust, LanguageRules::rust());
        conventions.insert(LanguageConvention::TypeScript, LanguageRules::typescript());
        conventions.insert(LanguageConvention::JavaScript, LanguageRules::javascript());
        conventions.insert(LanguageConvention::Gleam, LanguageRules::gleam());
        conventions.insert(LanguageConvention::Python, LanguageRules::python());
        conventions.insert(LanguageConvention::Go, LanguageRules::go());

        Self { conventions }
    }

    /// Get naming rules for a specific language
    pub fn get_rules(&self, language: LanguageConvention) -> Option<&LanguageRules> {
        self.conventions.get(&language)
    }

    /// Suggest function names for a language
    pub fn suggest_function_names(&self, description: &str, language: LanguageConvention) -> Vec<String> {
        if let Some(rules) = self.get_rules(language) {
            rules.suggest_function_names(description)
        } else {
            vec![description.to_string()]
        }
    }

    /// Suggest variable names for a language
    pub fn suggest_variable_names(&self, description: &str, language: LanguageConvention) -> Vec<String> {
        if let Some(rules) = self.get_rules(language) {
            rules.suggest_variable_names(description)
        } else {
            vec![description.to_string()]
        }
    }

    /// Suggest module names for a language
    pub fn suggest_module_names(&self, description: &str, language: LanguageConvention) -> Vec<String> {
        if let Some(rules) = self.get_rules(language) {
            rules.suggest_module_names(description)
        } else {
            vec![description.to_string()]
        }
    }
}

impl Default for LanguageNaming {
    fn default() -> Self {
        Self::new()
    }
}

/// Programming language conventions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum LanguageConvention {
    Elixir,
    Rust,
    TypeScript,
    JavaScript,
    Gleam,
    Python,
    Go,
}

/// Language-specific naming rules
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageRules {
    pub function_case: CaseStyle,
    pub variable_case: CaseStyle,
    pub module_case: CaseStyle,
    pub class_case: CaseStyle,
    pub constant_case: CaseStyle,
    pub file_extension: String,
}

impl LanguageRules {
    pub fn elixir() -> Self {
        Self {
            function_case: CaseStyle::SnakeCase,
            variable_case: CaseStyle::SnakeCase,
            module_case: CaseStyle::PascalCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "ex".to_string(),
        }
    }

    pub fn rust() -> Self {
        Self {
            function_case: CaseStyle::SnakeCase,
            variable_case: CaseStyle::SnakeCase,
            module_case: CaseStyle::SnakeCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "rs".to_string(),
        }
    }

    pub fn typescript() -> Self {
        Self {
            function_case: CaseStyle::CamelCase,
            variable_case: CaseStyle::CamelCase,
            module_case: CaseStyle::PascalCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "ts".to_string(),
        }
    }

    pub fn javascript() -> Self {
        Self {
            function_case: CaseStyle::CamelCase,
            variable_case: CaseStyle::CamelCase,
            module_case: CaseStyle::PascalCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "js".to_string(),
        }
    }

    pub fn gleam() -> Self {
        Self {
            function_case: CaseStyle::SnakeCase,
            variable_case: CaseStyle::SnakeCase,
            module_case: CaseStyle::PascalCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "gleam".to_string(),
        }
    }

    pub fn python() -> Self {
        Self {
            function_case: CaseStyle::SnakeCase,
            variable_case: CaseStyle::SnakeCase,
            module_case: CaseStyle::SnakeCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "py".to_string(),
        }
    }

    pub fn go() -> Self {
        Self {
            function_case: CaseStyle::CamelCase,
            variable_case: CaseStyle::CamelCase,
            module_case: CaseStyle::SnakeCase,
            class_case: CaseStyle::PascalCase,
            constant_case: CaseStyle::SCREAMING_SNAKE_CASE,
            file_extension: "go".to_string(),
        }
    }

    pub fn suggest_function_names(&self, description: &str) -> Vec<String> {
        let base = self.convert_case(description, self.function_case);
        vec![base]
    }

    pub fn suggest_variable_names(&self, description: &str) -> Vec<String> {
        let base = self.convert_case(description, self.variable_case);
        vec![base]
    }

    pub fn suggest_module_names(&self, description: &str) -> Vec<String> {
        let base = self.convert_case(description, self.module_case);
        vec![base]
    }

    fn convert_case(&self, input: &str, case_style: CaseStyle) -> String {
        match case_style {
            CaseStyle::SnakeCase => input.to_snake_case(),
            CaseStyle::CamelCase => {
                let snake = input.to_snake_case();
                let mut chars = snake.chars();
                let first = chars.next().unwrap_or('_').to_lowercase();
                first.chain(chars).collect()
            }
            CaseStyle::PascalCase => {
                let snake = input.to_snake_case();
                snake.split('_').map(|s| {
                    let mut chars = s.chars();
                    let first = chars.next().unwrap_or('_').to_uppercase();
                    first.chain(chars).collect::<String>()
                }).collect::<Vec<String>>().join("")
            }
            CaseStyle::SCREAMING_SNAKE_CASE => input.to_snake_case().to_uppercase(),
            CaseStyle::KebabCase => input.to_kebab_case(),
        }
    }
}

/// Case style for naming conventions
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CaseStyle {
    SnakeCase,
    CamelCase,
    PascalCase,
    SCREAMING_SNAKE_CASE,
    KebabCase,
}
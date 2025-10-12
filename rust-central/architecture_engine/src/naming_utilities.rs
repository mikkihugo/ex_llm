//! Naming utilities for intelligent code naming

use crate::naming_conventions::NamingConventions;

/// Intelligent naming utilities
pub struct NamingUtilities {
    conventions: NamingConventions,
}

impl NamingUtilities {
    /// Create new naming utilities
    pub fn new() -> Self {
        Self {
            conventions: NamingConventions::new(),
        }
    }

    /// Validate function name according to language conventions
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

    /// Convert to snake_case
    fn to_snake_case(&self, input: &str) -> String {
        self.convert_to_snake_case(input)
    }

    /// Convert to kebab-case
    fn to_kebab_case(&self, input: &str) -> String {
        self.convert_to_kebab_case(input)
    }

    /// Validate snake_case naming
    fn validate_snake_case(&self, name: &str) -> bool {
        self.conventions.validate_snake_case(name)
    }

    /// Validate camelCase naming
    fn validate_camel_case(&self, name: &str) -> bool {
        self.conventions.validate_camel_case(name)
    }

    /// Convert string to snake_case
    fn convert_to_snake_case(&self, input: &str) -> String {
        self.conventions.to_snake_case(input)
    }

    /// Convert string to kebab-case
    fn convert_to_kebab_case(&self, input: &str) -> String {
        self.conventions.to_kebab_case(input)
    }
}

impl Default for NamingUtilities {
    fn default() -> Self {
        Self::new()
    }
}

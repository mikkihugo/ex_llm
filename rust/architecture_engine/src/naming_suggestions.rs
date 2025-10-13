//! Naming Suggestions - Generate intelligent naming suggestions
//!
//! Provides context-aware naming suggestions for various code elements.

use crate::naming_core::CodeElementType;
use crate::naming_utilities::NamingUtilities;

/// Naming suggestions generator
pub struct NamingSuggestions {
    utilities: NamingUtilities,
}

impl NamingSuggestions {
    pub fn new() -> Self {
        Self {
            utilities: NamingUtilities::new(),
        }
    }

    fn generate_suggestions(&self, description: &str, element_type: CodeElementType, _context: Option<&str>) -> Vec<String> {
        // Generate multiple naming variants using utilities
        let mut suggestions = Vec::new();

        match element_type {
            CodeElementType::Function | CodeElementType::Method | CodeElementType::Variable | CodeElementType::Field => {
                // snake_case for functions, methods, variables
                suggestions.push(self.utilities.to_snake_case(description));
                // Also offer camelCase variant
                suggestions.push(self.utilities.to_camel_case(description));
            },
            CodeElementType::Module | CodeElementType::Class | CodeElementType::Struct | CodeElementType::Enum | CodeElementType::Trait | CodeElementType::Interface => {
                // PascalCase for types
                suggestions.push(self.utilities.to_pascal_case(description));
                // Also offer snake_case for module files
                suggestions.push(self.utilities.to_snake_case(description));
            },
            CodeElementType::Constant => {
                // SCREAMING_SNAKE_CASE for constants
                suggestions.push(self.utilities.to_snake_case(description).to_uppercase());
                // Also offer snake_case
                suggestions.push(self.utilities.to_snake_case(description));
            },
            CodeElementType::Property => {
                // camelCase for properties (JavaScript/TypeScript)
                suggestions.push(self.utilities.to_camel_case(description));
                // Also offer snake_case
                suggestions.push(self.utilities.to_snake_case(description));
            },
            CodeElementType::File => {
                // snake_case for files
                suggestions.push(self.utilities.to_snake_case(description));
                // Also offer kebab-case
                suggestions.push(self.utilities.to_kebab_case(description));
            },
            CodeElementType::Directory => {
                // kebab-case for directories
                suggestions.push(self.utilities.to_kebab_case(description));
                // Also offer snake_case
                suggestions.push(self.utilities.to_snake_case(description));
            },
        }

        // Remove duplicates and empty strings
        suggestions.sort();
        suggestions.dedup();
        suggestions.into_iter().filter(|s| !s.is_empty()).collect()
    }
    pub fn suggest_function_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Function, context)
    }
    pub fn suggest_module_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Module, context)
    }
    pub fn suggest_variable_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Variable, context)
    }
    pub fn suggest_class_names(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Class, context)
    }
    pub fn suggest_filename(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Struct, context)
    }
    pub fn suggest_directory_name(&self, description: &str, context: Option<&str>) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Module, context)
    }
    
    // Add missing methods that are referenced in naming_conventions.rs
    pub fn suggest_microservice_names(&self, description: &str) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Module, None)
    }
    
    pub fn suggest_library_names(&self, description: &str) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Module, None)
    }
    
    pub fn suggest_monorepo_names(&self, description: &str) -> Vec<String> {
        self.generate_suggestions(description, CodeElementType::Module, None)
    }
}

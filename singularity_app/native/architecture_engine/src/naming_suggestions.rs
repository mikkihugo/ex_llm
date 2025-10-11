//! Naming Suggestions - Generate intelligent naming suggestions
//!
//! Provides context-aware naming suggestions for various code elements.

use crate::naming_core::CodeElementType;

/// Naming suggestions generator
pub struct NamingSuggestions {
    // Add fields as needed
}

impl NamingSuggestions {
    pub fn new() -> Self {
        Self {}
    }

    fn generate_suggestions(&self, description: &str, element_type: CodeElementType, context: Option<&str>) -> Vec<String> {
        // Basic implementation - can be enhanced
        match element_type {
            CodeElementType::Function => vec![description.to_string()],
            CodeElementType::Module => vec![description.to_string()],
            CodeElementType::Variable => vec![description.to_string()],
            CodeElementType::Class => vec![description.to_string()],
            CodeElementType::Struct => vec![description.to_string()],
            CodeElementType::Enum => vec![description.to_string()],
            CodeElementType::Trait => vec![description.to_string()],
            CodeElementType::Interface => vec![description.to_string()],
            CodeElementType::Constant => vec![description.to_string()],
            CodeElementType::Field => vec![description.to_string()],
            CodeElementType::Method => vec![description.to_string()],
            CodeElementType::Property => vec![description.to_string()],
        }
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

//! Core Naming Conventions Module
//! 
//! Handles basic naming rules, validation, and core functionality.
//! Pure analysis - no I/O operations.

use std::collections::HashMap;
use anyhow::Result;
use heck::{ToKebabCase, ToSnakeCase};
use serde::{Deserialize, Serialize};

/// Core naming conventions handler
pub struct NamingCore {
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
}

impl NamingCore {
    /// Create a new naming core
    pub fn new() -> Self {
        Self {
            patterns: HashMap::new(),
            naming_rules: NamingRules::default(),
            descriptions: HashMap::new(),
            search_index: HashMap::new(),
            confidence_threshold: 0.7,
        }
    }

    /// Validate function name
    pub fn validate_function_name(&self, name: &str) -> bool {
        self.naming_rules.validate_function_name(name)
    }

    /// Validate variable name
    pub fn validate_variable_name(&self, name: &str) -> bool {
        self.naming_rules.validate_variable_name(name)
    }

    /// Validate module name
    pub fn validate_module_name(&self, name: &str) -> bool {
        self.naming_rules.validate_module_name(name)
    }

    /// Convert to snake_case
    pub fn to_snake_case(&self, input: &str) -> String {
        input.to_snake_case()
    }

    /// Convert to kebab-case
    pub fn to_kebab_case(&self, input: &str) -> String {
        input.to_kebab_case()
    }

    /// Get naming rules
    pub fn get_naming_rules(&self) -> &NamingRules {
        &self.naming_rules
    }

    /// Set confidence threshold
    pub fn set_confidence_threshold(&mut self, threshold: f64) {
        self.confidence_threshold = threshold;
    }
}

impl Default for NamingCore {
    fn default() -> Self {
        Self::new()
    }
}

/// Code element categories for naming
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum CodeElementCategory {
    Naming,
    Structure,
}

/// Code element types for naming
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum CodeElementType {
    Function,
    Variable,
    Module,
    Class,
    Struct,
    Enum,
    Trait,
    Interface,
    Constant,
    Field,
    Method,
    Property,
}

/// Search result for naming suggestions
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchResult {
    pub name: String,
    pub confidence: f64,
    pub context: String,
}

/// Naming rules configuration
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NamingRules {
    pub function_pattern: String,
    pub variable_pattern: String,
    pub module_pattern: String,
    pub class_pattern: String,
    pub constant_pattern: String,
}

impl NamingRules {
    pub fn validate_function_name(&self, name: &str) -> bool {
        // Basic validation logic
        !name.is_empty() && name.chars().all(|c| c.is_alphanumeric() || c == '_')
    }

    pub fn validate_variable_name(&self, name: &str) -> bool {
        // Basic validation logic
        !name.is_empty() && name.chars().all(|c| c.is_alphanumeric() || c == '_')
    }

    pub fn validate_module_name(&self, name: &str) -> bool {
        // Basic validation logic
        !name.is_empty() && name.chars().all(|c| c.is_alphanumeric() || c == '_')
    }
}
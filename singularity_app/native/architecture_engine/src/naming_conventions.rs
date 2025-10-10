//! Naming Conventions - Main Module
//!
//! Orchestrates all naming functionality using modular components.
//! Pure analysis - no I/O operations.

use std::collections::HashMap;
use anyhow::Result;
use serde::{Deserialize, Serialize};

// Import modular components
use crate::naming_core::{NamingCore, CodeElementCategory, SearchResult, NamingRules};
use crate::naming_languages::{LanguageNaming, LanguageConvention};
use crate::naming_suggestions::NamingSuggestions;

/// Main naming conventions handler
pub struct NamingConventions {
    /// Core naming functionality
    pub(crate) core: NamingCore,
    /// Language-specific naming
    pub(crate) languages: LanguageNaming,
    /// Suggestions generator
    pub(crate) suggestions: NamingSuggestions,
    /// Framework integration
    pub(crate) framework_integration: Option<FrameworkIntegration>,
    /// Agent integration
    pub(crate) agent_integration: Option<AgentIntegration>,
    /// Context analyzer
    pub(crate) context_analyzer: Option<ContextAnalyzer>,
}

impl NamingConventions {
    /// Create a new naming conventions handler
    pub fn new() -> Self {
        Self {
            core: NamingCore::new(),
            languages: LanguageNaming::new(),
            suggestions: NamingSuggestions::new(),
            framework_integration: None,
            agent_integration: None,
            context_analyzer: None,
        }
    }

    /// Suggest function names
    pub fn suggest_function_names(&self, description: &str, language: Option<LanguageConvention>) -> Vec<String> {
        if let Some(lang) = language {
            self.languages.suggest_function_names(description, lang)
        } else {
            self.suggestions.suggest_function_names(description, None)
        }
    }

    /// Suggest variable names
    pub fn suggest_variable_names(&self, description: &str, language: Option<LanguageConvention>) -> Vec<String> {
        if let Some(lang) = language {
            self.languages.suggest_variable_names(description, lang)
        } else {
            self.suggestions.suggest_variable_names(description, None)
        }
    }

    /// Suggest module names
    pub fn suggest_module_names(&self, description: &str, language: Option<LanguageConvention>) -> Vec<String> {
        if let Some(lang) = language {
            self.languages.suggest_module_names(description, lang)
        } else {
            self.suggestions.suggest_module_names(description, None)
        }
    }

    /// Suggest microservice names
    pub fn suggest_microservice_names(&self, description: &str) -> Vec<String> {
        self.suggestions.suggest_microservice_names(description)
    }

    /// Suggest library names
    pub fn suggest_library_names(&self, description: &str) -> Vec<String> {
        self.suggestions.suggest_library_names(description)
    }

    /// Suggest monorepo names
    pub fn suggest_monorepo_names(&self, description: &str) -> Vec<String> {
        self.suggestions.suggest_monorepo_names(description)
    }

    /// Validate function name
    pub fn validate_function_name(&self, name: &str) -> bool {
        self.core.validate_function_name(name)
    }

    /// Validate variable name
    pub fn validate_variable_name(&self, name: &str) -> bool {
        self.core.validate_variable_name(name)
    }

    /// Validate module name
    pub fn validate_module_name(&self, name: &str) -> bool {
        self.core.validate_module_name(name)
    }

    /// Convert to snake_case
    pub fn to_snake_case(&self, input: &str) -> String {
        self.core.to_snake_case(input)
    }

    /// Convert to kebab-case
    pub fn to_kebab_case(&self, input: &str) -> String {
        self.core.to_kebab_case(input)
    }

    /// Get naming rules
    pub fn get_naming_rules(&self) -> &NamingRules {
        self.core.get_naming_rules()
    }

    /// Set confidence threshold
    pub fn set_confidence_threshold(&mut self, threshold: f64) {
        self.core.set_confidence_threshold(threshold);
    }
}

impl Default for NamingConventions {
    fn default() -> Self {
        Self::new()
    }
}

/// Framework integration for naming
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FrameworkIntegration {
    pub framework_name: String,
    pub naming_patterns: HashMap<String, String>,
}

/// Agent integration for naming
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentIntegration {
    pub agent_name: String,
    pub naming_preferences: HashMap<String, String>,
}

/// Context analyzer for naming
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContextAnalyzer {
    pub context_type: String,
    pub analysis_rules: HashMap<String, String>,
}
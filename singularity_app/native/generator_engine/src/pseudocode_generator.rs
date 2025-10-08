//! Pseudocode Generator - Generate pseudocode with proper naming conventions
//!
//! This module generates pseudocode that follows proper naming conventions
//! and can be converted to clean code with comprehensive documentation.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Main pseudocode generator
#[derive(Debug, Clone)]
pub struct PseudocodeGenerator {
    naming_rules: HashMap<String, NamingRule>,
    language_templates: HashMap<String, LanguageTemplate>,
}

/// Naming rule for different code elements
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NamingRule {
    pub pattern: String,
    pub description: String,
    pub examples: Vec<String>,
}

/// Language-specific template for pseudocode generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageTemplate {
    pub function_template: String,
    pub module_template: String,
    pub variable_template: String,
    pub comment_style: String,
}

/// Pseudocode element types
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PseudocodeType {
    Function,
    Module,
    Variable,
    Class,
    Interface,
    Enum,
    Struct,
}

/// Base pseudocode element
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PseudocodeElement {
    pub name: String,
    pub element_type: PseudocodeType,
    pub description: String,
    pub parameters: Vec<PseudocodeVariable>,
    pub return_type: Option<String>,
    pub body: Vec<String>,
    pub documentation: String,
}

/// Pseudocode function
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PseudocodeFunction {
    pub name: String,
    pub description: String,
    pub parameters: Vec<PseudocodeVariable>,
    pub return_type: Option<String>,
    pub body: Vec<String>,
    pub documentation: String,
    pub complexity: ComplexityLevel,
}

/// Pseudocode module
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PseudocodeModule {
    pub name: String,
    pub description: String,
    pub functions: Vec<PseudocodeFunction>,
    pub variables: Vec<PseudocodeVariable>,
    pub documentation: String,
    pub dependencies: Vec<String>,
}

/// Pseudocode variable
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PseudocodeVariable {
    pub name: String,
    pub variable_type: String,
    pub description: String,
    pub initial_value: Option<String>,
    pub scope: VariableScope,
}

/// Variable scope
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum VariableScope {
    Global,
    Module,
    Function,
    Block,
}

/// Complexity level
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ComplexityLevel {
    Simple,
    Medium,
    Complex,
    VeryComplex,
}

impl PseudocodeGenerator {
    /// Create a new pseudocode generator
    pub fn new() -> Self {
        let mut generator = Self {
            naming_rules: HashMap::new(),
            language_templates: HashMap::new(),
        };
        
        generator.initialize_naming_rules();
        generator.initialize_language_templates();
        
        generator
    }
    
    /// Initialize naming rules for different code elements
    fn initialize_naming_rules(&mut self) {
        // Function naming rules
        self.naming_rules.insert("function".to_string(), NamingRule {
            pattern: r"^[a-z][a-zA-Z0-9]*$".to_string(),
            description: "Functions should use camelCase".to_string(),
            examples: vec!["calculateTotal".to_string(), "processUserData".to_string()],
        });
        
        // Module naming rules
        self.naming_rules.insert("module".to_string(), NamingRule {
            pattern: r"^[A-Z][a-zA-Z0-9]*$".to_string(),
            description: "Modules should use PascalCase".to_string(),
            examples: vec!["UserManager".to_string(), "DataProcessor".to_string()],
        });
        
        // Variable naming rules
        self.naming_rules.insert("variable".to_string(), NamingRule {
            pattern: r"^[a-z][a-zA-Z0-9]*$".to_string(),
            description: "Variables should use camelCase".to_string(),
            examples: vec!["userCount".to_string(), "isValid".to_string()],
        });
    }
    
    /// Initialize language templates
    fn initialize_language_templates(&mut self) {
        // Elixir template
        self.language_templates.insert("elixir".to_string(), LanguageTemplate {
            function_template: "def {name}({parameters}) do\n  {body}\nend".to_string(),
            module_template: "defmodule {name} do\n  {content}\nend".to_string(),
            variable_template: "{name} = {value}".to_string(),
            comment_style: "#".to_string(),
        });
        
        // Rust template
        self.language_templates.insert("rust".to_string(), LanguageTemplate {
            function_template: "fn {name}({parameters}) -> {return_type} {{\n  {body}\n}}".to_string(),
            module_template: "mod {name} {{\n  {content}\n}}".to_string(),
            variable_template: "let {name} = {value};".to_string(),
            comment_style: "//".to_string(),
        });
    }
    
    /// Generate pseudocode for a function
    pub fn generate_function_pseudocode(
        &self,
        name: &str,
        description: &str,
        parameters: Vec<PseudocodeVariable>,
        return_type: Option<String>,
        body: Vec<String>,
        language: &str,
    ) -> Result<PseudocodeFunction, String> {
        // Note: Naming validation is now handled by Detection Engine
        // The name should already be validated before calling this method
        
        // Generate documentation
        let documentation = self.generate_function_documentation(name, description, &parameters, &return_type);
        
        // Determine complexity
        let complexity = self.determine_complexity(&body);
        
        Ok(PseudocodeFunction {
            name: name.to_string(),
            description: description.to_string(),
            parameters,
            return_type,
            body,
            documentation,
            complexity,
        })
    }
    
    /// Generate pseudocode for a module
    pub fn generate_module_pseudocode(
        &self,
        name: &str,
        description: &str,
        functions: Vec<PseudocodeFunction>,
        variables: Vec<PseudocodeVariable>,
        language: &str,
    ) -> Result<PseudocodeModule, String> {
        // Validate naming convention
        if let Some(rule) = self.naming_rules.get("module") {
            if !self.validate_naming(name, rule) {
                return Err(format!("Module name '{}' doesn't follow naming convention: {}", name, rule.description));
            }
        }
        
        // Generate documentation
        let documentation = self.generate_module_documentation(name, description, &functions);
        
        // Extract dependencies
        let dependencies = self.extract_dependencies(&functions);
        
        Ok(PseudocodeModule {
            name: name.to_string(),
            description: description.to_string(),
            functions,
            variables,
            documentation,
            dependencies,
        })
    }
    
    /// Convert pseudocode to clean code
    pub fn convert_to_clean_code(
        &self,
        pseudocode: &PseudocodeFunction,
        language: &str,
    ) -> Result<String, String> {
        let template = self.language_templates.get(language)
            .ok_or_else(|| format!("Language '{}' not supported", language))?;
        
        let parameters = pseudocode.parameters.iter()
            .map(|p| format!("{}: {}", p.name, p.variable_type))
            .collect::<Vec<_>>()
            .join(", ");
        
        let body = pseudocode.body.join("\n  ");
        
        let code = template.function_template
            .replace("{name}", &pseudocode.name)
            .replace("{parameters}", &parameters)
            .replace("{body}", &body)
            .replace("{return_type}", &pseudocode.return_type.as_deref().unwrap_or("()"));
        
        Ok(code)
    }
    
    /// Validate naming convention
    fn validate_naming(&self, name: &str, rule: &NamingRule) -> bool {
        use regex::Regex;
        let re = Regex::new(&rule.pattern).unwrap();
        re.is_match(name)
    }
    
    /// Generate function documentation
    fn generate_function_documentation(
        &self,
        name: &str,
        description: &str,
        parameters: &[PseudocodeVariable],
        return_type: &Option<String>,
    ) -> String {
        let mut doc = format!("/// {}\n", description);
        doc.push_str("///\n");
        
        for param in parameters {
            doc.push_str(&format!("/// * `{}` - {}\n", param.name, param.description));
        }
        
        if let Some(return_type) = return_type {
            doc.push_str(&format!("///\n/// Returns: {}\n", return_type));
        }
        
        doc
    }
    
    /// Generate module documentation
    fn generate_module_documentation(
        &self,
        name: &str,
        description: &str,
        functions: &[PseudocodeFunction],
    ) -> String {
        let mut doc = format!("/// {}\n", description);
        doc.push_str("///\n");
        doc.push_str("/// ## Functions\n");
        doc.push_str("///\n");
        
        for func in functions {
            doc.push_str(&format!("/// * `{}` - {}\n", func.name, func.description));
        }
        
        doc
    }
    
    /// Determine complexity level
    fn determine_complexity(&self, body: &[String]) -> ComplexityLevel {
        let line_count = body.len();
        let has_loops = body.iter().any(|line| line.contains("for") || line.contains("while"));
        let has_conditionals = body.iter().any(|line| line.contains("if") || line.contains("match"));
        
        match (line_count, has_loops, has_conditionals) {
            (0..=5, false, false) => ComplexityLevel::Simple,
            (6..=15, false, true) => ComplexityLevel::Medium,
            (16..=30, true, true) => ComplexityLevel::Complex,
            _ => ComplexityLevel::VeryComplex,
        }
    }
    
    /// Extract dependencies from functions
    fn extract_dependencies(&self, functions: &[PseudocodeFunction]) -> Vec<String> {
        let mut deps = Vec::new();
        
        for func in functions {
            for line in &func.body {
                // Simple dependency extraction (can be enhanced)
                if line.contains("use ") {
                    deps.push(line.trim().to_string());
                }
            }
        }
        
        deps.sort();
        deps.dedup();
        deps
    }
}

impl Default for PseudocodeGenerator {
    fn default() -> Self {
        Self::new()
    }
}

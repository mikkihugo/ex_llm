//! Code Generator - Convert pseudocode to clean code
//!
//! This module converts pseudocode to clean, production-ready code
//! with proper formatting, error handling, and documentation.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Main code generator
#[derive(Debug, Clone)]
pub struct CodeGenerator {
    language_formatters: HashMap<String, LanguageFormatter>,
    error_handlers: HashMap<String, ErrorHandler>,
}

/// Language-specific formatter
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LanguageFormatter {
    pub indent_style: String,
    pub line_ending: String,
    pub max_line_length: usize,
    pub comment_style: String,
}

/// Error handler for different languages
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ErrorHandler {
    pub error_type: String,
    pub error_handling_pattern: String,
    pub logging_pattern: String,
}

/// Generated code element
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeElement {
    pub name: String,
    pub code: String,
    pub documentation: String,
    pub error_handling: Option<String>,
    pub tests: Option<String>,
}

/// Generated function
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeFunction {
    pub name: String,
    pub code: String,
    pub documentation: String,
    pub error_handling: String,
    pub tests: String,
    pub complexity: String,
}

/// Generated module
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeModule {
    pub name: String,
    pub code: String,
    pub documentation: String,
    pub functions: Vec<CodeFunction>,
    pub dependencies: Vec<String>,
}

/// Generated variable
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeVariable {
    pub name: String,
    pub declaration: String,
    pub documentation: String,
    pub scope: String,
}

impl CodeGenerator {
    /// Create a new code generator
    pub fn new() -> Self {
        let mut generator = Self {
            language_formatters: HashMap::new(),
            error_handlers: HashMap::new(),
        };
        
        generator.initialize_formatters();
        generator.initialize_error_handlers();
        
        generator
    }
    
    /// Initialize language formatters
    fn initialize_formatters(&mut self) {
        // Elixir formatter
        self.language_formatters.insert("elixir".to_string(), LanguageFormatter {
            indent_style: "  ".to_string(),
            line_ending: "\n".to_string(),
            max_line_length: 80,
            comment_style: "#".to_string(),
        });
        
        // Rust formatter
        self.language_formatters.insert("rust".to_string(), LanguageFormatter {
            indent_style: "  ".to_string(),
            line_ending: "\n".to_string(),
            max_line_length: 100,
            comment_style: "//".to_string(),
        });
    }
    
    /// Initialize error handlers
    fn initialize_error_handlers(&mut self) {
        // Elixir error handling
        self.error_handlers.insert("elixir".to_string(), ErrorHandler {
            error_type: "Result".to_string(),
            error_handling_pattern: "case result do\n  {:ok, value} -> value\n  {:error, reason} -> {:error, reason}\nend".to_string(),
            logging_pattern: "Logger.error(\"Error: #{inspect(reason)}\")".to_string(),
        });
        
        // Rust error handling
        self.error_handlers.insert("rust".to_string(), ErrorHandler {
            error_type: "Result".to_string(),
            error_handling_pattern: "match result {\n  Ok(value) => value,\n  Err(e) => return Err(e),\n}".to_string(),
            logging_pattern: "eprintln!(\"Error: {}\", e)".to_string(),
        });
    }
    
    /// Generate clean code from pseudocode
    pub fn generate_clean_code(
        &self,
        pseudocode: &crate::pseudocode_generator::PseudocodeFunction,
        language: &str,
    ) -> Result<CodeFunction, String> {
        let formatter = self.language_formatters.get(language)
            .ok_or_else(|| format!("Language '{}' not supported", language))?;
        
        let error_handler = self.error_handlers.get(language)
            .ok_or_else(|| format!("Error handling for '{}' not supported", language))?;
        
        // Generate the main code
        let code = self.format_code(pseudocode, formatter)?;
        
        // Generate error handling
        let error_handling = self.generate_error_handling(pseudocode, error_handler)?;
        
        // Generate tests
        let tests = self.generate_tests(pseudocode, language)?;
        
        // Generate documentation
        let documentation = self.generate_documentation(pseudocode, language)?;
        
        Ok(CodeFunction {
            name: pseudocode.name.clone(),
            code,
            documentation,
            error_handling,
            tests,
            complexity: format!("{:?}", pseudocode.complexity),
        })
    }
    
    /// Format code according to language standards
    fn format_code(
        &self,
        pseudocode: &crate::pseudocode_generator::PseudocodeFunction,
        formatter: &LanguageFormatter,
    ) -> Result<String, String> {
        let mut code = String::new();
        
        // Add function signature
        let parameters = pseudocode.parameters.iter()
            .map(|p| format!("{}: {}", p.name, p.variable_type))
            .collect::<Vec<_>>()
            .join(", ");
        
        let return_type = pseudocode.return_type.as_deref().unwrap_or("()");
        
        // Format function body
        let body = pseudocode.body.iter()
            .map(|line| format!("{}{}", formatter.indent_style, line))
            .collect::<Vec<_>>()
            .join(&formatter.line_ending);
        
        // Build complete function
        code.push_str(&format!("fn {}({}) -> {} {{\n", pseudocode.name, parameters, return_type));
        code.push_str(&body);
        code.push_str(&format!("\n}}"));
        
        Ok(code)
    }
    
    /// Generate error handling code
    fn generate_error_handling(
        &self,
        pseudocode: &crate::pseudocode_generator::PseudocodeFunction,
        error_handler: &ErrorHandler,
    ) -> Result<String, String> {
        let mut error_code = String::new();
        
        // Add error handling wrapper
        error_code.push_str(&format!("// Error handling for {}\n", pseudocode.name));
        error_code.push_str(&error_handler.error_handling_pattern);
        error_code.push_str("\n");
        error_code.push_str(&error_handler.logging_pattern);
        
        Ok(error_code)
    }
    
    /// Generate tests for the function
    fn generate_tests(
        &self,
        pseudocode: &crate::pseudocode_generator::PseudocodeFunction,
        language: &str,
    ) -> Result<String, String> {
        let mut tests = String::new();
        
        tests.push_str(&format!("// Tests for {}\n", pseudocode.name));
        tests.push_str("#[cfg(test)]\n");
        tests.push_str("mod tests {\n");
        tests.push_str("    use super::*;\n\n");
        
        // Generate basic test
        tests.push_str(&format!("    #[test]\n"));
        tests.push_str(&format!("    fn test_{}() {{\n", pseudocode.name));
        tests.push_str(&format!("        // Test basic functionality\n"));
        tests.push_str(&format!("        // TODO: Add test cases\n"));
        tests.push_str(&format!("    }}\n"));
        
        tests.push_str("}\n");
        
        Ok(tests)
    }
    
    /// Generate comprehensive documentation
    fn generate_documentation(
        &self,
        pseudocode: &crate::pseudocode_generator::PseudocodeFunction,
        language: &str,
    ) -> Result<String, String> {
        let mut doc = String::new();
        
        // Add function documentation
        doc.push_str(&pseudocode.documentation);
        doc.push_str("\n");
        
        // Add usage examples
        doc.push_str("/// ## Examples\n");
        doc.push_str("///\n");
        doc.push_str(&format!("/// ```{}\n", language));
        doc.push_str(&format!("/// let result = {}(...);\n", pseudocode.name));
        doc.push_str("/// ```\n");
        
        // Add complexity information
        doc.push_str(&format!("/// ## Complexity: {:?}\n", pseudocode.complexity));
        
        Ok(doc)
    }
}

impl Default for CodeGenerator {
    fn default() -> Self {
        Self::new()
    }
}

//! Framework Detection Module
//! 
//! Handles framework detection and technology stack analysis.
//! Pure analysis - no I/O operations.

use crate::types::*;
use anyhow::Result;
use std::path::Path;

/// Framework detector for technology stack analysis
#[derive(Debug, Clone)]
pub struct FrameworkDetector;

impl FrameworkDetector {
    /// Create a new framework detector
    pub fn new() -> Result<Self> {
        Ok(Self)
    }

    /// Detect frameworks (stub - returns empty)
    pub fn detect_frameworks(&self, _path: &Path) -> Result<Vec<String>> {
        Ok(Vec::new())
    }

    /// Detect programming language from file extension
    fn detect_language_from_extension(
        &self,
        file_path: &Path,
    ) -> universal_parser::ProgrammingLanguage {
        use universal_parser::ProgrammingLanguage;

        if let Some(extension) = file_path.extension().and_then(|ext| ext.to_str()) {
            match extension.to_lowercase().as_str() {
                "rs" => ProgrammingLanguage::Rust,
                "py" | "pyi" | "pyc" => ProgrammingLanguage::Python,
                "js" | "mjs" => ProgrammingLanguage::JavaScript,
                "ts" | "tsx" => ProgrammingLanguage::TypeScript,
                "go" => ProgrammingLanguage::Go,
                "java" => ProgrammingLanguage::Java,
                "cs" => ProgrammingLanguage::CSharp,
                "c" | "h" => ProgrammingLanguage::C,
                "cpp" | "cc" | "cxx" | "hpp" | "hxx" => ProgrammingLanguage::Cpp,
                "erl" | "hrl" => ProgrammingLanguage::Erlang,
                "ex" | "exs" => ProgrammingLanguage::Elixir,
                "gleam" => ProgrammingLanguage::Gleam,
                _ => ProgrammingLanguage::Unknown,
            }
        } else {
            ProgrammingLanguage::Unknown
        }
    }

    /// Analyze technology stack from language distribution
    fn analyze_technology_stack(
        &self,
        language_groups: &std::collections::HashMap<
            universal_parser::ProgrammingLanguage,
            Vec<&ParsedFile>,
        >,
    ) -> TechnologyStack {
        let mut stack = TechnologyStack::default();

        for (language, files) in language_groups {
            let file_count = files.len();
            let total_lines: usize = files.iter().map(|f| f.metrics.lines_of_code).sum();

            match language {
                universal_parser::ProgrammingLanguage::Rust => {
                    stack.backend_languages.push("Rust".to_string());
                    stack.performance_focused = true;
                }
                universal_parser::ProgrammingLanguage::Python => {
                    stack.backend_languages.push("Python".to_string());
                    stack.data_science_focused = true;
                }
                universal_parser::ProgrammingLanguage::JavaScript => {
                    stack.frontend_languages.push("JavaScript".to_string());
                    stack.web_focused = true;
                }
                universal_parser::ProgrammingLanguage::TypeScript => {
                    stack.frontend_languages.push("TypeScript".to_string());
                    stack.type_safety_focused = true;
                }
                universal_parser::ProgrammingLanguage::Go => {
                    stack.backend_languages.push("Go".to_string());
                    stack.concurrency_focused = true;
                }
                universal_parser::ProgrammingLanguage::Java => {
                    stack.backend_languages.push("Java".to_string());
                    stack.enterprise_focused = true;
                }
                universal_parser::ProgrammingLanguage::CSharp => {
                    stack.backend_languages.push("C#".to_string());
                    stack.microsoft_ecosystem = true;
                }
                universal_parser::ProgrammingLanguage::C
                | universal_parser::ProgrammingLanguage::Cpp => {
                    stack.system_languages.push("C/C++".to_string());
                    stack.low_level_focused = true;
                }
                universal_parser::ProgrammingLanguage::Erlang
                | universal_parser::ProgrammingLanguage::Elixir => {
                    stack.backend_languages.push(format!("{:?}", language));
                    stack.fault_tolerance_focused = true;
                }
                universal_parser::ProgrammingLanguage::Gleam => {
                    stack.backend_languages.push("Gleam".to_string());
                    stack.functional_focused = true;
                }
                _ => {}
            }

            // Determine primary language
            if file_count > stack.primary_language_file_count {
                stack.primary_language = format!("{:?}", language);
                stack.primary_language_file_count = file_count;
                stack.primary_language_lines = total_lines;
            }
        }

        stack
    }
}

impl Default for FrameworkDetector {
    fn default() -> Self {
        Self::new().unwrap_or_else(|_| panic!("Failed to initialize FrameworkDetector"))
    }
}
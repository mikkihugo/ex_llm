//! Code Snippet Extractor - Delegates to source code parser
//!
//! This module provides a bridge between package_registry_indexer and
//! source code parser for extracting code snippets from downloaded packages.
//!
//! Architecture:
//! 1. package_registry_indexer downloads tarball (npm, cargo, etc.)
//! 2. Extractor calls source code parser to parse with tree-sitter
//! 3. Converts source code parser results to CodeSnippet format
//! 4. Returns snippets for storage

use crate::storage::{CodeSnippet, PackageExample};
use crate::package_file_watcher::ProgrammingLanguage;
use anyhow::Result;
use std::path::Path;
use parser_code::{UniversalDependencies, ProgrammingLanguage as PolyglotLanguage, AnalysisResult};

/// Code extractor that uses polyglot parser for comprehensive analysis
pub struct SourceCodeExtractor {
    parser: UniversalDependencies,
}

impl SourceCodeExtractor {
    /// Create new extractor
    pub fn new() -> Result<Self> {
        Ok(Self {
            parser: UniversalDependencies::new()?,
        })
    }

    /// Extract code snippets from a source file using polyglot parser
    ///
    /// Process:
    /// 1. Use polyglot parser for comprehensive AST analysis
    /// 2. Extract public exports (functions, classes, etc.) from AST
    /// 3. Convert to CodeSnippet format
    pub async fn extract_snippets(
        &self,
        file_path: &Path,
        source: &str,
    ) -> Result<Vec<CodeSnippet>> {
        // Convert file path to string for polyglot parser
        let file_path_str = file_path.to_string_lossy().to_string();
        
        // Detect language from file extension
        let lang = detect_language(file_path)?;
        let polyglot_lang = self.convert_to_polyglot_language(&lang)?;

        // Use polyglot parser for comprehensive analysis
        let analysis_result = self.parser
            .analyze_with_all_tools(source, polyglot_lang, &file_path_str)
            .await?;

        // Extract code snippets from analysis result
        let mut snippets = Vec::new();
        
        // Extract from tree-sitter analysis if available
        if let Some(tree_sitter) = &analysis_result.tree_sitter_analysis {
            snippets.extend(self.extract_snippets_from_tree_sitter(tree_sitter, file_path, source)?);
        }
        
        // Extract from dependency analysis if available
        if let Some(deps) = &analysis_result.dependency_analysis {
            snippets.extend(self.extract_snippets_from_dependencies(deps, file_path, source)?);
        }
        
        // If no snippets found from AST analysis, fall back to basic parsing
        if snippets.is_empty() {
            snippets.extend(self.extract_snippets_basic(file_path, source, &lang)?);
        }

        Ok(snippets)
    }
    
    /// Convert internal ProgrammingLanguage to polyglot ProgrammingLanguage
    fn convert_to_polyglot_language(&self, lang: &ProgrammingLanguage) -> Result<PolyglotLanguage> {
        match lang {
            ProgrammingLanguage::Rust => Ok(PolyglotLanguage::Rust),
            ProgrammingLanguage::TypeScript => Ok(PolyglotLanguage::TypeScript),
            ProgrammingLanguage::JavaScript => Ok(PolyglotLanguage::JavaScript),
            ProgrammingLanguage::Python => Ok(PolyglotLanguage::Python),
            ProgrammingLanguage::Go => Ok(PolyglotLanguage::Go),
            ProgrammingLanguage::Elixir => Ok(PolyglotLanguage::Elixir),
            _ => anyhow::bail!("Unsupported language: {:?}", lang),
        }
    }
    
    /// Extract snippets from tree-sitter analysis
    fn extract_snippets_from_tree_sitter(
        &self,
        tree_sitter: &parser_code::TreeSitterAnalysis,
        file_path: &Path,
        source: &str,
    ) -> Result<Vec<CodeSnippet>> {
        let mut snippets = Vec::new();
        
        // Extract functions, classes, and other symbols from AST
        if let Some(symbols) = &tree_sitter.symbols {
            for symbol in symbols {
                if symbol.is_public || symbol.is_exported {
                    let code = if let Some(range) = &symbol.range {
                        source.chars()
                            .skip(range.start)
                            .take(range.end - range.start)
                            .collect::<String>()
                    } else {
                        symbol.name.clone()
                    };
                    
                    snippets.push(CodeSnippet {
                        title: symbol.name.clone(),
                        code,
                        language: self.get_language_string(file_path),
                        description: symbol.documentation.clone().unwrap_or_default(),
                        file_path: file_path.to_string_lossy().to_string(),
                        line_number: symbol.line_number.unwrap_or(0) as u32,
                    });
                }
            }
        }
        
        Ok(snippets)
    }
    
    /// Extract snippets from dependency analysis
    fn extract_snippets_from_dependencies(
        &self,
        deps: &parser_code::DependencyAnalysis,
        file_path: &Path,
        source: &str,
    ) -> Result<Vec<CodeSnippet>> {
        let mut snippets = Vec::new();
        
        // Extract exported functions and classes from dependencies
        if let Some(exports) = &deps.exports {
            for export in exports {
                snippets.push(CodeSnippet {
                    title: export.name.clone(),
                    code: export.signature.clone().unwrap_or_else(|| export.name.clone()),
                    language: self.get_language_string(file_path),
                    description: export.description.clone().unwrap_or_default(),
                    file_path: file_path.to_string_lossy().to_string(),
                    line_number: export.line_number.unwrap_or(0) as u32,
                });
            }
        }
        
        Ok(snippets)
    }
    
    /// Fallback to basic parsing if AST analysis fails
    fn extract_snippets_basic(
        &self,
        file_path: &Path,
        source: &str,
        lang: &ProgrammingLanguage,
    ) -> Result<Vec<CodeSnippet>> {
        let mut snippets = Vec::new();
        let lines: Vec<&str> = source.lines().collect();
        
        for (line_num, line) in lines.iter().enumerate() {
            let line = line.trim();
            
            // Extract functions, classes, and other public symbols based on language
            match lang {
                ProgrammingLanguage::Rust => {
                    if let Some(snippet) = self.extract_rust_symbol(line, &lines, line_num, file_path) {
                        snippets.push(snippet);
                    }
                }
                ProgrammingLanguage::TypeScript | ProgrammingLanguage::JavaScript => {
                    if let Some(snippet) = self.extract_js_symbol(line, &lines, line_num, file_path) {
                        snippets.push(snippet);
                    }
                }
                ProgrammingLanguage::Python => {
                    if let Some(snippet) = self.extract_python_symbol(line, &lines, line_num, file_path) {
                        snippets.push(snippet);
                    }
                }
                ProgrammingLanguage::Go => {
                    if let Some(snippet) = self.extract_go_symbol(line, &lines, line_num, file_path) {
                        snippets.push(snippet);
                    }
                }
                ProgrammingLanguage::Elixir => {
                    if let Some(snippet) = self.extract_elixir_symbol(line, &lines, line_num, file_path) {
                        snippets.push(snippet);
                    }
                }
            }
        }

        Ok(snippets)
    }
    
    /// Get language string from file path
    fn get_language_string(&self, file_path: &Path) -> String {
        match file_path.extension().and_then(|e| e.to_str()) {
            Some("rs") => "rust".to_string(),
            Some("ts") | Some("tsx") => "typescript".to_string(),
            Some("js") | Some("jsx") => "javascript".to_string(),
            Some("py") => "python".to_string(),
            Some("go") => "go".to_string(),
            Some("ex") | Some("exs") => "elixir".to_string(),
            _ => "unknown".to_string(),
        }
    }
    
    /// Extract Rust symbols (functions, structs, impl blocks)
    fn extract_rust_symbol(&self, line: &str, lines: &[&str], line_num: usize, file_path: &Path) -> Option<CodeSnippet> {
        // Public functions
        if line.starts_with("pub fn ") {
            let name = self.extract_function_name(line, "pub fn ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_function_body(lines, line_num),
                language: "rust".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Public structs
        if line.starts_with("pub struct ") {
            let name = self.extract_struct_name(line, "pub struct ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_struct_body(lines, line_num),
                language: "rust".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Public impl blocks
        if line.starts_with("impl ") && line.contains(" for ") {
            let name = self.extract_impl_name(line);
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_impl_body(lines, line_num),
                language: "rust".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        None
    }
    
    /// Extract JavaScript/TypeScript symbols
    fn extract_js_symbol(&self, line: &str, lines: &[&str], line_num: usize, file_path: &Path) -> Option<CodeSnippet> {
        // Exported functions
        if line.starts_with("export function ") || line.starts_with("export const ") {
            let name = if line.starts_with("export function ") {
                self.extract_function_name(line, "export function ")
            } else {
                self.extract_function_name(line, "export const ")
            };
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_function_body(lines, line_num),
                language: "javascript".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Exported classes
        if line.starts_with("export class ") {
            let name = self.extract_class_name(line, "export class ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_class_body(lines, line_num),
                language: "javascript".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        None
    }
    
    /// Extract Python symbols
    fn extract_python_symbol(&self, line: &str, lines: &[&str], line_num: usize, file_path: &Path) -> Option<CodeSnippet> {
        // Public functions
        if line.starts_with("def ") {
            let name = self.extract_function_name(line, "def ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_function_body(lines, line_num),
                language: "python".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Public classes
        if line.starts_with("class ") {
            let name = self.extract_class_name(line, "class ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_class_body(lines, line_num),
                language: "python".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        None
    }
    
    /// Extract Go symbols
    fn extract_go_symbol(&self, line: &str, lines: &[&str], line_num: usize, file_path: &Path) -> Option<CodeSnippet> {
        // Public functions
        if line.starts_with("func ") && line.contains("(") {
            let name = self.extract_function_name(line, "func ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_function_body(lines, line_num),
                language: "go".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Public types
        if line.starts_with("type ") {
            let name = self.extract_type_name(line, "type ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_type_body(lines, line_num),
                language: "go".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        None
    }
    
    /// Extract Elixir symbols
    fn extract_elixir_symbol(&self, line: &str, lines: &[&str], line_num: usize, file_path: &Path) -> Option<CodeSnippet> {
        // Public functions
        if line.starts_with("def ") {
            let name = self.extract_function_name(line, "def ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_function_body(lines, line_num),
                language: "elixir".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        // Public modules
        if line.starts_with("defmodule ") {
            let name = self.extract_module_name(line, "defmodule ");
            return Some(CodeSnippet {
                title: name.clone(),
                code: self.extract_module_body(lines, line_num),
                language: "elixir".to_string(),
                description: self.extract_doc_comment(lines, line_num),
                file_path: file_path.to_string_lossy().to_string(),
                line_number: (line_num + 1) as u32,
            });
        }
        
        None
    }
    
    /// Extract function name from line
    fn extract_function_name(&self, line: &str, prefix: &str) -> String {
        line.strip_prefix(prefix)
            .and_then(|s| s.split_whitespace().next())
            .and_then(|s| s.split('(').next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract struct name from line
    fn extract_struct_name(&self, line: &str, prefix: &str) -> String {
        line.strip_prefix(prefix)
            .and_then(|s| s.split_whitespace().next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract class name from line
    fn extract_class_name(&self, line: &str, prefix: &str) -> String {
        line.strip_prefix(prefix)
            .and_then(|s| s.split_whitespace().next())
            .and_then(|s| s.split('(').next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract impl name from line
    fn extract_impl_name(&self, line: &str) -> String {
        line.strip_prefix("impl ")
            .and_then(|s| s.split(" for ").next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract type name from line
    fn extract_type_name(&self, line: &str, prefix: &str) -> String {
        line.strip_prefix(prefix)
            .and_then(|s| s.split_whitespace().next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract module name from line
    fn extract_module_name(&self, line: &str, prefix: &str) -> String {
        line.strip_prefix(prefix)
            .and_then(|s| s.split_whitespace().next())
            .unwrap_or("unknown")
            .to_string()
    }
    
    /// Extract function body
    fn extract_function_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_function = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("fn ") || line.contains("def ") || line.contains("function ") || line.contains("func ") {
                in_function = true;
            }
            
            if in_function {
                body.push(line);
                
                // Count braces to detect function end
                for ch in line.chars() {
                    match ch {
                        '{' | '(' => brace_count += 1,
                        '}' | ')' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Function ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract struct body
    fn extract_struct_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_struct = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("struct ") {
                in_struct = true;
            }
            
            if in_struct {
                body.push(line);
                
                // Count braces to detect struct end
                for ch in line.chars() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Struct ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract class body
    fn extract_class_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_class = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("class ") {
                in_class = true;
            }
            
            if in_class {
                body.push(line);
                
                // Count braces to detect class end
                for ch in line.chars() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Class ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract impl body
    fn extract_impl_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_impl = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("impl ") {
                in_impl = true;
            }
            
            if in_impl {
                body.push(line);
                
                // Count braces to detect impl end
                for ch in line.chars() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Impl ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract type body
    fn extract_type_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_type = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("type ") {
                in_type = true;
            }
            
            if in_type {
                body.push(line);
                
                // Count braces to detect type end
                for ch in line.chars() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Type ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract module body
    fn extract_module_body(&self, lines: &[&str], start_line: usize) -> String {
        let mut body = Vec::new();
        let mut brace_count = 0;
        let mut in_module = false;
        
        for (i, line) in lines.iter().enumerate().skip(start_line) {
            let line = line.trim();
            
            if line.contains("defmodule ") {
                in_module = true;
            }
            
            if in_module {
                body.push(line);
                
                // Count braces to detect module end
                for ch in line.chars() {
                    match ch {
                        '{' => brace_count += 1,
                        '}' => brace_count -= 1,
                        _ => {}
                    }
                }
                
                // Module ended
                if brace_count == 0 && body.len() > 1 {
                    break;
                }
            }
        }
        
        body.join("\n")
    }
    
    /// Extract doc comment from lines before the symbol
    fn extract_doc_comment(&self, lines: &[&str], line_num: usize) -> String {
        let mut doc_lines = Vec::new();
        
        // Look backwards for doc comments
        for i in (0..line_num).rev() {
            let line = lines[i].trim();
            
            if line.starts_with("///") || line.starts_with("#") || line.starts_with("//") {
                doc_lines.insert(0, line.strip_prefix("///").or(line.strip_prefix("#")).or(line.strip_prefix("//")).unwrap_or(line));
            } else if line.is_empty() {
                continue;
            } else {
                break;
            }
        }
        
        doc_lines.join(" ").trim().to_string()
    }

    /// Extract usage examples from documentation files
    pub async fn extract_examples(
        &self,
        doc_file: &Path,
        content: &str,
    ) -> Result<Vec<PackageExample>> {
        let mut examples = Vec::new();
        
        // Extract code blocks from markdown/docs
        let lines: Vec<&str> = content.lines().collect();
        let mut in_code_block = false;
        let mut code_block_language = String::new();
        let mut code_block_content = Vec::new();
        
        for (line_num, line) in lines.iter().enumerate() {
            let line = line.trim();
            
            // Check for code block start
            if line.starts_with("```") {
                if in_code_block {
                    // End of code block - process accumulated content
                    if !code_block_content.is_empty() {
                        let code = code_block_content.join("\n");
                        let language = if code_block_language.is_empty() {
                            "unknown".to_string()
                        } else {
                            code_block_language.clone()
                        };
                        
                        examples.push(PackageExample {
                            title: format!("Example from line {}", line_num + 1),
                            code,
                            language,
                            description: "Extracted from documentation".to_string(),
                            file_path: doc_file.to_string_lossy().to_string(),
                            line_number: (line_num + 1) as u32,
                        });
                    }
                    
                    // Reset for next code block
                    in_code_block = false;
                    code_block_language.clear();
                    code_block_content.clear();
                } else {
                    // Start of code block
                    in_code_block = true;
                    code_block_language = line.strip_prefix("```").unwrap_or("").to_string();
                }
            } else if in_code_block {
                // Inside code block - accumulate content
                code_block_content.push(line);
            }
        }
        
        // Process any remaining code block
        if in_code_block && !code_block_content.is_empty() {
            let code = code_block_content.join("\n");
            let language = if code_block_language.is_empty() {
                "unknown".to_string()
            } else {
                code_block_language.clone()
            };
            
            examples.push(PackageExample {
                title: "Example from documentation".to_string(),
                code,
                language,
                description: "Extracted from documentation".to_string(),
                file_path: doc_file.to_string_lossy().to_string(),
                line_number: 0,
            });
        }
        
        Ok(examples)
    }

    /// Extract snippets from entire directory (package)
    pub async fn extract_from_directory(
        &self,
        dir: &Path,
    ) -> Result<ExtractedCode> {
        use std::fs;
        use walkdir::WalkDir;

        let mut extracted = ExtractedCode::default();

        // Walk directory and parse source files
        for entry in WalkDir::new(dir)
            .follow_links(false)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let path = entry.path();

            // Skip if not a source file
            if detect_language(path).is_err() {
                continue;
            }

            // Read and parse
            if let Ok(content) = fs::read_to_string(path) {
                if let Ok(snippets) = self.extract_snippets(path, &content).await {
                    extracted.snippets.extend(snippets);
                }
            }
        }

        Ok(extracted)
    }
}

/// Detect programming language from file extension
fn detect_language(path: &Path) -> Result<ProgrammingLanguage> {
    match path.extension().and_then(|e| e.to_str()) {
        Some("rs") => Ok(ProgrammingLanguage::Rust),
        Some("ts") | Some("tsx") => Ok(ProgrammingLanguage::TypeScript),
        Some("js") | Some("jsx") => Ok(ProgrammingLanguage::JavaScript),
        Some("py") => Ok(ProgrammingLanguage::Python),
        Some("go") => Ok(ProgrammingLanguage::Go),
        Some("ex") | Some("exs") => Ok(ProgrammingLanguage::Elixir),
        _ => anyhow::bail!("Unsupported language"),
    }
}

/// Extracted code data from a package
#[derive(Debug, Clone, Default)]
pub struct ExtractedCode {
    pub snippets: Vec<CodeSnippet>,
    pub examples: Vec<PackageExample>,
    pub exports: Vec<String>,  // List of exported symbols
}

/// Create extractor (unified interface)
pub fn create_extractor() -> Result<SourceCodeExtractor> {
    SourceCodeExtractor::new()
}

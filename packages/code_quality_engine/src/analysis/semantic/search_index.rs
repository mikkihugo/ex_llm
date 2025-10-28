use serde::{Deserialize, Serialize};

// Import graph types from the graph module
use crate::graph::{CodeGraph, CodeGraphBuilder, GraphType};

/// Placeholder for CodeGraph (kept for backward compatibility but types above are used)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SemanticCodeGraph {
    pub nodes: Vec<String>,
    pub edges: Vec<(String, String)>,
}

/// Placeholder for CodeGraphBuilder
#[derive(Debug, Clone)]
pub struct SemanticCodeGraphBuilder {
    pub working_directory: std::path::PathBuf,
}

impl SemanticCodeGraphBuilder {
    pub fn new(working_directory: std::path::PathBuf) -> Self {
        Self { working_directory }
    }

    pub async fn build_call_graph(
        &self,
        _metadata_cache: &HashMap<std::path::PathBuf, CodeMetadata>,
    ) -> anyhow::Result<SemanticCodeGraph> {
        Ok(SemanticCodeGraph {
            nodes: vec![],
            edges: vec![],
        })
    }

    pub async fn build_import_graph(
        &self,
        _metadata_cache: &HashMap<std::path::PathBuf, CodeMetadata>,
    ) -> anyhow::Result<SemanticCodeGraph> {
        Ok(SemanticCodeGraph {
            nodes: vec![],
            edges: vec![],
        })
    }
}

/// Placeholder for GraphType
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum SemanticGraphType {
    CallGraph,
    ImportGraph,
    DependencyGraph,
}
/// Local Vector Code Index
///
/// Provides semantic code understanding using local text similarity
/// and AST-based pattern recognition without external APIs.
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    time::SystemTime,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeMetadata {
    pub file_path: PathBuf,
    pub file_type: String,
    pub functions: Vec<String>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
    pub classes: Vec<String>,
    pub interfaces: Vec<String>,
    pub patterns: Vec<String>,
    pub keywords: Vec<String>,
    pub last_modified: SystemTime,
    pub size_bytes: u64,
}

#[derive(Debug, Clone)]
pub struct CodeSimilarity {
    pub file_path: PathBuf,
    pub similarity_score: f32,
    pub matching_patterns: Vec<String>,
    pub metadata: CodeMetadata,
}

pub struct CodeIndex {
    metadata_cache: HashMap<PathBuf, CodeMetadata>,
    keyword_index: HashMap<String, Vec<PathBuf>>,
    pattern_index: HashMap<String, Vec<PathBuf>>,
    function_index: HashMap<String, Vec<PathBuf>>,
    working_directory: PathBuf,
}

impl CodeIndex {
    pub fn new(working_directory: PathBuf) -> Self {
        Self {
            metadata_cache: HashMap::new(),
            keyword_index: HashMap::new(),
            pattern_index: HashMap::new(),
            function_index: HashMap::new(),
            working_directory,
        }
    }

    /// Build index by scanning the codebase
    pub async fn build_index(&mut self) -> anyhow::Result<()> {
        println!("🔍 Building local code index...");

        let supported_extensions = vec![
            "ts", "tsx", "js", "jsx", "rs", "py", "go", "java", "cpp", "c", "h", "json", "yaml",
            "yml", "toml", "md", "sql",
        ];

        self.scan_directory(&self.working_directory.clone(), &supported_extensions)
            .await?;
        self.build_indices();

        println!("✅ Indexed {} files", self.metadata_cache.len());
        Ok(())
    }

    async fn scan_directory(&mut self, dir: &Path, extensions: &[&str]) -> anyhow::Result<()> {
        if dir
            .file_name()
            .and_then(|n| n.to_str())
            .map_or(false, |name| {
                name.starts_with('.')
                    || name == "node_modules"
                    || name == "target"
                    || name == "dist"
            })
        {
            return Ok(());
        }

        let mut entries = tokio::fs::read_dir(dir).await?;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();

            if path.is_dir() {
                Box::pin(self.scan_directory(&path, extensions)).await?;
            } else if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
                if extensions.contains(&ext) {
                    if let Ok(metadata) = self.analyze_file(&path).await {
                        self.metadata_cache.insert(path.clone(), metadata);
                    }
                }
            }
        }

        Ok(())
    }

    async fn analyze_file(&self, file_path: &Path) -> anyhow::Result<CodeMetadata> {
        let content = tokio::fs::read_to_string(file_path).await?;
        let metadata = tokio::fs::metadata(file_path).await?;

        let file_type = file_path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("unknown")
            .to_string();

        let mut functions = Vec::new();
        let mut imports = Vec::new();
        let mut exports = Vec::new();
        let mut classes = Vec::new();
        let mut interfaces = Vec::new();
        let mut patterns = Vec::new();
        let mut keywords = Vec::new();

        // Extract patterns based on file type
        match file_type.as_str() {
            "ts" | "tsx" | "js" | "jsx" => {
                self.extract_typescript_patterns(
                    &content,
                    &mut functions,
                    &mut imports,
                    &mut exports,
                    &mut classes,
                    &mut interfaces,
                    &mut patterns,
                );
            }
            "rs" => {
                self.extract_rust_patterns(&content, &mut functions, &mut imports, &mut patterns);
            }
            "py" => {
                self.extract_python_patterns(
                    &content,
                    &mut functions,
                    &mut imports,
                    &mut classes,
                    &mut patterns,
                );
            }
            _ => {
                self.extract_generic_patterns(&content, &mut keywords, &mut patterns);
            }
        }

        Ok(CodeMetadata {
            file_path: file_path.to_path_buf(),
            file_type,
            functions,
            imports,
            exports,
            classes,
            interfaces,
            patterns,
            keywords,
            last_modified: metadata.modified()?,
            size_bytes: metadata.len(),
        })
    }

    fn extract_typescript_patterns(
        &self,
        content: &str,
        functions: &mut Vec<String>,
        imports: &mut Vec<String>,
        exports: &mut Vec<String>,
        classes: &mut Vec<String>,
        interfaces: &mut Vec<String>,
        patterns: &mut Vec<String>,
    ) {
        for line in content.lines() {
            let trimmed = line.trim();

            // Functions
            if let Some(func_name) = self.extract_function_name(trimmed) {
                functions.push(func_name);
            }

            // Imports
            if trimmed.starts_with("import ") {
                imports.push(trimmed.to_string());
            }

            // Exports
            if trimmed.starts_with("export ") {
                exports.push(trimmed.to_string());
            }

            // Classes
            if trimmed.starts_with("class ") {
                if let Some(class_name) = trimmed.split_whitespace().nth(1) {
                    classes.push(class_name.to_string());
                }
            }

            // Interfaces
            if trimmed.starts_with("interface ") {
                if let Some(interface_name) = trimmed.split_whitespace().nth(1) {
                    interfaces.push(interface_name.to_string());
                }
            }

            // Common patterns
            self.detect_common_patterns(trimmed, patterns);
        }
    }

    fn extract_rust_patterns(
        &self,
        content: &str,
        functions: &mut Vec<String>,
        imports: &mut Vec<String>,
        patterns: &mut Vec<String>,
    ) {
        for line in content.lines() {
            let trimmed = line.trim();

            // Functions
            if trimmed.starts_with("fn ") || trimmed.starts_with("pub fn ") {
                if let Some(func_name) = self.extract_rust_function_name(trimmed) {
                    functions.push(func_name);
                }
            }

            // Use statements
            if trimmed.starts_with("use ") {
                imports.push(trimmed.to_string());
            }

            // CodePatterns
            self.detect_rust_patterns(trimmed, patterns);
        }
    }

    fn extract_python_patterns(
        &self,
        content: &str,
        functions: &mut Vec<String>,
        imports: &mut Vec<String>,
        classes: &mut Vec<String>,
        patterns: &mut Vec<String>,
    ) {
        for line in content.lines() {
            let trimmed = line.trim();

            // Functions
            if trimmed.starts_with("def ") {
                if let Some(func_name) = self.extract_python_function_name(trimmed) {
                    functions.push(func_name);
                }
            }

            // Imports
            if trimmed.starts_with("import ") || trimmed.starts_with("from ") {
                imports.push(trimmed.to_string());
            }

            // Classes
            if trimmed.starts_with("class ") {
                if let Some(class_name) = trimmed.split_whitespace().nth(1) {
                    classes.push(class_name.to_string());
                }
            }

            // CodePatterns
            self.detect_python_patterns(trimmed, patterns);
        }
    }

    fn extract_generic_patterns(
        &self,
        content: &str,
        keywords: &mut Vec<String>,
        patterns: &mut Vec<String>,
    ) {
        // Extract common keywords and patterns for generic files
        let common_keywords = [
            "TODO",
            "FIXME",
            "BUG",
            "HACK",
            "NOTE",
            "WARNING",
            "config",
            "setup",
            "init",
            "main",
            "test",
            "spec",
            "auth",
            "user",
            "admin",
            "api",
            "service",
            "controller",
            "model",
            "view",
            "component",
            "util",
            "helper",
        ];

        for line in content.lines() {
            let line_lower = line.to_lowercase();
            for keyword in &common_keywords {
                if line_lower.contains(&keyword.to_lowercase()) {
                    keywords.push(keyword.to_string());
                }
            }
        }
    }

    fn extract_function_name(&self, line: &str) -> Option<String> {
        // Extract function names from various patterns
        if line.contains("function ") {
            // function name() or function name(
            if let Some(start) = line.find("function ") {
                let after_function = &line[start + 9..];
                if let Some(name_end) = after_function.find('(') {
                    return Some(after_function[..name_end].trim().to_string());
                }
            }
        } else if line.contains(" = ") && (line.contains("() =>") || line.contains("async ")) {
            // const name = () => or const name = async
            if let Some(equals_pos) = line.find(" = ") {
                let before_equals = &line[..equals_pos];
                if let Some(name_start) = before_equals.rfind(' ') {
                    return Some(before_equals[name_start + 1..].trim().to_string());
                }
            }
        }
        None
    }

    fn extract_rust_function_name(&self, line: &str) -> Option<String> {
        // Extract Rust function names: fn name( or pub fn name(
        let start_pos = if line.starts_with("pub fn ") { 7 } else { 3 };
        let after_fn = &line[start_pos..];
        if let Some(paren_pos) = after_fn.find('(') {
            Some(after_fn[..paren_pos].trim().to_string())
        } else {
            None
        }
    }

    fn extract_python_function_name(&self, line: &str) -> Option<String> {
        // Extract Python function names: def name(
        let after_def = &line[4..];
        if let Some(paren_pos) = after_def.find('(') {
            Some(after_def[..paren_pos].trim().to_string())
        } else {
            None
        }
    }

    fn detect_common_patterns(&self, line: &str, patterns: &mut Vec<String>) {
        let pattern_indicators = [
            ("async/await", vec!["async ", "await "]),
            ("error_handling", vec!["try {", "catch", "throw ", "Error("]),
            ("http_client", vec!["fetch(", "axios", "http.", "request("]),
            (
                "database",
                vec!["SELECT", "INSERT", "UPDATE", "DELETE", "query("],
            ),
            (
                "authentication",
                vec!["jwt", "token", "auth", "login", "password"],
            ),
            (
                "validation",
                vec!["validate", "schema", "required", "optional"],
            ),
            (
                "logging",
                vec!["console.log", "logger", "log.", "debug", "warn", "error"],
            ),
            (
                "testing",
                vec!["test(", "it(", "describe(", "expect(", "assert"],
            ),
        ];

        for (pattern_name, indicators) in &pattern_indicators {
            for indicator in indicators {
                if line.to_lowercase().contains(&indicator.to_lowercase()) {
                    patterns.push(pattern_name.to_string());
                    break;
                }
            }
        }
    }

    fn detect_rust_patterns(&self, line: &str, patterns: &mut Vec<String>) {
        let rust_patterns = [
            ("async_rust", vec!["async fn", "await"]),
            ("error_handling", vec!["Result<", "Error", "anyhow::", "?"]),
            ("memory_safety", vec!["Arc<", "Mutex<", "RefCell<", "&mut"]),
            ("traits", vec!["impl ", "trait ", "dyn "]),
            ("macros", vec!["macro_rules!", "#[derive"]),
        ];

        for (pattern_name, indicators) in &rust_patterns {
            for indicator in indicators {
                if line.contains(indicator) {
                    patterns.push(pattern_name.to_string());
                    break;
                }
            }
        }
    }

    fn detect_python_patterns(&self, line: &str, patterns: &mut Vec<String>) {
        let python_patterns = [
            ("async_python", vec!["async def", "await "]),
            (
                "data_science",
                vec!["pandas", "numpy", "matplotlib", "sklearn"],
            ),
            ("web_framework", vec!["flask", "django", "fastapi", "@app."]),
            ("decorators", vec!["@"]),
            ("comprehensions", vec!["[", "for ", " in "]),
        ];

        for (pattern_name, indicators) in &python_patterns {
            for indicator in indicators {
                if line.to_lowercase().contains(&indicator.to_lowercase()) {
                    patterns.push(pattern_name.to_string());
                    break;
                }
            }
        }
    }

    fn build_indices(&mut self) {
        // Build keyword, pattern, and function indices for fast lookup
        for metadata in self.metadata_cache.values() {
            // Index keywords
            for keyword in &metadata.keywords {
                self.keyword_index
                    .entry(keyword.clone())
                    .or_insert_with(Vec::new)
                    .push(metadata.file_path.clone());
            }

            // Index patterns
            for pattern in &metadata.patterns {
                self.pattern_index
                    .entry(pattern.clone())
                    .or_insert_with(Vec::new)
                    .push(metadata.file_path.clone());
            }

            // Index functions
            for function in &metadata.functions {
                self.function_index
                    .entry(function.clone())
                    .or_insert_with(Vec::new)
                    .push(metadata.file_path.clone());
            }
        }
    }

    /// Find files similar to a query using local text similarity
    pub fn find_similar_files(&self, query: &str, limit: usize) -> Vec<CodeSimilarity> {
        let query_lower = query.to_lowercase();
        let query_words: Vec<&str> = query_lower.split_whitespace().collect();

        let mut similarities = Vec::new();

        for metadata in self.metadata_cache.values() {
            let similarity_score = self.calculate_similarity(&query_words, metadata);
            let matching_patterns = self.find_matching_patterns(&query_lower, metadata);

            if similarity_score > 0.1 || !matching_patterns.is_empty() {
                similarities.push(CodeSimilarity {
                    file_path: metadata.file_path.clone(),
                    similarity_score,
                    matching_patterns,
                    metadata: metadata.clone(),
                });
            }
        }

        // Sort by similarity score
        similarities.sort_by(|a, b| {
            b.similarity_score
                .partial_cmp(&a.similarity_score)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        similarities.truncate(limit);
        similarities
    }

    fn calculate_similarity(&self, query_words: &[&str], metadata: &CodeMetadata) -> f32 {
        let mut score = 0.0f32;
        let total_words = query_words.len() as f32;

        // Check file path
        let file_path_str = metadata.file_path.to_string_lossy().to_lowercase();
        for word in query_words {
            if file_path_str.contains(word) {
                score += 0.3;
            }
        }

        // Check functions
        for function in &metadata.functions {
            let function_lower = function.to_lowercase();
            for word in query_words {
                if function_lower.contains(word) {
                    score += 0.4;
                }
            }
        }

        // Check patterns
        for pattern in &metadata.patterns {
            let pattern_lower = pattern.to_lowercase();
            for word in query_words {
                if pattern_lower.contains(word) {
                    score += 0.3;
                }
            }
        }

        // Check keywords
        for keyword in &metadata.keywords {
            let keyword_lower = keyword.to_lowercase();
            for word in query_words {
                if keyword_lower.contains(word) {
                    score += 0.2;
                }
            }
        }

        score / total_words
    }

    fn find_matching_patterns(&self, query: &str, metadata: &CodeMetadata) -> Vec<String> {
        let mut matches = Vec::new();

        for pattern in &metadata.patterns {
            if query.contains(&pattern.to_lowercase()) {
                matches.push(pattern.clone());
            }
        }

        matches
    }

    /// Get statistics about the indexed codebase
    pub fn get_stats(&self) -> HashMap<String, usize> {
        let mut stats = HashMap::new();

        stats.insert("total_files".to_string(), self.metadata_cache.len());
        stats.insert("total_functions".to_string(), self.function_index.len());
        stats.insert("total_patterns".to_string(), self.pattern_index.len());
        stats.insert("total_keywords".to_string(), self.keyword_index.len());

        // File type breakdown
        let mut file_types = HashMap::new();
        for metadata in self.metadata_cache.values() {
            *file_types.entry(metadata.file_type.clone()).or_insert(0) += 1;
        }

        for (file_type, count) in file_types {
            stats.insert(format!("files_{}", file_type), count);
        }

        stats
    }

    /// Find files by pattern
    pub fn find_by_pattern(&self, pattern: &str) -> Vec<&CodeMetadata> {
        self.pattern_index
            .get(pattern)
            .map(|paths| {
                paths
                    .iter()
                    .filter_map(|path| self.metadata_cache.get(path))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Find files by function name
    pub fn find_by_function(&self, function_name: &str) -> Vec<&CodeMetadata> {
        self.function_index
            .get(function_name)
            .map(|paths| {
                paths
                    .iter()
                    .filter_map(|path| self.metadata_cache.get(path))
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Get metadata summary for session storage
    pub fn get_metadata_summary(&self) -> HashMap<String, serde_json::Value> {
        let mut summary = HashMap::new();

        summary.insert(
            "total_files".to_string(),
            serde_json::Value::Number(self.metadata_cache.len().into()),
        );
        summary.insert(
            "total_functions".to_string(),
            serde_json::Value::Number(
                self.metadata_cache
                    .values()
                    .map(|m| m.functions.len())
                    .sum::<usize>()
                    .into(),
            ),
        );
        summary.insert(
            "total_keywords".to_string(),
            serde_json::Value::Number(self.keyword_index.len().into()),
        );
        summary.insert(
            "total_patterns".to_string(),
            serde_json::Value::Number(self.pattern_index.len().into()),
        );

        // Add file type breakdown
        let mut file_types = HashMap::new();
        for metadata in self.metadata_cache.values() {
            *file_types.entry(metadata.file_type.clone()).or_insert(0) += 1;
        }
        summary.insert(
            "file_types".to_string(),
            serde_json::to_value(file_types).unwrap_or_default(),
        );

        summary
    }

    /// Get keyword index for session storage
    pub fn get_keyword_index(&self) -> &HashMap<String, Vec<PathBuf>> {
        &self.keyword_index
    }

    /// Get function index for session storage
    pub fn get_function_index(&self) -> &HashMap<String, Vec<PathBuf>> {
        &self.function_index
    }

    /// Get pattern index for session storage
    pub fn get_pattern_index(&self) -> &HashMap<String, Vec<PathBuf>> {
        &self.pattern_index
    }

    /// Get simple stats tuple (files, functions) for display
    pub fn get_simple_stats(&self) -> (usize, usize) {
        let total_files = self.metadata_cache.len();
        let total_functions = self
            .metadata_cache
            .values()
            .map(|m| m.functions.len())
            .sum();
        (total_files, total_functions)
    }

    /// Build call graph from indexed code
    pub async fn build_call_graph(&self) -> anyhow::Result<CodeGraph> {
        let builder = CodeGraphBuilder::new(self.working_directory.clone());
        builder.build_call_graph(&self.metadata_cache).await
    }

    /// Build import graph from indexed code
    pub async fn build_import_graph(&self) -> anyhow::Result<CodeGraph> {
        let builder = CodeGraphBuilder::new(self.working_directory.clone());
        builder.build_import_graph(&self.metadata_cache).await
    }

    /// Build all available graphs
    pub async fn build_all_graphs(&self) -> anyhow::Result<HashMap<GraphType, CodeGraph>> {
        let mut graphs = HashMap::new();

        let call_graph = self.build_call_graph().await?;
        let import_graph = self.build_import_graph().await?;

        graphs.insert(GraphType::CallGraph, call_graph);
        graphs.insert(GraphType::ImportGraph, import_graph);

        Ok(graphs)
    }

    /// Get metadata cache for external use
    pub fn get_metadata_cache(&self) -> &HashMap<PathBuf, CodeMetadata> {
        &self.metadata_cache
    }
}

//! Unified Parsers Module
//!
//! This module contains ALL parsers and analyzers that are shared between NIF and Server.
//! No duplication - single source of truth!

use anyhow::Result;
use std::path::Path;
use std::sync::Arc;

// Import all the analysis modules
use analysis_suite::{
    quality::QualityAnalyzer,
    security::SecurityAnalyzer,
    architecture::ArchitectureAnalyzer,
};
use tech_detector::TechDetector;
use source_code_parser::{
    dependencies::DependencyParser,
    languages::LanguageDetector,
    parsing::CodeParser,
};
use embedding_engine::{
    EmbeddingEngine,
    models::EmbeddingModel,
};

/// Unified Parsers and Analyzers
/// 
/// This contains ALL the parsers and analyzers that both NIF and Server use.
/// No duplication - single source of truth!
#[derive(Debug, Clone)]
pub struct UnifiedParsers {
    // Core parsers (shared by both NIF and Server)
    pub tech_detector: Arc<TechDetector>,
    pub language_detector: Arc<LanguageDetector>,
    pub code_parser: Arc<CodeParser>,
    pub dependency_parser: Arc<DependencyParser>,
    pub quality_analyzer: Arc<QualityAnalyzer>,
    pub security_analyzer: Arc<SecurityAnalyzer>,
    pub architecture_analyzer: Arc<ArchitectureAnalyzer>,
    pub embedding_engine: Arc<EmbeddingEngine>,
}

impl UnifiedParsers {
    /// Create a new unified parsers instance
    /// 
    /// This initializes ALL parsers and analyzers in one place.
    /// Both NIF and Server use this same instance - no duplication!
    pub fn new() -> Result<Self> {
        // Initialize all parsers and analyzers
        let tech_detector = Arc::new(TechDetector::new());
        let language_detector = Arc::new(LanguageDetector::new());
        let code_parser = Arc::new(CodeParser::new());
        let dependency_parser = Arc::new(DependencyParser::new());
        let quality_analyzer = Arc::new(QualityAnalyzer::new());
        let security_analyzer = Arc::new(SecurityAnalyzer::new());
        let architecture_analyzer = Arc::new(ArchitectureAnalyzer::new());
        
        // Initialize embedding engine
        let embedding_model = EmbeddingModel::from_name("text-embedding-004")?;
        let embedding_engine = Arc::new(EmbeddingEngine::new(embedding_model));
        
        Ok(Self {
            tech_detector,
            language_detector,
            code_parser,
            dependency_parser,
            quality_analyzer,
            security_analyzer,
            architecture_analyzer,
            embedding_engine,
        })
    }
    
    /// Analyze a single file
    /// 
    /// This is the core file analysis function that both NIF and Server use.
    /// No duplication - same code, same results!
    pub async fn analyze_file(&self, file_path: &Path) -> Result<FileAnalysisResult> {
        // 1. Detect language
        let language = self.language_detector.detect_language(file_path)?;
        
        // 2. Parse the file
        let content = std::fs::read_to_string(file_path)?;
        let parsed_ast = self.code_parser.parse_file(&content, &language).ok();
        
        // 3. Extract dependencies
        let dependencies = self.dependency_parser.parse_dependencies(file_path)?;
        
        // 4. Analyze quality
        let quality_metrics = self.quality_analyzer.analyze(file_path)?;
        
        // 5. Analyze security
        let security_issues = self.security_analyzer.analyze(file_path)?;
        
        // 6. Analyze architecture
        let architecture_patterns = self.architecture_analyzer.analyze(file_path)?;
        
        // 7. Generate embedding
        let embedding = self.embedding_engine.generate_embedding(&content).ok();
        
        Ok(FileAnalysisResult {
            file_path: file_path.to_path_buf(),
            language,
            parsed_ast,
            dependencies,
            quality_metrics,
            security_issues,
            architecture_patterns,
            embedding,
        })
    }
    
    /// Analyze a codebase
    /// 
    /// This orchestrates the analysis of all files in a codebase.
    /// Both NIF and Server use this same function - no duplication!
    pub async fn analyze_codebase(&self, codebase_path: &Path) -> Result<CodebaseAnalysisResult> {
        // 1. Discover all files
        let files = self.discover_files(codebase_path)?;
        
        // 2. Analyze each file
        let mut file_results = Vec::new();
        for file_path in &files {
            match self.analyze_file(file_path).await {
                Ok(result) => file_results.push(result),
                Err(e) => eprintln!("Failed to analyze {}: {}", file_path.display(), e),
            }
        }
        
        // 3. Perform cross-file analysis
        let cross_file_analysis = self.analyze_cross_file_relationships(&file_results)?;
        
        // 4. Generate embeddings
        let embeddings = self.generate_embeddings_for_files(&files).await?;
        
        // 5. Detect technologies
        let technologies = self.tech_detector.detect_technologies(codebase_path)?;
        
        Ok(CodebaseAnalysisResult {
            file_results,
            cross_file_analysis,
            embeddings,
            technologies,
        })
    }
    
    /// Discover all code files in a directory
    fn discover_files(&self, path: &Path) -> Result<Vec<std::path::PathBuf>> {
        let mut files = Vec::new();
        
        if path.is_file() {
            if self.is_code_file(path) {
                files.push(path.to_path_buf());
            }
        } else if path.is_dir() {
            for entry in std::fs::read_dir(path)? {
                let entry = entry?;
                let entry_path = entry.path();
                
                if entry_path.is_dir() {
                    if !self.should_skip_directory(&entry_path) {
                        files.extend(self.discover_files(&entry_path)?);
                    }
                } else if self.is_code_file(&entry_path) {
                    files.push(entry_path);
                }
            }
        }
        
        Ok(files)
    }
    
    /// Generate embeddings for all files
    async fn generate_embeddings_for_files(&self, files: &[std::path::PathBuf]) -> Result<Vec<EmbeddingInfo>> {
        let mut embeddings = Vec::new();
        
        for file_path in files {
            if let Ok(content) = std::fs::read_to_string(file_path) {
                if let Ok(embedding) = self.embedding_engine.generate_embedding(&content) {
                    embeddings.push(EmbeddingInfo {
                        file_path: file_path.to_string_lossy().to_string(),
                        embedding,
                        similarity_score: None,
                    });
                }
            }
        }
        
        Ok(embeddings)
    }
    
    /// Analyze cross-file relationships
    fn analyze_cross_file_relationships(&self, file_results: &[FileAnalysisResult]) -> Result<CrossFileAnalysis> {
        // This would analyze relationships between files
        // For now, return empty result
        Ok(CrossFileAnalysis {
            file_dependencies: std::collections::HashMap::new(),
            function_calls: std::collections::HashMap::new(),
            class_inheritance: std::collections::HashMap::new(),
            module_imports: std::collections::HashMap::new(),
            circular_dependencies: Vec::new(),
            architecture_patterns: Vec::new(),
        })
    }
    
    // Helper methods
    
    fn is_code_file(&self, path: &Path) -> bool {
        if let Some(extension) = path.extension() {
            let ext = extension.to_string_lossy().to_lowercase();
            matches!(ext.as_str(), 
                "rs" | "elixir" | "ex" | "exs" | "gleam" | "js" | "ts" | "py" | "go" | 
                "java" | "c" | "cpp" | "h" | "hpp" | "cs" | "swift" | "kt" | "php" | 
                "rb" | "lua" | "json" | "yaml" | "yml" | "toml" | "xml" | "html" | 
                "css" | "scss" | "sass" | "less" | "sh" | "bash" | "zsh" | "fish"
            )
        } else {
            false
        }
    }
    
    fn should_skip_directory(&self, path: &Path) -> bool {
        if let Some(dir_name) = path.file_name() {
            let dir_name = dir_name.to_string_lossy().to_lowercase();
            matches!(dir_name.as_str(), 
                "node_modules" | "target" | "build" | "dist" | ".git" | ".svn" | 
                "vendor" | "deps" | "_build" | "priv" | "test" | "tests" | "spec"
            )
        } else {
            false
        }
    }
}

// Types for file analysis results

#[derive(Debug, Clone)]
pub struct FileAnalysisResult {
    pub file_path: std::path::PathBuf,
    pub language: String,
    pub parsed_ast: Option<serde_json::Value>,
    pub dependencies: Vec<DependencyInfo>,
    pub quality_metrics: QualityMetrics,
    pub security_issues: Vec<SecurityIssue>,
    pub architecture_patterns: Vec<ArchitecturePattern>,
    pub embedding: Option<Vec<f32>>,
}

#[derive(Debug, Clone)]
pub struct CodebaseAnalysisResult {
    pub file_results: Vec<FileAnalysisResult>,
    pub cross_file_analysis: CrossFileAnalysis,
    pub embeddings: Vec<EmbeddingInfo>,
    pub technologies: Vec<TechnologyInfo>,
}

#[derive(Debug, Clone)]
pub struct CrossFileAnalysis {
    pub file_dependencies: std::collections::HashMap<std::path::PathBuf, Vec<std::path::PathBuf>>,
    pub function_calls: std::collections::HashMap<String, Vec<String>>,
    pub class_inheritance: std::collections::HashMap<String, Vec<String>>,
    pub module_imports: std::collections::HashMap<String, Vec<String>>,
    pub circular_dependencies: Vec<Vec<std::path::PathBuf>>,
    pub architecture_patterns: Vec<ArchitecturePattern>,
}

// Re-export types from the main types module
use crate::types::*;

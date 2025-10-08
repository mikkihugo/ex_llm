//! Unified Analysis Engine
//!
//! The core analysis engine that can be used by both NIF and Server
//! All parsers, analyzers, and engines are centralized here

use anyhow::Result;
use std::sync::Arc;
use std::path::Path;

use crate::types::*;
use code_engine::{
    quality::QualityAnalyzer,
    security::SecurityAnalyzer,
    architecture::ArchitectureAnalyzer,
};
use tech_detector::TechDetector;
use source_code_parser::dependencies::DependencyParser;
use embedding_engine::{
    EmbeddingEngine,
    models::EmbeddingModel,
};

#[cfg(feature = "server")]
use package_registry_indexer::{
    collector::PackageCollector,
    storage::DependencyCatalogStorage,
};

/// Unified Analysis Engine
/// 
/// This is the SINGLE source of truth for all analysis capabilities.
/// Both NIF and Server use this same engine - no duplication!
#[derive(Debug, Clone)]
pub struct UnifiedAnalysisEngine {
    // Core analyzers (used by both NIF and Server)
    pub tech_detector: Arc<TechDetector>,
    pub dependency_parser: Arc<DependencyParser>,
    pub quality_analyzer: Arc<QualityAnalyzer>,
    pub security_analyzer: Arc<SecurityAnalyzer>,
    pub architecture_analyzer: Arc<ArchitectureAnalyzer>,
    pub embedding_engine: Arc<EmbeddingEngine>,
    
    // Server-only components (package downloading, database storage)
    #[cfg(feature = "server")]
    pub package_collector: Arc<PackageCollector>,
    #[cfg(feature = "server")]
    pub database_storage: Arc<DependencyCatalogStorage>,
}

impl UnifiedAnalysisEngine {
    /// Create a new unified analysis engine
    /// 
    /// This initializes ALL the parsers, analyzers, and engines
    /// in one place - no duplication between NIF and Server!
    pub fn new() -> Result<Self> {
        // Initialize all core analyzers (shared by NIF and Server)
        let tech_detector = Arc::new(TechDetector::new());
        let dependency_parser = Arc::new(DependencyParser::new());
        let quality_analyzer = Arc::new(QualityAnalyzer::new());
        let security_analyzer = Arc::new(SecurityAnalyzer::new());
        let architecture_analyzer = Arc::new(ArchitectureAnalyzer::new());
        
        // Initialize embedding engine (shared by NIF and Server)
        let embedding_model = EmbeddingModel::from_name("text-embedding-004")?;
        let embedding_engine = Arc::new(EmbeddingEngine::new(embedding_model));
        
        // Initialize server-only components
        #[cfg(feature = "server")]
        let package_collector = Arc::new(PackageCollector::new());
        #[cfg(feature = "server")]
        let database_storage = Arc::new(DependencyCatalogStorage::new()?);
        
        Ok(Self {
            tech_detector,
            dependency_parser,
            quality_analyzer,
            security_analyzer,
            architecture_analyzer,
            embedding_engine,
            #[cfg(feature = "server")]
            package_collector,
            #[cfg(feature = "server")]
            database_storage,
        })
    }
    
    /// Analyze a codebase (works for both NIF and Server)
    /// 
    /// This is the MAIN analysis function that both NIF and Server use.
    /// No duplication - same code, same results!
    pub async fn analyze_codebase(&self, request: AnalysisRequest) -> Result<AnalysisResult> {
        let codebase_path = Path::new(&request.codebase_path);
        let mode = request.mode.unwrap_or_else(|| "nif".to_string());
        
        // Use the SAME parsers and analyzers for both NIF and Server
        let technologies = self.tech_detector.detect_technologies(codebase_path)?;
        let dependencies = self.dependency_parser.parse_dependencies(codebase_path)?;
        let quality_metrics = self.quality_analyzer.analyze(codebase_path)?;
        let security_issues = self.security_analyzer.analyze(codebase_path)?;
        let architecture_patterns = self.architecture_analyzer.analyze(codebase_path)?;
        
        // Generate embeddings using the SAME engine
        let embeddings = if request.analysis_types.contains(&"embeddings".to_string()) {
            self.generate_embeddings_for_path(codebase_path).await?
        } else {
            Vec::new()
        };
        
        // Write to database if URL provided
        let database_written = if let Some(db_url) = request.database_url {
            let result = AnalysisResult {
                success: true,
                technologies: technologies.clone(),
                dependencies: dependencies.clone(),
                quality_metrics: quality_metrics.clone(),
                security_issues: security_issues.clone(),
                architecture_patterns: architecture_patterns.clone(),
                embeddings: embeddings.clone(),
                database_written: false,
                error: None,
                mode: mode.clone(),
            };
            self.write_to_database(result, &db_url).await?
        } else {
            false
        };
        
        Ok(AnalysisResult {
            success: true,
            technologies,
            dependencies,
            quality_metrics,
            security_issues,
            architecture_patterns,
            embeddings,
            database_written,
            error: None,
            mode,
        })
    }
    
    /// Analyze a package (Server only)
    /// 
    /// This downloads packages and analyzes them using the SAME engine
    #[cfg(feature = "server")]
    pub async fn analyze_package(&self, request: PackageAnalysisRequest) -> Result<PackageAnalysisResult> {
        // 1. Download package using server-only collector
        let package_data = self.package_collector.collect_package(&request.package_name, &request.ecosystem).await?;
        
        // 2. Analyze using the SAME engine as NIF
        let analysis_request = AnalysisRequest {
            codebase_path: package_data.local_path,
            analysis_types: request.analysis_types,
            database_url: request.database_url,
            embedding_model: None,
            mode: Some("server".to_string()),
        };
        
        let analysis_result = self.analyze_codebase(analysis_request).await?;
        
        // 3. Write to database using server-only storage
        self.database_storage.store_analysis_result(&analysis_result).await?;
        
        Ok(PackageAnalysisResult {
            success: true,
            package_name: request.package_name,
            ecosystem: request.ecosystem,
            analysis: analysis_result,
            download_path: Some(package_data.local_path),
            error: None,
        })
    }
    
    /// Generate embeddings for all code files in a path
    /// 
    /// This uses the SAME embedding engine for both NIF and Server
    pub async fn generate_embeddings_for_path(&self, path: &Path) -> Result<Vec<EmbeddingInfo>> {
        let files = self.find_code_files(path)?;
        let mut embeddings = Vec::new();
        
        for file_path in files {
            if let Ok(content) = tokio::fs::read_to_string(&file_path).await {
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
    
    /// Find all code files in a directory
    /// 
    /// This is the SAME file finding logic for both NIF and Server
    pub fn find_code_files(&self, path: &Path) -> Result<Vec<std::path::PathBuf>> {
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
                    files.extend(self.find_code_files(&entry_path)?);
                } else if self.is_code_file(&entry_path) {
                    files.push(entry_path);
                }
            }
        }
        
        Ok(files)
    }
    
    /// Check if a file is a code file
    /// 
    /// This is the SAME file type detection for both NIF and Server
    pub fn is_code_file(&self, path: &Path) -> bool {
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
    
    /// Write analysis results to database
    /// 
    /// This is the SAME database writing logic for both NIF and Server
    async fn write_to_database(&self, result: AnalysisResult, database_url: &str) -> Result<bool> {
        // This would connect to PostgreSQL and write the analysis results
        // For now, just return true as a placeholder
        println!("Writing analysis results to database: {}", database_url);
        println!("Mode: {}", result.mode);
        println!("Technologies: {}", result.technologies.len());
        println!("Dependencies: {}", result.dependencies.len());
        println!("Security issues: {}", result.security_issues.len());
        println!("Architecture patterns: {}", result.architecture_patterns.len());
        println!("Embeddings: {}", result.embeddings.len());
        
        Ok(true)
    }
}

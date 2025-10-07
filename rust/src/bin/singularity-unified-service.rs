//! Singularity Unified Service
//!
//! A single service that includes all capabilities:
//! - Package Registry Indexer (npm, cargo, hex, pypi)
//! - Analysis Suite (quality, security, architecture)
//! - Tech Detector
//! - Source Code Parser
//! - Embedding Engine
//! - Database Writer
//!
//! All using the same unified analysis engine.

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, Level};
use tracing_subscriber;

// Import all the services and analyzers
use package_registry_indexer::{
    nats_service::PackageRegistryNatsService,
    collector::PackageCollector,
    storage::DependencyCatalogStorage,
};
use analysis_suite::{
    analyzer::Analyzer,
    codebase::CodebaseAnalyzer,
    quality::QualityAnalyzer,
    security::SecurityAnalyzer,
    architecture::ArchitectureAnalyzer,
};
use tech_detector::TechDetector;
use source_code_parser::{
    languages::LanguageDetector,
    dependencies::DependencyParser,
    parsing::CodeParser,
};
use embedding_engine::{
    EmbeddingEngine,
    models::EmbeddingModel,
    tokenizers::Tokenizer,
};

#[derive(Debug, Clone)]
pub struct UnifiedAnalysisEngine {
    pub tech_detector: Arc<TechDetector>,
    pub dependency_parser: Arc<DependencyParser>,
    pub quality_analyzer: Arc<QualityAnalyzer>,
    pub security_analyzer: Arc<SecurityAnalyzer>,
    pub architecture_analyzer: Arc<ArchitectureAnalyzer>,
    pub embedding_engine: Arc<EmbeddingEngine>,
    pub package_collector: Arc<PackageCollector>,
    pub database_storage: Arc<DependencyCatalogStorage>,
}

impl UnifiedAnalysisEngine {
    pub fn new() -> Result<Self> {
        let tech_detector = Arc::new(TechDetector::new());
        let dependency_parser = Arc::new(DependencyParser::new());
        let quality_analyzer = Arc::new(QualityAnalyzer::new());
        let security_analyzer = Arc::new(SecurityAnalyzer::new());
        let architecture_analyzer = Arc::new(ArchitectureAnalyzer::new());
        
        // Initialize embedding engine with default model
        let embedding_model = EmbeddingModel::from_name("text-embedding-004")?;
        let embedding_engine = Arc::new(EmbeddingEngine::new(embedding_model));
        
        // Initialize package collector and database storage
        let package_collector = Arc::new(PackageCollector::new());
        let database_storage = Arc::new(DependencyCatalogStorage::new()?);
        
        Ok(Self {
            tech_detector,
            dependency_parser,
            quality_analyzer,
            security_analyzer,
            architecture_analyzer,
            embedding_engine,
            package_collector,
            database_storage,
        })
    }
    
    /// Analyze a package and write to database
    pub async fn analyze_package(&self, package_name: &str, ecosystem: &str) -> Result<AnalysisResult> {
        info!("🔍 Analyzing package: {} ({})", package_name, ecosystem);
        
        // 1. Download and collect package data
        let package_data = self.package_collector.collect_package(package_name, ecosystem).await?;
        
        // 2. Analyze the downloaded package code
        let analysis_result = self.analyze_codebase(&package_data.local_path).await?;
        
        // 3. Write to database
        self.database_storage.store_analysis_result(&analysis_result).await?;
        
        info!("✅ Package analysis completed: {} ({})", package_name, ecosystem);
        Ok(analysis_result)
    }
    
    /// Analyze a local codebase
    pub async fn analyze_codebase(&self, codebase_path: &str) -> Result<AnalysisResult> {
        use std::path::Path;
        let path = Path::new(codebase_path);
        
        // Detect technologies
        let technologies = self.tech_detector.detect_technologies(path)?;
        
        // Parse dependencies
        let dependencies = self.dependency_parser.parse_dependencies(path)?;
        
        // Analyze quality
        let quality_metrics = self.quality_analyzer.analyze(path)?;
        
        // Analyze security
        let security_issues = self.security_analyzer.analyze(path)?;
        
        // Analyze architecture
        let architecture_patterns = self.architecture_analyzer.analyze(path)?;
        
        // Generate embeddings
        let embeddings = self.generate_embeddings_for_path(path).await?;
        
        Ok(AnalysisResult {
            success: true,
            technologies,
            dependencies,
            quality_metrics,
            security_issues,
            architecture_patterns,
            embeddings,
            database_written: false,
            error: None,
        })
    }
    
    /// Generate embeddings for all code files in a path
    async fn generate_embeddings_for_path(&self, path: &std::path::Path) -> Result<Vec<EmbeddingInfo>> {
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
    fn find_code_files(&self, path: &std::path::Path) -> Result<Vec<std::path::PathBuf>> {
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
    fn is_code_file(&self, path: &std::path::Path) -> bool {
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
}

#[derive(Debug, Clone)]
pub struct AnalysisResult {
    pub success: bool,
    pub technologies: Vec<TechnologyInfo>,
    pub dependencies: Vec<DependencyInfo>,
    pub quality_metrics: QualityMetrics,
    pub security_issues: Vec<SecurityIssue>,
    pub architecture_patterns: Vec<ArchitecturePattern>,
    pub embeddings: Vec<EmbeddingInfo>,
    pub database_written: bool,
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
pub struct TechnologyInfo {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f64,
    pub files: Vec<String>,
    pub category: String,
}

#[derive(Debug, Clone)]
pub struct DependencyInfo {
    pub name: String,
    pub version: String,
    pub ecosystem: String,
    pub dependencies: Vec<String>,
    pub dev_dependencies: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct QualityMetrics {
    pub complexity_score: f64,
    pub maintainability_score: f64,
    pub test_coverage: f64,
    pub code_duplication: f64,
    pub technical_debt: f64,
}

#[derive(Debug, Clone)]
pub struct SecurityIssue {
    pub severity: String,
    pub category: String,
    pub description: String,
    pub file: String,
    pub line: u32,
}

#[derive(Debug, Clone)]
pub struct ArchitecturePattern {
    pub pattern_type: String,
    pub confidence: f64,
    pub files: Vec<String>,
    pub description: String,
}

#[derive(Debug, Clone)]
pub struct EmbeddingInfo {
    pub file_path: String,
    pub embedding: Vec<f32>,
    pub similarity_score: Option<f64>,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    info!("🚀 Starting Singularity Unified Service...");

    // Get NATS URL from environment or use default
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());

    info!("📡 Connecting to NATS at: {}", nats_url);

    // Check if NATS is running
    if !is_nats_running(&nats_url).await {
        eprintln!("❌ NATS server is not running. Please start NATS first:");
        eprintln!("   nats-server -js");
        std::process::exit(1);
    }

    // Initialize unified analysis engine
    info!("🔧 Initializing unified analysis engine...");
    let analysis_engine = Arc::new(UnifiedAnalysisEngine::new()?);
    info!("✅ Unified analysis engine initialized");

    // Initialize all services
    let mut services = Vec::new();

    // 1. Package Registry Service
    info!("📦 Starting Package Registry Service...");
    match PackageRegistryNatsService::new(&nats_url).await {
        Ok(service) => {
            let service_handle = tokio::spawn(async move {
                if let Err(e) = service.start().await {
                    eprintln!("❌ Package Registry Service failed: {}", e);
                }
            });
            services.push(("Package Registry", service_handle));
            info!("✅ Package Registry Service started");
        }
        Err(e) => {
            eprintln!("❌ Failed to start Package Registry Service: {}", e);
        }
    }

    // 2. Analysis Service (using unified engine)
    info!("🔍 Starting Analysis Service...");
    let analysis_engine_clone = analysis_engine.clone();
    let analysis_handle = tokio::spawn(async move {
        // This would be a NATS service that uses the unified analysis engine
        // For now, just keep it running
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
            info!("🔍 Analysis engine is running...");
        }
    });
    services.push(("Analysis Engine", analysis_handle));
    info!("✅ Analysis Service started");

    info!("🎉 All services started! Service is running in background...");
    info!("💡 Use Ctrl+C to stop the service");

    // Wait for all services to complete or signal
    for (name, handle) in services {
        tokio::select! {
            _ = handle => {
                info!("{} service stopped", name);
            }
            _ = tokio::signal::ctrl_c() => {
                info!("🛑 Shutting down all services...");
                break;
            }
        }
    }

    info!("👋 Singularity Unified Service stopped");
    Ok(())
}

async fn is_nats_running(nats_url: &str) -> bool {
    match async_nats::connect(nats_url).await {
        Ok(_) => true,
        Err(_) => false,
    }
}

//! Feature Management System
//!
//! This module manages feature flags and dependencies between NIF and Server modes.

use anyhow::Result;
use std::collections::HashMap;

/// Feature flags for the unified analysis system
#[derive(Debug, Clone, PartialEq)]
pub enum Feature {
    /// NIF mode - Direct analysis in Elixir process
    Nif,
    /// Server mode - Distributed analysis via NATS
    Server,
    /// Package analysis - Download and analyze external packages
    PackageAnalysis,
    /// Database storage - Write results to PostgreSQL
    DatabaseStorage,
    /// Embedding generation - Generate embeddings for code
    EmbeddingGeneration,
    /// Cross-file analysis - Analyze relationships between files
    CrossFileAnalysis,
    /// Real-time analysis - Live analysis as files change
    RealTimeAnalysis,
}

/// Feature configuration
#[derive(Debug, Clone)]
pub struct FeatureConfig {
    pub enabled_features: Vec<Feature>,
    pub dependencies: HashMap<Feature, Vec<Feature>>,
}

impl FeatureConfig {
    /// Create a new feature configuration
    pub fn new() -> Self {
        let mut dependencies = HashMap::new();
        
        // Define feature dependencies
        dependencies.insert(Feature::PackageAnalysis, vec![Feature::Server]);
        dependencies.insert(Feature::DatabaseStorage, vec![Feature::Server]);
        dependencies.insert(Feature::CrossFileAnalysis, vec![Feature::Nif, Feature::Server]);
        dependencies.insert(Feature::RealTimeAnalysis, vec![Feature::Nif]);
        
        Self {
            enabled_features: Vec::new(),
            dependencies,
        }
    }
    
    /// Enable a feature
    pub fn enable(&mut self, feature: Feature) -> Result<()> {
        // Check if dependencies are met
        if let Some(deps) = self.dependencies.get(&feature) {
            for dep in deps {
                if !self.enabled_features.contains(dep) {
                    return Err(anyhow::anyhow!("Feature {:?} requires {:?} to be enabled first", feature, dep));
                }
            }
        }
        
        if !self.enabled_features.contains(&feature) {
            self.enabled_features.push(feature);
        }
        
        Ok(())
    }
    
    /// Disable a feature
    pub fn disable(&mut self, feature: Feature) -> Result<()> {
        // Check if any other features depend on this one
        for (other_feature, deps) in &self.dependencies {
            if deps.contains(&feature) && self.enabled_features.contains(other_feature) {
                return Err(anyhow::anyhow!("Cannot disable {:?} because {:?} depends on it", feature, other_feature));
            }
        }
        
        self.enabled_features.retain(|f| f != &feature);
        Ok(())
    }
    
    /// Check if a feature is enabled
    pub fn is_enabled(&self, feature: &Feature) -> bool {
        self.enabled_features.contains(feature)
    }
    
    /// Get all enabled features
    pub fn get_enabled_features(&self) -> &[Feature] {
        &self.enabled_features
    }
}

/// Feature-aware analysis engine
#[derive(Debug, Clone)]
pub struct FeatureAwareEngine {
    pub config: FeatureConfig,
    pub parsers: crate::parsers::UnifiedParsers,
}

impl FeatureAwareEngine {
    /// Create a new feature-aware engine
    pub fn new(config: FeatureConfig) -> Result<Self> {
        let parsers = crate::parsers::UnifiedParsers::new()?;
        
        Ok(Self {
            config,
            parsers,
        })
    }
    
    /// Analyze a codebase with feature awareness
    pub async fn analyze_codebase(&self, codebase_path: &std::path::Path) -> Result<crate::types::AnalysisResult> {
        // Use the unified parsers (same for both NIF and Server)
        let result = self.parsers.analyze_codebase(codebase_path).await?;
        
        // Convert to the expected format
        Ok(crate::types::AnalysisResult {
            success: true,
            technologies: result.technologies,
            dependencies: result.file_results.iter()
                .flat_map(|f| f.dependencies.clone())
                .collect(),
            quality_metrics: self.aggregate_quality_metrics(&result.file_results),
            security_issues: result.file_results.iter()
                .flat_map(|f| f.security_issues.clone())
                .collect(),
            architecture_patterns: result.cross_file_analysis.architecture_patterns,
            embeddings: result.embeddings,
            database_written: false,
            error: None,
            mode: if self.config.is_enabled(&Feature::Nif) { "nif".to_string() } else { "server".to_string() },
        })
    }
    
    /// Analyze a package (Server only)
    #[cfg(feature = "server")]
    pub async fn analyze_package(&self, package_name: &str, ecosystem: &str) -> Result<crate::types::PackageAnalysisResult> {
        if !self.config.is_enabled(&Feature::PackageAnalysis) {
            return Err(anyhow::anyhow!("Package analysis feature is not enabled"));
        }
        
        // This would use the server-only package collector
        // For now, return a placeholder
        Ok(crate::types::PackageAnalysisResult {
            success: true,
            package_name: package_name.to_string(),
            ecosystem: ecosystem.to_string(),
            analysis: crate::types::AnalysisResult {
                success: true,
                technologies: Vec::new(),
                dependencies: Vec::new(),
                quality_metrics: crate::types::QualityMetrics {
                    complexity_score: 0.0,
                    maintainability_score: 0.0,
                    test_coverage: 0.0,
                    code_duplication: 0.0,
                    technical_debt: 0.0,
                },
                security_issues: Vec::new(),
                architecture_patterns: Vec::new(),
                embeddings: Vec::new(),
                database_written: false,
                error: None,
                mode: "server".to_string(),
            },
            download_path: None,
            error: None,
        })
    }
    
    /// Generate embeddings (if feature is enabled)
    pub async fn generate_embeddings(&self, codebase_path: &std::path::Path) -> Result<Vec<crate::types::EmbeddingInfo>> {
        if !self.config.is_enabled(&Feature::EmbeddingGeneration) {
            return Err(anyhow::anyhow!("Embedding generation feature is not enabled"));
        }
        
        let result = self.parsers.analyze_codebase(codebase_path).await?;
        Ok(result.embeddings)
    }
    
    /// Write to database (if feature is enabled)
    pub async fn write_to_database(&self, result: &crate::types::AnalysisResult, database_url: &str) -> Result<bool> {
        if !self.config.is_enabled(&Feature::DatabaseStorage) {
            return Err(anyhow::anyhow!("Database storage feature is not enabled"));
        }
        
        // This would write to the database
        println!("Writing to database: {}", database_url);
        Ok(true)
    }
    
    /// Aggregate quality metrics from file results
    fn aggregate_quality_metrics(&self, file_results: &[crate::parsers::FileAnalysisResult]) -> crate::types::QualityMetrics {
        if file_results.is_empty() {
            return crate::types::QualityMetrics {
                complexity_score: 0.0,
                maintainability_score: 0.0,
                test_coverage: 0.0,
                code_duplication: 0.0,
                technical_debt: 0.0,
            };
        }
        
        let total_files = file_results.len() as f64;
        let mut total_complexity = 0.0;
        let mut total_maintainability = 0.0;
        let mut total_duplication = 0.0;
        let mut total_debt = 0.0;
        
        for file_result in file_results {
            total_complexity += file_result.quality_metrics.complexity_score;
            total_maintainability += file_result.quality_metrics.maintainability_score;
            total_duplication += file_result.quality_metrics.code_duplication;
            total_debt += file_result.quality_metrics.technical_debt;
        }
        
        crate::types::QualityMetrics {
            complexity_score: total_complexity / total_files,
            maintainability_score: total_maintainability / total_files,
            test_coverage: 0.0, // Would be calculated from test files
            code_duplication: total_duplication / total_files,
            technical_debt: total_debt / total_files,
        }
    }
}

/// Create a NIF configuration
pub fn create_nif_config() -> FeatureConfig {
    let mut config = FeatureConfig::new();
    config.enable(Feature::Nif).unwrap();
    config.enable(Feature::EmbeddingGeneration).unwrap();
    config.enable(Feature::CrossFileAnalysis).unwrap();
    config.enable(Feature::RealTimeAnalysis).unwrap();
    config
}

/// Create a Server configuration
pub fn create_server_config() -> FeatureConfig {
    let mut config = FeatureConfig::new();
    config.enable(Feature::Server).unwrap();
    config.enable(Feature::PackageAnalysis).unwrap();
    config.enable(Feature::DatabaseStorage).unwrap();
    config.enable(Feature::EmbeddingGeneration).unwrap();
    config.enable(Feature::CrossFileAnalysis).unwrap();
    config
}

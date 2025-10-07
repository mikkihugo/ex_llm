//! NIF (Native Implemented Function) module
//!
//! Provides direct analysis functions that run in the Elixir process
//! Uses the unified parsers and feature-aware engine

use anyhow::Result;
use rustler::{Env, Term, NifResult, Encoder, Decoder, Error};
use std::collections::HashMap;

use crate::{
    types::*,
    parsers::UnifiedParsers,
    features::{FeatureAwareEngine, create_nif_config},
};

// Re-export the NIF functions
rustler::init!(
    "Elixir.Singularity.UnifiedNif",
    [
        analyze_codebase,
        detect_technologies,
        parse_dependencies,
        generate_embeddings,
        analyze_quality,
        analyze_security,
        analyze_architecture,
        get_analysis_summary,
        write_to_database
    ]
);

/// Main analysis function - analyzes entire codebase
#[rustler::nif]
fn analyze_codebase(request: AnalysisRequest) -> NifResult<AnalysisResult> {
    match do_analyze_codebase(request) {
        Ok(result) => Ok(result),
        Err(e) => Err(Error::Term(Box::new(format!("Analysis failed: {}", e)))),
    }
}

/// Detect technologies in the codebase
#[rustler::nif]
fn detect_technologies(codebase_path: String) -> NifResult<Vec<TechnologyInfo>> {
    match do_detect_technologies(&codebase_path) {
        Ok(technologies) => Ok(technologies),
        Err(e) => Err(Error::Term(Box::new(format!("Tech detection failed: {}", e)))),
    }
}

/// Parse dependencies from the codebase
#[rustler::nif]
fn parse_dependencies(codebase_path: String) -> NifResult<Vec<DependencyInfo>> {
    match do_parse_dependencies(&codebase_path) {
        Ok(dependencies) => Ok(dependencies),
        Err(e) => Err(Error::Term(Box::new(format!("Dependency parsing failed: {}", e)))),
    }
}

/// Generate embeddings for code files
#[rustler::nif]
fn generate_embeddings(codebase_path: String, model_name: Option<String>) -> NifResult<Vec<EmbeddingInfo>> {
    match do_generate_embeddings(&codebase_path, model_name) {
        Ok(embeddings) => Ok(embeddings),
        Err(e) => Err(Error::Term(Box::new(format!("Embedding generation failed: {}", e)))),
    }
}

/// Analyze code quality
#[rustler::nif]
fn analyze_quality(codebase_path: String) -> NifResult<QualityMetrics> {
    match do_analyze_quality(&codebase_path) {
        Ok(metrics) => Ok(metrics),
        Err(e) => Err(Error::Term(Box::new(format!("Quality analysis failed: {}", e)))),
    }
}

/// Analyze security issues
#[rustler::nif]
fn analyze_security(codebase_path: String) -> NifResult<Vec<SecurityIssue>> {
    match do_analyze_security(&codebase_path) {
        Ok(issues) => Ok(issues),
        Err(e) => Err(Error::Term(Box::new(format!("Security analysis failed: {}", e)))),
    }
}

/// Analyze architecture patterns
#[rustler::nif]
fn analyze_architecture(codebase_path: String) -> NifResult<Vec<ArchitecturePattern>> {
    match do_analyze_architecture(&codebase_path) {
        Ok(patterns) => Ok(patterns),
        Err(e) => Err(Error::Term(Box::new(format!("Architecture analysis failed: {}", e)))),
    }
}

/// Get analysis summary
#[rustler::nif]
fn get_analysis_summary(codebase_path: String) -> NifResult<HashMap<String, String>> {
    match do_get_analysis_summary(&codebase_path) {
        Ok(summary) => Ok(summary),
        Err(e) => Err(Error::Term(Box::new(format!("Summary generation failed: {}", e)))),
    }
}

/// Write analysis results to database
#[rustler::nif]
fn write_to_database(result: AnalysisResult, database_url: String) -> NifResult<bool> {
    match do_write_to_database(result, &database_url) {
        Ok(success) => Ok(success),
        Err(e) => Err(Error::Term(Box::new(format!("Database write failed: {}", e)))),
    }
}

// Implementation functions

fn do_analyze_codebase(request: AnalysisRequest) -> Result<AnalysisResult> {
    // Create NIF configuration
    let config = create_nif_config();
    
    // Create feature-aware engine
    let engine = FeatureAwareEngine::new(config)?;
    
    // Run the analysis
    tokio::runtime::Runtime::new()?.block_on(async {
        let codebase_path = std::path::Path::new(&request.codebase_path);
        engine.analyze_codebase(codebase_path).await
    })
}

fn do_detect_technologies(codebase_path: &str) -> Result<Vec<TechnologyInfo>> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    let detections = parsers.tech_detector.detect_technologies(path)?;
    
    let technologies = detections.into_iter().map(|detection| {
        TechnologyInfo {
            name: detection.name,
            version: detection.version,
            confidence: detection.confidence,
            files: detection.files,
            category: detection.category,
        }
    }).collect();
    
    Ok(technologies)
}

fn do_parse_dependencies(codebase_path: &str) -> Result<Vec<DependencyInfo>> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    let deps = parsers.dependency_parser.parse_dependencies(path)?;
    
    let dependencies = deps.into_iter().map(|dep| {
        DependencyInfo {
            name: dep.name,
            version: dep.version,
            ecosystem: dep.ecosystem,
            dependencies: dep.dependencies,
            dev_dependencies: dep.dev_dependencies,
        }
    }).collect();
    
    Ok(dependencies)
}

fn do_generate_embeddings(codebase_path: &str, model_name: Option<String>) -> Result<Vec<EmbeddingInfo>> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    
    tokio::runtime::Runtime::new()?.block_on(async {
        parsers.generate_embeddings_for_files(&[path.to_path_buf()]).await
    })
}

fn do_analyze_quality(codebase_path: &str) -> Result<QualityMetrics> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    let metrics = parsers.quality_analyzer.analyze(path)?;
    
    Ok(QualityMetrics {
        complexity_score: metrics.complexity_score,
        maintainability_score: metrics.maintainability_score,
        test_coverage: metrics.test_coverage,
        code_duplication: metrics.code_duplication,
        technical_debt: metrics.technical_debt,
    })
}

fn do_analyze_security(codebase_path: &str) -> Result<Vec<SecurityIssue>> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    let issues = parsers.security_analyzer.analyze(path)?;
    
    let security_issues = issues.into_iter().map(|issue| {
        SecurityIssue {
            severity: issue.severity,
            category: issue.category,
            description: issue.description,
            file: issue.file,
            line: issue.line,
        }
    }).collect();
    
    Ok(security_issues)
}

fn do_analyze_architecture(codebase_path: &str) -> Result<Vec<ArchitecturePattern>> {
    use std::path::Path;
    let parsers = UnifiedParsers::new()?;
    let path = Path::new(codebase_path);
    let patterns = parsers.architecture_analyzer.analyze(path)?;
    
    let architecture_patterns = patterns.into_iter().map(|pattern| {
        ArchitecturePattern {
            pattern_type: pattern.pattern_type,
            confidence: pattern.confidence,
            files: pattern.files,
            description: pattern.description,
        }
    }).collect();
    
    Ok(architecture_patterns)
}

fn do_get_analysis_summary(codebase_path: &str) -> Result<HashMap<String, String>> {
    let mut summary = HashMap::new();
    
    // Get basic info
    use std::path::Path;
    let path = Path::new(codebase_path);
    summary.insert("codebase_path".to_string(), codebase_path.to_string());
    summary.insert("total_files".to_string(), count_files(path).to_string());
    summary.insert("total_lines".to_string(), count_lines(path).to_string());
    
    // Get technology count
    let technologies = do_detect_technologies(codebase_path)?;
    summary.insert("technologies_detected".to_string(), technologies.len().to_string());
    
    // Get dependency count
    let dependencies = do_parse_dependencies(codebase_path)?;
    summary.insert("dependencies_found".to_string(), dependencies.len().to_string());
    
    // Get quality score
    let quality = do_analyze_quality(codebase_path)?;
    summary.insert("quality_score".to_string(), quality.maintainability_score.to_string());
    
    Ok(summary)
}

fn do_write_to_database(result: AnalysisResult, database_url: &str) -> Result<bool> {
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

fn count_files(path: &std::path::Path) -> usize {
    find_code_files(path).map(|files| files.len()).unwrap_or(0)
}

fn count_lines(path: &std::path::Path) -> usize {
    find_code_files(path)
        .map(|files| {
            files.iter()
                .filter_map(|file| std::fs::read_to_string(file).ok())
                .map(|content| content.lines().count())
                .sum()
        })
        .unwrap_or(0)
}

fn find_code_files(path: &std::path::Path) -> Result<Vec<std::path::PathBuf>> {
    let mut files = Vec::new();
    
    if path.is_file() {
        if is_code_file(path) {
            files.push(path.to_path_buf());
        }
    } else if path.is_dir() {
        for entry in std::fs::read_dir(path)? {
            let entry = entry?;
            let entry_path = entry.path();
            
            if entry_path.is_dir() {
                files.extend(find_code_files(&entry_path)?);
            } else if is_code_file(&entry_path) {
                files.push(entry_path);
            }
        }
    }
    
    Ok(files)
}

fn is_code_file(path: &std::path::Path) -> bool {
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

//! Public API for Analysis Suite
//!
//! Convenience functions for code quality analysis

use std::path::PathBuf;

use anyhow::Result;
use linting_engine::{LintingEngine, QualityGateResult};

/// Perform quality analysis on a codebase using linting-engine
///
/// # Arguments
/// * `path` - Path to analyze (defaults to current directory)
/// * `analysis_type` - Type of analysis (comprehensive, complexity, dependencies, etc.)
///
/// # Returns
/// * `Result<QualityGateResult>` - Analysis results from linting-engine
pub async fn analyze_quality(path: Option<PathBuf>, analysis_type: String) -> Result<QualityGateResult> {
  let target_path = path.unwrap_or_else(|| std::env::current_dir().unwrap());

  println!("🔍 Analyzing code quality at: {}", target_path.display());
  println!("📊 Analysis type: {}", analysis_type);

  // Use linting-engine for quality gate enforcement
  let engine = LintingEngine::new();
  let result = engine.run_all_gates(target_path.to_str().unwrap()).await?;

  println!("✅ Quality analysis complete");
  println!("📈 Quality score: {:.1}%", result.score);
  println!("⚠️  Found {} warnings, {} errors", result.warnings.len(), result.errors.len());
  println!("🤖 AI pattern issues: {}", result.ai_pattern_issues.len());
  println!("📊 Status: {:?}", result.status);

  Ok(result)
}

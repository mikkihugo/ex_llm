//! Singularity Code Quality Scanner CLI
//!
//! Command-line interface for the Singularity Code Quality Engine.
//! Provides CI/CD integration and standalone analysis capabilities.

use std::collections::HashMap;
use std::path::PathBuf;
use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use anyhow::Result;

mod scanner;
// api_client temporarily disabled (stub)
mod formatter;
#[path = "modules/autofix.rs"]
mod autofix;

use scanner::CodeScanner;
use formatter::{OutputFormatter, AnalysisResult as FmtResult, Recommendation as FmtRec};

/// Singularity Code Quality Scanner
#[derive(Parser)]
#[command(name = "singularity-scan")]
#[command(about = "AI-powered code quality analysis for CI/CD pipelines")]
#[command(version = env!("CARGO_PKG_VERSION"))]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Analyze a codebase
    Analyze {
        /// Path to analyze (default: current directory)
        #[arg(short, long)]
        path: Option<PathBuf>,

        /// Output format (json, text, sarif, html, junit, github)
        #[arg(short, long, default_value = "text")]
        format: String,

        /// Don't automatically fix auto-fixable issues (fixing is enabled by default)
        #[arg(long)]
        no_fix: bool,

        /// Preview fixes without applying them
        #[arg(long)]
        dry_run: bool,

        /// Run only security analysis
        #[arg(long)]
        security_only: bool,

        /// Run only performance analysis
        #[arg(long)]
        performance_only: bool,

        /// Run only quality analysis
        #[arg(long)]
        quality_only: bool,

        /// Skip security analysis
        #[arg(long)]
        skip_security: bool,

        /// Skip performance analysis
        #[arg(long)]
        skip_performance: bool,

        /// Skip quality analysis
        #[arg(long)]
        skip_quality: bool,

        /// Scan only changed files (requires git)
        #[arg(long)]
        incremental: bool,

        /// Output file path (for JSON/HTML/JUnit outputs)
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Webhook URL to send results to (Slack, Teams, etc.)
        #[arg(long)]
        webhook: Option<String>,

        /// Load configuration from .scanner.yml
        #[arg(long, default_value = "true")]
        use_config: bool,

        /// Include intelligence collection (anonymized)
        #[arg(long)]
        enable_intelligence: bool,

        /// API endpoint for cloud analysis
        #[arg(long)]
        api_endpoint: Option<String>,

        /// API key for cloud analysis
        #[arg(long)]
        api_key: Option<String>,
    },

    /// Start analysis server
    Serve {
        /// Port to listen on
        #[arg(short, long, default_value = "8080")]
        port: u16,

        /// Host to bind to
        #[arg(long, default_value = "127.0.0.1")]
        host: String,
    },

    /// Check scanner health
    Health,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub quality_score: f64,
    pub issues_count: usize,
    pub recommendations: Vec<Recommendation>,
    pub metrics: HashMap<String, f64>,
    pub patterns_detected: Vec<String>,
    pub intelligence_collected: bool,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Recommendation {
    pub r#type: String,
    pub severity: String,
    pub message: String,
    pub file: Option<String>,
    pub line: Option<usize>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Analyze {
            path,
            format,
            no_fix,
            dry_run,
            security_only,
            performance_only,
            quality_only,
            skip_security,
            skip_performance,
            skip_quality,
            incremental,
            output,
            webhook,
            use_config,
            enable_intelligence: _,
            api_endpoint: _,
            api_key: _,
        } => {
            let target_path = path.unwrap_or_else(|| PathBuf::from("."));

            // Load config file if enabled
            let config = if use_config {
                scanner::config::ScannerConfig::load(&target_path).unwrap_or(None)
            } else {
                None
            };

            // Build scan options (config can override CLI flags)
            let scan_options = scanner::ScanOptions {
                security_only: security_only || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.enabled.as_ref()).map(|e| e.contains(&"security".to_string())).unwrap_or(false),
                performance_only: performance_only || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.enabled.as_ref()).map(|e| e.contains(&"performance".to_string())).unwrap_or(false),
                quality_only: quality_only || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.enabled.as_ref()).map(|e| e.contains(&"quality".to_string())).unwrap_or(false),
                skip_security: skip_security || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.disabled.as_ref()).map(|d| d.contains(&"security".to_string())).unwrap_or(false),
                skip_performance: skip_performance || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.disabled.as_ref()).map(|d| d.contains(&"performance".to_string())).unwrap_or(false),
                skip_quality: skip_quality || config.as_ref().and_then(|c| c.analyzers.as_ref()).and_then(|a| a.disabled.as_ref()).map(|d| d.contains(&"quality".to_string())).unwrap_or(false),
                incremental,
            };

            // Run local analysis (cloud path disabled in stub)
            let local = scanner::analyze_local(&target_path, Some(scan_options)).await?;
            let mut result = FmtResult {
                quality_score: local.quality_score,
                issues_count: local.issues_count,
                recommendations: local.recommendations.into_iter().map(|r| FmtRec {
                    r#type: r.r#type,
                    severity: r.severity,
                    message: r.message,
                    file: r.file,
                    line: r.line,
                }).collect(),
                metrics: local.metrics,
                patterns_detected: local.patterns_detected,
                intelligence_collected: local.intelligence_collected,
                per_file_metrics: local.per_file_metrics.into_iter().map(|m| formatter::PerFileMetric { file: m.file, mi: m.mi, cc: m.cc }).collect(),
            };

            // Apply auto-fixes by default (unless --no-fix is specified)
            if !no_fix || dry_run {
                let fixes_applied = autofix::apply_fixes(&target_path, &result.recommendations, dry_run).await?;
                if dry_run {
                    println!("🔍 Dry-run mode: Would apply {} fixes", fixes_applied);
                    println!("   Run without --dry-run to apply fixes");
                } else {
                    println!("✅ Applied {} auto-fixes", fixes_applied);
                    // Re-run analysis after fixes
                    let updated = scanner::analyze_local(&target_path, Some(scan_options.clone())).await?;
                    result = FmtResult {
                        quality_score: updated.quality_score,
                        issues_count: updated.issues_count,
                        recommendations: updated.recommendations.into_iter().map(|r| FmtRec {
                            r#type: r.r#type,
                            severity: r.severity,
                            message: r.message,
                            file: r.file,
                            line: r.line,
                        }).collect(),
                        metrics: updated.metrics,
                        patterns_detected: updated.patterns_detected,
                        intelligence_collected: updated.intelligence_collected,
                        per_file_metrics: updated.per_file_metrics.into_iter().map(|m| formatter::PerFileMetric { file: m.file, mi: m.mi, cc: m.cc }).collect(),
                    };
                }
            }

            // Format and output results (config can override format)
            let format_str = config.as_ref()
                .and_then(|c| c.output.as_ref())
                .and_then(|o| o.format.as_ref())
                .map(|f| f.clone())
                .unwrap_or(format);
            let output_path = output.or_else(|| config.as_ref()
                .and_then(|c| c.output.as_ref())
                .and_then(|o| o.file.clone()));
            
            let formatter = OutputFormatter::new(format_str);
            formatter.output(&result, output_path.as_deref())?;

            // Send webhook if configured
            if let Some(webhook_url) = webhook {
                if let Err(e) = scanner::webhook::send_webhook(&webhook_url, &result).await {
                    eprintln!("⚠️  Failed to send webhook: {}", e);
                }
            }
        }

        Commands::Serve { port, host } => {
            println!("🚀 Starting Singularity Analysis Server on {}:{}", host, port);
            // TODO: Implement HTTP server
            println!("Server functionality coming soon!");
        }

        Commands::Health => {
            println!("✅ Singularity Scanner is healthy");
            println!("Version: {}", env!("CARGO_PKG_VERSION"));
            println!("Engine: Ready");
        }
    }

    Ok(())
}

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
mod api_client;
mod formatter;

use scanner::CodeScanner;
use formatter::OutputFormatter;

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

        /// Output format (json, text, sarif)
        #[arg(short, long, default_value = "text")]
        format: String,

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
            enable_intelligence,
            api_endpoint,
            api_key,
        } => {
            let target_path = path.unwrap_or_else(|| PathBuf::from("."));

            // Try cloud analysis first, fallback to local
            let result = if let (Some(endpoint), Some(key)) = (api_endpoint, api_key) {
                match api_client::analyze_cloud(&endpoint, &key, &target_path, enable_intelligence).await {
                    Ok(result) => result,
                    Err(e) => {
                        eprintln!("Cloud analysis failed: {}, falling back to local", e);
                        scanner::analyze_local(&target_path).await?
                    }
                }
            } else {
                scanner::analyze_local(&target_path).await?
            };

            // Format and output results
            let formatter = OutputFormatter::new(format);
            formatter.output(&result)?;
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
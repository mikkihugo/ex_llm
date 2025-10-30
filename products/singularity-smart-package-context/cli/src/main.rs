use clap::{Parser, Subcommand};
use colored::*;
use comfy_table::Table;
use singularity_smart_package_context_backend::*;
use std::io::Read;

/// Singularity Smart Package Context CLI
/// Know before you code - Package intelligence powered by community consensus
#[derive(Parser)]
#[command(name = "smartpackage")]
#[command(version = "0.1.0")]
#[command(author = "Singularity AI <support@singularity.ai>")]
#[command(about = "Know before you code - Package intelligence powered by community consensus", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Output format (json, table, text)
    #[arg(global = true, short, long, default_value = "table")]
    format: OutputFormat,

    /// Enable verbose output
    #[arg(global = true, short)]
    verbose: bool,
}

#[derive(clap::ValueEnum, Clone, Debug)]
enum OutputFormat {
    /// JSON output
    Json,
    /// Table output (default)
    Table,
    /// Plain text output
    Text,
}

#[derive(Subcommand)]
enum Commands {
    /// Get complete package information
    #[command(about = "Get package metadata, quality score, and statistics")]
    Info {
        /// Package name
        #[arg(value_name = "NAME")]
        name: String,

        /// Package ecosystem (npm, cargo, hex, pypi, go, maven, nuget)
        #[arg(short, long, default_value = "npm")]
        ecosystem: String,
    },

    /// Get code examples for a package
    #[command(about = "Get code examples from official documentation and GitHub")]
    Examples {
        /// Package name
        #[arg(value_name = "NAME")]
        name: String,

        /// Package ecosystem (npm, cargo, hex, pypi, go, maven, nuget)
        #[arg(short, long, default_value = "npm")]
        ecosystem: String,

        /// Maximum number of examples to return
        #[arg(short, long, default_value = "5")]
        limit: usize,
    },

    /// Get community consensus patterns for a package
    #[command(about = "Get best practices and patterns with confidence scores")]
    Patterns {
        /// Package name
        #[arg(value_name = "NAME")]
        name: String,

        /// Filter by pattern type
        #[arg(short, long)]
        r#type: Option<String>,
    },

    /// Search patterns across all packages
    #[command(about = "Search patterns using natural language queries")]
    Search {
        /// Search query
        #[arg(value_name = "QUERY")]
        query: String,

        /// Maximum number of results
        #[arg(short, long, default_value = "10")]
        limit: usize,
    },

    /// Analyze a file for improvements
    #[command(about = "Analyze code file and suggest improvements")]
    Analyze {
        /// File path to analyze (use - for stdin)
        #[arg(value_name = "FILE")]
        file: String,

        /// File type (detect from extension or override)
        #[arg(short, long)]
        file_type: Option<String>,
    },
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    // Create backend context
    let ctx = SmartPackageContext::new().await?;

    match cli.command {
        Commands::Info { name, ecosystem } => {
            cmd_info(&ctx, &name, &ecosystem, &cli.format, cli.verbose).await?;
        }
        Commands::Examples {
            name,
            ecosystem,
            limit,
        } => {
            cmd_examples(&ctx, &name, &ecosystem, limit, &cli.format, cli.verbose).await?;
        }
        Commands::Patterns { name, r#type: _ } => {
            cmd_patterns(&ctx, &name, &cli.format, cli.verbose).await?;
        }
        Commands::Search { query, limit } => {
            cmd_search(&ctx, &query, limit, &cli.format, cli.verbose).await?;
        }
        Commands::Analyze { file, file_type } => {
            cmd_analyze(&ctx, &file, file_type.as_deref(), &cli.format, cli.verbose).await?;
        }
    }

    Ok(())
}

/// Get package information
async fn cmd_info(
    ctx: &SmartPackageContext,
    name: &str,
    ecosystem: &str,
    format: &OutputFormat,
    _verbose: bool,
) -> anyhow::Result<()> {
    println!(
        "{}",
        format!("Fetching package info for '{}'...", name).bold().cyan()
    );

    let eco = Ecosystem::from_str(ecosystem)
        .ok_or_else(|| anyhow::anyhow!("Unknown ecosystem: {}", ecosystem))?;

    match ctx.get_package_info(name, eco).await {
        Ok(pkg) => {
            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&pkg)?);
                }
                OutputFormat::Table => {
                    print_package_info_table(&pkg);
                }
                OutputFormat::Text => {
                    print_package_info_text(&pkg);
                }
            }
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

/// Get package examples
async fn cmd_examples(
    ctx: &SmartPackageContext,
    name: &str,
    ecosystem: &str,
    limit: usize,
    format: &OutputFormat,
    _verbose: bool,
) -> anyhow::Result<()> {
    println!(
        "{}",
        format!("Fetching examples for '{}'...", name).bold().cyan()
    );

    let eco = Ecosystem::from_str(ecosystem)
        .ok_or_else(|| anyhow::anyhow!("Unknown ecosystem: {}", ecosystem))?;

    match ctx.get_package_examples(name, eco, limit).await {
        Ok(examples) => {
            if examples.is_empty() {
                println!("{}", "No examples found.".yellow());
                return Ok(());
            }

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&examples)?);
                }
                OutputFormat::Table | OutputFormat::Text => {
                    for (idx, example) in examples.iter().enumerate() {
                        print_example(idx + 1, example);
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

/// Get package patterns
async fn cmd_patterns(
    ctx: &SmartPackageContext,
    name: &str,
    format: &OutputFormat,
    _verbose: bool,
) -> anyhow::Result<()> {
    println!(
        "{}",
        format!("Fetching patterns for '{}'...", name).bold().cyan()
    );

    match ctx.get_package_patterns(name).await {
        Ok(patterns) => {
            if patterns.is_empty() {
                println!("{}", "No patterns found.".yellow());
                return Ok(());
            }

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&patterns)?);
                }
                OutputFormat::Table => {
                    print_patterns_table(&patterns);
                }
                OutputFormat::Text => {
                    for pattern in patterns {
                        print_pattern(&pattern);
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

/// Search patterns
async fn cmd_search(
    ctx: &SmartPackageContext,
    query: &str,
    limit: usize,
    format: &OutputFormat,
    _verbose: bool,
) -> anyhow::Result<()> {
    println!(
        "{}",
        format!("Searching for patterns: '{}'...", query).bold().cyan()
    );

    match ctx.search_patterns(query, limit).await {
        Ok(results) => {
            if results.is_empty() {
                println!("{}", "No patterns found matching query.".yellow());
                return Ok(());
            }

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&results)?);
                }
                OutputFormat::Table => {
                    print_search_results_table(&results);
                }
                OutputFormat::Text => {
                    for (idx, result) in results.iter().enumerate() {
                        println!("{}. {} in {}", idx + 1, result.pattern.name, result.package);
                        println!("   Relevance: {:.0}%", result.relevance * 100.0);
                        println!();
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

/// Analyze a file
async fn cmd_analyze(
    ctx: &SmartPackageContext,
    file: &str,
    file_type: Option<&str>,
    format: &OutputFormat,
    _verbose: bool,
) -> anyhow::Result<()> {
    // Read file content
    let content = if file == "-" {
        let mut buffer = String::new();
        std::io::stdin().read_to_string(&mut buffer)?;
        buffer
    } else {
        std::fs::read_to_string(file)?
    };

    // Detect file type if not provided
    let detected_type = file_type
        .map(|s| s.to_string())
        .or_else(|| {
            std::path::Path::new(file)
                .extension()
                .and_then(|ext| ext.to_str())
                .map(|s| s.to_string())
        })
        .unwrap_or_else(|| "unknown".to_string());

    println!(
        "{}",
        format!("Analyzing {} file ({} bytes)...", detected_type, content.len())
            .bold()
            .cyan()
    );

    // Try to detect file type from extension
    let file_type = FileType::from_extension(&detected_type)
        .unwrap_or(FileType::JavaScript); // Default to JavaScript if unknown

    match ctx.analyze_file(&content, file_type).await {
        Ok(suggestions) => {
            if suggestions.is_empty() {
                println!("{}", "No issues found! Code looks good.".green());
                return Ok(());
            }

            match format {
                OutputFormat::Json => {
                    println!("{}", serde_json::to_string_pretty(&suggestions)?);
                }
                OutputFormat::Table => {
                    print_suggestions_table(&suggestions);
                }
                OutputFormat::Text => {
                    for suggestion in suggestions {
                        print_suggestion(&suggestion);
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("{}", format!("Error: {}", e).red());
            std::process::exit(1);
        }
    }

    Ok(())
}

// ============================================================================
// Utility functions
// ============================================================================

fn format_number(n: usize) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, c) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            result.insert(0, ',');
        }
        result.insert(0, c);
    }
    result
}

// ============================================================================
// Display functions
// ============================================================================

fn print_package_info_table(pkg: &PackageInfo) {
    let mut table = Table::new();

    table.add_row(vec!["Package".bold().to_string(), pkg.name.clone()]);
    table.add_row(vec!["Version".bold().to_string(), pkg.version.clone()]);
    table.add_row(vec![
        "Quality Score".bold().to_string(),
        format!("{}/100", pkg.quality_score.to_string().yellow()),
    ]);

    if let Some(desc) = &pkg.description {
        table.add_row(vec!["Description".bold().to_string(), desc.clone()]);
    }

    if let Some(downloads) = &pkg.downloads {
        table.add_row(vec![
            "Downloads/Week".bold().to_string(),
            format_number(downloads.per_week),
        ]);
    }

    if let Some(license) = &pkg.license {
        table.add_row(vec!["License".bold().to_string(), license.clone()]);
    }

    println!("{table}");
}

fn print_package_info_text(pkg: &PackageInfo) {
    println!("  {} {}", "Package:".bold(), pkg.name);
    println!("  {} {}", "Version:".bold(), pkg.version);
    println!(
        "  {} {}/100",
        "Quality Score:".bold(),
        pkg.quality_score.to_string().yellow()
    );

    if let Some(desc) = &pkg.description {
        println!("  {} {}", "Description:".bold(), desc);
    }

    if let Some(downloads) = &pkg.downloads {
        println!(
            "  {} {}/week",
            "Downloads:".bold(),
            format_number(downloads.per_week)
        );
    }

    if let Some(license) = &pkg.license {
        println!("  {} {}", "License:".bold(), license);
    }
}

fn print_example(index: usize, example: &CodeExample) {
    println!();
    println!("  {}. {}", index, example.title.bold());

    if let Some(desc) = &example.description {
        println!("     {}", desc);
    }

    println!("     {}", format!("[{}]", &example.language).cyan());
    for line in example.code.lines() {
        println!("     {}", line);
    }

    if let Some(url) = &example.source_url {
        println!("     {} {}", "Source:".underline(), url);
    }
}

fn print_pattern(pattern: &PatternConsensus) {
    println!();
    println!("  {} {}", pattern.name.bold(), {
        if pattern.recommended {
            "✅ RECOMMENDED".green().to_string()
        } else {
            String::new()
        }
    });
    println!(
        "    Confidence: {:.0}% | Type: {}",
        pattern.confidence * 100.0,
        pattern.pattern_type.yellow()
    );

    println!("    {}", pattern.description);

    println!("    Observed {} times in community code", pattern.observation_count);
}

fn print_patterns_table(patterns: &[PatternConsensus]) {
    let mut table = Table::new();
    table.set_header(vec![
        "Pattern".bold().to_string(),
        "Type".bold().to_string(),
        "Confidence".bold().to_string(),
        "Observations".bold().to_string(),
    ]);

    for pattern in patterns {
        table.add_row(vec![
            pattern.name.clone(),
            pattern.pattern_type.clone(),
            format!("{:.0}%", pattern.confidence * 100.0),
            pattern.observation_count.to_string(),
        ]);
    }

    println!("{table}");
}

fn print_search_results_table(results: &[PatternMatch]) {
    let mut table = Table::new();
    table.set_header(vec![
        "Pattern".bold().to_string(),
        "Package".bold().to_string(),
        "Type".bold().to_string(),
        "Relevance".bold().to_string(),
    ]);

    for result in results {
        table.add_row(vec![
            result.pattern.name.clone(),
            result.package.clone(),
            result.pattern.pattern_type.clone(),
            format!("{:.0}%", result.relevance * 100.0),
        ]);
    }

    println!("{table}");
}

fn print_suggestion(suggestion: &Suggestion) {
    let severity_icon = match suggestion.severity {
        SeverityLevel::Error => "❌",
        SeverityLevel::Warning => "⚠️ ",
        SeverityLevel::Info => "ℹ️ ",
    };

    println!("  {} {}", severity_icon, suggestion.title.bold());
    println!("     {}", suggestion.description);

    if let Some(example) = &suggestion.example {
        println!("     Example: {}", example);
    }
}

fn print_suggestions_table(suggestions: &[Suggestion]) {
    let mut table = Table::new();
    table.set_header(vec!["Severity".bold().to_string(), "Title".bold().to_string()]);

    for suggestion in suggestions {
        let severity = match suggestion.severity {
            SeverityLevel::Error => "Error".red().to_string(),
            SeverityLevel::Warning => "Warning".yellow().to_string(),
            SeverityLevel::Info => "Info".cyan().to_string(),
        };

        table.add_row(vec![severity, suggestion.title.clone()]);
    }

    println!("{table}");
}

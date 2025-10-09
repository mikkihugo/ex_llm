//! Demonstration of CodeCapability system
//!
//! Run with: cargo run --example capability_demo
//!
//! This example shows:
//! 1. Creating code capabilities
//! 2. Storing them in the database
//! 3. Searching for capabilities
//! 4. Using SPARC knowledge interface

use code_engine::codebase::{
    CodeCapability, CapabilityKind, CapabilityLocation,
    CapabilityStorage, SparcKnowledge,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    println!("=== CodeCapability System Demo ===\n");

    // Create storage
    println!("1. Creating capability storage...");
    let storage = CapabilityStorage::new("demo-project")?;
    println!("   ✓ Storage created\n");

    // Create capabilities
    println!("2. Creating code capabilities...");

    let rust_parser = CodeCapability::new(
        "rust_parser::parse",
        "Rust Parser",
        CapabilityKind::Parser { language: "rust".to_string() },
        "pub fn parse_rust(source: &str) -> Result<ParsedFile>",
        CapabilityLocation {
            crate_name: "rust-parser".to_string(),
            module_path: "parser".to_string(),
            file_path: "crates/rust-parser/src/lib.rs".to_string(),
            line_range: (100, 250),
        },
    )
    .with_documentation("Parses Rust source code using tree-sitter")
    .with_examples(vec![
        "let result = parse_rust(source)?;".to_string(),
        "let ast = parser.parse_rust(&code)?;".to_string(),
    ]);

    let typescript_parser = CodeCapability::new(
        "typescript_parser::parse",
        "TypeScript Parser",
        CapabilityKind::Parser { language: "typescript".to_string() },
        "pub fn parse_typescript(source: &str) -> Result<ParsedFile>",
        CapabilityLocation {
            crate_name: "typescript-parser".to_string(),
            module_path: "parser".to_string(),
            file_path: "crates/typescript-parser/src/lib.rs".to_string(),
            line_range: (50, 180),
        },
    )
    .with_documentation("Parses TypeScript/JavaScript code");

    let quality_analyzer = CodeCapability::new(
        "quality::analyze",
        "Quality Analyzer",
        CapabilityKind::Analyzer { analysis_type: "quality".to_string() },
        "pub fn analyze_quality(code: &ParsedFile) -> QualityMetrics",
        CapabilityLocation {
            crate_name: "code-engine".to_string(),
            module_path: "analysis::quality".to_string(),
            file_path: "crates/code-engine/src/analysis/quality/mod.rs".to_string(),
            line_range: (1, 50),
        },
    )
    .with_documentation("Analyzes code quality metrics including complexity and maintainability");

    println!("   ✓ Created 3 capabilities\n");

    // Store capabilities
    println!("3. Storing capabilities...");
    storage.store(rust_parser).await?;
    storage.store(typescript_parser).await?;
    storage.store(quality_analyzer).await?;
    println!("   ✓ Stored 3 capabilities\n");

    // Get statistics
    println!("4. Getting statistics...");
    let stats = storage.stats().await?;
    println!("   Total capabilities: {}", stats.total_capabilities);
    println!("   By kind:");
    for (kind, count) in &stats.by_kind {
        println!("     - {}: {}", kind, count);
    }
    println!("   By crate:");
    for (crate_name, count) in &stats.by_crate {
        println!("     - {}: {}", crate_name, count);
    }
    println!();

    // Search capabilities
    println!("5. Searching for 'parser'...");
    let results = storage.search("parser").await?;
    println!("   Found {} results:", results.len());
    for result in results {
        println!("     - {} (score: {:.2})", result.capability.name, result.score);
        println!("       Location: {}", result.capability.location.file_path);
    }
    println!();

    // Find by pattern
    println!("6. Finding capabilities by kind 'Parser'...");
    let parsers = storage.find_by_pattern("Parser").await?;
    println!("   Found {} parsers:", parsers.len());
    for parser in parsers {
        println!("     - {}", parser.name);
    }
    println!();

    // SPARC Knowledge interface
    println!("7. Using SPARC Knowledge interface...");
    let sparc = SparcKnowledge::new("demo-project")?;

    let how_to = sparc.how_to("parse TypeScript").await?;
    println!("   Query: 'How do I parse TypeScript?'");
    println!("   Our capabilities: {}", how_to.our_capabilities.len());
    for cap_result in how_to.our_capabilities {
        println!("     - {}", cap_result.capability.name);
        println!("       {}", cap_result.capability.documentation);
    }
    println!();

    // Overview
    println!("8. Getting capabilities overview...");
    let overview = sparc.capabilities_overview().await?;
    println!("   Total: {} capabilities", overview.total_capabilities);
    println!("   Categories: {}", overview.by_category.len());
    println!();

    println!("=== Demo Complete ===");
    println!("\nThe capability system is working:");
    println!("✓ Store code capabilities");
    println!("✓ Search by text");
    println!("✓ Find by kind/pattern");
    println!("✓ Query via SPARC interface");
    println!("✓ Get statistics");

    Ok(())
}

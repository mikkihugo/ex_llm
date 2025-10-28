use parser_core::PolyglotCodeParser;
use std::path::Path;

fn main() {
    // Test with parser_engine's own Cargo.toml directory
    // We need to analyze from the parent directory of src/ so that
    // analyze_dependencies looks in the right place for Cargo.toml
    let project_root = Path::new("rust/parser_engine");

    // Create parser
    let mut parser = PolyglotCodeParser::new().expect("Failed to create parser");

    // Get a source file from the project
    // NOTE: The path must be inside the project root so its parent can find Cargo.toml
    let test_file = project_root.join("src/lib.rs");

    println!(
        "Analyzing: {:?}",
        test_file
            .canonicalize()
            .unwrap_or_else(|_| test_file.clone())
    );

    match parser.analyze_file(&test_file) {
        Ok(result) => {
            println!("\n✅ Analysis successful!");
            println!("  File: {}", result.file_path);
            println!("  Language: {}", result.language);

            if let Some(deps) = &result.dependency_analysis {
                println!("\n📦 Dependency Analysis:");
                println!("  Dependencies: {}", deps.dependencies.len());
                if deps.dependencies.len() > 0 && deps.dependencies.len() <= 5 {
                    for dep in &deps.dependencies[..deps.dependencies.len().min(5)] {
                        println!("    - {}", dep);
                    }
                    if deps.dependencies.len() > 5 {
                        println!("    ... and {} more", deps.dependencies.len() - 5);
                    }
                }

                println!("  Dev Dependencies: {}", deps.dev_dependencies.len());

                println!("  Total: {}", deps.total_dependencies);

                if let Some(manifest) = &deps.manifest_file {
                    println!("  Manifest: {}", manifest);
                }

                if let Some(frameworks) = &deps.frameworks {
                    if frameworks.len() > 0 {
                        println!("\n🎯 Frameworks detected: {}", frameworks.len());
                        for fw in frameworks {
                            println!("    - {} ({})", fw.name, fw.framework_type);
                        }
                    }
                }
            } else {
                println!("No dependency analysis available");
            }
        }
        Err(e) => {
            eprintln!("❌ Error analyzing file: {}", e);
        }
    }
}

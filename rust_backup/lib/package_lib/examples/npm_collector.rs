//! NPM Collector Example
//!
//! Demonstrates how to use the NPM collector to download and analyze
//! npm packages without needing GitHub access.
//!
//! Usage:
//! ```bash
//! cargo run --example npm_collector --features npm-collector
//! ```

#[cfg(feature = "npm-collector")]
fn main() {
  use fact_tools::collectors::npm::NpmCollector;
  use fact_tools::collectors::PackageCollector;
  use fact_tools::storage::versioned_storage::VersionedFactStorage;

  let rt = tokio::runtime::Runtime::new().unwrap();

  rt.block_on(async {
    println!("🔍 NPM Collector Example\n");

    // Initialize collector with default cache
    let collector =
      NpmCollector::default_cache().expect("Failed to create npm collector");

    println!("✅ NPM Collector initialized");
    println!("   Ecosystem: {}\n", collector.ecosystem());

    // Example 1: Check if package exists
    println!("📦 Example 1: Check package existence");
    match collector.exists("lodash", "4.17.21").await {
      Ok(exists) => println!("   lodash@4.17.21 exists: {}", exists),
      Err(e) => println!("   Error: {}", e),
    }

    // Example 2: Get latest version
    println!("\n📦 Example 2: Get latest version");
    match collector.latest_version("react").await {
      Ok(version) => println!("   Latest React version: {}", version),
      Err(e) => println!("   Error: {}", e),
    }

    // Example 3: List available versions
    println!("\n📦 Example 3: List available versions");
    match collector.available_versions("is-odd").await {
      Ok(versions) => {
        println!("   Available versions of is-odd:");
        for v in versions.iter().take(5) {
          println!("     - {}", v);
        }
        if versions.len() > 5 {
          println!("     ... and {} more", versions.len() - 5);
        }
      }
      Err(e) => println!("   Error: {}", e),
    }

    // Example 4: Collect and analyze a package
    println!("\n📦 Example 4: Collect and analyze package");
    println!("   Downloading and analyzing is-odd@3.0.1...");

    match collector.collect("is-odd", "3.0.1").await {
      Ok(fact_data) => {
        println!("   ✅ Collection complete!");
        println!("   Package: {} v{}", fact_data.tool, fact_data.version);
        println!("   Ecosystem: {}", fact_data.ecosystem);
        println!("   Source: {}", fact_data.source);

        if let Some(code_index) = &fact_data.code_index {
          println!("\n   📊 Code Analysis:");
          println!("     Files analyzed: {}", code_index.files.len());
          println!("     Exports found: {}", code_index.exports.len());

          println!("\n   📄 Files:");
          for file in &code_index.files {
            println!(
              "     - {} ({} lines, {} exports)",
              file.path,
              file.line_count,
              file.exports.len()
            );
          }

          println!("\n   🔗 Exports:");
          for export in code_index.exports.iter().take(10) {
            println!("     - {} ({})", export.name, export.export_type);
          }

          println!("\n   📝 Naming Conventions:");
          println!("     Files: {}", code_index.naming_conventions.file_naming);
          println!(
            "     Functions: {}",
            code_index.naming_conventions.function_naming
          );
          println!(
            "     Classes: {}",
            code_index.naming_conventions.class_naming
          );
        }

        if !fact_data.snippets.is_empty() {
          println!("\n   💡 Code Snippets: {}", fact_data.snippets.len());
          for snippet in fact_data.snippets.iter().take(3) {
            println!("     - {}", snippet.title);
          }
        }
      }
      Err(e) => println!("   ❌ Error collecting package: {}", e),
    }

    // Example 5: Store in versioned storage
    println!("\n📦 Example 5: Store facts in versioned storage");

    let storage_dir = dirs::cache_dir()
      .expect("Failed to get cache dir")
      .join("sparc-engine")
      .join("fact-storage");

    std::fs::create_dir_all(&storage_dir).unwrap();

    match VersionedFactStorage::new(&storage_dir).await {
      Ok(storage) => {
        println!("   ✅ Storage initialized: {}", storage_dir.display());

        // Collect and store a package
        if let Ok(fact_data) = collector.collect("is-odd", "3.0.1").await {
          let key = fact_tools::storage::FactKey::new(
            "is-odd".to_string(),
            "3.0.1".to_string(),
            "npm".to_string(),
          );

          if let Err(e) = storage.store_fact(&key, &fact_data).await {
            println!("   ❌ Failed to store fact: {}", e);
          } else {
            println!("   ✅ Stored fact: fact:npm:is-odd:3.0.1");

            // Retrieve it back
            match storage.get_fact(&key).await {
              Ok(Some(retrieved)) => {
                println!(
                  "   ✅ Retrieved fact: {} v{}",
                  retrieved.tool, retrieved.version
                );
              }
              Ok(None) => println!("   ⚠️  Fact not found"),
              Err(e) => println!("   ❌ Error retrieving fact: {}", e),
            }
          }
        }
      }
      Err(e) => println!("   ❌ Failed to initialize storage: {}", e),
    }

    println!("\n✅ Example complete!");
  });
}

#[cfg(not(feature = "npm-collector"))]
fn main() {
  eprintln!("❌ This example requires the 'npm-collector' feature.");
  eprintln!(
    "Run with: cargo run --example npm_collector --features npm-collector"
  );
}

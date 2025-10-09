//! NPM Collector Integration Tests
//!
//! Tests the NPM collector's ability to download and analyze packages
//! from registry.npmjs.org without needing GitHub access

#[cfg(feature = "npm-collector")]
mod npm_tests {
  use fact_tools::collectors::npm::NpmCollector;
  use fact_tools::collectors::PackageCollector;
  use fact_tools::storage::versioned_storage::VersionedFactStorage;
  use tempfile::TempDir;

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_collector_basic() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), true);

    assert_eq!(collector.ecosystem(), "npm");
  }

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_package_exists() {
    let collector = NpmCollector::default_cache().unwrap();

    // Test popular package
    let exists = collector.exists("lodash", "4.17.21").await;
    assert!(exists.is_ok());
  }

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_latest_version() {
    let collector = NpmCollector::default_cache().unwrap();

    // Get latest version of lodash
    let latest = collector.latest_version("lodash").await;
    assert!(latest.is_ok());
    assert!(!latest.unwrap().is_empty());
  }

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_available_versions() {
    let collector = NpmCollector::default_cache().unwrap();

    // Get all versions of a small package
    let versions = collector.available_versions("is-odd").await;
    assert!(versions.is_ok());
    assert!(!versions.unwrap().is_empty());
  }

  #[tokio::test]
  #[ignore] // Requires network access - downloads ~100KB
  async fn test_npm_collect_small_package() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), true);

    // Collect a small utility package
    let result = collector.collect("is-odd", "3.0.1").await;

    assert!(result.is_ok());
    let fact_data = result.unwrap();

    // Verify basic metadata
    assert_eq!(fact_data.tool, "is-odd");
    assert_eq!(fact_data.version, "3.0.1");
    assert_eq!(fact_data.ecosystem, "npm");
    assert_eq!(fact_data.source, "npm:package");

    // Verify code index was created
    assert!(fact_data.code_index.is_some());
    let code_index = fact_data.code_index.unwrap();
    assert!(!code_index.files.is_empty());

    // Verify exports were extracted
    assert!(!code_index.exports.is_empty());

    println!("Collected {} files", code_index.files.len());
    println!("Found {} exports", code_index.exports.len());
    println!("Extracted {} snippets", fact_data.snippets.len());
  }

  #[tokio::test]
  #[ignore] // Requires network access - downloads ~500KB
  async fn test_npm_collect_with_typescript() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), true);

    // Collect a TypeScript package with .d.ts files
    let result = collector.collect("axios", "1.6.0").await;

    assert!(result.is_ok());
    let fact_data = result.unwrap();

    assert_eq!(fact_data.tool, "axios");
    assert_eq!(fact_data.ecosystem, "npm");

    // Verify TypeScript files were analyzed
    let code_index = fact_data.code_index.unwrap();
    let has_ts_files = code_index
      .files
      .iter()
      .any(|f| f.language == "typescript" || f.path.ends_with(".d.ts"));

    assert!(has_ts_files, "Should have TypeScript definition files");

    println!("Analyzed {} files for axios", code_index.files.len());
  }

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_collector_with_storage() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), true);

    // Initialize versioned storage
    let storage_dir = temp_dir.path().join("storage");
    std::fs::create_dir_all(&storage_dir).unwrap();

    let storage = VersionedFactStorage::new(&storage_dir).await.unwrap();

    // Collect package
    let fact_data = collector.collect("is-odd", "3.0.1").await.unwrap();

    // Store in versioned storage
    let key = fact_tools::storage::FactKey::new(
      "is-odd".to_string(),
      "3.0.1".to_string(),
      "npm".to_string(),
    );

    storage.store_fact(&key, &fact_data).await.unwrap();

    // Retrieve from storage
    let retrieved = storage.get_fact(&key).await.unwrap();
    assert!(retrieved.is_some());

    let retrieved_data = retrieved.unwrap();
    assert_eq!(retrieved_data.tool, "is-odd");
    assert_eq!(retrieved_data.version, "3.0.1");

    println!("Successfully stored and retrieved npm package facts");
  }

  #[tokio::test]
  #[ignore] // Requires network access
  async fn test_npm_collector_extracts_examples() {
    let temp_dir = TempDir::new().unwrap();
    let collector = NpmCollector::new(temp_dir.path().to_path_buf(), true);

    // Some packages have examples/ or test/ directories
    // This is a test to verify we extract code snippets from them
    let result = collector.collect("commander", "11.0.0").await;

    if let Ok(fact_data) = result {
      println!("Extracted {} code snippets", fact_data.snippets.len());

      if !fact_data.snippets.is_empty() {
        println!("Sample snippet: {}", fact_data.snippets[0].title);
      }
    }
  }
}

//! Integration tests for semantic versioning with TechStack data
//!
//! Tests the combination of:
//! - Semantic version matching (14.1.0 → 14.1 → 14)
//! - TechStack storage and retrieval
//! - Version-specific technology stacks

use fact_tools::storage::versioned_storage::VersionedFactStorage;
use fact_tools::storage::{
  FactData, FactKey, Factstorage, Framework, FrameworkUsage, LanguageInfo,
  TechStack,
};
use std::time::SystemTime;
use tempfile::TempDir;

fn create_detected_framework_for_version(major: u32, minor: u32) -> TechStack {
  TechStack {
    frameworks: vec![Framework {
      name: format!("Next.js {}.{}", major, minor),
      version: format!("{}.{}.0", major, minor),
      usage: FrameworkUsage::Primary,
    }],
    languages: vec![LanguageInfo {
      name: "TypeScript".to_string(),
      version: format!("5.{}.0", minor),
      file_count: 100 + (minor * 10),
      line_count: 10000 + (minor * 1000) as u32,
    }],
    build_system: if major >= 14 {
      "turbo".to_string()
    } else {
      "webpack".to_string()
    },
    workspace_type: "monorepo".to_string(),
    package_manager: if minor >= 1 {
      "pnpm".to_string()
    } else {
      "npm".to_string()
    },
    databases: vec!["PostgreSQL".to_string()],
    message_brokers: vec![],
  }
}

fn create_fact_with_profile(
  tool: &str,
  version: &str,
  ecosystem: &str,
  profile: TechStack,
) -> FactData {
  FactData {
    tool: tool.to_string(),
    version: version.to_string(),
    ecosystem: ecosystem.to_string(),
    documentation: format!("{} {} with tech profile", tool, version),
    snippets: vec![],
    examples: vec![],
    best_practices: vec![],
    troubleshooting: vec![],
    github_sources: vec![],
    dependencies: vec![],
    tags: vec!["framework".to_string()],
    last_updated: SystemTime::now(),
    source: "test".to_string(),
    code_index: None,
    detected_framework: Some(profile),
    prompt_templates: vec![],
    quick_starts: vec![],
    migration_guides: vec![],
    usage_patterns: vec![],
    cli_commands: vec![],
    semantic_embedding: None,
    code_embedding: None,
    graph_embedding: None,
    relationships: vec![],
    usage_stats: Default::default(),
    execution_history: vec![],
    learning_data: Default::default(),
  }
}

#[tokio::test]
async fn test_semver_fallback_with_detected_framework() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store versions: 14.0.0, 14.1.0, 14.2.0
  for (major, minor) in [(14, 0), (14, 1), (14, 2)] {
    let version = format!("{}.{}.0", major, minor);
    let profile = create_detected_framework_for_version(major, minor);
    let key =
      FactKey::new("nextjs".to_string(), version.clone(), "npm".to_string());
    let data = create_fact_with_profile("nextjs", &version, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Query "14.1.5" (doesn't exist) - should fallback to 14.1.0
  let result = storage
    .get_with_fallback("npm", "nextjs", "14.1.5")
    .await
    .unwrap();
  assert!(result.is_some());

  let (data, version_match) = result.unwrap();
  assert!(data.version.starts_with("14.1"));
  assert!(!version_match.is_exact);

  // Verify tech profile exists and shows correct build tool
  let profile = data.detected_framework.unwrap();
  assert_eq!(profile.build_system, "turbo");
  assert_eq!(profile.package_manager, "pnpm");
}

#[tokio::test]
async fn test_query_versions_with_different_detected_frameworks() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store versions with evolving tech profiles
  for (major, minor) in [(13, 0), (13, 5), (14, 0), (14, 1), (14, 2), (15, 0)] {
    let version = format!("{}.{}.0", major, minor);
    let profile = create_detected_framework_for_version(major, minor);
    let key =
      FactKey::new("nextjs".to_string(), version.clone(), "npm".to_string());
    let data = create_fact_with_profile("nextjs", &version, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Query all 14.x versions
  let matches = storage.query_versions("npm", "nextjs", "14").await.unwrap();
  assert_eq!(matches.len(), 3); // 14.0.0, 14.1.0, 14.2.0

  // Verify all have tech profiles
  for (version, data) in &matches {
    assert!(data.detected_framework.is_some());
    let profile = data.detected_framework.as_ref().unwrap();
    assert_eq!(profile.build_system, "turbo");
    println!(
      "Version {} uses package manager: {}",
      version, profile.package_manager
    );
  }

  // Verify package manager evolution
  assert_eq!(
    matches[0]
      .1
      .detected_framework
      .as_ref()
      .unwrap()
      .package_manager,
    "npm"
  );
  assert_eq!(
    matches[1]
      .1
      .detected_framework
      .as_ref()
      .unwrap()
      .package_manager,
    "pnpm"
  );
}

#[tokio::test]
async fn test_get_latest_with_detected_framework() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store versions in random order
  for (major, minor) in [(14, 2), (14, 0), (15, 0), (14, 1)] {
    let version = format!("{}.{}.0", major, minor);
    let profile = create_detected_framework_for_version(major, minor);
    let key =
      FactKey::new("nextjs".to_string(), version.clone(), "npm".to_string());
    let data = create_fact_with_profile("nextjs", &version, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Get latest should return 15.0.0
  let result = storage.get_latest_version("npm", "nextjs").await.unwrap();
  assert!(result.is_some());

  let (version, data) = result.unwrap();
  assert_eq!(version, "15.0.0");

  // Verify latest has tech profile
  let profile = data.detected_framework.unwrap();
  assert!(profile.frameworks[0].name.contains("15"));
}

#[tokio::test]
async fn test_compare_detected_frameworks_across_versions() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store two versions with different tech profiles
  for (major, minor) in [(13, 0), (14, 1)] {
    let version = format!("{}.{}.0", major, minor);
    let profile = create_detected_framework_for_version(major, minor);
    let key =
      FactKey::new("nextjs".to_string(), version.clone(), "npm".to_string());
    let data = create_fact_with_profile("nextjs", &version, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Compare versions
  let (data1, data2) = storage
    .compare_versions("npm", "nextjs", "13.0.0", "14.1.0")
    .await
    .unwrap();

  let profile1 = data1.detected_framework.unwrap();
  let profile2 = data2.detected_framework.unwrap();

  // Verify build system changed
  assert_eq!(profile1.build_system, "webpack");
  assert_eq!(profile2.build_system, "turbo");

  // Verify package manager changed
  assert_eq!(profile1.package_manager, "npm");
  assert_eq!(profile2.package_manager, "pnpm");
}

#[tokio::test]
async fn test_semver_with_detected_framework_migration() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Simulate migration path: 13.5 → 14.0 → 14.1
  let migration_versions = vec!["13.5.0", "14.0.0", "14.1.0"];

  for version_str in &migration_versions {
    let parts: Vec<&str> = version_str.split('.').collect();
    let major: u32 = parts[0].parse().unwrap();
    let minor: u32 = parts[1].parse().unwrap();

    let profile = create_detected_framework_for_version(major, minor);
    let key = FactKey::new(
      "nextjs".to_string(),
      version_str.to_string(),
      "npm".to_string(),
    );
    let data = create_fact_with_profile("nextjs", version_str, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Query migration path
  for version in migration_versions {
    let result = storage
      .get_with_fallback("npm", "nextjs", version)
      .await
      .unwrap();
    assert!(result.is_some());

    let (data, _) = result.unwrap();
    assert_eq!(data.version, version);
    assert!(data.detected_framework.is_some());
  }
}

#[tokio::test]
async fn test_major_version_detected_framework_differences() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store major versions: 13, 14, 15
  for major in [13, 14, 15] {
    let version = format!("{}.0.0", major);
    let profile = create_detected_framework_for_version(major, 0);
    let key =
      FactKey::new("nextjs".to_string(), version.clone(), "npm".to_string());
    let data = create_fact_with_profile("nextjs", &version, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Query each major version pattern
  for major in [13, 14, 15] {
    let pattern = format!("{}", major);
    let matches = storage
      .query_versions("npm", "nextjs", &pattern)
      .await
      .unwrap();
    assert!(!matches.is_empty());

    let profile = matches[0].1.detected_framework.as_ref().unwrap();
    println!(
      "Major {} uses build system: {}",
      major, profile.build_system
    );

    // Version 13 uses webpack, 14+ uses turbo
    if major >= 14 {
      assert_eq!(profile.build_system, "turbo");
    } else {
      assert_eq!(profile.build_system, "webpack");
    }
  }
}

#[tokio::test]
async fn test_detected_framework_with_semver_pre_release() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store stable and pre-release versions
  for version_str in ["14.0.0", "14.1.0", "14.2.0-canary.1", "14.2.0"] {
    let parts: Vec<&str> =
      version_str.split(|c| c == '.' || c == '-').collect();
    let major: u32 = parts[0].parse().unwrap();
    let minor: u32 = parts[1].parse().unwrap_or(0);

    let profile = create_detected_framework_for_version(major, minor);
    let key = FactKey::new(
      "nextjs".to_string(),
      version_str.to_string(),
      "npm".to_string(),
    );
    let data = create_fact_with_profile("nextjs", version_str, "npm", profile);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Query all 14.2 versions (including pre-release)
  let versions = storage.get_tool_versions("npm", "nextjs").await.unwrap();
  assert!(versions.contains(&"14.2.0-canary.1".to_string()));
  assert!(versions.contains(&"14.2.0".to_string()));
}

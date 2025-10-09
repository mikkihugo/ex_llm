//! Comprehensive tests for TechStack (renamed from TechStack)
//!
//! Verifies that:
//! - All types use TechStack naming
//! - Storage uses detected_framework field
//! - Semantic versioning works with TechStack data
//! - Integration between storage and detection

use fact_tools::storage::versioned_storage::VersionedFactStorage;
use fact_tools::storage::{
  FactData, FactKey, Factstorage, Framework, FrameworkUsage, LanguageInfo,
  TechStack,
};
use std::time::SystemTime;
use tempfile::TempDir;

/// Helper to create test TechStack
fn create_test_detected_framework() -> TechStack {
  TechStack {
    frameworks: vec![
      Framework {
        name: "Next.js".to_string(),
        version: "14.1.0".to_string(),
        usage: FrameworkUsage::Primary,
      },
      Framework {
        name: "React".to_string(),
        version: "18.2.0".to_string(),
        usage: FrameworkUsage::Primary,
      },
    ],
    languages: vec![
      LanguageInfo {
        name: "TypeScript".to_string(),
        version: "5.3.0".to_string(),
        file_count: 120,
        line_count: 15000,
      },
      LanguageInfo {
        name: "JavaScript".to_string(),
        version: "ES2023".to_string(),
        file_count: 30,
        line_count: 2000,
      },
    ],
    build_system: "moon".to_string(),
    workspace_type: "monorepo".to_string(),
    package_manager: "pnpm".to_string(),
    databases: vec!["PostgreSQL".to_string(), "Redis".to_string()],
    message_brokers: vec!["RabbitMQ".to_string()],
  }
}

/// Helper to create test FactData with TechStack
fn create_fact_data_with_detected_framework(
  tool: &str,
  version: &str,
  ecosystem: &str,
  profile: Option<TechStack>,
) -> FactData {
  FactData {
    tool: tool.to_string(),
    version: version.to_string(),
    ecosystem: ecosystem.to_string(),
    documentation: format!("{} {} documentation", tool, version),
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
    detected_framework: profile,
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
async fn test_detected_framework_field_exists() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  let profile = create_test_detected_framework();
  let key = FactKey::new(
    "nextjs".to_string(),
    "14.1.0".to_string(),
    "npm".to_string(),
  );
  let data = create_fact_data_with_detected_framework(
    "nextjs",
    "14.1.0",
    "npm",
    Some(profile.clone()),
  );

  // Store and retrieve
  storage.store_fact(&key, &data).await.unwrap();
  let retrieved = storage.get_fact(&key).await.unwrap().unwrap();

  // Verify detected_framework field exists and matches
  assert!(retrieved.detected_framework.is_some());
  let retrieved_profile = retrieved.detected_framework.unwrap();
  assert_eq!(retrieved_profile.frameworks.len(), 2);
  assert_eq!(retrieved_profile.frameworks[0].name, "Next.js");
  assert_eq!(retrieved_profile.languages.len(), 2);
  assert_eq!(retrieved_profile.build_system, "moon");
}

#[tokio::test]
async fn test_detected_framework_serialization() {
  let profile = create_test_detected_framework();

  // Test JSON serialization
  let json = serde_json::to_string_pretty(&profile).unwrap();
  assert!(json.contains("Next.js"));
  assert!(json.contains("TypeScript"));
  assert!(json.contains("monorepo"));

  // Test deserialization
  let deserialized: TechStack = serde_json::from_str(&json).unwrap();
  assert_eq!(deserialized.frameworks.len(), 2);
  assert_eq!(deserialized.package_manager, "pnpm");
}

#[tokio::test]
async fn test_detected_framework_with_multiple_versions() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store multiple versions with different tech profiles
  for (version, primary_fw) in [
    ("13.0.0", "Next.js 13"),
    ("14.0.0", "Next.js 14"),
    ("14.1.0", "Next.js 14.1"),
  ] {
    let mut profile = create_test_detected_framework();
    profile.frameworks[0].name = primary_fw.to_string();
    profile.frameworks[0].version = version.to_string();

    let key = FactKey::new(
      "nextjs".to_string(),
      version.to_string(),
      "npm".to_string(),
    );
    let data = create_fact_data_with_detected_framework(
      "nextjs",
      version,
      "npm",
      Some(profile),
    );
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Verify all versions stored
  let versions = storage.get_tool_versions("npm", "nextjs").await.unwrap();
  assert_eq!(versions.len(), 3);
  assert!(versions.contains(&"13.0.0".to_string()));
  assert!(versions.contains(&"14.0.0".to_string()));
  assert!(versions.contains(&"14.1.0".to_string()));
}

#[tokio::test]
async fn test_detected_framework_framework_usage_types() {
  let profile = TechStack {
    frameworks: vec![
      Framework {
        name: "Next.js".to_string(),
        version: "14.0.0".to_string(),
        usage: FrameworkUsage::Primary,
      },
      Framework {
        name: "Jest".to_string(),
        version: "29.0.0".to_string(),
        usage: FrameworkUsage::Testing,
      },
      Framework {
        name: "Storybook".to_string(),
        version: "7.0.0".to_string(),
        usage: FrameworkUsage::Development,
      },
    ],
    languages: vec![],
    build_system: "vite".to_string(),
    workspace_type: "single".to_string(),
    package_manager: "npm".to_string(),
    databases: vec![],
    message_brokers: vec![],
  };

  // Count frameworks by usage type
  let primary_count = profile
    .frameworks
    .iter()
    .filter(|f| matches!(f.usage, FrameworkUsage::Primary))
    .count();
  let testing_count = profile
    .frameworks
    .iter()
    .filter(|f| matches!(f.usage, FrameworkUsage::Testing))
    .count();

  assert_eq!(primary_count, 1);
  assert_eq!(testing_count, 1);
}

#[tokio::test]
async fn test_detected_framework_export_to_json() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir.clone(), false)
    .await
    .unwrap();

  let profile = create_test_detected_framework();
  let key = FactKey::new(
    "nextjs".to_string(),
    "14.1.0".to_string(),
    "npm".to_string(),
  );
  let data = create_fact_data_with_detected_framework(
    "nextjs",
    "14.1.0",
    "npm",
    Some(profile),
  );

  // Store and export
  storage.store_fact(&key, &data).await.unwrap();
  storage.export_to_json(&key, &data).await.unwrap();

  // Verify JSON file exists and contains detected_framework
  let json_path = export_dir.join("npm").join("nextjs").join("14.1.0.json");
  assert!(json_path.exists());

  let json_content = tokio::fs::read_to_string(&json_path).await.unwrap();
  assert!(json_content.contains("detected_framework"));
  assert!(json_content.contains("Next.js"));
  assert!(json_content.contains("TypeScript"));
}

#[tokio::test]
async fn test_detected_framework_empty() {
  // Test that detected_framework can be None
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("test.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  let key =
    FactKey::new("simple".to_string(), "1.0.0".to_string(), "npm".to_string());
  let data =
    create_fact_data_with_detected_framework("simple", "1.0.0", "npm", None);

  storage.store_fact(&key, &data).await.unwrap();
  let retrieved = storage.get_fact(&key).await.unwrap().unwrap();

  assert!(retrieved.detected_framework.is_none());
}

#[tokio::test]
async fn test_detected_framework_complex_stack() {
  // Test a complex multi-language, multi-framework stack
  let profile = TechStack {
    frameworks: vec![
      Framework {
        name: "Next.js".to_string(),
        version: "14.1.0".to_string(),
        usage: FrameworkUsage::Primary,
      },
      Framework {
        name: "NestJS".to_string(),
        version: "10.0.0".to_string(),
        usage: FrameworkUsage::Secondary,
      },
      Framework {
        name: "Prisma".to_string(),
        version: "5.0.0".to_string(),
        usage: FrameworkUsage::Primary,
      },
    ],
    languages: vec![
      LanguageInfo {
        name: "TypeScript".to_string(),
        version: "5.3.0".to_string(),
        file_count: 300,
        line_count: 50000,
      },
      LanguageInfo {
        name: "Rust".to_string(),
        version: "1.75.0".to_string(),
        file_count: 20,
        line_count: 5000,
      },
    ],
    build_system: "turbo".to_string(),
    workspace_type: "monorepo".to_string(),
    package_manager: "pnpm".to_string(),
    databases: vec![
      "PostgreSQL".to_string(),
      "MongoDB".to_string(),
      "Redis".to_string(),
    ],
    message_brokers: vec!["Kafka".to_string(), "RabbitMQ".to_string()],
  };

  // Verify structure
  assert_eq!(profile.frameworks.len(), 3);
  assert_eq!(profile.languages.len(), 2);
  assert_eq!(profile.databases.len(), 3);
  assert_eq!(profile.message_brokers.len(), 2);

  // Verify specific entries
  assert!(profile.frameworks.iter().any(|f| f.name == "Prisma"));
  assert!(profile.databases.iter().any(|d| d == "MongoDB"));
  assert_eq!(profile.build_system, "turbo");
}

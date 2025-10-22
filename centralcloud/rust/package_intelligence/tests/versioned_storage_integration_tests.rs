//! Integration tests for VersionedFactStorage
//!
//! Tests complete workflows:
//! - Store → Query → Export → Import
//! - Concurrent operations
//! - Large datasets
//! - JSON exports for git tracking

use fact_tools::storage::versioned_storage::VersionedFactStorage;
use fact_tools::storage::{
  FactData, FactKey, Factstorage, Framework, FrameworkUsage, TechStack,
};
use std::sync::Arc;
use std::time::SystemTime;
use tempfile::TempDir;
use tokio::task::JoinSet;

fn create_simple_fact(tool: &str, version: &str, ecosystem: &str) -> FactData {
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
    tags: vec![ecosystem.to_string()],
    last_updated: SystemTime::now(),
    source: "integration_test".to_string(),
    code_index: None,
    detected_framework: None,
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
async fn test_complete_workflow() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("workflow.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir.clone(), false)
    .await
    .unwrap();

  // 1. Store facts
  let versions = vec!["14.0.0", "14.1.0", "14.2.0", "15.0.0"];
  for version in &versions {
    let key = FactKey::new(
      "nextjs".to_string(),
      version.to_string(),
      "npm".to_string(),
    );
    let data = create_simple_fact("nextjs", version, "npm");
    storage.store_fact(&key, &data).await.unwrap();
  }

  // 2. Query versions
  let all_versions = storage.get_tool_versions("npm", "nextjs").await.unwrap();
  assert_eq!(all_versions.len(), 4);

  // 3. Query with pattern
  let v14_versions =
    storage.query_versions("npm", "nextjs", "14").await.unwrap();
  assert_eq!(v14_versions.len(), 3);

  // 4. Get with fallback
  let result = storage
    .get_with_fallback("npm", "nextjs", "14.1.5")
    .await
    .unwrap();
  assert!(result.is_some());

  // 5. Get latest
  let (latest_version, _) = storage
    .get_latest_version("npm", "nextjs")
    .await
    .unwrap()
    .unwrap();
  assert_eq!(latest_version, "15.0.0");

  // 6. Export to JSON
  for version in &versions {
    let key = FactKey::new(
      "nextjs".to_string(),
      version.to_string(),
      "npm".to_string(),
    );
    let data = create_simple_fact("nextjs", version, "npm");
    storage.export_to_json(&key, &data).await.unwrap();
  }

  // 7. Verify JSON files exist
  for version in &versions {
    let json_path = export_dir
      .join("npm")
      .join("nextjs")
      .join(format!("{}.json", version));
    assert!(json_path.exists());
  }

  // 8. Import from JSON
  let import_key = FactKey::new(
    "nextjs".to_string(),
    "14.0.0".to_string(),
    "npm".to_string(),
  );
  let imported = storage.import_from_json(&import_key).await.unwrap();
  assert!(imported.is_some());
}

#[tokio::test]
async fn test_concurrent_writes() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("concurrent.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = Arc::new(
    VersionedFactStorage::new(db_path, export_dir, false)
      .await
      .unwrap(),
  );

  let mut set = JoinSet::new();

  // Spawn 10 concurrent write tasks
  for i in 0..10 {
    let storage_clone = storage.clone();
    set.spawn(async move {
      let version = format!("1.{}.0", i);
      let key =
        FactKey::new("test".to_string(), version.clone(), "npm".to_string());
      let data = create_simple_fact("test", &version, "npm");
      storage_clone.store_fact(&key, &data).await.unwrap();
    });
  }

  // Wait for all tasks
  while let Some(result) = set.join_next().await {
    result.unwrap();
  }

  // Verify all versions stored
  let versions = storage.get_tool_versions("npm", "test").await.unwrap();
  assert_eq!(versions.len(), 10);
}

#[tokio::test]
async fn test_large_dataset() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("large.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store 100 versions across 10 tools
  let tools = vec![
    "react", "vue", "angular", "svelte", "solid", "preact", "lit", "alpine",
    "htmx", "astro",
  ];

  for tool in &tools {
    for minor in 0..10 {
      let version = format!("1.{}.0", minor);
      let key =
        FactKey::new(tool.to_string(), version.clone(), "npm".to_string());
      let data = create_simple_fact(tool, &version, "npm");
      storage.store_fact(&key, &data).await.unwrap();
    }
  }

  // Verify storage stats
  let stats = storage.stats().await.unwrap();
  assert_eq!(stats.total_entries, 100);
  assert_eq!(stats.ecosystems.get("npm"), Some(&100));

  // Verify we can query any tool
  for tool in &tools {
    let versions = storage.get_tool_versions("npm", tool).await.unwrap();
    assert_eq!(versions.len(), 10);
  }
}

#[tokio::test]
async fn test_json_export_import_round_trip() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("roundtrip.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Create fact with all fields populated
  let mut data = create_simple_fact("nextjs", "14.1.0", "npm");
  data.detected_framework = Some(TechStack {
    frameworks: vec![Framework {
      name: "Next.js".to_string(),
      version: "14.1.0".to_string(),
      usage: FrameworkUsage::Primary,
    }],
    languages: vec![],
    build_system: "turbo".to_string(),
    workspace_type: "monorepo".to_string(),
    package_manager: "pnpm".to_string(),
    databases: vec!["PostgreSQL".to_string()],
    message_brokers: vec![],
  });

  let key = FactKey::new(
    "nextjs".to_string(),
    "14.1.0".to_string(),
    "npm".to_string(),
  );

  // Store and export
  storage.store_fact(&key, &data).await.unwrap();
  storage.export_to_json(&key, &data).await.unwrap();

  // Import from JSON
  let imported = storage.import_from_json(&key).await.unwrap().unwrap();

  // Verify data matches
  assert_eq!(imported.tool, data.tool);
  assert_eq!(imported.version, data.version);
  assert!(imported.detected_framework.is_some());

  let imported_profile = imported.detected_framework.unwrap();
  let original_profile = data.detected_framework.unwrap();
  assert_eq!(
    imported_profile.frameworks.len(),
    original_profile.frameworks.len()
  );
  assert_eq!(imported_profile.build_system, original_profile.build_system);
}

#[tokio::test]
async fn test_auto_export_mode() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("auto_export.redb");
  let export_dir = temp_dir.path().join("exports");

  // Enable auto-export
  let storage = VersionedFactStorage::new(db_path, export_dir.clone(), true)
    .await
    .unwrap();

  let key =
    FactKey::new("react".to_string(), "18.2.0".to_string(), "npm".to_string());
  let data = create_simple_fact("react", "18.2.0", "npm");

  // Store should automatically export
  storage.store_fact(&key, &data).await.unwrap();

  // Verify JSON file was created automatically
  let json_path = export_dir.join("npm").join("react").join("18.2.0.json");
  assert!(json_path.exists());
}

#[tokio::test]
async fn test_export_all_facts() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("export_all.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir.clone(), false)
    .await
    .unwrap();

  // Store multiple facts
  let facts = vec![
    ("react", "18.2.0", "npm"),
    ("vue", "3.3.0", "npm"),
    ("angular", "17.0.0", "npm"),
  ];

  for (tool, version, ecosystem) in &facts {
    let key = FactKey::new(
      tool.to_string(),
      version.to_string(),
      ecosystem.to_string(),
    );
    let data = create_simple_fact(tool, version, ecosystem);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Export all
  let count = storage.export_all_to_json().await.unwrap();
  assert_eq!(count, 3);

  // Verify all JSON files exist
  for (tool, version, ecosystem) in &facts {
    let json_path = export_dir
      .join(ecosystem)
      .join(tool)
      .join(format!("{}.json", version));
    assert!(json_path.exists());
  }
}

#[tokio::test]
async fn test_search_and_list_operations() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("search.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store facts across multiple ecosystems
  let facts = vec![
    ("react", "18.2.0", "npm"),
    ("rails", "7.0.0", "gem"),
    ("django", "4.2.0", "pypi"),
  ];

  for (tool, version, ecosystem) in &facts {
    let key = FactKey::new(
      tool.to_string(),
      version.to_string(),
      ecosystem.to_string(),
    );
    let data = create_simple_fact(tool, version, ecosystem);
    storage.store_fact(&key, &data).await.unwrap();
  }

  // List tools by ecosystem
  let npm_tools = storage.list_tools("npm").await.unwrap();
  assert_eq!(npm_tools.len(), 1);
  assert_eq!(npm_tools[0].tool, "react");

  // Search with prefix
  let results = storage.search_tools("npm:").await.unwrap();
  assert_eq!(results.len(), 1);

  // Get all facts
  let all_facts = storage.get_all_facts().await.unwrap();
  assert_eq!(all_facts.len(), 3);
}

#[tokio::test]
async fn test_delete_and_cleanup() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("delete.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  let key =
    FactKey::new("test".to_string(), "1.0.0".to_string(), "npm".to_string());
  let data = create_simple_fact("test", "1.0.0", "npm");

  // Store
  storage.store_fact(&key, &data).await.unwrap();
  assert!(storage.exists(&key).await.unwrap());

  // Delete
  storage.delete_fact(&key).await.unwrap();
  assert!(!storage.exists(&key).await.unwrap());

  // Verify it's gone
  let retrieved = storage.get_fact(&key).await.unwrap();
  assert!(retrieved.is_none());
}

#[tokio::test]
async fn test_version_comparison_workflow() {
  let temp_dir = TempDir::new().unwrap();
  let db_path = temp_dir.path().join("compare.redb");
  let export_dir = temp_dir.path().join("exports");

  let storage = VersionedFactStorage::new(db_path, export_dir, false)
    .await
    .unwrap();

  // Store two versions
  for version in ["13.0.0", "14.0.0"] {
    let key = FactKey::new(
      "nextjs".to_string(),
      version.to_string(),
      "npm".to_string(),
    );
    let data = create_simple_fact("nextjs", version, "npm");
    storage.store_fact(&key, &data).await.unwrap();
  }

  // Compare versions
  let (v13, v14) = storage
    .compare_versions("npm", "nextjs", "13.0.0", "14.0.0")
    .await
    .unwrap();

  assert_eq!(v13.version, "13.0.0");
  assert_eq!(v14.version, "14.0.0");
}

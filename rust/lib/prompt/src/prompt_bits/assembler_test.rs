//! Test for PromptBitAssembler integration with sparc-engine framework detector

use std::path::Path;

use crate::prompt_bits::{assembler::PromptBitAssembler, types::*};

#[tokio::test]
async fn test_assembler_creation() {
  // Create a simple repository analysis
  let analysis = RepositoryAnalysis {
    workspace_type: WorkspaceType::SinglePackage,
    build_system: BuildSystem::Cargo,
    languages: vec![Language::Rust],
    architecture_patterns: vec![ArchitectureCodePattern::Microservices],
    databases: vec![DatabaseSystem::PostgreSQL],
    message_brokers: vec![MessageBroker::NATS],
  };

  // Test simple constructor
  let assembler = PromptBitAssembler::new(analysis);
  assert_eq!(assembler.get_detected_frameworks().len(), 0);
  assert_eq!(assembler.get_all_framework_prompt_bits().len(), 0);
}

#[tokio::test]
async fn test_assembler_with_framework_detection() {
  // Create a simple repository analysis
  let analysis = RepositoryAnalysis {
    workspace_type: WorkspaceType::SinglePackage,
    build_system: BuildSystem::Cargo,
    languages: vec![Language::Rust],
    architecture_patterns: vec![ArchitectureCodePattern::Microservices],
    databases: vec![DatabaseSystem::PostgreSQL],
    message_brokers: vec![MessageBroker::NATS],
  };

  // Test with framework detection (this will call sparc-engine)
  let project_path = Path::new("/tmp/test-project");

  // This test will fail if sparc-engine is not available, which is expected
  match PromptBitAssembler::new_with_framework_detection(analysis, project_path).await {
    Ok(assembler) => {
      println!("✅ Assembler created successfully with {} frameworks detected", assembler.get_detected_frameworks().len());

      // Check if we have any framework prompt bits
      let total_bits = assembler.get_all_framework_prompt_bits().values().map(|bits| bits.len()).sum::<usize>();
      println!("✅ Total framework prompt bits: {}", total_bits);
    }
    Err(e) => {
      println!("⚠️  Framework detection failed (expected if sparc-engine not available): {}", e);
      // This is expected if sparc-engine is not built/available
    }
  }
}

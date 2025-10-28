//! Multi-tech detection example
//!
//! Shows how the detector handles monorepos with multiple technologies

use std::path::Path;
use tool_doc_index::detection::{FrameworkInfo, TechnologyDetector};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
  // Detect technologies in Singularity monorepo
  let detector = TechnologyDetector::new()?;
  let result = detector
    .detect(Path::new("/home/mhugo/code/singularity"))
    .await?;

  println!("🔍 Multi-Tech Detection Results:\n");

  // Show all detected frameworks
  println!("Detected {} frameworks:", result.frameworks.len());
  for framework in &result.frameworks {
    println!("\n  📦 {}", framework.name);
    println!("     Type: {}", framework.framework_type);
    println!("     Confidence: {:.0}%", framework.confidence * 100.0);
    println!("     Files: {:?}", framework.detected_files);
  }

  // Show primary framework
  if let Some(primary) = &result.primary_framework {
    println!("\n🎯 Primary Framework: {}", primary.name);
  }

  // Example output for Singularity:
  //
  // 🔍 Multi-Tech Detection Results:
  //
  // Detected 5 frameworks:
  //
  //   📦 rust
  //      Type: backend
  //      Confidence: 90%
  //      Files: ["rust/Cargo.toml", "rust/tool_doc_index/src/lib.rs"]
  //
  //   📦 elixir
  //      Type: backend
  //      Confidence: 95%
  //      Files: ["singularity_app/mix.exs", "singularity_app/lib/singularity.ex"]
  //
  //   📦 gleam
  //      Type: backend
  //      Confidence: 85%
  //      Files: ["gleam_modules/htdag/gleam.toml"]
  //
  //   📦 typescript
  //      Type: fullstack
  //      Confidence: 80%
  //      Files: ["ai-server/package.json", "ai-server/src/server.ts"]
  //
  //   📦 nats
  //      Type: messaging
  //      Confidence: 75%
  //      Files: ["ai-server/src/nats.ts", "rust/db_service/src/nats_db_service.rs"]
  //
  // 🎯 Primary Framework: elixir

  Ok(())
}

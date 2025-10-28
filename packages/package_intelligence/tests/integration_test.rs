//! Integration tests - Run with `cargo test --test integration_test`

use anyhow::Result;

#[tokio::test]
async fn test_detector_works_standalone() -> Result<()> {
  // Detector should work WITHOUT NATS (standalone mode)
  std::env::remove_var("NATS_URL");

  let detector = tool_doc_index::detection::LayeredDetector::new().await?;
  let results = detector.detect(std::path::Path::new(".")).await?;

  // Should detect Rust in this project
  assert!(results.iter().any(|r| r.technology_id == "rust"));

  println!("✅ Standalone detection works");
  Ok(())
}

#[tokio::test]
async fn test_templates_load() -> Result<()> {
  let detector = tool_doc_index::detection::LayeredDetector::new().await?;

  // Try to detect - this will fail if templates didn't load
  let results = detector.detect(std::path::Path::new(".")).await?;

  assert!(
    !results.is_empty(),
    "Templates should have loaded and detected something"
  );

  println!(
    "✅ Templates loaded: {} technologies detected",
    results.len()
  );
  Ok(())
}

#[tokio::test]
async fn test_confidence_levels() -> Result<()> {
  let detector = tool_doc_index::detection::LayeredDetector::new().await?;
  let results = detector.detect(std::path::Path::new(".")).await?;

  for result in &results {
    assert!(
      result.confidence >= 0.0 && result.confidence <= 1.0,
      "Confidence must be 0-1, got: {}",
      result.confidence
    );

    assert!(
      !result.evidence.is_empty(),
      "Should have evidence for detection"
    );
  }

  println!("✅ Confidence scoring works");
  Ok(())
}

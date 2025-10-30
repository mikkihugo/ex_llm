//! Architecture Engine Usage Example
//!
//! This example shows how to use the consolidated Rust architecture engine
//! that replaces the Elixir architecture_engine.

use std::path::Path;
use code_quality_engine::{
    architecture::{
        PatternDetectorRegistry, PatternDetectorOrchestrator,
        FrameworkDetector, TechnologyDetector, ServiceArchitectureDetector,
        PatternType, DetectionOptions
    },
    infrastructure::InfrastructureDetector,
    orchestrators::{AnalysisOrchestrator, AnalysisInput, AnalysisType},
    registry::MetaRegistry,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🚀 Starting Architecture Engine Consolidation Demo");

    // 1. Set up pattern detectors
    let mut registry = PatternDetectorRegistry::new();

    // Register all detectors
    registry.register(FrameworkDetector::new());
    registry.register(TechnologyDetector::new());
    registry.register(ServiceArchitectureDetector::new());
    registry.register(InfrastructureDetector::new());

    println!("✅ Registered {} pattern detectors", registry.registered_types().len());

    // 2. Create pattern orchestrator
    let pattern_orchestrator = PatternDetectorOrchestrator::new(registry);

    // 3. Set up analysis orchestrator
    let mut analysis_orchestrator = AnalysisOrchestrator::new(pattern_orchestrator.registry);

    // Register analyzers (would implement FeedbackAnalyzer, QualityAnalyzer, etc.)
    // analysis_orchestrator.register_analyzer(FeedbackAnalyzer::new());
    // analysis_orchestrator.register_analyzer(QualityAnalyzer::new());

    // 4. Set up meta registry
    let mut meta_registry = MetaRegistry::new();

    // 5. Run pattern detection on current project
    let project_path = Path::new("/home/mhugo/code/singularity");
    let detection_opts = DetectionOptions {
        min_confidence: 0.5,
        max_results: Some(10),
        use_learned_patterns: true,
        max_depth: 3,
    };

    println!("🔍 Detecting patterns in project...");
    let pattern_results = pattern_orchestrator.detect_all(
        project_path,
        None, // All pattern types
        &detection_opts,
    ).await?;

    // Display results
    for (pattern_type, detections) in &pattern_results {
        println!("📋 {}: {} detections", format!("{:?}", pattern_type), detections.len());
        for detection in detections.iter().take(3) {
            println!("  • {} ({:.1}%) - {}",
                detection.name,
                detection.confidence * 100.0,
                detection.description.as_deref().unwrap_or(""));
        }
        if detections.len() > 3 {
            println!("  ... and {} more", detections.len() - 3);
        }
    }

    // 6. Run full analysis orchestration
    println!("🎯 Running full analysis orchestration...");
    let analysis_input = AnalysisInput {
        path: project_path.to_path_buf(),
        pattern_types: None,
        detection_options: detection_opts,
        analysis_options: Default::default(),
        context: Default::default(),
    };

    let analysis_results = analysis_orchestrator.analyze_all(
        &analysis_input,
        Some(vec![AnalysisType::Feedback, AnalysisType::Quality]),
    ).await?;

    println!("📊 Analysis complete:");
    println!("  • Pattern results: {} types", analysis_results.pattern_results.as_ref().map(|r| r.len()).unwrap_or(0));
    println!("  • Analysis results: {} types", analysis_results.analysis_results.len());
    println!("  • Errors: {}", analysis_results.errors.len());

    // 7. Learn from results
    println!("🧠 Learning from detection results...");
    analysis_orchestrator.learn_all(&analysis_results).await?;
    println!("✅ Learning complete");

    // 8. Sync with CentralCloud (placeholder)
    println!("☁️  Syncing with CentralCloud...");
    meta_registry.sync_with_centralcloud().await?;
    println!("✅ CentralCloud sync complete");

    println!("🎉 Architecture Engine consolidation demo complete!");
    println!("");
    println!("Key Benefits:");
    println!("• All analysis in Rust = better performance");
    println!("• Single library for Elixir to consume via NIFs");
    println!("• CentralCloud integration for cross-instance learning");
    println!("• Unified API for all pattern detection and analysis");
    println!("• No more duplicating quality analysis between Elixir/Rust");

    Ok(())
}
//! Example: AI-powered framework detection
//!
//! This example demonstrates how to use the AI analysis feature
//! for detecting unknown frameworks when other methods fail.

use architecture_engine::tech_detector::TechDetector;
use tracing::{info, warn};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    // Create detector with AI client (requires NATS server running)
    let detector = match TechDetector::new_with_ai("nats://127.0.0.1:4222").await {
        Ok(detector) => {
            info!("✅ TechDetector created with AI analysis capability");
            detector
        }
        Err(e) => {
            warn!("⚠️  Failed to create detector with AI: {}", e);
            warn!("   Falling back to basic detector (no AI analysis)");
            TechDetector::new().await?
        }
    };

    // Example: Analyze some unknown code
    let code_sample = r#"
        import { createApp } from 'vue'
        import App from './App.vue'
        
        const app = createApp(App)
        app.mount('#app')
    "#;

    let patterns = vec![
        "createApp".to_string(),
        "vue".to_string(),
        ".mount(".to_string(),
    ];

    info!("🔍 Analyzing code sample with AI...");
    info!("Code: {}", code_sample);
    info!("Patterns: {:?}", patterns);

    match detector
        .identify_unknown_framework_with_ai(code_sample, &patterns)
        .await
    {
        Ok(framework) => {
            info!("🎯 AI Analysis Result:");
            info!("   Framework: {}", framework.name);
            if let Some(version) = &framework.version {
                info!("   Version: {}", version);
            }
            info!("   Confidence: {:.2}", framework.confidence);
            info!("   Method: {:?}", framework.detected_by);
            info!("   Evidence: {:?}", framework.evidence);
        }
        Err(e) => {
            warn!("❌ AI analysis failed: {}", e);
            warn!("   This might be because:");
            warn!("   - NATS server is not running");
            warn!("   - AI server is not available");
            warn!("   - No AI client was configured");
        }
    }

    Ok(())
}

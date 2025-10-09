//! Consolidated Detector Service
//!
//! Single Rust service that consolidates all 3 detector systems:
//! 1. Elixir FrameworkDetector (removed)
//! 2. Rust LayeredDetector (package_registry_indexer) - KEPT
//! 3. Rust TechnologyDetection (analysis_suite) - KEPT as wrapper
//!
//! Exposes unified NATS interface for framework detection.

use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::{info, warn, error};

mod layered_detector;
mod nats_service;

use layered_detector::LayeredDetector;
use nats_service::DetectorNatsService;

#[derive(Debug, Deserialize)]
pub struct DetectionRequest {
    pub patterns: Vec<String>,
    pub context: String,
    pub codebase_id: Option<String>,
    pub correlation_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct DetectionResponse {
    pub frameworks: Vec<DetectedFramework>,
    pub confidence: f32,
    pub detection_level: String,
    pub llm_used: bool,
    pub correlation_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct DetectedFramework {
    pub name: String,
    pub version: Option<String>,
    pub confidence: f32,
    pub evidence: Vec<String>,
    pub reasoning: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    info!("🔍 Starting Consolidated Detector Service...");

    // Get NATS URL from environment
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());

    info!("📡 Connecting to NATS at: {}", nats_url);

    // Connect to NATS
    let nats_client = async_nats::connect(&nats_url).await?;
    info!("✅ Connected to NATS");

    // Initialize layered detector
    let detector = Arc::new(LayeredDetector::new().await?);
    info!("✅ Layered detector initialized");

    // Start NATS service
    let nats_service = DetectorNatsService::new(nats_client, detector);
    nats_service.start().await?;

    info!("🚀 Consolidated Detector Service running");
    
    // Keep the service running
    tokio::signal::ctrl_c().await?;
    info!("🛑 Shutting down Consolidated Detector Service");

    Ok(())
}
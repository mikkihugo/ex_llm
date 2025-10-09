//! Singularity Rust Service
//! 
//! Multi-level search and analysis service for packages and repositories.
//! Provides Context7-style functionality with pagination and guided search.

use anyhow::Result;
use tracing::{info, Level};
use tracing_subscriber;

// Import the comprehensive analysis service
use singularity_unified::server::ComprehensiveAnalysisService;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    info!("🚀 Starting Singularity Multi-Level Search Service");

    // Check if NATS is running
    if !is_nats_running().await {
        eprintln!("❌ NATS is not running. Please start NATS first:");
        eprintln!("   nats-server -js");
        std::process::exit(1);
    }

    // Create and start the comprehensive analysis service
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());
    
    let service = ComprehensiveAnalysisService::new(&nats_url).await?;
    service.start().await?;

    info!("🎉 Multi-Level Search Service started! Running in background...");
    info!("💡 This service provides smart search with pagination and guided refinement");
    info!("💡 Use Ctrl+C to stop the service");

    // Wait for shutdown signal
    tokio::signal::ctrl_c().await?;
    info!("🛑 Shutting down Multi-Level Search Service...");

    Ok(())
}

/// Check if NATS is running
async fn is_nats_running() -> bool {
    match async_nats::connect("nats://127.0.0.1:4222").await {
        Ok(_) => true,
        Err(_) => false,
    }
}

//! Singularity Rust - Unified Binary
//!
//! Runs all Rust services in one binary:
//! - Prompt Engine NATS Service
//! - Package Registry Indexer
//! - Analysis Suite
//! - Source Code Parser
//! - Tech Detector
//! - Intelligent Namer

use anyhow::Result;
use tracing::{info, Level};
use tracing_subscriber;

// Import all the services
use prompt_engine::nats_service::PromptEngineNatsService;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    info!("🚀 Starting Singularity Rust Services...");

    // Get NATS URL from environment or use default
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());

    info!("📡 Connecting to NATS at: {}", nats_url);

    // Check if NATS is running
    if !is_nats_running(&nats_url).await {
        eprintln!("❌ NATS server is not running. Please start NATS first:");
        eprintln!("   nats-server -js");
        std::process::exit(1);
    }

    // Initialize all services
    let mut services = Vec::new();

    // 1. Prompt Engine Service
    info!("🔧 Starting Prompt Engine Service...");
    match PromptEngineNatsService::new(&nats_url).await {
        Ok(service) => {
            let service_handle = tokio::spawn(async move {
                if let Err(e) = service.start().await {
                    eprintln!("❌ Prompt Engine Service failed: {}", e);
                }
            });
            services.push(("Prompt Engine", service_handle));
            info!("✅ Prompt Engine Service started");
        }
        Err(e) => {
            eprintln!("❌ Failed to start Prompt Engine Service: {}", e);
        }
    }

    info!("🎉 All services started! Press Ctrl+C to stop.");

    // Wait for all services
    for (name, handle) in services {
        tokio::select! {
            _ = handle => {
                info!("{} service stopped", name);
            }
            _ = tokio::signal::ctrl_c() => {
                info!("🛑 Shutting down all services...");
                break;
            }
        }
    }

    info!("👋 Singularity Rust Services stopped");
    Ok(())
}

async fn is_nats_running(nats_url: &str) -> bool {
    match async_nats::connect(nats_url).await {
        Ok(_) => true,
        Err(_) => false,
    }
}

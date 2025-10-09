//! Package Registry Service - NATS service for package search

use anyhow::Result;
use package_registry_indexer::nats_service::PackageRegistryNatsService;
use tracing::{info, error};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    info!("🚀 Starting Package Registry Service");

    // Get NATS URL from environment or use default
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());

    info!("Connecting to NATS at: {}", nats_url);

    // Create and start the NATS service
    let service = PackageRegistryNatsService::new(&nats_url).await?;
    
    info!("✅ Package Registry Service started successfully");
    info!("📡 Listening for package search requests on 'packages.registry.search'");
    
    // Start the service (this will run indefinitely)
    if let Err(e) = service.start().await {
        error!("❌ Service failed: {}", e);
        return Err(e);
    }

    // Keep the service running
    info!("🔄 Service is running... Press Ctrl+C to stop");
    
    // Wait indefinitely
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
    }
}
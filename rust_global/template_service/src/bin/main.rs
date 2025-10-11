//! Global Template Service Binary
//!
//! Runs the global template service that loads templates from templates_data/
//! and provides them to all Singularity instances via NATS.

use anyhow::Result;
use template_service::GlobalTemplateService;
use tracing::{info, error};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    info!("Starting Global Template Service...");
    
    // Get configuration from environment
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".to_string());
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://localhost/singularity".to_string());
    
    info!("Configuration:");
    info!("  NATS URL: {}", nats_url);
    info!("  Database URL: {}", database_url);
    
    // Create and start the global template service
    let service = GlobalTemplateService::new(&nats_url, &database_url).await?;
    service.start().await?;
    
    info!("Global Template Service started successfully!");
    info!("Listening for template requests on NATS...");
    
    // Keep running until interrupted
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Global Template Service...");
    
    Ok(())
}

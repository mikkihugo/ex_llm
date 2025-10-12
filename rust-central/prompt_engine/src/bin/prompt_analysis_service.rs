//! Prompt Engine NATS Service Binary
//!
//! Runs the prompt engine as a standalone NATS service.

use anyhow::Result;
use prompt::nats_service::PromptEngineNatsService;
use tracing::{info, Level};
use tracing_subscriber;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt().with_max_level(Level::INFO).init();

    info!("Starting Prompt Engine NATS Service...");

    // Get NATS URL from environment or use default
    let nats_url =
        std::env::var("NATS_URL").unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());

    // Create and start the service
    let service = PromptEngineNatsService::new(&nats_url).await?;
    service.start().await?;

    info!("Prompt Engine NATS Service is running. Press Ctrl+C to stop.");

    // Keep the service running
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Prompt Engine NATS Service...");

    Ok(())
}

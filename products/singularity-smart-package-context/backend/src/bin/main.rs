use anyhow::Result;
use singularity_smart_package_context_backend::SmartPackageContext;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tracing::{info, warn};

/// Binary entry point for Smart Package Context backend
///
/// This binary can be:
/// 1. Called directly (dev/debug)
/// 2. Wrapped by MCP server (Week 3)
/// 3. Wrapped by VS Code extension (Week 4-5)
/// 4. Wrapped by CLI tool (Week 6)
/// 5. Wrapped by HTTP API (Week 7)
#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();

    info!("Starting Singularity Smart Package Context Backend v{}",
        singularity_smart_package_context_backend::VERSION);

    // Create the Smart Package Context
    let ctx = SmartPackageContext::new().await?;

    // Health check
    let health = ctx.health_check().await?;
    info!("{}", health.message);

    // For now, just demonstrate the API is working
    // In Week 3+, this will be wrapped by MCP/VS Code/CLI/API

    // Start a simple TCP listener (placeholder for future server)
    let addr: SocketAddr = "127.0.0.1:0".parse()?;
    let listener = TcpListener::bind(&addr).await?;
    let local_addr = listener.local_addr()?;

    info!("Backend listening on {}", local_addr);
    info!("Ready for channel wrappers (MCP/VS Code/CLI/API)");

    // Keep the server running
    let accept_loop = async {
        loop {
            match listener.accept().await {
                Ok((_socket, _addr)) => {
                    info!("Connection received");
                    // In production, would handle the connection
                    // For now just log it
                }
                Err(e) => {
                    warn!("Error accepting connection: {}", e);
                }
            }
        }
    };

    // Run indefinitely
    accept_loop.await;

    Ok(())
}

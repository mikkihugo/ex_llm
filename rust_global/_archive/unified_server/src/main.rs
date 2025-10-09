//! Unified Server - Launches all Singularity services
//! 
//! This server manages:
//! - NATS Server
//! - PostgreSQL Database  
//! - Rust Package Registry Service
//! - Elixir Phoenix Application

use anyhow::Result;
use std::process::{Command, Stdio};
use std::time::Duration;
use tokio::time::sleep;
use tracing::{info, error, warn};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    info!("🚀 Starting Singularity Unified Server");
    info!("{}", "=".repeat(60));

    // Check if we're in the right directory
    if !std::path::Path::new("singularity_app").exists() {
        error!("❌ Please run from the singularity project root directory");
        std::process::exit(1);
    }

    // Start services in order
    start_nats().await?;
    start_postgres().await?;
    start_rust_package_registry().await?;
    start_elixir_app().await?;

    info!("✅ All services started successfully!");
    info!("🌐 Elixir app: http://localhost:4000");
    info!("📡 NATS: nats://localhost:4222");
    info!("🗄️  PostgreSQL: localhost:5432");
    info!("📦 Package Registry: Running via NATS");

    // Keep the server running
    keep_alive().await;

    Ok(())
}

async fn start_nats() -> Result<()> {
    info!("🔧 Starting NATS Server...");
    
    // Check if NATS is already running
    if is_process_running("nats-server") {
        info!("✅ NATS Server already running");
        return Ok(());
    }

    // Start NATS in background
    let mut child = Command::new("nats-server")
        .args(&["-js", "-sd", ".nats", "-p", "4222"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    // Wait for NATS to start
    sleep(Duration::from_secs(2)).await;
    
    // Check if it's still running
    if child.try_wait()?.is_none() {
        info!("✅ NATS Server started");
    } else {
        error!("❌ Failed to start NATS Server");
        return Err(anyhow::anyhow!("NATS Server failed to start"));
    }

    Ok(())
}

async fn start_postgres() -> Result<()> {
    info!("🔧 Checking PostgreSQL...");
    
    // Check if PostgreSQL is already running
    if is_process_running("postgres") {
        info!("✅ PostgreSQL already running");
        return Ok(());
    }

    warn!("⚠️  PostgreSQL not running - please start it manually");
    warn!("   Run: nix develop (to start PostgreSQL)");
    
    // Try to connect to verify it's working
    match test_postgres_connection().await {
        Ok(_) => {
            info!("✅ PostgreSQL connection successful");
            Ok(())
        }
        Err(e) => {
            error!("❌ PostgreSQL connection failed: {}", e);
            Err(e)
        }
    }
}

async fn start_rust_package_registry() -> Result<()> {
    info!("🔧 Starting Rust Package Registry Service...");
    
    // Check if already running
    if is_process_running("package-registry-service") {
        info!("✅ Rust Package Registry Service already running");
        return Ok(());
    }

    // Start Rust service in background
    let mut child = Command::new("bash")
        .args(&["-c", "cd rust/package_registry_indexer && RUST_LOG=info cargo run --bin package-registry-service"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    // Wait for Rust service to start
    sleep(Duration::from_secs(3)).await;
    
    // Check if it's still running
    if child.try_wait()?.is_none() {
        info!("✅ Rust Package Registry Service started");
    } else {
        error!("❌ Failed to start Rust Package Registry Service");
        return Err(anyhow::anyhow!("Rust Package Registry Service failed to start"));
    }

    Ok(())
}

async fn start_elixir_app() -> Result<()> {
    info!("🔧 Starting Elixir Phoenix Application...");
    
    // Check if already running
    if is_process_running("beam.smp") {
        info!("✅ Elixir application already running");
        return Ok(());
    }

    // Start Elixir app in background
    let mut child = Command::new("bash")
        .args(&["-c", "cd singularity_app && mix phx.server"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    // Wait for Elixir app to start
    sleep(Duration::from_secs(5)).await;
    
    // Check if it's still running
    if child.try_wait()?.is_none() {
        info!("✅ Elixir Phoenix Application started");
    } else {
        error!("❌ Failed to start Elixir Phoenix Application");
        return Err(anyhow::anyhow!("Elixir Phoenix Application failed to start"));
    }

    Ok(())
}

async fn keep_alive() {
    info!("🔄 Server is running... Press Ctrl+C to stop");
    
    // Set up signal handler for graceful shutdown
    tokio::signal::ctrl_c().await.expect("Failed to listen for ctrl+c");
    
    info!("🛑 Shutting down unified server...");
    stop_all_services().await;
    info!("✅ Shutdown complete");
}

async fn stop_all_services() {
    info!("🛑 Stopping all services...");
    
    // Stop Elixir app
    if let Err(e) = Command::new("pkill").args(&["-f", "beam.smp"]).output() {
        warn!("Failed to stop Elixir app: {}", e);
    }
    
    // Stop Rust service
    if let Err(e) = Command::new("pkill").args(&["-f", "package-registry-service"]).output() {
        warn!("Failed to stop Rust service: {}", e);
    }
    
    // Note: We don't stop NATS and PostgreSQL as they might be used by other processes
    info!("✅ Services stopped");
}

fn is_process_running(process_name: &str) -> bool {
    Command::new("pgrep")
        .args(&["-f", process_name])
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

async fn test_postgres_connection() -> Result<()> {
    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://postgres:password@localhost:5432/singularity".to_string());
    
    let (client, connection) = tokio_postgres::connect(&db_url, tokio_postgres::NoTls).await?;
    
    // Spawn connection task
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            error!("PostgreSQL connection error: {}", e);
        }
    });
    
    // Test query
    let _rows = client.query("SELECT 1", &[]).await?;
    
    Ok(())
}
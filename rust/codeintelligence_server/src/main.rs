//! Singularity Unified Server
//! 
//! A comprehensive server that manages all Singularity services:
//! - NATS Server
//! - PostgreSQL Database  
//! - Rust Package Registry Service
//! - Elixir Phoenix Application
//! - Health monitoring and service management

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::process::{Command, Stdio};
use std::time::Duration;
use tokio::time::sleep;
use tracing::{info, error, warn};

#[derive(Parser)]
#[command(name = "singularity-server")]
#[command(about = "Singularity Unified Server - Manages all services")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Start all services
    Start {
        /// Start in background mode
        #[arg(short, long)]
        daemon: bool,
        /// Skip service checks
        #[arg(short, long)]
        force: bool,
    },
    /// Stop all services
    Stop,
    /// Restart all services
    Restart,
    /// Check service status
    Status,
    /// Health check
    Health,
    /// Start specific service
    StartService {
        /// Service name (nats, postgres, rust, elixir)
        service: String,
    },
    /// Stop specific service
    StopService {
        /// Service name (nats, postgres, rust, elixir)
        service: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let cli = Cli::parse();

    // Check if we're in the right directory
    if !std::path::Path::new("singularity_app").exists() {
        error!("❌ Please run from the singularity project root directory");
        std::process::exit(1);
    }

    match cli.command {
        Commands::Start { daemon, force } => start_all_services(daemon, force).await,
        Commands::Stop => stop_all_services().await,
        Commands::Restart => restart_all_services().await,
        Commands::Status => check_status().await,
        Commands::Health => health_check().await,
        Commands::StartService { service } => start_service(&service).await,
        Commands::StopService { service } => stop_service(&service).await,
    }
}

async fn start_all_services(daemon: bool, force: bool) -> Result<()> {
    info!("🚀 Starting Singularity Unified Server");
    info!("{}", "=".repeat(60));

    if !force {
        // Check if services are already running
        let status = check_services_status().await;
        if status.nats && status.postgres && status.rust && status.elixir {
            info!("✅ All services are already running");
            return Ok(());
        }
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

    if daemon {
        info!("🔄 Running in daemon mode...");
        keep_alive().await;
    } else {
        info!("🔄 Server is running... Press Ctrl+C to stop");
        keep_alive().await;
    }

    Ok(())
}

async fn stop_all_services() -> Result<()> {
    info!("🛑 Stopping all Singularity services...");
    
    stop_service("elixir").await?;
    stop_service("rust").await?;
    // Note: We don't stop NATS and PostgreSQL as they might be used by other processes
    
    info!("✅ All services stopped");
    Ok(())
}

async fn restart_all_services() -> Result<()> {
    info!("🔄 Restarting all services...");
    stop_all_services().await?;
    sleep(Duration::from_secs(2)).await;
    start_all_services(false, true).await
}

async fn check_status() -> Result<()> {
    info!("📊 Checking service status...");
    
    let status = check_services_status().await;
    
    println!("┌─────────────────┬──────────┐");
    println!("│ Service         │ Status   │");
    println!("├─────────────────┼──────────┤");
    println!("│ NATS Server     │ {} │", if status.nats { "✅ Running" } else { "❌ Stopped" });
    println!("│ PostgreSQL      │ {} │", if status.postgres { "✅ Running" } else { "❌ Stopped" });
    println!("│ Rust Registry   │ {} │", if status.rust { "✅ Running" } else { "❌ Stopped" });
    println!("│ Elixir App      │ {} │", if status.elixir { "✅ Running" } else { "❌ Stopped" });
    println!("└─────────────────┴──────────┘");
    
    Ok(())
}

async fn health_check() -> Result<()> {
    info!("🏥 Performing health check...");
    
    let mut healthy = true;
    
    // Check NATS
    if is_process_running("nats-server") {
        info!("✅ NATS Server: Healthy");
    } else {
        error!("❌ NATS Server: Not running");
        healthy = false;
    }
    
    // Check PostgreSQL
    match test_postgres_connection().await {
        Ok(_) => info!("✅ PostgreSQL: Healthy"),
        Err(e) => {
            error!("❌ PostgreSQL: Connection failed - {}", e);
            healthy = false;
        }
    }
    
    // Check Rust service
    if is_process_running("package-registry-service") {
        info!("✅ Rust Package Registry: Healthy");
    } else {
        error!("❌ Rust Package Registry: Not running");
        healthy = false;
    }
    
    // Check Elixir app
    if is_process_running("beam.smp") {
        info!("✅ Elixir Application: Healthy");
    } else {
        error!("❌ Elixir Application: Not running");
        healthy = false;
    }
    
    if healthy {
        info!("🎉 All services are healthy!");
    } else {
        error!("💥 Some services are unhealthy!");
        std::process::exit(1);
    }
    
    Ok(())
}

async fn start_service(service: &str) -> Result<()> {
    match service {
        "nats" => start_nats().await,
        "postgres" => start_postgres().await,
        "rust" => start_rust_package_registry().await,
        "elixir" => start_elixir_app().await,
        _ => {
            error!("❌ Unknown service: {}", service);
            Err(anyhow::anyhow!("Unknown service: {}", service))
        }
    }
}

async fn stop_service(service: &str) -> Result<()> {
    match service {
        "nats" => {
            info!("🛑 Stopping NATS Server...");
            Command::new("pkill").args(&["-f", "nats-server"]).output()?;
            info!("✅ NATS Server stopped");
        }
        "postgres" => {
            info!("🛑 Stopping PostgreSQL...");
            Command::new("pkill").args(&["-f", "postgres"]).output()?;
            info!("✅ PostgreSQL stopped");
        }
        "rust" => {
            info!("🛑 Stopping Rust Package Registry...");
            Command::new("pkill").args(&["-f", "package-registry-service"]).output()?;
            info!("✅ Rust Package Registry stopped");
        }
        "elixir" => {
            info!("🛑 Stopping Elixir Application...");
            Command::new("pkill").args(&["-f", "beam.smp"]).output()?;
            info!("✅ Elixir Application stopped");
        }
        _ => {
            error!("❌ Unknown service: {}", service);
            return Err(anyhow::anyhow!("Unknown service: {}", service));
        }
    }
    Ok(())
}

// Service management functions

async fn start_nats() -> Result<()> {
    info!("🔧 Starting NATS Server...");
    
    if is_process_running("nats-server") {
        info!("✅ NATS Server already running");
        return Ok(());
    }

    let mut child = Command::new("nats-server")
        .args(&["-js", "-sd", ".nats", "-p", "4222"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    sleep(Duration::from_secs(2)).await;
    
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
    
    if is_process_running("postgres") {
        info!("✅ PostgreSQL already running");
        return Ok(());
    }

    warn!("⚠️  PostgreSQL not running - please start it manually");
    warn!("   Run: nix develop (to start PostgreSQL)");
    
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
    
    if is_process_running("package-registry-service") {
        info!("✅ Rust Package Registry Service already running");
        return Ok(());
    }

    let mut child = Command::new("bash")
        .args(&["-c", "cd rust/package_registry_indexer && RUST_LOG=info cargo run --bin package-registry-service"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    sleep(Duration::from_secs(3)).await;
    
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
    
    if is_process_running("beam.smp") {
        info!("✅ Elixir application already running");
        return Ok(());
    }

    let mut child = Command::new("bash")
        .args(&["-c", "cd singularity_app && mix phx.server"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    sleep(Duration::from_secs(5)).await;
    
    if child.try_wait()?.is_none() {
        info!("✅ Elixir Phoenix Application started");
    } else {
        error!("❌ Failed to start Elixir Phoenix Application");
        return Err(anyhow::anyhow!("Elixir Phoenix Application failed to start"));
    }

    Ok(())
}

async fn keep_alive() {
    // Set up signal handler for graceful shutdown
    tokio::signal::ctrl_c().await.expect("Failed to listen for ctrl+c");
    
    info!("🛑 Shutting down unified server...");
    stop_all_services().await.expect("Failed to stop services");
    info!("✅ Shutdown complete");
}

// Helper functions

struct ServiceStatus {
    nats: bool,
    postgres: bool,
    rust: bool,
    elixir: bool,
}

async fn check_services_status() -> ServiceStatus {
    ServiceStatus {
        nats: is_process_running("nats-server"),
        postgres: is_process_running("postgres"),
        rust: is_process_running("package-registry-service"),
        elixir: is_process_running("beam.smp"),
    }
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
    
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            error!("PostgreSQL connection error: {}", e);
        }
    });
    
    let _rows = client.query("SELECT 1", &[]).await?;
    
    Ok(())
}
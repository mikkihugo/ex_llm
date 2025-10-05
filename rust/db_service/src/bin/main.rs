/*!
 * Database Service - PostgreSQL via NATS
 *
 * All PostgreSQL access goes through this service via NATS.
 * No other services connect to PostgreSQL directly.
 */

use anyhow::Result;
use db_service::NatsDbService;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "db_service=info".into()),
        )
        .init();

    // Load environment
    dotenvy::dotenv().ok();

    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://localhost/facts_db".to_string());
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://localhost:4222".to_string());

    info!("🚀 Starting database service");
    info!("📊 Database: {}", database_url);
    info!("📡 NATS: {}", nats_url);

    // Initialize service
    let service = NatsDbService::new(&database_url, &nats_url).await?;

    // Start request handlers
    service.handle_db_requests().await?;
    service.handle_db_mutations().await?;
    service.handle_codebase_snapshots().await?;

    info!("✅ Database service ready");
    info!("   db.query                        - SELECT queries");
    info!("   db.execute                      - INSERT/UPDATE/DELETE");
    info!("   db.insert.codebase_snapshots    - Technology detection results");

    // Keep running
    tokio::signal::ctrl_c().await?;
    info!("👋 Shutting down database service");

    Ok(())
}

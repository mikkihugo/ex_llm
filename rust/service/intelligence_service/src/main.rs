//! Intelligence Service
//!
//! Central intelligence layer that aggregates insights across all Singularity instances.
//!
//! Handles THREE types of intelligence:
//! 1. **Code Intelligence** - Patterns, quality metrics, best practices
//! 2. **Architectural Intelligence** - System design, component relationships, architectural patterns
//! 3. **Data Intelligence** - Database schemas, data flows, data architecture
//!
//! Coordinates with local analysis libraries:
//! - Local: Fast analysis per-instance (code_analysis, architecture libs)
//! - Central: Pattern learning, global insights, cross-instance intelligence
//!
//! NATS subjects:
//! - intelligence.code.pattern.learned - Code patterns from instances
//! - intelligence.architecture.pattern.learned - Architectural patterns
//! - intelligence.data.schema.learned - Data schemas and relationships
//! - intelligence.insights.query - Query aggregated intelligence
//! - intelligence.quality.aggregate - Aggregate quality metrics

use anyhow::Result;
use tracing::{info, error};

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    info!("Starting Intelligence Service (code + architecture + data aggregation)");

    // Connect to NATS
    let nats_url = std::env::var("NATS_URL")
        .unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());
    let client = async_nats::connect(&nats_url).await?;

    info!("Connected to NATS at {}", nats_url);

    // Subscribe to intelligence subjects
    subscribe_to_subjects(&client).await?;

    info!("Intelligence Service ready - aggregating code, architecture, and data insights");

    // Keep service running
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Intelligence Service");

    Ok(())
}

async fn subscribe_to_subjects(client: &async_nats::Client) -> Result<()> {
    // Code pattern learning (from local instances)
    let mut sub_code_patterns = client.subscribe("intelligence.code.pattern.learned").await?;

    // Architectural pattern learning
    let mut sub_arch_patterns = client.subscribe("intelligence.architecture.pattern.learned").await?;

    // Data schema learning
    let mut sub_data_schemas = client.subscribe("intelligence.data.schema.learned").await?;

    // Global insights queries
    let mut sub_insights = client.subscribe("intelligence.insights.query").await?;

    // Quality aggregation
    let mut sub_quality = client.subscribe("intelligence.quality.aggregate").await?;

    tokio::spawn(async move {
        while let Some(msg) = sub_code_patterns.next().await {
            info!("Received code pattern from instance");
            // Aggregate code patterns across all instances
            // Store in central knowledge base
            // Broadcast if pattern reaches confidence threshold
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_arch_patterns.next().await {
            info!("Received architectural pattern from instance");
            // Aggregate architectural patterns
            // Learn system design patterns
            // Track component relationships
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_data_schemas.next().await {
            info!("Received data schema from instance");
            // Aggregate database schemas
            // Learn data flow patterns
            // Track data architecture evolution
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_insights.next().await {
            info!("Received global insights query");
            // Query aggregated insights (code + architecture + data)
            // Return patterns/suggestions learned from all instances
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_quality.next().await {
            info!("Received quality metrics from instance");
            // Aggregate quality metrics across instances
            // Track quality trends
            // Alert on quality regressions
        }
    });

    Ok(())
}

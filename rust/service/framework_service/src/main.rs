use anyhow::Result;
use tracing::info;

mod detector;
mod analyzer;
mod recommender;
mod knowledge_loader;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    info!("Starting Framework Intelligence Service");

    // Load framework knowledge from DB (templates_data/frameworks/*.json → PostgreSQL)
    let knowledge = knowledge_loader::load_framework_knowledge().await?;
    info!("Loaded {} framework detection rules", knowledge.len());

    // Connect to NATS
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());
    let client = async_nats::connect(&nats_url).await?;

    info!("Connected to NATS at {}", nats_url);

    // Subscribe to framework-related subjects
    subscribe_to_subjects(&client).await?;

    info!("Framework Intelligence Service ready - detecting frameworks, analyzing patterns, recommending solutions");

    // Keep service running
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Framework Intelligence Service");

    Ok(())
}

async fn subscribe_to_subjects(client: &async_nats::Client) -> Result<()> {
    // Framework detection
    let mut sub_detect = client.subscribe("frameworks.detect").await?;

    // Framework analysis
    let mut sub_analyze = client.subscribe("frameworks.analyze").await?;

    // Framework recommendations
    let mut sub_recommend = client.subscribe("frameworks.recommend").await?;

    // Framework search (semantic)
    let mut sub_search = client.subscribe("frameworks.search").await?;

    tokio::spawn(async move {
        while let Some(msg) = sub_detect.next().await {
            info!("Received framework detection request");
            // Parse codebase snapshot
            // Run multi-signal detection
            // If low confidence, call LLM via ai.llm.request
            // Return: {framework, version, confidence, method}
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_analyze.next().await {
            info!("Received framework analysis request");
            // Analyze framework usage patterns
            // Check for best practices violations
            // Detect sub-frameworks (LiveView, Channels, etc.)
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_recommend.next().await {
            info!("Received framework recommendation request");
            // Based on requirements, recommend framework
            // Compare options (Phoenix vs Rails vs Django)
            // Consider team, scale, features needed
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_search.next().await {
            info!("Received framework search request");
            // Semantic search across framework knowledge
            // Find frameworks matching description
            // "realtime web framework for elixir" → Phoenix
        }
    });

    Ok(())
}

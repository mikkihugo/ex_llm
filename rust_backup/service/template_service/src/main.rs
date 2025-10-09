use anyhow::Result;
use tracing::info;

mod handlers;
mod code_templates;
mod prompt_templates;
mod quality_templates;
mod framework_templates;

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    info!("Starting Template Service - Central template management");

    // Connect to NATS
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://127.0.0.1:4222".to_string());
    let client = async_nats::connect(&nats_url).await?;

    info!("Connected to NATS at {}", nats_url);

    // Subscribe to all template subjects
    subscribe_to_template_subjects(&client).await?;

    info!("Template Service ready - managing ALL templates (code, prompts, quality, frameworks)");

    // Keep service running
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Template Service");

    Ok(())
}

async fn subscribe_to_template_subjects(client: &async_nats::Client) -> Result<()> {
    // Code templates
    let mut sub_code = client.subscribe("templates.code.>").await?;

    // Prompt templates
    let mut sub_prompt = client.subscribe("templates.prompt.>").await?;

    // Quality templates
    let mut sub_quality = client.subscribe("templates.quality.>").await?;

    // Framework templates
    let mut sub_framework = client.subscribe("templates.framework.>").await?;

    tokio::spawn(async move {
        while let Some(msg) = sub_code.next().await {
            info!("Received code template request");
            // TODO: Handle code template request
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_prompt.next().await {
            info!("Received prompt template request");
            // TODO: Handle prompt template request
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_quality.next().await {
            info!("Received quality template request");
            // TODO: Handle quality template request
        }
    });

    tokio::spawn(async move {
        while let Some(msg) = sub_framework.next().await {
            info!("Received framework template request");
            // TODO: Handle framework template request
        }
    });

    Ok(())
}

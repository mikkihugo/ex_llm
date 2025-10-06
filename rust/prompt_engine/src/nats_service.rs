//! NATS Service for Prompt Engine
//!
//! Exposes AI prompt generation and optimization via NATS.
//!
//! **Architecture:**
//! - Elixir → NATS → prompt_engine → DSPy optimization
//!
//! **NATS Subjects:**
//! - `prompt.generate` - Generate prompt from context
//! - `prompt.optimize` - Optimize prompt with DSPy
//! - `prompt.template.get` - Get template by ID
//! - `prompt.template.list` - List available templates

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use tracing::{info, warn, error};

/// Request to generate a prompt
#[derive(Debug, Deserialize)]
pub struct GeneratePromptRequest {
    pub context: String,
    pub template_id: Option<String>,
    pub language: String,
}

/// Response with generated prompt
#[derive(Debug, Serialize)]
pub struct GeneratePromptResponse {
    pub prompt: String,
    pub template_used: String,
    pub confidence: f32,
}

/// Prompt Engine NATS Service
pub struct PromptEngineNatsService {
    nats_client: Client,
}

impl PromptEngineNatsService {
    /// Create new NATS service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;

        info!("Prompt Engine NATS service connected to {}", nats_url);

        Ok(Self {
            nats_client,
        })
    }

    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Prompt Engine NATS service...");

        // Spawn handlers for each subject
        let generate_sub = self.nats_client.subscribe("prompt.generate").await?;
        let optimize_sub = self.nats_client.subscribe("prompt.optimize").await?;
        let template_get_sub = self.nats_client.subscribe("prompt.template.get").await?;

        // Handle prompt generation
        tokio::spawn(async move {
            while let Some(msg) = generate_sub.next().await {
                info!("Received prompt generation request");
                // TODO: Call template engine, generate prompt
            }
        });

        // Handle prompt optimization
        tokio::spawn(async move {
            while let Some(msg) = optimize_sub.next().await {
                info!("Received prompt optimization request");
                // TODO: Call DSPy optimizer
            }
        });

        info!("Prompt Engine NATS service started");
        Ok(())
    }
}

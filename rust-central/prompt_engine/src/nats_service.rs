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
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, info, warn};

use crate::template_loader::TemplateLoader;
use crate::{OptimizationResult, PromptEngine};

/// Request to generate a prompt
#[derive(Debug, Deserialize)]
pub struct GeneratePromptRequest {
    pub context: String,
    pub template_id: Option<String>,
    pub language: String,
    pub trigger_type: Option<String>, // "framework", "language", "pattern", etc.
    pub trigger_value: Option<String>, // "phoenix", "rust", "microservice", etc.
    pub category: Option<String>,     // "commands", "dependencies", "examples", etc.
}

/// Request to optimize a prompt
#[derive(Debug, Deserialize)]
pub struct OptimizePromptRequest {
    pub prompt: String,
    pub context: Option<String>,
    pub language: Option<String>,
}

/// Response with generated prompt
#[derive(Debug, Serialize)]
pub struct GeneratePromptResponse {
    pub prompt: String,
    pub template_used: String,
    pub confidence: f32,
    pub optimization_score: Option<f64>,
    pub improvement_summary: Option<String>,
}

/// Response with optimized prompt
#[derive(Debug, Serialize)]
pub struct OptimizePromptResponse {
    pub original_prompt: String,
    pub optimized_prompt: String,
    pub optimization_score: f64,
    pub improvement_summary: String,
}

/// Template request
#[derive(Debug, Deserialize)]
pub struct TemplateRequest {
    pub template_id: String,
    pub context: Option<HashMap<String, String>>,
}

/// Template response
#[derive(Debug, Serialize)]
pub struct TemplateResponse {
    pub template: String,
    pub template_id: String,
    pub language: String,
    pub domain: String,
    pub quality_score: f64,
}

/// Prompt Engine NATS Service
pub struct PromptEngineNatsService {
    nats_client: Client,
    prompt_engine: Arc<RwLock<PromptEngine>>,
    template_loader: Arc<TemplateLoader>,
}

impl PromptEngineNatsService {
    /// Create new NATS service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;

        // Initialize prompt engine components
        let prompt_engine = Arc::new(RwLock::new(PromptEngine::new()?));
        let template_loader = Arc::new(TemplateLoader::new());

        info!("Prompt Engine NATS service connected to {}", nats_url);

        Ok(Self {
            nats_client,
            prompt_engine,
            template_loader,
        })
    }

    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Prompt Engine NATS service...");

        // Clone Arc references for async handlers
        let prompt_engine = Arc::clone(&self.prompt_engine);
        let template_loader = Arc::clone(&self.template_loader);

        // Spawn handlers for each subject
        let mut generate_sub = self.nats_client.subscribe("prompt.generate").await?;
        let mut optimize_sub = self.nats_client.subscribe("prompt.optimize").await?;
        let mut template_get_sub = self.nats_client.subscribe("prompt.template.get").await?;
        let mut template_list_sub = self.nats_client.subscribe("prompt.template.list").await?;

        // Handle prompt generation
        let client = self.nats_client.clone();
        let tl = Arc::clone(&template_loader);
        tokio::spawn(async move {
            while let Some(msg) = generate_sub.next().await {
                if let Err(e) = Self::handle_generate_request(&client, msg, &tl).await {
                    error!("Error handling generate request: {}", e);
                }
            }
        });

        // Handle prompt optimization
        let client = self.nats_client.clone();
        let pe = Arc::clone(&prompt_engine);
        tokio::spawn(async move {
            while let Some(msg) = optimize_sub.next().await {
                if let Err(e) = Self::handle_optimize_request(&client, msg, &pe).await {
                    error!("Error handling optimize request: {}", e);
                }
            }
        });

        // Handle template get requests
        let client = self.nats_client.clone();
        let tl = Arc::clone(&template_loader);
        tokio::spawn(async move {
            while let Some(msg) = template_get_sub.next().await {
                if let Err(e) = Self::handle_template_get_request(&client, msg, &tl).await {
                    error!("Error handling template get request: {}", e);
                }
            }
        });

        // Handle template list requests
        let client = self.nats_client.clone();
        let tl = Arc::clone(&template_loader);
        tokio::spawn(async move {
            while let Some(msg) = template_list_sub.next().await {
                if let Err(e) = Self::handle_template_list_request(&client, msg, &tl).await {
                    error!("Error handling template list request: {}", e);
                }
            }
        });

        info!("Prompt Engine NATS service started");
        Ok(())
    }

    /// Handle prompt generation request
    async fn handle_generate_request(
        client: &Client,
        msg: async_nats::Message,
        template_loader: &Arc<TemplateLoader>,
    ) -> Result<()> {
        let request: GeneratePromptRequest = serde_json::from_slice(&msg.payload)?;
        info!("Handling generate request: {:?}", request);

        let (prompt, template_used) = if let Some(template_id) = &request.template_id {
            match template_loader.load_template(template_id) {
                Ok(template_json) => {
                    let mut context = HashMap::new();
                    context.insert("context".to_string(), request.context.clone());

                    let content = template_json
                        .get("template")
                        .and_then(|v| v.as_str())
                        .unwrap_or("# Prompt\n{context}");

                    let rendered = Self::render_template(content, &context)?;
                    (rendered, template_id.clone())
                }
                Err(err) => {
                    warn!("Failed to load template {}: {}", template_id, err);
                    (
                        format!("# Prompt\n{}", request.context),
                        "fallback".to_string(),
                    )
                }
            }
        } else {
            (
                format!("# Prompt\n{}", request.context),
                "ad-hoc".to_string(),
            )
        };

        let response = GeneratePromptResponse {
            prompt,
            template_used,
            confidence: 0.85,
            optimization_score: None,
            improvement_summary: None,
        };

        Self::publish_response(client, &msg, &response).await?;

        Ok(())
    }

    /// Handle prompt optimization request
    async fn handle_optimize_request(
        client: &Client,
        msg: async_nats::Message,
        prompt_engine: &Arc<RwLock<PromptEngine>>,
    ) -> Result<()> {
        let request: OptimizePromptRequest = serde_json::from_slice(&msg.payload)?;
        info!("Handling optimize request for prompt: {}", request.prompt);

        let mut engine = prompt_engine.write().await;
        let optimization_result = engine.optimize_prompt(&request.prompt)?;

        let response = OptimizePromptResponse {
            original_prompt: request.prompt,
            optimized_prompt: optimization_result.optimized_prompt,
            optimization_score: optimization_result.optimization_score,
            improvement_summary: optimization_result.improvement_summary,
        };

        Self::publish_response(client, &msg, &response).await?;

        Ok(())
    }

    /// Handle template get request
    async fn handle_template_get_request(
        client: &Client,
        msg: async_nats::Message,
        template_loader: &Arc<TemplateLoader>,
    ) -> Result<()> {
        let request: TemplateRequest = serde_json::from_slice(&msg.payload)?;
        info!("Handling template get request: {}", request.template_id);

        let template_json = template_loader.load_template(&request.template_id)?;

        let template_content = template_json
            .get("template")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();

        let language = template_json
            .get("language")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();

        let domain = template_json
            .get("domain")
            .and_then(|v| v.as_str())
            .unwrap_or("general")
            .to_string();

        let quality_score = template_json
            .get("quality_score")
            .and_then(|v| v.as_f64())
            .unwrap_or(0.8);

        let mut response = TemplateResponse {
            template: template_content,
            template_id: request.template_id,
            language,
            domain,
            quality_score,
        };

        if let Some(context) = request.context {
            response.template = Self::render_template(&response.template, &context)?;
        }

        Self::publish_response(client, &msg, &response).await?;

        Ok(())
    }

    /// Handle template list request
    async fn handle_template_list_request(
        client: &Client,
        msg: async_nats::Message,
        template_loader: &Arc<TemplateLoader>,
    ) -> Result<()> {
        info!("Handling template list request");

        let templates = template_loader.list_templates()?;

        Self::publish_response(client, &msg, &templates).await?;

        Ok(())
    }

    /// Render template with context variables
    fn render_template(template: &str, context: &HashMap<String, String>) -> Result<String> {
        let mut rendered = template.to_string();

        for (key, value) in context {
            let placeholder = format!("{{{}}}", key);
            rendered = rendered.replace(&placeholder, value);
        }

        Ok(rendered)
    }

    /// Publish response to NATS
    async fn publish_response<T: Serialize>(
        client: &Client,
        msg: &async_nats::Message,
        response: &T,
    ) -> Result<()> {
        if let Some(reply) = msg.reply.clone() {
            let response_json = serde_json::to_vec(response)?;
            client.publish(reply, response_json.into()).await?;
        } else {
            warn!("No reply subject for {}", msg.subject);
        }
        Ok(())
    }
}

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
//! - `prompt.cache.get` - Get cached prompt
//! - `prompt.cache.put` - Store prompt in cache

use anyhow::Result;
use async_nats::Client;
use futures::StreamExt;
use serde::{Deserialize, Serialize};
use tracing::{info, warn, error};
use std::sync::Arc;
use std::collections::HashMap;
use tokio::sync::RwLock;

use crate::{PromptEngine, OptimizationResult};
use crate::prompt_bits::{PromptBitAssembler, PromptBitTrigger, PromptBitCategory};
use crate::templates::{TemplateLoader, RegistryTemplate};
use crate::caching::PromptCache;

/// Request to generate a prompt
#[derive(Debug, Deserialize)]
pub struct GeneratePromptRequest {
    pub context: String,
    pub template_id: Option<String>,
    pub language: String,
    pub trigger_type: Option<String>,  // "framework", "language", "pattern", etc.
    pub trigger_value: Option<String>, // "phoenix", "rust", "microservice", etc.
    pub category: Option<String>,      // "commands", "dependencies", "examples", etc.
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

/// Cache get request
#[derive(Debug, Deserialize)]
pub struct CacheGetRequest {
    pub key: String,
}

/// Cache put request
#[derive(Debug, Deserialize)]
pub struct CachePutRequest {
    pub key: String,
    pub entry: CacheEntry,
}

/// Cache entry for prompt caching
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct CacheEntry {
    pub prompt: String,
    pub score: f64,
    pub timestamp: u64,
}

/// Prompt Engine NATS Service
pub struct PromptEngineNatsService {
    nats_client: Client,
    prompt_engine: Arc<RwLock<PromptEngine>>,
    template_loader: Arc<TemplateLoader>,
    template_registry: Arc<RegistryTemplate>,
    prompt_assembler: Arc<PromptBitAssembler>,
    prompt_cache: Arc<RwLock<PromptCache>>,
}

impl PromptEngineNatsService {
    /// Create new NATS service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        
        // Initialize prompt engine components
        let prompt_engine = Arc::new(RwLock::new(PromptEngine::new()?));
        let template_loader = Arc::new(TemplateLoader::new());
        let template_registry = Arc::new(RegistryTemplate::new());
        let prompt_assembler = Arc::new(PromptBitAssembler::new());
        let prompt_cache = Arc::new(RwLock::new(PromptCache::new()));

        info!("Prompt Engine NATS service connected to {}", nats_url);

        Ok(Self {
            nats_client,
            prompt_engine,
            template_loader,
            template_registry,
            prompt_assembler,
            prompt_cache,
        })
    }

    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Prompt Engine NATS service...");

        // Clone Arc references for async handlers
        let prompt_engine = Arc::clone(&self.prompt_engine);
        let template_loader = Arc::clone(&self.template_loader);
        let template_registry = Arc::clone(&self.template_registry);
        let prompt_assembler = Arc::clone(&self.prompt_assembler);

        // Spawn handlers for each subject
        let mut generate_sub = self.nats_client.subscribe("prompt.generate").await?;
        let mut optimize_sub = self.nats_client.subscribe("prompt.optimize").await?;
        let mut template_get_sub = self.nats_client.subscribe("prompt.template.get").await?;
        let mut template_list_sub = self.nats_client.subscribe("prompt.template.list").await?;
        let mut cache_get_sub = self.nats_client.subscribe("prompt.cache.get").await?;
        let mut cache_put_sub = self.nats_client.subscribe("prompt.cache.put").await?;

        // Handle prompt generation
        let pe = Arc::clone(&prompt_engine);
        let tl = Arc::clone(&template_loader);
        let pa = Arc::clone(&prompt_assembler);
        tokio::spawn(async move {
            while let Some(msg) = generate_sub.next().await {
                if let Err(e) = Self::handle_generate_request(msg, &pe, &tl, &pa).await {
                    error!("Error handling generate request: {}", e);
                }
            }
        });

        // Handle prompt optimization
        let pe = Arc::clone(&prompt_engine);
        tokio::spawn(async move {
            while let Some(msg) = optimize_sub.next().await {
                if let Err(e) = Self::handle_optimize_request(msg, &pe).await {
                    error!("Error handling optimize request: {}", e);
                }
            }
        });

        // Handle template get requests
        let tr = Arc::clone(&template_registry);
        tokio::spawn(async move {
            while let Some(msg) = template_get_sub.next().await {
                if let Err(e) = Self::handle_template_get_request(msg, &tr).await {
                    error!("Error handling template get request: {}", e);
                }
            }
        });

        // Handle template list requests
        let tr = Arc::clone(&template_registry);
        tokio::spawn(async move {
            while let Some(msg) = template_list_sub.next().await {
                if let Err(e) = Self::handle_template_list_request(msg, &tr).await {
                    error!("Error handling template list request: {}", e);
                }
            }
        });

        // Handle cache get requests
        let pc = Arc::clone(&self.prompt_cache);
        tokio::spawn(async move {
            while let Some(msg) = cache_get_sub.next().await {
                if let Err(e) = Self::handle_cache_get_request(msg, &pc).await {
                    error!("Error handling cache get request: {}", e);
                }
            }
        });

        // Handle cache put requests
        let pc = Arc::clone(&self.prompt_cache);
        tokio::spawn(async move {
            while let Some(msg) = cache_put_sub.next().await {
                if let Err(e) = Self::handle_cache_put_request(msg, &pc).await {
                    error!("Error handling cache put request: {}", e);
                }
            }
        });

        info!("Prompt Engine NATS service started");
        Ok(())
    }

    /// Handle prompt generation request
    async fn handle_generate_request(
        msg: async_nats::Message,
        prompt_engine: &Arc<RwLock<PromptEngine>>,
        template_loader: &Arc<TemplateLoader>,
        prompt_assembler: &Arc<PromptBitAssembler>,
    ) -> Result<()> {
        let request: GeneratePromptRequest = serde_json::from_slice(&msg.payload)?;
        info!("Handling generate request: {:?}", request);

        let response = if let (Some(trigger_type), Some(trigger_value), Some(category)) = 
            (&request.trigger_type, &request.trigger_value, &request.category) {
            // Use prompt bits assembler for context-aware generation
            let trigger = Self::parse_trigger(trigger_type, trigger_value)?;
            let category = Self::parse_category(category)?;
            
            let prompt = prompt_assembler.assemble_prompt(&trigger, &category, &request.context)?;
            
            GeneratePromptResponse {
                prompt,
                template_used: format!("{}-{}-{}", trigger_type, trigger_value, category),
                confidence: 0.9,
                optimization_score: None,
                improvement_summary: None,
            }
        } else if let Some(template_id) = &request.template_id {
            // Use specific template
            let template = template_loader.load_template(template_id)?;
            let mut context = std::collections::HashMap::new();
            context.insert("context".to_string(), request.context);
            
            let prompt = Self::render_template(&template.template, &context)?;
            
            GeneratePromptResponse {
                prompt,
                template_used: template_id.clone(),
                confidence: template.quality_score as f32,
                optimization_score: None,
                improvement_summary: None,
            }
        } else {
            // Use prompt engine optimization
            let mut engine = prompt_engine.write().await;
            let optimization_result = engine.optimize_prompt(&request.context)?;
            
            GeneratePromptResponse {
                prompt: optimization_result.optimized_prompt,
                template_used: "optimized".to_string(),
                confidence: optimization_result.optimization_score as f32,
                optimization_score: Some(optimization_result.optimization_score),
                improvement_summary: Some(optimization_result.improvement_summary),
            }
        };

        let response_json = serde_json::to_vec(&response)?;
        if let Some(reply) = msg.reply {
            msg.respond(response_json).await?;
        }
        
        Ok(())
    }

    /// Handle prompt optimization request
    async fn handle_optimize_request(
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

        let response_json = serde_json::to_vec(&response)?;
        if let Some(reply) = msg.reply {
            msg.respond(response_json).await?;
        }
        
        Ok(())
    }

    /// Handle template get request
    async fn handle_template_get_request(
        msg: async_nats::Message,
        template_registry: &Arc<RegistryTemplate>,
    ) -> Result<()> {
        let request: TemplateRequest = serde_json::from_slice(&msg.payload)?;
        info!("Handling template get request: {}", request.template_id);

        let template = template_registry.get_template(&request.template_id)
            .ok_or_else(|| anyhow::anyhow!("Template not found: {}", request.template_id))?;

        let mut rendered_template = template.template.clone();
        if let Some(context) = &request.context {
            rendered_template = Self::render_template(&template.template, context)?;
        }

        let response = TemplateResponse {
            template: rendered_template,
            template_id: template.name.clone(),
            language: template.language.clone(),
            domain: template.domain.clone(),
            quality_score: template.quality_score,
        };

        let response_json = serde_json::to_vec(&response)?;
        if let Some(reply) = msg.reply {
            msg.respond(response_json).await?;
        }
        
        Ok(())
    }

    /// Handle template list request
    async fn handle_template_list_request(
        msg: async_nats::Message,
        template_registry: &Arc<RegistryTemplate>,
    ) -> Result<()> {
        info!("Handling template list request");

        let templates = template_registry.list_templates();
        let template_list: Vec<TemplateResponse> = templates
            .iter()
            .map(|template| TemplateResponse {
                template: template.template.clone(),
                template_id: template.name.clone(),
                language: template.language.clone(),
                domain: template.domain.clone(),
                quality_score: template.quality_score,
            })
            .collect();

        let response_json = serde_json::to_vec(&template_list)?;
        if let Some(reply) = msg.reply {
            msg.respond(response_json).await?;
        }
        
        Ok(())
    }

    /// Parse trigger type and value into PromptBitTrigger
    fn parse_trigger(trigger_type: &str, trigger_value: &str) -> Result<PromptBitTrigger> {
        match trigger_type {
            "framework" => Ok(PromptBitTrigger::Framework(trigger_value.to_string())),
            "language" => Ok(PromptBitTrigger::Language(trigger_value.to_string())),
            "build_system" => Ok(PromptBitTrigger::BuildSystem(trigger_value.to_string())),
            "infrastructure" => Ok(PromptBitTrigger::Infrastructure(trigger_value.to_string())),
            "pattern" => Ok(PromptBitTrigger::CodePattern(trigger_value.to_string())),
            _ => Ok(PromptBitTrigger::Custom(format!("{}:{}", trigger_type, trigger_value))),
        }
    }

    /// Parse category string into PromptBitCategory
    fn parse_category(category: &str) -> Result<PromptBitCategory> {
        match category {
            "commands" => Ok(PromptBitCategory::Commands),
            "dependencies" => Ok(PromptBitCategory::Dependencies),
            "configuration" => Ok(PromptBitCategory::Configuration),
            "best_practices" => Ok(PromptBitCategory::BestPractices),
            "examples" => Ok(PromptBitCategory::Examples),
            "integration" => Ok(PromptBitCategory::Integration),
            "testing" => Ok(PromptBitCategory::Testing),
            "deployment" => Ok(PromptBitCategory::Deployment),
            _ => Ok(PromptBitCategory::Commands), // Default fallback
        }
    }

    /// Render template with context variables
    fn render_template(template: &str, context: &std::collections::HashMap<String, String>) -> Result<String> {
        let mut rendered = template.to_string();
        
        for (key, value) in context {
            let placeholder = format!("{{{}}}", key);
            rendered = rendered.replace(&placeholder, value);
        }
        
        Ok(rendered)
    }

    /// Handle cache get request
    async fn handle_cache_get_request(
        msg: async_nats::Message,
        prompt_cache: &Arc<RwLock<PromptCache>>,
    ) -> Result<()> {
        let request: CacheGetRequest = serde_json::from_slice(&msg.payload)?;
        
        let cache = prompt_cache.read().await;
        let response = if let Some(entry) = cache.get(&request.key) {
            serde_json::json!({
                "found": true,
                "entry": entry
            })
        } else {
            serde_json::json!({
                "found": false
            })
        };

        msg.respond(serde_json::to_vec(&response)?).await?;
        Ok(())
    }

    /// Handle cache put request
    async fn handle_cache_put_request(
        msg: async_nats::Message,
        prompt_cache: &Arc<RwLock<PromptCache>>,
    ) -> Result<()> {
        let request: CachePutRequest = serde_json::from_slice(&msg.payload)?;
        
        let mut cache = prompt_cache.write().await;
        cache.store(&request.key, request.entry)?;
        
        let response = serde_json::json!({"status": "stored"});
        msg.respond(serde_json::to_vec(&response)?).await?;
        Ok(())
    }
}

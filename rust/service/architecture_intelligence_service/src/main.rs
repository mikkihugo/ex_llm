//! Architecture Analysis Service
//!
//! Thin NATS service for centralized framework enrichment:
//! 1. Query PostgreSQL framework database
//! 2. Run LLM enrichment for unknown frameworks
//! 3. Save new frameworks back to PostgreSQL
//! 4. Broadcast updates via NATS

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::collections::HashMap;
use tracing::{info, error, warn};

#[derive(Debug, Serialize, Deserialize)]
struct FrameworkEnrichmentRequest {
    /// Unknown framework name (e.g., "SvelteKit", "Astro")
    name: String,
    /// Context files that indicate this framework
    context_files: Vec<String>,
    /// Code snippets for LLM analysis
    code_samples: Option<Vec<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
struct FrameworkEnrichmentResponse {
    /// Framework name (validated/corrected by LLM)
    name: String,
    /// Official version if detected
    version: Option<String>,
    /// Framework category (web, mobile, desktop, etc.)
    category: String,
    /// Detection patterns (file paths, import statements, etc.)
    detection_patterns: Vec<DetectionPattern>,
    /// Confidence score (0.0-1.0)
    confidence: f32,
    /// Whether this was newly created
    newly_discovered: bool,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
struct DetectionPattern {
    /// Pattern type: "file", "import", "dependency", "code"
    pattern_type: String,
    /// Pattern value (e.g., "svelte.config.js", "import { SvelteKit }")
    pattern: String,
    /// Confidence weight (0.0-1.0)
    weight: f32,
}

struct AnalyzeArchService {
    nats: Client,
    db: PgPool,
    framework_cache: HashMap<String, FrameworkEnrichmentResponse>,
}

impl AnalyzeArchService {
    async fn new(nats_url: &str, database_url: &str) -> Result<Self> {
        let nats = async_nats::connect(nats_url).await?;
        let db = PgPool::connect(database_url).await?;

        Ok(Self {
            nats,
            db,
            framework_cache: HashMap::new(),
        })
    }

    /// Main NATS handler for framework enrichment requests
    async fn handle_enrichment_request(
        &mut self,
        request: FrameworkEnrichmentRequest,
    ) -> Result<FrameworkEnrichmentResponse> {
        info!("Enriching framework: {}", request.name);

        // 1. Check cache
        if let Some(cached) = self.framework_cache.get(&request.name) {
            info!("Found {} in cache", request.name);
            return Ok(cached.clone());
        }

        // 2. Query PostgreSQL framework database
        if let Some(db_result) = self.query_framework_db(&request.name).await? {
            info!("Found {} in database", request.name);
            self.framework_cache.insert(request.name.clone(), db_result.clone());
            return Ok(db_result);
        }

        // 3. Run LLM enrichment for unknown framework
        warn!("Unknown framework {}, running LLM enrichment", request.name);
        let enriched = self.llm_enrich_framework(&request).await?;

        // 4. Save to database
        self.save_framework_to_db(&enriched).await?;

        // 5. Broadcast update via NATS
        self.broadcast_framework_update(&enriched).await?;

        // 6. Cache it
        self.framework_cache.insert(request.name.clone(), enriched.clone());

        Ok(enriched)
    }

    /// Query existing framework from PostgreSQL
    async fn query_framework_db(&self, name: &str) -> Result<Option<FrameworkEnrichmentResponse>> {
        // TODO: Implement actual PostgreSQL query
        // Query framework_patterns or knowledge_artifacts table
        Ok(None)
    }

    /// Use LLM to enrich unknown framework
    async fn llm_enrich_framework(
        &self,
        request: &FrameworkEnrichmentRequest,
    ) -> Result<FrameworkEnrichmentResponse> {
        info!("Calling LLM for framework enrichment: {}", request.name);

        // Load enrichment prompt template
        let prompt_template = self.load_enrichment_prompt()?;

        // Build LLM request
        let llm_request = self.build_llm_request(&prompt_template, request)?;

        // Send to LLM via NATS (ai.llm.request)
        let llm_response = self.call_llm_via_nats(llm_request).await?;

        // Parse LLM JSON response into FrameworkEnrichmentResponse
        let enriched = self.parse_llm_response(&llm_response)?;

        Ok(enriched)
    }

    /// Load framework discovery prompt template from templates_data/
    fn load_enrichment_prompt(&self) -> Result<serde_json::Value> {
        let template_path = "templates_data/enrichment_prompts/framework_discovery.json";
        let content = std::fs::read_to_string(template_path)?;
        let template: serde_json::Value = serde_json::from_str(&content)?;
        Ok(template)
    }

    /// Build LLM request with filled prompt template
    fn build_llm_request(
        &self,
        template: &serde_json::Value,
        request: &FrameworkEnrichmentRequest,
    ) -> Result<serde_json::Value> {
        let prompt_template = template["prompt_template"]
            .as_str()
            .ok_or_else(|| anyhow::anyhow!("Missing prompt_template"))?;

        // Fill in variables
        let filled_prompt = prompt_template
            .replace("{{framework_name}}", &request.name)
            .replace("{{files_list}}", &format!("{:?}", request.context_files))
            .replace(
                "{{code_samples}}",
                &request.code_samples
                    .as_ref()
                    .map(|samples| samples.join("\n\n"))
                    .unwrap_or_default()
            );

        Ok(serde_json::json!({
            "complexity": "complex",
            "task_type": "architect",
            "messages": [
                {
                    "role": "system",
                    "content": template["system_prompt"]["role"].as_str().unwrap_or("")
                },
                {
                    "role": "user",
                    "content": filled_prompt
                }
            ],
            "response_format": {"type": "json"}
        }))
    }

    /// Call LLM via NATS ai.llm.request subject
    async fn call_llm_via_nats(&self, request: serde_json::Value) -> Result<serde_json::Value> {
        let subject = "ai.llm.request";
        let payload = serde_json::to_vec(&request)?;

        // Request-reply pattern with timeout
        let response = self.nats
            .request(subject, payload.into())
            .await?;

        let llm_response: serde_json::Value = serde_json::from_slice(&response.payload)?;
        Ok(llm_response)
    }

    /// Parse LLM JSON response into structured FrameworkEnrichmentResponse
    fn parse_llm_response(&self, response: &serde_json::Value) -> Result<FrameworkEnrichmentResponse> {
        // LLM returns JSON matching our schema
        let framework = &response["framework"];
        let detection = &response["detection"];

        let detection_patterns: Vec<DetectionPattern> = detection["config_files"]
            .as_array()
            .unwrap_or(&vec![])
            .iter()
            .map(|f| DetectionPattern {
                pattern_type: "file".to_string(),
                pattern: f["file"].as_str().unwrap_or("").to_string(),
                weight: f["weight"].as_f64().unwrap_or(0.8) as f32,
            })
            .collect();

        Ok(FrameworkEnrichmentResponse {
            name: framework["name"].as_str().unwrap_or("").to_string(),
            version: framework["version"].as_str().map(|s| s.to_string()),
            category: framework["category"].as_str().unwrap_or("web").to_string(),
            detection_patterns,
            confidence: framework["confidence"].as_f64().unwrap_or(0.8) as f32,
            newly_discovered: true,
        })
    }

    /// Save enriched framework to PostgreSQL
    async fn save_framework_to_db(&self, framework: &FrameworkEnrichmentResponse) -> Result<()> {
        // TODO: Insert into framework_patterns or knowledge_artifacts table
        info!("Saving framework {} to database", framework.name);
        Ok(())
    }

    /// Broadcast framework update to all nodes
    async fn broadcast_framework_update(&self, framework: &FrameworkEnrichmentResponse) -> Result<()> {
        let subject = "architecture.framework.discovered";
        let payload = serde_json::to_vec(&framework)?;
        self.nats.publish(subject, payload.into()).await?;
        info!("Broadcasted new framework: {}", framework.name);
        Ok(())
    }

    async fn run(&mut self) -> Result<()> {
        info!("Architecture Analysis Service starting...");

        let subject = "architecture.enrich.request";
        let mut subscriber = self.nats.subscribe(subject).await?;

        info!("Listening on NATS subject: {}", subject);

        while let Some(message) = subscriber.next().await {
            match serde_json::from_slice::<FrameworkEnrichmentRequest>(&message.payload) {
                Ok(request) => {
                    match self.handle_enrichment_request(request).await {
                        Ok(response) => {
                            if let Some(reply) = message.reply {
                                let payload = serde_json::to_vec(&response)?;
                                self.nats.publish(reply, payload.into()).await?;
                            }
                        }
                        Err(e) => {
                            error!("Enrichment failed: {}", e);
                        }
                    }
                }
                Err(e) => {
                    error!("Failed to parse request: {}", e);
                }
            }
        }

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".to_string());
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    let mut service = AnalyzeArchService::new(&nats_url, &database_url).await?;
    service.run().await?;

    Ok(())
}

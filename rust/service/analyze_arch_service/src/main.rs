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
        // TODO: Implement LLM call via NATS
        // Subject: ai.llm.request
        // Prompt: "Analyze this framework: {name}, files: {files}, code: {samples}"
        // Expected: detection patterns, category, version, confidence

        // Mock for now
        Ok(FrameworkEnrichmentResponse {
            name: request.name.clone(),
            version: None,
            category: "web".to_string(),
            detection_patterns: vec![
                DetectionPattern {
                    pattern_type: "file".to_string(),
                    pattern: format!("{}.config.js", request.name.to_lowercase()),
                    weight: 0.9,
                }
            ],
            confidence: 0.8,
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

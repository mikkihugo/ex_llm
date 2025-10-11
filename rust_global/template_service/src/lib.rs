//! Global Template Service
//!
//! Provides centralized template management and distribution across all Singularity instances.
//! 
//! **Bidirectional Learning Architecture:**
//! - **Local → Global**: Local instances request templates and send usage analytics
//! - **Global → Local**: Global service distributes templates and learns from usage patterns
//! - **Global Analysis**: Analyzes usage patterns to improve and generate new templates
//!
//! Handles template storage, retrieval, search, synchronization, and learning via NATS.

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, error};

pub mod template_store;
pub mod nats_service;
pub mod template_cache;
pub mod template_processor;
pub mod template_analytics;

/// Template metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Template {
    pub id: String,
    pub name: String,
    pub template_type: String, // "framework", "quality", "language", "technology"
    pub language: Option<String>,
    pub framework: Option<String>,
    pub content: String,
    pub metadata: HashMap<String, String>,
    pub version: i32,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

/// Template search request
#[derive(Debug, Deserialize)]
pub struct TemplateSearchRequest {
    pub query: String,
    pub template_type: Option<String>,
    pub language: Option<String>,
    pub limit: Option<usize>,
}

/// Template search response
#[derive(Debug, Serialize)]
pub struct TemplateSearchResponse {
    pub templates: Vec<Template>,
    pub total: usize,
    pub query: String,
}

/// Template store request
#[derive(Debug, Deserialize)]
pub struct TemplateStoreRequest {
    pub template: Template,
    pub sync_to_instances: bool,
}

/// Template store response
#[derive(Debug, Serialize)]
pub struct TemplateStoreResponse {
    pub template_id: String,
    pub status: String,
    pub synced_instances: usize,
}

/// Global Template Service
pub struct GlobalTemplateService {
    /// NATS client for communication
    nats_client: Client,
    
    /// Template storage backend
    template_store: Arc<template_store::TemplateStore>,
    
    /// Template cache for performance
    template_cache: Arc<template_cache::TemplateCache>,
    
    /// Template processor for rendering
    template_processor: Arc<template_processor::TemplateProcessor>,
    
    /// Template analytics for learning
    template_analytics: Arc<template_analytics::TemplateAnalytics>,
}

impl GlobalTemplateService {
    /// Create new global template service
    pub async fn new(nats_url: &str, database_url: &str) -> Result<Self> {
        info!("Initializing Global Template Service...");
        
        // Connect to NATS
        let nats_client = async_nats::connect(nats_url).await?;
        info!("Connected to NATS at {}", nats_url);
        
        // Initialize template store
        let template_store = Arc::new(template_store::TemplateStore::new(database_url).await?);
        info!("Initialized template store");
        
        // Initialize template cache
        let template_cache = Arc::new(template_cache::TemplateCache::new());
        info!("Initialized template cache");
        
        // Initialize template processor
        let template_processor = Arc::new(template_processor::TemplateProcessor::new());
        info!("Initialized template processor");
        
        // Initialize template analytics
        let template_analytics = Arc::new(template_analytics::TemplateAnalytics::new());
        info!("Initialized template analytics");
        
        let service = Self {
            nats_client,
            template_store,
            template_cache,
            template_processor,
            template_analytics,
        };
        
        // Load templates from templates_data/ on startup
        service.load_templates_from_disk().await?;
        
        Ok(service)
    }
    
    /// Start the global template service
    pub async fn start(&self) -> Result<()> {
        info!("Starting Global Template Service...");
        
        // Start NATS service
        let nats_service = nats_service::TemplateNatsService::new(
            self.nats_client.clone(),
            self.template_store.clone(),
            self.template_cache.clone(),
            self.template_processor.clone(),
        );
        
        nats_service.start().await?;
        info!("Global Template Service started successfully");
        
        Ok(())
    }
    
    /// Store template globally
    pub async fn store_template(&self, template: Template) -> Result<String> {
        info!("Storing template: {}", template.id);
        
        // Store in database
        let template_id = self.template_store.store_template(template.clone()).await?;
        
        // Cache for performance
        self.template_cache.put(&template_id, template.clone()).await;
        
        // Broadcast to all instances
        self.broadcast_template_update(&template).await?;
        
        info!("Template stored and broadcasted: {}", template_id);
        Ok(template_id)
    }
    
    /// Get template by ID
    pub async fn get_template(&self, template_id: &str) -> Result<Option<Template>> {
        // Try cache first
        if let Some(template) = self.template_cache.get(template_id).await {
            return Ok(Some(template));
        }
        
        // Fallback to database
        let template = self.template_store.get_template(template_id).await?;
        
        // Cache if found
        if let Some(ref template) = template {
            self.template_cache.put(template_id, template.clone()).await;
        }
        
        Ok(template)
    }
    
    /// Search templates
    pub async fn search_templates(&self, request: TemplateSearchRequest) -> Result<TemplateSearchResponse> {
        info!("Searching templates: {}", request.query);
        
        let templates = self.template_store.search_templates(&request).await?;
        
        Ok(TemplateSearchResponse {
            templates,
            total: templates.len(),
            query: request.query,
        })
    }
    
    /// Record usage analytics from local instance
    pub async fn record_usage_analytics(&self, analytics: template_analytics::TemplateUsageAnalytics) -> Result<()> {
        info!("Recording usage analytics from local instance: {}", analytics.instance_id);
        self.template_analytics.record_usage(analytics).await?;
        Ok(())
    }
    
    /// Get performance metrics for a template
    pub async fn get_performance_metrics(&self, template_id: &str) -> Option<template_analytics::TemplatePerformanceMetrics> {
        self.template_analytics.get_performance_metrics(template_id).await
    }
    
    /// Get learning insights for a template
    pub async fn get_learning_insights(&self, template_id: &str) -> Option<template_analytics::TemplateLearningInsights> {
        self.template_analytics.get_learning_insights(template_id).await
    }
    
    /// Get all performance metrics
    pub async fn get_all_performance_metrics(&self) -> Vec<template_analytics::TemplatePerformanceMetrics> {
        self.template_analytics.get_all_performance_metrics().await
    }
    
    /// Load templates from templates_data/ directory on startup
    async fn load_templates_from_disk(&self) -> Result<()> {
        info!("Loading templates from templates_data/ directory...");
        
        let templates_dir = std::path::Path::new("../templates_data");
        if !templates_dir.exists() {
            warn!("templates_data/ directory not found, skipping template loading");
            return Ok(());
        }
        
        let mut loaded_count = 0;
        let mut error_count = 0;
        
        // Walk through all JSON files in templates_data/
        for entry in walkdir::WalkDir::new(templates_dir)
            .follow_links(true)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file() && e.path().extension().map_or(false, |ext| ext == "json"))
        {
            let file_path = entry.path();
            info!("Loading template from: {:?}", file_path);
            
            match self.load_template_from_file(file_path).await {
                Ok(template) => {
                    // Store in database
                    match self.template_store.store_template(template.clone()).await {
                        Ok(template_id) => {
                            // Cache for performance
                            self.template_cache.put(&template_id, template).await;
                            loaded_count += 1;
                            info!("Loaded template: {}", template_id);
                        }
                        Err(e) => {
                            error_count += 1;
                            warn!("Failed to store template from {:?}: {}", file_path, e);
                        }
                    }
                }
                Err(e) => {
                    error_count += 1;
                    warn!("Failed to load template from {:?}: {}", file_path, e);
                }
            }
        }
        
        info!("Template loading complete: {} loaded, {} errors", loaded_count, error_count);
        Ok(())
    }
    
    /// Load a single template from JSON file
    async fn load_template_from_file(&self, file_path: &std::path::Path) -> Result<Template> {
        let content = std::fs::read_to_string(file_path)?;
        let json_value: serde_json::Value = serde_json::from_str(&content)?;
        
        // Extract template metadata
        let id = json_value
            .get("id")
            .or_else(|| json_value.get("name"))
            .and_then(|v| v.as_str())
            .unwrap_or("unknown")
            .to_string();
        
        let name = json_value
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or(&id)
            .to_string();
        
        let template_type = json_value
            .get("template_type")
            .or_else(|| json_value.get("type"))
            .and_then(|v| v.as_str())
            .unwrap_or("general")
            .to_string();
        
        let language = json_value
            .get("language")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        
        let framework = json_value
            .get("framework")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string());
        
        let content = json_value
            .get("content")
            .or_else(|| json_value.get("template"))
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        
        let metadata = json_value
            .get("metadata")
            .and_then(|v| v.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| v.as_str().map(|s| (k.clone(), s.to_string())))
                    .collect()
            })
            .unwrap_or_default();
        
        let version = json_value
            .get("version")
            .and_then(|v| v.as_i64())
            .unwrap_or(1) as i32;
        
        let now = chrono::Utc::now();
        
        Ok(Template {
            id,
            name,
            template_type,
            language,
            framework,
            content,
            metadata,
            version,
            created_at: now,
            updated_at: now,
        })
    }
    
    /// Broadcast template update to all instances
    async fn broadcast_template_update(&self, template: &Template) -> Result<()> {
        let subject = format!("template.updated.{}.{}", template.template_type, template.id);
        let payload = serde_json::to_vec(template)?;
        
        match self.nats_client.publish(subject, payload.into()).await {
            Ok(_) => info!("Broadcasted template update: {}", template.id),
            Err(e) => warn!("Failed to broadcast template update: {}", e),
        }
        
        Ok(())
    }
}

/// Main entry point
#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt::init();
    
    // Get configuration
    let nats_url = std::env::var("NATS_URL").unwrap_or_else(|_| "nats://localhost:4222".to_string());
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://localhost/singularity".to_string());
    
    // Create and start service
    let service = GlobalTemplateService::new(&nats_url, &database_url).await?;
    service.start().await?;
    
    // Keep running
    tokio::signal::ctrl_c().await?;
    info!("Shutting down Global Template Service");
    
    Ok(())
}
//! NATS service for template distribution

use anyhow::Result;
use async_nats::Client;
use serde_json;
use std::sync::Arc;
use tracing::{info, error};

use super::{Template, TemplateSearchRequest, TemplateStoreRequest, TemplateStoreResponse};
use crate::template_store::TemplateStore;
use crate::template_cache::TemplateCache;
use crate::template_processor::TemplateProcessor;

/// NATS service for template distribution
pub struct TemplateNatsService {
    nats_client: Client,
    template_store: Arc<TemplateStore>,
    template_cache: Arc<TemplateCache>,
    template_processor: Arc<TemplateProcessor>,
}

impl TemplateNatsService {
    /// Create new NATS service
    pub fn new(
        nats_client: Client,
        template_store: Arc<TemplateStore>,
        template_cache: Arc<TemplateCache>,
        template_processor: Arc<TemplateProcessor>,
    ) -> Self {
        Self {
            nats_client,
            template_store,
            template_cache,
            template_processor,
        }
    }
    
    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Template NATS service...");
        
        // Clone references for async handlers
        let nats_client = self.nats_client.clone();
        let template_store = self.template_store.clone();
        let template_cache = self.template_cache.clone();
        let template_processor = self.template_processor.clone();
        
        // Template get requests
        let nats_client_get = nats_client.clone();
        let template_store_get = template_store.clone();
        let template_cache_get = template_cache.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::handle_template_get(nats_client_get, template_store_get, template_cache_get).await {
                error!("Template get handler error: {}", e);
            }
        });
        
        // Template search requests
        let nats_client_search = nats_client.clone();
        let template_store_search = template_store.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::handle_template_search(nats_client_search, template_store_search).await {
                error!("Template search handler error: {}", e);
            }
        });
        
        // Template store requests
        let nats_client_store = nats_client.clone();
        let template_store_store = template_store.clone();
        let template_cache_store = template_cache.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::handle_template_store(nats_client_store, template_store_store, template_cache_store).await {
                error!("Template store handler error: {}", e);
            }
        });
        
        // Template render requests
        let nats_client_render = nats_client.clone();
        let template_processor_render = template_processor.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::handle_template_render(nats_client_render, template_processor_render).await {
                error!("Template render handler error: {}", e);
            }
        });
        
        info!("Template NATS service started");
        Ok(())
    }
    
    /// Handle template get requests
    async fn handle_template_get(
        nats_client: Client,
        template_store: Arc<TemplateStore>,
        template_cache: Arc<TemplateCache>,
    ) -> Result<()> {
        let mut subscriber = nats_client.subscribe("template.get.*").await?;
        
        while let Some(message) = subscriber.next().await {
            let subject = &message.subject;
            let template_id = subject.strip_prefix("template.get.").unwrap_or("");
            
            if template_id.is_empty() {
                continue;
            }
            
            // Try cache first
            if let Some(template) = template_cache.get(template_id).await {
                let response = serde_json::to_vec(&template)?;
                if let Err(e) = message.respond(response.into()).await {
                    error!("Failed to respond to template get request: {}", e);
                }
                continue;
            }
            
            // Fallback to database
            match template_store.get_template(template_id).await {
                Ok(Some(template)) => {
                    // Cache for next time
                    template_cache.put(template_id, template.clone()).await;
                    
                    let response = serde_json::to_vec(&template)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template get request: {}", e);
                    }
                }
                Ok(None) => {
                    let error_response = serde_json::json!({"error": "Template not found"});
                    let response = serde_json::to_vec(&error_response)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template get request: {}", e);
                    }
                }
                Err(e) => {
                    error!("Database error getting template {}: {}", template_id, e);
                    let error_response = serde_json::json!({"error": "Database error"});
                    let response = serde_json::to_vec(&error_response)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template get request: {}", e);
                    }
                }
            }
        }
        
        Ok(())
    }
    
    /// Handle template search requests
    async fn handle_template_search(
        nats_client: Client,
        template_store: Arc<TemplateStore>,
    ) -> Result<()> {
        let mut subscriber = nats_client.subscribe("template.search").await?;
        
        while let Some(message) = subscriber.next().await {
            let request: TemplateSearchRequest = match serde_json::from_slice(&message.payload) {
                Ok(req) => req,
                Err(e) => {
                    error!("Invalid search request: {}", e);
                    continue;
                }
            };
            
            match template_store.search_templates(&request).await {
                Ok(templates) => {
                    let response = serde_json::json!({
                        "templates": templates,
                        "total": templates.len(),
                        "query": request.query
                    });
                    let response_bytes = serde_json::to_vec(&response)?;
                    if let Err(e) = message.respond(response_bytes.into()).await {
                        error!("Failed to respond to template search request: {}", e);
                    }
                }
                Err(e) => {
                    error!("Database error searching templates: {}", e);
                    let error_response = serde_json::json!({"error": "Database error"});
                    let response = serde_json::to_vec(&error_response)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template search request: {}", e);
                    }
                }
            }
        }
        
        Ok(())
    }
    
    /// Handle template store requests
    async fn handle_template_store(
        nats_client: Client,
        template_store: Arc<TemplateStore>,
        template_cache: Arc<TemplateCache>,
    ) -> Result<()> {
        let mut subscriber = nats_client.subscribe("template.store").await?;
        
        while let Some(message) = subscriber.next().await {
            let request: TemplateStoreRequest = match serde_json::from_slice(&message.payload) {
                Ok(req) => req,
                Err(e) => {
                    error!("Invalid store request: {}", e);
                    continue;
                }
            };
            
            match template_store.store_template(request.template.clone()).await {
                Ok(template_id) => {
                    // Cache the template
                    template_cache.put(&template_id, request.template).await;
                    
                    let response = TemplateStoreResponse {
                        template_id,
                        status: "stored".to_string(),
                        synced_instances: 1, // TODO: Track actual instances
                    };
                    let response_bytes = serde_json::to_vec(&response)?;
                    if let Err(e) = message.respond(response_bytes.into()).await {
                        error!("Failed to respond to template store request: {}", e);
                    }
                }
                Err(e) => {
                    error!("Database error storing template: {}", e);
                    let error_response = serde_json::json!({"error": "Database error"});
                    let response = serde_json::to_vec(&error_response)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template store request: {}", e);
                    }
                }
            }
        }
        
        Ok(())
    }
    
    /// Handle template render requests
    async fn handle_template_render(
        nats_client: Client,
        template_processor: Arc<TemplateProcessor>,
    ) -> Result<()> {
        let mut subscriber = nats_client.subscribe("template.render").await?;
        
        while let Some(message) = subscriber.next().await {
            let request: serde_json::Value = match serde_json::from_slice(&message.payload) {
                Ok(req) => req,
                Err(e) => {
                    error!("Invalid render request: {}", e);
                    continue;
                }
            };
            
            let template_id = request.get("template_id")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            let context = request.get("context")
                .and_then(|v| v.as_object())
                .map(|obj| {
                    obj.iter()
                        .map(|(k, v)| (k.clone(), v.as_str().unwrap_or("").to_string()))
                        .collect()
                })
                .unwrap_or_default();
            
            match template_processor.render_template(template_id, &context).await {
                Ok(rendered) => {
                    let response = serde_json::json!({
                        "rendered": rendered,
                        "template_id": template_id
                    });
                    let response_bytes = serde_json::to_vec(&response)?;
                    if let Err(e) = message.respond(response_bytes.into()).await {
                        error!("Failed to respond to template render request: {}", e);
                    }
                }
                Err(e) => {
                    error!("Template render error: {}", e);
                    let error_response = serde_json::json!({"error": "Render error"});
                    let response = serde_json::to_vec(&error_response)?;
                    if let Err(e) = message.respond(response.into()).await {
                        error!("Failed to respond to template render request: {}", e);
                    }
                }
            }
        }
        
        Ok(())
    }
}
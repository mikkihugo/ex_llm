//! Template cache for performance

use anyhow::Result;
use moka::future::Cache;
use std::sync::Arc;
use std::time::Duration;
use super::Template;

/// Template cache for fast access
pub struct TemplateCache {
    cache: Cache<String, Template>,
}

impl TemplateCache {
    /// Create new template cache
    pub fn new() -> Self {
        let cache = Cache::builder()
            .time_to_live(Duration::from_secs(3600)) // 1 hour TTL
            .time_to_idle(Duration::from_secs(1800)) // 30 minutes idle
            .max_capacity(1000) // Max 1000 templates
            .build();
        
        Self { cache }
    }
    
    /// Get template from cache
    pub async fn get(&self, template_id: &str) -> Option<Template> {
        self.cache.get(template_id).await
    }
    
    /// Put template in cache
    pub async fn put(&self, template_id: &str, template: Template) {
        self.cache.insert(template_id.to_string(), template).await;
    }
    
    /// Remove template from cache
    pub async fn remove(&self, template_id: &str) {
        self.cache.remove(template_id).await;
    }
    
    /// Clear all templates from cache
    pub async fn clear(&self) {
        self.cache.invalidate_all().await;
    }
}

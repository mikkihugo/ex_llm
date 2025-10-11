//! Template storage backend using PostgreSQL

use anyhow::Result;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use std::collections::HashMap;
use super::{Template, TemplateSearchRequest};

/// Template storage backend
pub struct TemplateStore {
    pool: PgPool,
}

impl TemplateStore {
    /// Create new template store
    pub async fn new(database_url: &str) -> Result<Self> {
        let pool = PgPool::connect(database_url).await?;
        
        // Create tables if they don't exist
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS templates (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                template_type TEXT NOT NULL,
                language TEXT,
                framework TEXT,
                content TEXT NOT NULL,
                metadata JSONB,
                version INTEGER NOT NULL DEFAULT 1,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            "#,
        )
        .execute(&pool)
        .await?;
        
        // Create index for search
        sqlx::query(
            r#"
            CREATE INDEX IF NOT EXISTS idx_templates_search 
            ON templates USING gin(to_tsvector('english', name || ' ' || content))
            "#,
        )
        .execute(&pool)
        .await?;
        
        Ok(Self { pool })
    }
    
    /// Store template in database
    pub async fn store_template(&self, template: Template) -> Result<String> {
        let metadata_json = serde_json::to_value(template.metadata)?;
        
        sqlx::query(
            r#"
            INSERT INTO templates (id, name, template_type, language, framework, content, metadata, version, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                template_type = EXCLUDED.template_type,
                language = EXCLUDED.language,
                framework = EXCLUDED.framework,
                content = EXCLUDED.content,
                metadata = EXCLUDED.metadata,
                version = EXCLUDED.version + 1,
                updated_at = NOW()
            "#,
        )
        .bind(&template.id)
        .bind(&template.name)
        .bind(&template.template_type)
        .bind(&template.language)
        .bind(&template.framework)
        .bind(&template.content)
        .bind(&metadata_json)
        .bind(template.version)
        .bind(template.created_at)
        .bind(template.updated_at)
        .execute(&self.pool)
        .await?;
        
        Ok(template.id)
    }
    
    /// Get template by ID
    pub async fn get_template(&self, template_id: &str) -> Result<Option<Template>> {
        let row = sqlx::query(
            r#"
            SELECT id, name, template_type, language, framework, content, metadata, version, created_at, updated_at
            FROM templates
            WHERE id = $1
            "#,
        )
        .bind(template_id)
        .fetch_optional(&self.pool)
        .await?;
        
        if let Some(row) = row {
            let metadata: serde_json::Value = row.get("metadata");
            let metadata_map: HashMap<String, String> = serde_json::from_value(metadata)?;
            
            Ok(Some(Template {
                id: row.get("id"),
                name: row.get("name"),
                template_type: row.get("template_type"),
                language: row.get("language"),
                framework: row.get("framework"),
                content: row.get("content"),
                metadata: metadata_map,
                version: row.get("version"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            }))
        } else {
            Ok(None)
        }
    }
    
    /// Search templates
    pub async fn search_templates(&self, request: &TemplateSearchRequest) -> Result<Vec<Template>> {
        let mut query = "SELECT id, name, template_type, language, framework, content, metadata, version, created_at, updated_at FROM templates WHERE 1=1".to_string();
        let mut params: Vec<Box<dyn sqlx::Encode<'_, sqlx::Postgres> + Send + Sync>> = Vec::new();
        let mut param_count = 0;
        
        // Add search query
        if !request.query.is_empty() {
            param_count += 1;
            query.push_str(&format!(" AND to_tsvector('english', name || ' ' || content) @@ plainto_tsquery('english', ${})", param_count));
            params.push(Box::new(request.query.clone()));
        }
        
        // Add template type filter
        if let Some(ref template_type) = request.template_type {
            param_count += 1;
            query.push_str(&format!(" AND template_type = ${}", param_count));
            params.push(Box::new(template_type.clone()));
        }
        
        // Add language filter
        if let Some(ref language) = request.language {
            param_count += 1;
            query.push_str(&format!(" AND language = ${}", param_count));
            params.push(Box::new(language.clone()));
        }
        
        // Add limit
        let limit = request.limit.unwrap_or(50);
        query.push_str(&format!(" ORDER BY updated_at DESC LIMIT {}", limit));
        
        // Execute query
        let mut query_builder = sqlx::query(&query);
        for param in params {
            query_builder = query_builder.bind(param);
        }
        
        let rows = query_builder.fetch_all(&self.pool).await?;
        
        let mut templates = Vec::new();
        for row in rows {
            let metadata: serde_json::Value = row.get("metadata");
            let metadata_map: HashMap<String, String> = serde_json::from_value(metadata)?;
            
            templates.push(Template {
                id: row.get("id"),
                name: row.get("name"),
                template_type: row.get("template_type"),
                language: row.get("language"),
                framework: row.get("framework"),
                content: row.get("content"),
                metadata: metadata_map,
                version: row.get("version"),
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
            });
        }
        
        Ok(templates)
    }
}
use anyhow::Result;
use async_trait::async_trait;

pub mod pgvector;
pub mod qdrant;

/// Vector storage trait
#[async_trait]
pub trait VectorStore {
    async fn store(&self, id: &str, embedding: Vec<f32>, metadata: serde_json::Value) -> Result<()>;
    async fn search(&self, query: Vec<f32>, limit: usize) -> Result<Vec<SearchResult>>;
    async fn delete(&self, id: &str) -> Result<()>;
}

#[derive(Debug, Clone)]
pub struct SearchResult {
    pub id: String,
    pub score: f32,
    pub metadata: serde_json::Value,
}

/// Dual vector storage (pgvector primary, qdrant optional)
pub struct VectorManager {
    pgvector: Option<Box<dyn VectorStore + Send + Sync>>,
    qdrant: Option<Box<dyn VectorStore + Send + Sync>>,
}

impl VectorManager {
    pub fn new() -> Self {
        Self {
            pgvector: None,
            qdrant: None,
        }
    }

    pub async fn search(&self, query: Vec<f32>, limit: usize) -> Result<Vec<SearchResult>> {
        if let Some(pg) = &self.pgvector {
            return pg.search(query, limit).await;
        }

        Ok(vec![])
    }
}

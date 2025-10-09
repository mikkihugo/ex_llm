use anyhow::Result;
use async_trait::async_trait;
use sqlx::PgPool;

pub mod pool;
pub mod templates;
pub mod packages;
pub mod knowledge;
pub mod code_analysis;

/// Central database configuration
#[derive(Debug, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
}

/// Database connection pool manager
pub struct Database {
    pool: PgPool,
}

impl Database {
    pub async fn new(config: DatabaseConfig) -> Result<Self> {
        let pool = sqlx::postgres::PgPoolOptions::new()
            .max_connections(config.max_connections)
            .connect(&config.url)
            .await?;

        Ok(Self { pool })
    }

    pub fn pool(&self) -> &PgPool {
        &self.pool
    }
}

#[async_trait]
pub trait Repository {
    type Entity;
    type Id;

    async fn find_by_id(&self, id: Self::Id) -> Result<Option<Self::Entity>>;
    async fn save(&self, entity: &Self::Entity) -> Result<Self::Id>;
    async fn delete(&self, id: Self::Id) -> Result<()>;
}

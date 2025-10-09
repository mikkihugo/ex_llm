//! Dependency Catalog Storage - Direct PostgreSQL connection
//!
//! **Product:** Dependency Catalog - Your searchable library index
//! **Table:** dependency_catalog (in singularity database)
//! **Cache:** Optional JetStream KV (1hr TTL, read-through)

use super::{PackageKey, PackageMetadata, PackageStorage, StorageStats};
use anyhow::Result;
use async_trait::async_trait;
use tokio_postgres::{Client, NoTls};
use tracing::{debug, info, warn};
use uuid::Uuid;

/// PostgreSQL storage backend
pub struct DependencyCatalogStorage {
    pg_client: Client,
    jetstream_cache: Option<JetStreamCache>,
}

struct JetStreamCache {
    kv_store: async_nats::jetstream::kv::Store,
}

impl DependencyCatalogStorage {
    /// Create new PostgreSQL storage
    /// 
    /// Connects directly to dependency_catalog table
    pub async fn new(db_url: &str, nats_url: Option<&str>) -> Result<Self> {
        let (pg_client, connection) = tokio_postgres::connect(db_url, NoTls).await?;
        
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                eprintln!("PostgreSQL error: {}", e);
            }
        });
        
        info!("PostgreSQL connected: dependency_catalog table");
        
        let jetstream_cache = if let Some(url) = nats_url {
            JetStreamCache::new(url).await.ok()
        } else {
            None
        };
        
        Ok(Self { pg_client, jetstream_cache })
    }
}

impl JetStreamCache {
    async fn new(nats_url: &str) -> Result<Self> {
        let client = async_nats::connect(nats_url).await?;
        let js = async_nats::jetstream::new(client);
        
        let kv_store = js.create_key_value(async_nats::jetstream::kv::Config {
            bucket: "dependency_catalog".to_string(),
            max_value_size: 1024 * 1024,
            history: 1,
            max_age: std::time::Duration::from_secs(3600),
            ..Default::default()
        }).await?;
        
        info!("JetStream cache enabled");
        Ok(Self { kv_store })
    }
    
    fn key(k: &PackageKey) -> String {
        format!("{}.{}.{}", k.ecosystem, k.tool, k.version)
    }
    
    async fn get(&self, key: &PackageKey) -> Option<PackageMetadata> {
        self.kv_store.get(&Self::key(key)).await.ok()
            .and_then(|entry| entry)
            .and_then(|e| serde_json::from_slice(&e).ok())
    }
    
    async fn set(&self, key: &PackageKey, meta: &PackageMetadata) {
        if let Ok(v) = serde_json::to_vec(meta) {
            let _ = self.kv_store.put(&Self::key(key), v.into()).await;
        }
    }
    
    async fn del(&self, key: &PackageKey) {
        let _ = self.kv_store.delete(&Self::key(key)).await;
    }
}

#[async_trait]
impl PackageStorage for DependencyCatalogStorage {
    async fn store_fact(&self, key: &PackageKey, data: &PackageMetadata) -> Result<()> {
        let id = Uuid::new_v4();
        
        self.pg_client.execute(
            "INSERT INTO dependency_catalog 
             (id, package_name, version, ecosystem, description, documentation, tags)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             ON CONFLICT (package_name, version, ecosystem)
             DO UPDATE SET description = $5, documentation = $6, tags = $7",
            &[&id.to_string(), &key.tool, &key.version, &key.ecosystem, 
              &data.documentation.get(..500).unwrap_or(""), 
              &data.documentation, &data.tags]
        ).await?;
        
        if let Some(ref cache) = self.jetstream_cache {
            cache.set(key, data).await;
        }
        
        Ok(())
    }

    async fn get_fact(&self, key: &PackageKey) -> Result<Option<PackageMetadata>> {
        if let Some(ref cache) = self.jetstream_cache {
            if let Some(cached) = cache.get(key).await {
                return Ok(Some(cached));
            }
        }
        
        let row = self.pg_client.query_opt(
            "SELECT package_name, version, ecosystem, documentation, tags 
             FROM dependency_catalog 
             WHERE package_name = $1 AND version = $2 AND ecosystem = $3",
            &[&key.tool, &key.version, &key.ecosystem]
        ).await?;
        
        Ok(row.map(|r| PackageMetadata {
            tool: r.get(0),
            version: r.get(1),
            ecosystem: r.get(2),
            documentation: r.get(3),
            tags: r.get(4),
            ..Default::default()
        }))
    }

    async fn exists(&self, key: &PackageKey) -> Result<bool> {
        Ok(self.get_fact(key).await?.is_some())
    }

    async fn delete_fact(&self, key: &PackageKey) -> Result<()> {
        self.pg_client.execute(
            "DELETE FROM dependency_catalog WHERE package_name = $1 AND version = $2 AND ecosystem = $3",
            &[&key.tool, &key.version, &key.ecosystem]
        ).await?;
        
        if let Some(ref cache) = self.jetstream_cache {
            cache.del(key).await;
        }
        
        Ok(())
    }

    async fn list_tools(&self, ecosystem: &str) -> Result<Vec<PackageKey>> {
        let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem FROM dependency_catalog WHERE ecosystem = $1",
            &[&ecosystem]
        ).await?;
        
        Ok(rows.iter().map(|r| PackageKey {
            tool: r.get(0),
            version: r.get(1),
            ecosystem: r.get(2),
        }).collect())
    }

    async fn search_tools(&self, prefix: &str) -> Result<Vec<PackageKey>> {
        let pattern = format!("{}%", prefix);
        let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem FROM dependency_catalog WHERE package_name LIKE $1",
            &[&pattern]
        ).await?;
        
        Ok(rows.iter().map(|r| PackageKey {
            tool: r.get(0),
            version: r.get(1),
            ecosystem: r.get(2),
        }).collect())
    }

    async fn stats(&self) -> Result<StorageStats> {
        let row = self.pg_client.query_one("SELECT COUNT(*) FROM dependency_catalog", &[]).await?;
        Ok(StorageStats {
            total_entries: row.get::<_, i64>(0) as u64,
            total_size_bytes: 0,
            ecosystems: std::collections::HashMap::new(),
            last_compaction: None,
        })
    }

    async fn search_by_tags(&self, tags: &[String]) -> Result<Vec<PackageKey>> {
        let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem FROM dependency_catalog WHERE tags && $1::text[]",
            &[&tags]
        ).await?;
        
        Ok(rows.iter().map(|r| PackageKey {
            tool: r.get(0),
            version: r.get(1),
            ecosystem: r.get(2),
        }).collect())
    }

    async fn get_all_facts(&self) -> Result<Vec<(PackageKey, PackageMetadata)>> {
        let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem, documentation, tags FROM dependency_catalog",
            &[]
        ).await?;
        
        Ok(rows.iter().map(|r| {
            let key = PackageKey {
                tool: r.get(0),
                version: r.get(1),
                ecosystem: r.get(2),
            };
            let meta = PackageMetadata {
                tool: r.get(0),
                version: r.get(1),
                ecosystem: r.get(2),
                documentation: r.get(3),
                tags: r.get(4),
                ..Default::default()
            };
            (key, meta)
        }).collect())
    }
}

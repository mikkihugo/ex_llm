//! Dependency Catalog Storage - Direct PostgreSQL connection
//!
//! **Product:** Dependency Catalog - Your searchable library index
//! **Table:** dependency_catalog (in singularity database)
//! **Cache:** PostgreSQL only (NATS JetStream disabled in Phase 4)
//! **Note:** For persistent message queue, use pgmq or ex_pgflow via Elixir

use super::{PackageKey, PackageMetadata, PackageStorage, StorageStats};
use anyhow::Result;
use async_trait::async_trait;
use tokio_postgres::{Client, NoTls};
use tracing::{debug, info, warn};
use uuid::Uuid;

/// PostgreSQL storage backend
pub struct DependencyCatalogStorage {
  pg_client: Client,
  // jetstream_cache: Option<JetStreamCache>,  // NATS JetStream disabled - Phase 4 NATS removal
}

// Stub for disabled JetStreamCache
// struct JetStreamCache {
//     kv_store: async_nats::jetstream::kv::Store,
// }

impl DependencyCatalogStorage {
  /// Create new PostgreSQL storage
  ///
  /// Connects directly to dependency_catalog table
  /// NOTE: NATS JetStream caching disabled - Phase 4 NATS removal
  /// Use pgmq or ex_pgflow via Elixir for message queue functionality
  pub async fn new(db_url: &str, _nats_url: Option<&str>) -> Result<Self> {
    let (pg_client, connection) =
      tokio_postgres::connect(db_url, NoTls).await?;

    tokio::spawn(async move {
      if let Err(e) = connection.await {
        eprintln!("PostgreSQL error: {}", e);
      }
    });

    info!(
      "PostgreSQL connected: dependency_catalog table (NATS caching disabled)"
    );

    // NATS JetStream caching disabled - use PostgreSQL only
    // let jetstream_cache = if let Some(url) = nats_url {
    //     JetStreamCache::new(url).await.ok()
    // } else {
    //     None
    // };

    Ok(Self {
      pg_client, /* jetstream_cache: None */
    })
  }
}

// Disabled JetStream cache implementation (NATS removed in Phase 4)
// Entire impl block removed - use PostgreSQL only
//
// Previous implementation used:
// - async_nats::jetstream::kv::Store for distributed caching
// - Key-value store with TTL (3600s max_age)
// - Async methods: new(), key(), get(), set(), del()
//
// Replaced by: Direct PostgreSQL storage (dependency_catalog table)

#[async_trait]
impl PackageStorage for DependencyCatalogStorage {
  async fn store_fact(
    &self,
    key: &PackageKey,
    data: &PackageMetadata,
  ) -> Result<()> {
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

    // NATS JetStream caching disabled - PostgreSQL only

    Ok(())
  }

  async fn get_fact(
    &self,
    key: &PackageKey,
  ) -> Result<Option<PackageMetadata>> {
    // NATS JetStream caching disabled - PostgreSQL only

    let row = self
      .pg_client
      .query_opt(
        "SELECT package_name, version, ecosystem, documentation, tags
             FROM dependency_catalog
             WHERE package_name = $1 AND version = $2 AND ecosystem = $3",
        &[&key.tool, &key.version, &key.ecosystem],
      )
      .await?;

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

    // NATS JetStream caching disabled - PostgreSQL only

    Ok(())
  }

  async fn list_tools(&self, ecosystem: &str) -> Result<Vec<PackageKey>> {
    let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem FROM dependency_catalog WHERE ecosystem = $1",
            &[&ecosystem]
        ).await?;

    Ok(
      rows
        .iter()
        .map(|r| PackageKey {
          tool: r.get(0),
          version: r.get(1),
          ecosystem: r.get(2),
        })
        .collect(),
    )
  }

  async fn search_tools(&self, prefix: &str) -> Result<Vec<PackageKey>> {
    let pattern = format!("{}%", prefix);
    let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem FROM dependency_catalog WHERE package_name LIKE $1",
            &[&pattern]
        ).await?;

    Ok(
      rows
        .iter()
        .map(|r| PackageKey {
          tool: r.get(0),
          version: r.get(1),
          ecosystem: r.get(2),
        })
        .collect(),
    )
  }

  async fn stats(&self) -> Result<StorageStats> {
    let row = self
      .pg_client
      .query_one("SELECT COUNT(*) FROM dependency_catalog", &[])
      .await?;
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

    Ok(
      rows
        .iter()
        .map(|r| PackageKey {
          tool: r.get(0),
          version: r.get(1),
          ecosystem: r.get(2),
        })
        .collect(),
    )
  }

  async fn get_all_facts(&self) -> Result<Vec<(PackageKey, PackageMetadata)>> {
    let rows = self.pg_client.query(
            "SELECT package_name, version, ecosystem, documentation, tags FROM dependency_catalog",
            &[]
        ).await?;

    Ok(
      rows
        .iter()
        .map(|r| {
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
        })
        .collect(),
    )
  }
}

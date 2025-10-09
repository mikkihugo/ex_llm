//! Package Metadata Server
//!
//! Package metadata collection and storage management.
//! Handles package info, documentation, version tracking, and redb storage.

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod storage;
pub mod package_file_watcher;
pub mod nats_service;

/// Metadata server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetadataConfig {
    pub storage_path: String,
    pub cache_size: usize,
    pub watch_interval: u64,
}

/// Package metadata server
pub struct PackageMetadataServer {
    config: MetadataConfig,
    storage: Box<dyn storage::PackageStorage>,
}

impl PackageMetadataServer {
    pub fn new(config: MetadataConfig) -> Self {
        Self {
            config,
            storage: Box::new(storage::create_storage(&config.storage_path)),
        }
    }

    /// Store package metadata
    pub async fn store_metadata(&self, metadata: storage::PackageMetadata) -> Result<()> {
        self.storage.store_package(metadata).await
    }

    /// Get package metadata
    pub async fn get_metadata(&self, package_key: &storage::PackageKey) -> Result<Option<storage::PackageMetadata>> {
        self.storage.get_package(package_key).await
    }

    /// List packages by ecosystem
    pub async fn list_packages(&self, ecosystem: &str) -> Result<Vec<storage::PackageMetadata>> {
        self.storage.list_packages(ecosystem).await
    }
}

impl Default for MetadataConfig {
    fn default() -> Self {
        Self {
            storage_path: "./data/metadata".to_string(),
            cache_size: 1000,
            watch_interval: 30,
        }
    }
}

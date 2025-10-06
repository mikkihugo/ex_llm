//! NATS Service for Package Registry Indexer
//!
//! Exposes package collection and technology detection via NATS.
//!
//! **Architecture:**
//! - Elixir → NATS → package_registry_indexer → tech_detector (library)
//!
//! **NATS Subjects:**
//! - `packages.registry.collect.npm` - Collect npm package
//! - `packages.registry.collect.cargo` - Collect cargo package
//! - `packages.registry.detect.frameworks` - Detect frameworks in codebase
//! - `packages.registry.search` - Search package registry

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use tracing::{info, warn, error};
use tech_detector::{TechDetector, DetectionResults};

/// Request to collect a package from registry
#[derive(Debug, Deserialize)]
pub struct CollectPackageRequest {
    pub package_name: String,
    pub version: Option<String>,
    pub ecosystem: String, // npm, cargo, hex, pypi
}

/// Response with package metadata
#[derive(Debug, Serialize)]
pub struct CollectPackageResponse {
    pub package_name: String,
    pub version: String,
    pub success: bool,
    pub error: Option<String>,
}

/// Request to detect technologies in codebase
#[derive(Debug, Deserialize)]
pub struct DetectFrameworksRequest {
    pub codebase_path: String,
}

/// Package Registry NATS Service
pub struct PackageRegistryNatsService {
    nats_client: Client,
    tech_detector: TechDetector,
}

impl PackageRegistryNatsService {
    /// Create new NATS service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        let tech_detector = TechDetector::new().await?;

        info!("Package Registry NATS service connected to {}", nats_url);

        Ok(Self {
            nats_client,
            tech_detector,
        })
    }

    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Package Registry NATS service...");

        // Spawn handlers for each subject
        let frameworks_sub = self.nats_client.subscribe("packages.registry.detect.frameworks").await?;
        let npm_sub = self.nats_client.subscribe("packages.registry.collect.npm").await?;
        let cargo_sub = self.nats_client.subscribe("packages.registry.collect.cargo").await?;

        // Handle frameworks detection
        tokio::spawn(async move {
            while let Some(msg) = frameworks_sub.next().await {
                // Handle detection request
                info!("Received framework detection request");
            }
        });

        info!("Package Registry NATS service started");
        Ok(())
    }
}

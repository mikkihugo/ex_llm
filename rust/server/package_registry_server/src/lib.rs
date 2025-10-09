//! Package Registry Server
//!
//! Central registry integration and coordination for npm, cargo, hex, and pypi.
//! Handles registry API clients, GitHub integration, rate limiting, and data normalization.

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod collector;
pub mod github;
pub mod graphql;
pub mod nats_service;

/// Registry configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegistryConfig {
    pub npm: NpmConfig,
    pub cargo: CargoConfig,
    pub hex: HexConfig,
    pub pypi: PypiConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NpmConfig {
    pub registry_url: String,
    pub api_key: Option<String>,
    pub rate_limit: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CargoConfig {
    pub registry_url: String,
    pub api_key: Option<String>,
    pub rate_limit: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HexConfig {
    pub registry_url: String,
    pub api_key: Option<String>,
    pub rate_limit: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PypiConfig {
    pub registry_url: String,
    pub api_key: Option<String>,
    pub rate_limit: u32,
}

/// Package registry server
pub struct PackageRegistryServer {
    config: RegistryConfig,
    collectors: std::collections::HashMap<String, Box<dyn collector::PackageCollector>>,
}

impl PackageRegistryServer {
    pub fn new(config: RegistryConfig) -> Self {
        Self {
            config,
            collectors: std::collections::HashMap::new(),
        }
    }

    /// Register a package collector for an ecosystem
    pub fn register_collector(&mut self, ecosystem: String, collector: Box<dyn collector::PackageCollector>) {
        self.collectors.insert(ecosystem, collector);
    }

    /// Collect package data from registry
    pub async fn collect_package(&self, ecosystem: &str, package: &str, version: &str) -> Result<collector::PackageMetadata> {
        if let Some(collector) = self.collectors.get(ecosystem) {
            collector.collect(package, version).await
        } else {
            Err(anyhow::anyhow!("No collector registered for ecosystem: {}", ecosystem))
        }
    }
}

impl Default for RegistryConfig {
    fn default() -> Self {
        Self {
            npm: NpmConfig {
                registry_url: "https://registry.npmjs.org".to_string(),
                api_key: None,
                rate_limit: 1000,
            },
            cargo: CargoConfig {
                registry_url: "https://crates.io".to_string(),
                api_key: None,
                rate_limit: 1000,
            },
            hex: HexConfig {
                registry_url: "https://hex.pm".to_string(),
                api_key: None,
                rate_limit: 1000,
            },
            pypi: PypiConfig {
                registry_url: "https://pypi.org".to_string(),
                api_key: None,
                rate_limit: 1000,
            },
        }
    }
}

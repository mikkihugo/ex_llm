//! Package Security Server
//!
//! Security advisory and vulnerability management.
//! Handles security advisories from GitHub, RustSec, npm audit, and vulnerability tracking.

use anyhow::Result;
use serde::{Deserialize, Serialize};

pub mod github_advisory;
pub mod npm_advisory;
pub mod rustsec_advisory;
pub mod nats_service;

/// Security server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityConfig {
    pub advisory_sources: Vec<String>,
    pub scan_interval: u64,
    pub alert_threshold: f64,
}

/// Package security server
pub struct PackageSecurityServer {
    config: SecurityConfig,
    advisories: Vec<SecurityAdvisory>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityAdvisory {
    pub package_name: String,
    pub ecosystem: String,
    pub vulnerability_id: String,
    pub severity: String,
    pub description: String,
    pub affected_versions: Vec<String>,
    pub patched_versions: Vec<String>,
}

impl PackageSecurityServer {
    pub fn new(config: SecurityConfig) -> Self {
        Self {
            config,
            advisories: Vec::new(),
        }
    }

    /// Scan for security advisories
    pub async fn scan_advisories(&mut self) -> Result<()> {
        // Scan GitHub advisories
        let github_advisories = github_advisory::fetch_advisories().await?;
        
        // Scan npm advisories
        let npm_advisories = npm_advisory::fetch_advisories().await?;
        
        // Scan RustSec advisories
        let rustsec_advisories = rustsec_advisory::fetch_advisories().await?;
        
        // Combine all advisories
        self.advisories.extend(github_advisories);
        self.advisories.extend(npm_advisories);
        self.advisories.extend(rustsec_advisories);
        
        Ok(())
    }

    /// Get advisories for a package
    pub fn get_package_advisories(&self, package_name: &str, ecosystem: &str) -> Vec<&SecurityAdvisory> {
        self.advisories.iter()
            .filter(|adv| adv.package_name == package_name && adv.ecosystem == ecosystem)
            .collect()
    }
}

impl Default for SecurityConfig {
    fn default() -> Self {
        Self {
            advisory_sources: vec![
                "github".to_string(),
                "npm".to_string(),
                "rustsec".to_string(),
            ],
            scan_interval: 3600, // 1 hour
            alert_threshold: 7.0, // High severity
        }
    }
}

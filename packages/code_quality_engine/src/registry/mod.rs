//! Meta Registry and Package Registry
//!
//! Central registry for package knowledge, meta information, and cross-instance learning.
//! Integrates with CentralCloud for consensus and pattern aggregation.


use std::collections::HashMap;
use serde::{Deserialize, Serialize};

/// Meta registry for storing and retrieving package and pattern metadata
pub struct MetaRegistry {
    package_registry: PackageRegistry,
    pattern_registry: PatternRegistry,
}

impl MetaRegistry {
    pub fn new() -> Self {
        Self {
            package_registry: PackageRegistry::new(),
            pattern_registry: PatternRegistry::new(),
        }
    }

    /// Register package information
    pub async fn register_package(&mut self, package: PackageInfo) -> Result<(), RegistryError> {
        self.package_registry.register_package(package).await
    }

    /// Get package information
    pub async fn get_package(&self, name: &str, ecosystem: &str) -> Result<Option<PackageInfo>, RegistryError> {
        self.package_registry.get_package(name, ecosystem).await
    }

    /// Register pattern metadata
    pub async fn register_pattern(&mut self, pattern: PatternMetadata) -> Result<(), RegistryError> {
        self.pattern_registry.register_pattern(pattern).await
    }

    /// Get pattern metadata
    pub async fn get_pattern(&self, pattern_id: &str) -> Result<Option<PatternMetadata>, RegistryError> {
        self.pattern_registry.get_pattern(pattern_id).await
    }

    /// Search packages by criteria
    pub async fn search_packages(&self, query: &PackageQuery) -> Result<Vec<PackageInfo>, RegistryError> {
        self.package_registry.search_packages(query).await
    }

    /// Sync with CentralCloud
    pub async fn sync_with_centralcloud(&mut self) -> Result<(), RegistryError> {
        // TODO: Implement CentralCloud sync via pgmq queues
        // Instead of direct HTTP calls:
        // 1. Send registry data to "centralcloud_sync" queue
        // 2. ex_pgflow workflow consumes and forwards to CentralCloud
        // 3. Receive consensus data back through response queues
        // 4. Update local registry with merged results

        Ok(())
    }
}

impl Default for MetaRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Package registry for storing package information
pub struct PackageRegistry {
    packages: HashMap<String, HashMap<String, PackageInfo>>, // ecosystem -> name -> info
}

impl PackageRegistry {
    pub fn new() -> Self {
        Self {
            packages: HashMap::new(),
        }
    }

    pub async fn register_package(&mut self, package: PackageInfo) -> Result<(), RegistryError> {
        let ecosystem_packages = self
            .packages
            .entry(package.ecosystem.clone())
            .or_default();

        ecosystem_packages.insert(package.name.clone(), package);
        Ok(())
    }

    pub async fn get_package(&self, name: &str, ecosystem: &str) -> Result<Option<PackageInfo>, RegistryError> {
        Ok(self.packages
            .get(ecosystem)
            .and_then(|ecosystem_packages| ecosystem_packages.get(name))
            .cloned())
    }

    pub async fn search_packages(&self, query: &PackageQuery) -> Result<Vec<PackageInfo>, RegistryError> {
        let mut results = Vec::new();

        for ecosystem_packages in self.packages.values() {
            for package in ecosystem_packages.values() {
                if self.matches_query(package, query) {
                    results.push(package.clone());
                }
            }
        }

        Ok(results)
    }

    fn matches_query(&self, package: &PackageInfo, query: &PackageQuery) -> bool {
        if let Some(name_query) = &query.name_contains {
            if !package.name.contains(name_query) {
                return false;
            }
        }

        if let Some(ecosystem_query) = &query.ecosystem {
            if package.ecosystem != *ecosystem_query {
                return false;
            }
        }

        if let Some(category_query) = &query.category {
            if !package.categories.contains(category_query) {
                return false;
            }
        }

        true
    }
}

impl Default for PackageRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Pattern registry for storing pattern metadata
pub struct PatternRegistry {
    patterns: HashMap<String, PatternMetadata>,
}

impl PatternRegistry {
    pub fn new() -> Self {
        Self {
            patterns: HashMap::new(),
        }
    }

    pub async fn register_pattern(&mut self, pattern: PatternMetadata) -> Result<(), RegistryError> {
        self.patterns.insert(pattern.id.clone(), pattern);
        Ok(())
    }

    pub async fn get_pattern(&self, pattern_id: &str) -> Result<Option<PatternMetadata>, RegistryError> {
        Ok(self.patterns.get(pattern_id).cloned())
    }
}

impl Default for PatternRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Package information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageInfo {
    pub name: String,
    pub ecosystem: String, // "npm", "cargo", "pypi", "rubygems", etc.
    pub version: String,
    pub description: Option<String>,
    pub homepage: Option<String>,
    pub repository: Option<String>,
    pub categories: Vec<String>,
    pub keywords: Vec<String>,
    pub dependencies: Vec<PackageDependency>,
    pub metadata: HashMap<String, serde_json::Value>,
    pub last_updated: chrono::DateTime<chrono::Utc>,
}

/// Package dependency
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageDependency {
    pub name: String,
    pub version_constraint: String,
    pub ecosystem: String,
}

/// Pattern metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PatternMetadata {
    pub id: String,
    pub name: String,
    pub pattern_type: String,
    pub description: String,
    pub confidence_score: f64,
    pub usage_count: u64,
    pub success_rate: f64,
    pub tags: Vec<String>,
    pub metadata: HashMap<String, serde_json::Value>,
    pub last_updated: chrono::DateTime<chrono::Utc>,
}

/// Package search query
#[derive(Debug, Clone, Default)]
pub struct PackageQuery {
    pub name_contains: Option<String>,
    pub ecosystem: Option<String>,
    pub category: Option<String>,
    pub limit: Option<usize>,
}

/// Registry error
#[derive(Debug, thiserror::Error)]
pub enum RegistryError {
    #[error("Package not found: {0}")]
    PackageNotFound(String),

    #[error("Pattern not found: {0}")]
    PatternNotFound(String),

    #[error("CentralCloud sync error: {0}")]
    CentralCloudError(String),

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

// NIF interface for Elixir integration

/// Register package via NIF
#[no_mangle]
pub extern "C" fn register_package_nif(
    _package_json: *const std::os::raw::c_char,
) -> *mut std::os::raw::c_char {
    // TODO: Implement NIF interface
    // This would parse JSON package info and register it
    let result = r#"{"status": "success"}"#;
    let c_string = std::ffi::CString::new(result).unwrap();
    c_string.into_raw()
}

/// Search packages via NIF
#[no_mangle]
pub extern "C" fn search_packages_nif(
    _query_json: *const std::os::raw::c_char,
) -> *mut std::os::raw::c_char {
    // TODO: Implement NIF interface
    // This would parse query JSON and return matching packages
    let result = r#"{"packages": []}"#;
    let c_string = std::ffi::CString::new(result).unwrap();
    c_string.into_raw()
}

/// Sync registry with CentralCloud via NIF
#[no_mangle]
pub extern "C" fn sync_registry_nif() -> *mut std::os::raw::c_char {
    // TODO: Implement NIF interface
    // This would trigger sync with CentralCloud
    let result = r#"{"status": "sync_started"}"#;
    let c_string = std::ffi::CString::new(result).unwrap();
    c_string.into_raw()
}
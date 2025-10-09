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
#[cfg(feature = "detection")]
use tech_detector::{TechDetector, DetectionResults};
use futures_util::StreamExt;

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

/// Request to search packages
#[derive(Debug, Deserialize)]
pub struct SearchPackagesRequest {
    pub query: String,
    pub ecosystem: String,
    pub limit: usize,
}

/// Package search result
#[derive(Debug, Serialize)]
pub struct PackageSearchResult {
    pub package_name: String,
    pub version: String,
    pub description: String,
    pub downloads: u64,
    pub stars: Option<u64>,
    pub ecosystem: String,
    pub similarity: f64,
    pub tags: Vec<String>,
}

/// Package Registry NATS Service
pub struct PackageRegistryNatsService {
    nats_client: Client,
    #[cfg(feature = "detection")]
    tech_detector: TechDetector,
}

impl PackageRegistryNatsService {
    /// Create new NATS service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        #[cfg(feature = "detection")]
        let tech_detector = TechDetector::new().await?;

        info!("Package Registry NATS service connected to {}", nats_url);

        Ok(Self {
            nats_client,
            #[cfg(feature = "detection")]
            tech_detector,
        })
    }

    /// Start listening on NATS subjects
    pub async fn start(&self) -> Result<()> {
        info!("Starting Package Registry NATS service...");

        // Spawn handlers for each subject
        let mut frameworks_sub = self.nats_client.subscribe("packages.registry.detect.frameworks").await?;
        let mut search_sub = self.nats_client.subscribe("packages.registry.search").await?;
        let npm_sub = self.nats_client.subscribe("packages.registry.collect.npm").await?;
        let cargo_sub = self.nats_client.subscribe("packages.registry.collect.cargo").await?;

        // Handle package search requests
        let nats_client = self.nats_client.clone();
        tokio::spawn(async move {
            while let Some(msg) = search_sub.next().await {
                if let Err(e) = handle_search_request(&nats_client, &msg).await {
                    error!("Failed to handle search request: {}", e);
                }
            }
        });

        // Handle frameworks detection
        #[cfg(feature = "detection")]
        {
            let tech_detector = self.tech_detector.clone();
            tokio::spawn(async move {
                while let Some(msg) = frameworks_sub.next().await {
                    // Handle detection request
                    info!("Received framework detection request");
                    // TODO: Implement framework detection logic
                }
            });
        }

        info!("Package Registry NATS service started");
        Ok(())
    }
}

/// Handle package search requests
async fn handle_search_request(nats_client: &Client, msg: &async_nats::Message) -> Result<()> {
    info!("Received package search request");
    
    // Parse request
    let request: SearchPackagesRequest = match serde_json::from_slice(&msg.payload) {
        Ok(req) => req,
        Err(e) => {
            error!("Failed to parse search request: {}", e);
            return Ok(());
        }
    };
    
    // Search packages from database
    let results = match search_packages_from_db(&request.query, &request.ecosystem, request.limit).await {
        Ok(packages) => packages,
        Err(e) => {
            error!("Database search failed: {}", e);
            // Fallback to empty results
            Vec::new()
        }
    };
    
    // Send response
    let response_json = serde_json::to_string(&results)?;
    if let Some(reply_to) = &msg.reply {
        nats_client.publish(reply_to.clone(), response_json.into()).await?;
    }
    
    Ok(())
}

/// Search packages from database
async fn search_packages_from_db(query: &str, ecosystem: &str, limit: usize) -> Result<Vec<PackageSearchResult>> {
    // Connect to database
    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://postgres:password@localhost:5432/singularity".to_string());
    
    let (client, connection) = tokio_postgres::connect(&db_url, tokio_postgres::NoTls).await?;
    
    // Spawn connection task
    tokio::spawn(async move {
        if let Err(e) = connection.await {
            error!("PostgreSQL connection error: {}", e);
        }
    });
    
    // Search packages in database
    let rows = client.query(
        "SELECT package_name, version, ecosystem, description, github_stars, download_count, tags 
         FROM dependency_catalog 
         WHERE ecosystem = $1 AND (
             package_name ILIKE $2 OR 
             description ILIKE $2 OR 
             $3 = ANY(tags)
         )
         ORDER BY github_stars DESC, download_count DESC
         LIMIT $4",
        &[&ecosystem, &format!("%{}%", query), &query, &(limit as i32)]
    ).await?;
    
    let mut results = Vec::new();
    
    for row in rows {
        let package_name: String = row.get(0);
        let version: String = row.get(1);
        let ecosystem: String = row.get(2);
        let description: String = row.get(3);
        let github_stars: Option<i32> = row.get(4);
        let download_count: Option<i64> = row.get(5);
        let tags: Vec<String> = row.get(6);
        
        let similarity = calculate_similarity(query, &format!("{} {}", package_name, description));
        
        results.push(PackageSearchResult {
            package_name,
            version,
            description,
            downloads: download_count.unwrap_or(0) as u64,
            stars: github_stars.map(|s| s as u64),
            ecosystem,
            similarity,
            tags,
        });
    }
    
    // Sort by similarity and take limit
    results.sort_by(|a, b| b.similarity.partial_cmp(&a.similarity).unwrap());
    results.truncate(limit);
    
    Ok(results)
}

/// Simple similarity calculation
fn calculate_similarity(query: &str, description: &str) -> f64 {
    let query_words: std::collections::HashSet<String> = query
        .to_lowercase()
        .split_whitespace()
        .map(|s| s.to_string())
        .collect();
    
    let desc_words: std::collections::HashSet<String> = description
        .to_lowercase()
        .split_whitespace()
        .map(|s| s.to_string())
        .collect();
    
    let intersection = query_words.intersection(&desc_words).count();
    let union = query_words.union(&desc_words).count();
    
    if union == 0 {
        0.0
    } else {
        intersection as f64 / union as f64
    }
}

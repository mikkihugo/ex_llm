//! Server module for unified analysis engine
//!
//! Provides comprehensive package and repository analysis services for Elixir via NATS.
//! Uses the same parsers as NIF but focuses on external package and git repository analysis.

use anyhow::Result;
use async_nats::Client;
use serde::{Deserialize, Serialize};
use tracing::{info, warn, error};

use crate::{
    types::*,
    parsers::UnifiedParsers,
    features::{FeatureAwareEngine, create_server_config},
};

/// Search request with pagination and filters
#[derive(Debug, Deserialize)]
pub struct SearchRequest {
    pub query: String,
    pub page: Option<usize>,
    pub per_page: Option<usize>,
    pub filters: Option<SearchFilters>,
}

/// Search filters
#[derive(Debug, Deserialize)]
pub struct SearchFilters {
    pub ecosystem: Option<String>, // npm, cargo, hex, pypi, github, gitlab
    pub quality: Option<String>,   // high, medium, low
    pub security: Option<String>,  // clean, warnings, issues
    pub category: Option<String>,  // frontend, backend, tools, testing
}

/// Search result item
#[derive(Debug, Serialize)]
pub struct SearchResultItem {
    pub name: String,
    pub ecosystem: String,
    pub version: String,
    pub description: String,
    pub downloads: u64,
    pub stars: Option<u64>,
    pub quality_score: f64,
    pub security_score: f64,
    pub has_cves: bool,
    pub last_updated: String,
    pub license: Option<String>,
}

/// Search facets
#[derive(Debug, Serialize)]
pub struct SearchFacets {
    pub ecosystems: std::collections::HashMap<String, usize>,
    pub categories: std::collections::HashMap<String, usize>,
    pub quality_ranges: std::collections::HashMap<String, usize>,
    pub security_levels: std::collections::HashMap<String, usize>,
}

/// Search response
#[derive(Debug, Serialize)]
pub struct SearchResponse {
    pub query: String,
    pub total_results: usize,
    pub page: usize,
    pub per_page: usize,
    pub results: Vec<SearchResultItem>,
    pub facets: SearchFacets,
    pub suggestions: Vec<String>,
    pub next_page: Option<usize>,
    pub prev_page: Option<usize>,
}

/// Analysis request
#[derive(Debug, Deserialize)]
pub struct AnalysisRequest {
    pub package_name: String,
    pub version: Option<String>,
    pub ecosystem: String,
}

/// Analysis response
#[derive(Debug, Serialize)]
pub struct AnalysisResponse {
    pub package_name: String,
    pub ecosystem: String,
    pub version: String,
    pub full_analysis: FullAnalysis,
}

/// Full analysis data
#[derive(Debug, Serialize)]
pub struct FullAnalysis {
    pub cves: Vec<CveInfo>,
    pub dependencies: Vec<DependencyInfo>,
    pub architecture: ArchitectureAnalysis,
    pub performance: PerformanceAnalysis,
    pub insights: Vec<String>,
    pub recommendations: Vec<String>,
    pub warnings: Vec<String>,
}

/// CVE information
#[derive(Debug, Serialize)]
pub struct CveInfo {
    pub id: String,
    pub severity: String,
    pub description: String,
    pub affected_versions: Vec<String>,
    pub fixed_versions: Vec<String>,
}

/// Architecture analysis
#[derive(Debug, Serialize)]
pub struct ArchitectureAnalysis {
    pub patterns: Vec<String>,
    pub complexity: String,
    pub modularity: f64,
    pub maintainability: f64,
}

/// Performance analysis
#[derive(Debug, Serialize)]
pub struct PerformanceAnalysis {
    pub bundle_size: Option<String>,
    pub load_time: Option<String>,
    pub memory_usage: Option<String>,
    pub performance_score: f64,
}

/// Comprehensive Analysis Service
/// 
/// Provides package and repository analysis services for Elixir via NATS.
/// Uses the same parsers as NIF but focuses on external analysis.
pub struct ComprehensiveAnalysisService {
    nats_client: Client,
    analysis_engine: FeatureAwareEngine,
    parsers: UnifiedParsers,
}

impl ComprehensiveAnalysisService {
    /// Create new comprehensive analysis service
    pub async fn new(nats_url: &str) -> Result<Self> {
        let nats_client = async_nats::connect(nats_url).await?;
        let config = create_server_config();
        let analysis_engine = FeatureAwareEngine::new(config)?;
        let parsers = UnifiedParsers::new()?;

        info!("Comprehensive Analysis Service connected to NATS: {}", nats_url);

        Ok(Self {
            nats_client,
            analysis_engine,
            parsers,
        })
    }

    /// Start the comprehensive analysis service
    pub async fn start(&self) -> Result<()> {
        info!("Starting Comprehensive Analysis Service...");

        // Subscribe to analysis subjects
        let mut search_sub = self.nats_client.subscribe("packages.search").await?;
        let mut analyze_sub = self.nats_client.subscribe("packages.analyze").await?;

        // Handle search
        let nats_client = self.nats_client.clone();
        let parsers = self.parsers.clone();
        tokio::spawn(async move {
            while let Some(msg) = search_sub.next().await {
                if let Err(e) = Self::handle_search(&nats_client, &msg, &parsers).await {
                    error!("Failed to handle search: {}", e);
                }
            }
        });

        // Handle analysis
        let nats_client = self.nats_client.clone();
        let analysis_engine = self.analysis_engine.clone();
        tokio::spawn(async move {
            while let Some(msg) = analyze_sub.next().await {
                if let Err(e) = Self::handle_analyze(&nats_client, &msg, &analysis_engine).await {
                    error!("Failed to handle analyze: {}", e);
                }
            }
        });

        info!("Comprehensive Analysis Service started successfully");
        Ok(())
    }

    /// Handle search request
    async fn handle_search(
        nats_client: &Client,
        msg: &async_nats::Message,
        parsers: &UnifiedParsers,
    ) -> Result<()> {
        let request: SearchRequest = serde_json::from_slice(&msg.payload)?;

        info!("Searching: {} (page: {:?})", request.query, request.page);

        // Parse query for ecosystem hints
        let (query, ecosystem_hint) = Self::parse_query(&request.query);
        
        // Apply filters
        let filters = request.filters.as_ref();
        let ecosystem_filter = filters.and_then(|f| f.ecosystem.as_ref()).or(ecosystem_hint.as_ref());
        let quality_filter = filters.and_then(|f| f.quality.as_ref());
        let security_filter = filters.and_then(|f| f.security.as_ref());
        let category_filter = filters.and_then(|f| f.category.as_ref());

        // Search across all ecosystems
        let mut all_results = Vec::new();
        
        if ecosystem_filter.is_none() || ecosystem_filter == Some(&"npm".to_string()) {
            all_results.extend(Self::search_npm(&query, quality_filter, security_filter, category_filter).await?);
        }
        if ecosystem_filter.is_none() || ecosystem_filter == Some(&"cargo".to_string()) {
            all_results.extend(Self::search_cargo(&query, quality_filter, security_filter, category_filter).await?);
        }
        if ecosystem_filter.is_none() || ecosystem_filter == Some(&"hex".to_string()) {
            all_results.extend(Self::search_hex(&query, quality_filter, security_filter, category_filter).await?);
        }
        if ecosystem_filter.is_none() || ecosystem_filter == Some(&"pypi".to_string()) {
            all_results.extend(Self::search_pypi(&query, quality_filter, security_filter, category_filter).await?);
        }
        if ecosystem_filter.is_none() || ecosystem_filter == Some(&"github".to_string()) {
            all_results.extend(Self::search_github(&query, quality_filter, security_filter, category_filter).await?);
        }

        // Sort by relevance (quality + popularity)
        all_results.sort_by(|a, b| {
            let score_a = a.quality_score * 0.7 + (a.downloads as f64 / 1000000.0).min(1.0) * 0.3;
            let score_b = b.quality_score * 0.7 + (b.downloads as f64 / 1000000.0).min(1.0) * 0.3;
            score_b.partial_cmp(&score_a).unwrap()
        });

        // Pagination
        let page = request.page.unwrap_or(1);
        let per_page = request.per_page.unwrap_or(20);
        let start = (page - 1) * per_page;
        let end = start + per_page;
        
        let paginated_results = if start < all_results.len() {
            all_results[start..end.min(all_results.len())].to_vec()
        } else {
            Vec::new()
        };

        // Generate facets
        let facets = Self::generate_facets(&all_results);
        
        // Generate suggestions
        let suggestions = Self::generate_suggestions(&request.query, &facets);

        let response = SearchResponse {
            query: request.query.clone(),
            total_results: all_results.len(),
            page,
            per_page,
            results: paginated_results,
            facets,
            suggestions,
            next_page: if end < all_results.len() { Some(page + 1) } else { None },
            prev_page: if page > 1 { Some(page - 1) } else { None },
        };

        // Send response
        let response_json = serde_json::to_string(&response)?;
        if let Some(reply_to) = &msg.reply {
            nats_client.publish(reply_to.clone(), response_json.into()).await?;
        }

        Ok(())
    }

    /// Handle analysis request
    async fn handle_analyze(
        nats_client: &Client,
        msg: &async_nats::Message,
        analysis_engine: &FeatureAwareEngine,
    ) -> Result<()> {
        let request: AnalysisRequest = serde_json::from_slice(&msg.payload)?;
        
        info!("Analyzing package: {} ({})", request.package_name, request.ecosystem);

        // Perform deep analysis
        let analysis_result = analysis_engine.analyze_package(&request.package_name, &request.ecosystem).await?;
        
        // Generate full analysis
        let full_analysis = FullAnalysis {
            cves: Self::get_cve_data(&request.package_name, &request.ecosystem).await?,
            dependencies: analysis_result.analysis.dependencies,
            architecture: ArchitectureAnalysis {
                patterns: vec!["MVC".to_string(), "Repository".to_string()],
                complexity: "Medium".to_string(),
                modularity: 0.75,
                maintainability: 0.85,
            },
            performance: PerformanceAnalysis {
                bundle_size: Some("2.5MB".to_string()),
                load_time: Some("150ms".to_string()),
                memory_usage: Some("45MB".to_string()),
                performance_score: 0.88,
            },
            insights: vec![
                "Popular choice for React applications".to_string(),
                "Well-maintained with regular updates".to_string(),
                "Strong community support".to_string(),
            ],
            recommendations: vec![
                "Consider using for new React projects".to_string(),
                "Monitor for security updates".to_string(),
            ],
            warnings: vec![
                "Large bundle size may impact performance".to_string(),
            ],
        };

        let response = AnalysisResponse {
            package_name: request.package_name,
            ecosystem: request.ecosystem,
            version: request.version.unwrap_or_else(|| "latest".to_string()),
            full_analysis,
        };

        // Send response
        let response_json = serde_json::to_string(&response)?;
        if let Some(reply_to) = &msg.reply {
            nats_client.publish(reply_to.clone(), response_json.into()).await?;
        }

        Ok(())
    }

    /// Parse query for ecosystem hints
    fn parse_query(query: &str) -> (String, Option<String>) {
        if query.starts_with("/npm/") {
            (query[5..].to_string(), Some("npm".to_string()))
        } else if query.starts_with("/cargo/") {
            (query[7..].to_string(), Some("cargo".to_string()))
        } else if query.starts_with("/hex/") {
            (query[5..].to_string(), Some("hex".to_string()))
        } else if query.starts_with("/pypi/") {
            (query[6..].to_string(), Some("pypi".to_string()))
        } else if query.starts_with("/github/") {
            (query[8..].to_string(), Some("github".to_string()))
        } else if query.starts_with("/gitlab/") {
            (query[8..].to_string(), Some("gitlab".to_string()))
        } else {
            (query.to_string(), None)
        }
    }

    /// Search npm packages
    async fn search_npm(
        query: &str,
        quality_filter: Option<&String>,
        security_filter: Option<&String>,
        category_filter: Option<&String>,
    ) -> Result<Vec<SearchResultItem>> {
        // Mock npm search results
        let mut results = Vec::new();
        
        if query.to_lowercase().contains("react") {
            results.push(SearchResultItem {
                name: "react".to_string(),
                ecosystem: "npm".to_string(),
                version: "18.2.0".to_string(),
                description: "A JavaScript library for building user interfaces".to_string(),
                downloads: 15000000,
                stars: Some(200000),
                quality_score: 0.95,
                security_score: 0.90,
                has_cves: false,
                last_updated: "2024-01-15".to_string(),
                license: Some("MIT".to_string()),
            });
            
            results.push(SearchResultItem {
                name: "react-dom".to_string(),
                ecosystem: "npm".to_string(),
                version: "18.2.0".to_string(),
                description: "React package for working with the DOM".to_string(),
                downloads: 15000000,
                stars: Some(200000),
                quality_score: 0.95,
                security_score: 0.90,
                has_cves: false,
                last_updated: "2024-01-15".to_string(),
                license: Some("MIT".to_string()),
            });
        }
        
        Ok(results)
    }

    /// Search cargo packages
    async fn search_cargo(
        query: &str,
        quality_filter: Option<&String>,
        security_filter: Option<&String>,
        category_filter: Option<&String>,
    ) -> Result<Vec<SearchResultItem>> {
        // Mock cargo search results
        let mut results = Vec::new();
        
        if query.to_lowercase().contains("serde") {
            results.push(SearchResultItem {
                name: "serde".to_string(),
                ecosystem: "cargo".to_string(),
                version: "1.0.0".to_string(),
                description: "A generic serialization/deserialization framework".to_string(),
                downloads: 5000000,
                stars: Some(5000),
                quality_score: 0.98,
                security_score: 0.95,
                has_cves: false,
                last_updated: "2024-01-10".to_string(),
                license: Some("MIT OR Apache-2.0".to_string()),
            });
        }
        
        Ok(results)
    }

    /// Search hex packages
    async fn search_hex(
        query: &str,
        quality_filter: Option<&String>,
        security_filter: Option<&String>,
        category_filter: Option<&String>,
    ) -> Result<Vec<SearchResultItem>> {
        // Mock hex search results
        Ok(Vec::new())
    }

    /// Search pypi packages
    async fn search_pypi(
        query: &str,
        quality_filter: Option<&String>,
        security_filter: Option<&String>,
        category_filter: Option<&String>,
    ) -> Result<Vec<SearchResultItem>> {
        // Mock pypi search results
        Ok(Vec::new())
    }

    /// Search github repositories
    async fn search_github(
        query: &str,
        quality_filter: Option<&String>,
        security_filter: Option<&String>,
        category_filter: Option<&String>,
    ) -> Result<Vec<SearchResultItem>> {
        // Mock github search results
        let mut results = Vec::new();
        
        if query.to_lowercase().contains("react") {
            results.push(SearchResultItem {
                name: "facebook/react".to_string(),
                ecosystem: "github".to_string(),
                version: "main".to_string(),
                description: "A declarative, efficient, and flexible JavaScript library for building user interfaces".to_string(),
                downloads: 0,
                stars: Some(200000),
                quality_score: 0.98,
                security_score: 0.95,
                has_cves: false,
                last_updated: "2024-01-15".to_string(),
                license: Some("MIT".to_string()),
            });
        }
        
        Ok(results)
    }

    /// Generate facets from search results
    fn generate_facets(results: &[SearchResultItem]) -> SearchFacets {
        let mut ecosystems = std::collections::HashMap::new();
        let mut categories = std::collections::HashMap::new();
        let mut quality_ranges = std::collections::HashMap::new();
        let mut security_levels = std::collections::HashMap::new();

        for result in results {
            // Count ecosystems
            *ecosystems.entry(result.ecosystem.clone()).or_insert(0) += 1;
            
            // Count quality ranges
            let quality_range = if result.quality_score >= 0.8 {
                "high"
            } else if result.quality_score >= 0.6 {
                "medium"
            } else {
                "low"
            };
            *quality_ranges.entry(quality_range.to_string()).or_insert(0) += 1;
            
            // Count security levels
            let security_level = if result.security_score >= 0.9 {
                "clean"
            } else if result.security_score >= 0.7 {
                "warnings"
            } else {
                "issues"
            };
            *security_levels.entry(security_level.to_string()).or_insert(0) += 1;
        }

        SearchFacets {
            ecosystems,
            categories,
            quality_ranges,
            security_levels,
        }
    }

    /// Generate search suggestions
    fn generate_suggestions(query: &str, facets: &SearchFacets) -> Vec<String> {
        let mut suggestions = Vec::new();
        
        // Add ecosystem-specific suggestions
        if !query.starts_with("/") {
            for (ecosystem, count) in &facets.ecosystems {
                if *count > 0 {
                    suggestions.push(format!("Try: /{}/{} ({} results)", ecosystem, query, count));
                }
            }
        }
        
        // Add quality suggestions
        if let Some(high_count) = facets.quality_ranges.get("high") {
            if *high_count > 0 {
                suggestions.push(format!("Try: {} quality:high ({} high-quality results)", query, high_count));
            }
        }
        
        // Add security suggestions
        if let Some(clean_count) = facets.security_levels.get("clean") {
            if *clean_count > 0 {
                suggestions.push(format!("Try: {} security:clean ({} secure results)", query, clean_count));
            }
        }
        
        suggestions
    }

    /// Get CVE data for a package
    async fn get_cve_data(package_name: &str, ecosystem: &str) -> Result<Vec<CveInfo>> {
        // Mock CVE data
        let mut cves = Vec::new();
        
        if package_name == "react" && ecosystem == "npm" {
            cves.push(CveInfo {
                id: "CVE-2023-1234".to_string(),
                severity: "high".to_string(),
                description: "XSS vulnerability in React DOM".to_string(),
                affected_versions: vec!["<18.2.0".to_string()],
                fixed_versions: vec![">=18.2.0".to_string()],
            });
        }
        
        Ok(cves)
    }
}

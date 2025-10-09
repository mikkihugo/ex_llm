//! Hybrid Search Engine
//!
//! Combines Tantivy full-text search with custom vector search for optimal results.

use serde::{Deserialize, Serialize};
use anyhow::Result;
use super::tantivy_search::{TantivySearchEngine, TantivySearchResponse, TantivySearchOptions, CodeDocument};
use super::semantic_search::{SemanticSearchEngine, SemanticSearchResult, SearchOptions};

/// Hybrid search result combining both search engines
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HybridSearchResult {
    pub file_path: String,
    pub content: String,
    pub business_domain: Option<String>,
    pub architecture_pattern: Option<String>,
    pub security_pattern: Option<String>,
    pub line_number: Option<u32>,
    pub tantivy_score: f32,
    pub semantic_score: f64,
    pub combined_score: f64,
    pub search_source: SearchSource,
}

/// Search source indicator
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SearchSource {
    TantivyOnly,
    SemanticOnly,
    Both,
}

/// Hybrid search response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HybridSearchResponse {
    pub results: Vec<HybridSearchResult>,
    pub tantivy_results: TantivySearchResponse,
    pub semantic_results: SemanticSearchResult,
    pub total_hits: usize,
    pub search_time_ms: u64,
    pub query: String,
    pub search_strategy: SearchStrategy,
}

/// Search strategy used
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SearchStrategy {
    TantivyOnly,
    SemanticOnly,
    Hybrid,
    BusinessAware,
    ArchitectureAware,
    SecurityAware,
}

/// Hybrid search options
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HybridSearchOptions {
    pub tantivy_options: TantivySearchOptions,
    pub semantic_options: SearchOptions,
    pub strategy: SearchStrategy,
    pub combine_results: bool,
    pub tantivy_weight: f64,
    pub semantic_weight: f64,
}

impl Default for HybridSearchOptions {
    fn default() -> Self {
        Self {
            tantivy_options: TantivySearchOptions::default(),
            semantic_options: SearchOptions::default(),
            strategy: SearchStrategy::Hybrid,
            combine_results: true,
            tantivy_weight: 0.3,
            semantic_weight: 0.7,
        }
    }
}

/// Hybrid search engine
pub struct HybridSearchEngine {
    tantivy_engine: TantivySearchEngine,
    semantic_engine: SemanticSearchEngine,
}

impl HybridSearchEngine {
    /// Create a new hybrid search engine
    pub fn new() -> Result<Self> {
        Ok(Self {
            tantivy_engine: TantivySearchEngine::new()?,
            semantic_engine: SemanticSearchEngine::new(),
        })
    }
    
    /// Initialize with code data
    pub async fn initialize(&mut self, code_data: Vec<CodeDocument>) -> Result<()> {
        // Initialize Tantivy with code data
        self.tantivy_engine.initialize(code_data).await?;
        
        // Initialize semantic engine
        self.semantic_engine.initialize().await?;
        
        Ok(())
    }
    
    /// Perform hybrid search
    pub async fn search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        let start_time = std::time::Instant::now();
        
        match options.strategy {
            SearchStrategy::TantivyOnly => {
                self.tantivy_only_search(query, options).await
            },
            SearchStrategy::SemanticOnly => {
                self.semantic_only_search(query, options).await
            },
            SearchStrategy::Hybrid => {
                self.hybrid_search(query, options).await
            },
            SearchStrategy::BusinessAware => {
                self.business_aware_search(query, options).await
            },
            SearchStrategy::ArchitectureAware => {
                self.architecture_aware_search(query, options).await
            },
            SearchStrategy::SecurityAware => {
                self.security_aware_search(query, options).await
            },
        }
    }
    
    /// Tantivy-only search
    async fn tantivy_only_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        let tantivy_results = self.tantivy_engine.search(query, options.tantivy_options).await?;
        
        let results = tantivy_results.results.into_iter().map(|result| {
            HybridSearchResult {
                file_path: result.file_path,
                content: result.content,
                business_domain: result.business_domain,
                architecture_pattern: result.architecture_pattern,
                security_pattern: result.security_pattern,
                line_number: result.line_number,
                tantivy_score: result.score,
                semantic_score: 0.0,
                combined_score: result.score as f64,
                search_source: SearchSource::TantivyOnly,
            }
        }).collect();
        
        Ok(HybridSearchResponse {
            results,
            tantivy_results,
            semantic_results: SemanticSearchResult {
                query: query.to_string(),
                results: Vec::new(),
                search_metadata: super::semantic_search::SearchMetadata {
                    search_time: chrono::Utc::now(),
                    files_searched: 0,
                    matches_found: 0,
                    search_duration_ms: 0,
                    vector_similarity_threshold: 0.0,
                    business_awareness_enabled: false,
                    architecture_awareness_enabled: false,
                    security_awareness_enabled: false,
                },
                business_context: super::semantic_search::BusinessContext {
                    domains: Vec::new(),
                    patterns: Vec::new(),
                    entities: Vec::new(),
                    workflows: Vec::new(),
                },
                architecture_context: super::semantic_search::ArchitectureContext {
                    patterns: Vec::new(),
                    components: Vec::new(),
                    relationships: Vec::new(),
                    quality_attributes: Vec::new(),
                },
                security_context: super::semantic_search::SecurityContext {
                    vulnerabilities: Vec::new(),
                    compliance: Vec::new(),
                    patterns: Vec::new(),
                    controls: Vec::new(),
                },
            },
            total_hits: results.len(),
            search_time_ms: tantivy_results.search_time_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::TantivyOnly,
        })
    }
    
    /// Semantic-only search
    async fn semantic_only_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        let semantic_results = self.semantic_engine.search(query, options.semantic_options).await?;
        
        let results = semantic_results.results.into_iter().map(|result| {
            HybridSearchResult {
                file_path: result.file_path,
                content: result.code_snippet,
                business_domain: result.business_domain,
                architecture_pattern: result.architecture_pattern,
                security_pattern: result.security_pattern,
                line_number: Some(result.line_number),
                tantivy_score: 0.0,
                semantic_score: result.relevance_score,
                combined_score: result.relevance_score,
                search_source: SearchSource::SemanticOnly,
            }
        }).collect();
        
        Ok(HybridSearchResponse {
            results,
            tantivy_results: TantivySearchResponse {
                results: Vec::new(),
                total_hits: 0,
                search_time_ms: 0,
                query: query.to_string(),
            },
            semantic_results,
            total_hits: results.len(),
            search_time_ms: semantic_results.search_metadata.search_duration_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::SemanticOnly,
        })
    }
    
    /// Hybrid search combining both engines
    async fn hybrid_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        let start_time = std::time::Instant::now();
        
        // Run both searches in parallel
        let tantivy_future = self.tantivy_engine.search(query, options.tantivy_options.clone());
        let semantic_future = self.semantic_engine.search(query, options.semantic_options.clone());
        
        let (tantivy_results, semantic_results) = tokio::try_join!(tantivy_future, semantic_future)?;
        
        // Combine results
        let combined_results = if options.combine_results {
            self.combine_results(tantivy_results.clone(), semantic_results.clone(), &options).await?
        } else {
            Vec::new()
        };
        
        let search_time_ms = start_time.elapsed().as_millis() as u64;
        
        Ok(HybridSearchResponse {
            results: combined_results,
            tantivy_results,
            semantic_results,
            total_hits: combined_results.len(),
            search_time_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::Hybrid,
        })
    }
    
    /// Business-aware search
    async fn business_aware_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        // Extract business domain from query
        let business_domain = self.extract_business_domain(query);
        
        let tantivy_results = if let Some(domain) = &business_domain {
            self.tantivy_engine.search_by_business_domain(domain, query).await?
        } else {
            self.tantivy_engine.search(query, options.tantivy_options).await?
        };
        
        let semantic_results = self.semantic_engine.search(query, options.semantic_options).await?;
        
        let combined_results = self.combine_results(tantivy_results.clone(), semantic_results.clone(), &options).await?;
        
        Ok(HybridSearchResponse {
            results: combined_results,
            tantivy_results,
            semantic_results,
            total_hits: combined_results.len(),
            search_time_ms: tantivy_results.search_time_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::BusinessAware,
        })
    }
    
    /// Architecture-aware search
    async fn architecture_aware_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        // Extract architecture pattern from query
        let architecture_pattern = self.extract_architecture_pattern(query);
        
        let tantivy_results = if let Some(pattern) = &architecture_pattern {
            self.tantivy_engine.search_by_architecture_pattern(pattern, query).await?
        } else {
            self.tantivy_engine.search(query, options.tantivy_options).await?
        };
        
        let semantic_results = self.semantic_engine.search(query, options.semantic_options).await?;
        
        let combined_results = self.combine_results(tantivy_results.clone(), semantic_results.clone(), &options).await?;
        
        Ok(HybridSearchResponse {
            results: combined_results,
            tantivy_results,
            semantic_results,
            total_hits: combined_results.len(),
            search_time_ms: tantivy_results.search_time_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::ArchitectureAware,
        })
    }
    
    /// Security-aware search
    async fn security_aware_search(&self, query: &str, options: HybridSearchOptions) -> Result<HybridSearchResponse> {
        // Use semantic search for security analysis
        let mut semantic_options = options.semantic_options;
        semantic_options.security_awareness_enabled = true;
        
        let semantic_results = self.semantic_engine.search(query, semantic_options).await?;
        
        // Convert semantic results to hybrid results
        let results = semantic_results.results.into_iter().map(|result| {
            HybridSearchResult {
                file_path: result.file_path,
                content: result.code_snippet,
                business_domain: result.business_domain,
                architecture_pattern: result.architecture_pattern,
                security_pattern: result.security_pattern,
                line_number: Some(result.line_number),
                tantivy_score: 0.0,
                semantic_score: result.relevance_score,
                combined_score: result.relevance_score,
                search_source: SearchSource::SemanticOnly,
            }
        }).collect();
        
        Ok(HybridSearchResponse {
            results,
            tantivy_results: TantivySearchResponse {
                results: Vec::new(),
                total_hits: 0,
                search_time_ms: 0,
                query: query.to_string(),
            },
            semantic_results,
            total_hits: results.len(),
            search_time_ms: semantic_results.search_metadata.search_duration_ms,
            query: query.to_string(),
            search_strategy: SearchStrategy::SecurityAware,
        })
    }
    
    /// Combine results from both search engines
    async fn combine_results(
        &self,
        tantivy_results: TantivySearchResponse,
        semantic_results: SemanticSearchResult,
        options: &HybridSearchOptions,
    ) -> Result<Vec<HybridSearchResult>> {
        let mut combined_results = Vec::new();
        
        // Create a map of file paths to results for deduplication
        let mut file_results: std::collections::HashMap<String, HybridSearchResult> = std::collections::HashMap::new();
        
        // Add Tantivy results
        for tantivy_result in tantivy_results.results {
            let combined_score = tantivy_result.score as f64 * options.tantivy_weight;
            
            let hybrid_result = HybridSearchResult {
                file_path: tantivy_result.file_path.clone(),
                content: tantivy_result.content,
                business_domain: tantivy_result.business_domain,
                architecture_pattern: tantivy_result.architecture_pattern,
                security_pattern: tantivy_result.security_pattern,
                line_number: tantivy_result.line_number,
                tantivy_score: tantivy_result.score,
                semantic_score: 0.0,
                combined_score,
                search_source: SearchSource::TantivyOnly,
            };
            
            file_results.insert(tantivy_result.file_path, hybrid_result);
        }
        
        // Add semantic results and combine with existing ones
        for semantic_result in semantic_results.results {
            let combined_score = semantic_result.relevance_score * options.semantic_weight;
            
            if let Some(existing) = file_results.get_mut(&semantic_result.file_path) {
                // Combine with existing Tantivy result
                existing.semantic_score = semantic_result.relevance_score;
                existing.combined_score = existing.tantivy_score as f64 * options.tantivy_weight + 
                                        semantic_result.relevance_score * options.semantic_weight;
                existing.search_source = SearchSource::Both;
            } else {
                // Add new semantic result
                let hybrid_result = HybridSearchResult {
                    file_path: semantic_result.file_path,
                    content: semantic_result.code_snippet,
                    business_domain: semantic_result.business_domain,
                    architecture_pattern: semantic_result.architecture_pattern,
                    security_pattern: semantic_result.security_pattern,
                    line_number: Some(semantic_result.line_number),
                    tantivy_score: 0.0,
                    semantic_score: semantic_result.relevance_score,
                    combined_score,
                    search_source: SearchSource::SemanticOnly,
                };
                
                file_results.insert(semantic_result.file_path, hybrid_result);
            }
        }
        
        // Convert to vector and sort by combined score
        combined_results = file_results.into_values().collect();
        combined_results.sort_by(|a, b| b.combined_score.partial_cmp(&a.combined_score).unwrap());
        
        Ok(combined_results)
    }
    
    /// Extract business domain from query
    fn extract_business_domain(&self, query: &str) -> Option<String> {
        let query_lower = query.to_lowercase();
        
        if query_lower.contains("payment") || query_lower.contains("checkout") || query_lower.contains("billing") {
            Some("Payment Processing".to_string())
        } else if query_lower.contains("user") || query_lower.contains("authentication") || query_lower.contains("login") {
            Some("User Management".to_string())
        } else if query_lower.contains("order") || query_lower.contains("inventory") || query_lower.contains("product") {
            Some("E-Commerce".to_string())
        } else if query_lower.contains("notification") || query_lower.contains("email") || query_lower.contains("sms") {
            Some("Notification".to_string())
        } else {
            None
        }
    }
    
    /// Extract architecture pattern from query
    fn extract_architecture_pattern(&self, query: &str) -> Option<String> {
        let query_lower = query.to_lowercase();
        
        if query_lower.contains("microservice") || query_lower.contains("service") {
            Some("Microservices".to_string())
        } else if query_lower.contains("cqrs") || query_lower.contains("command") || query_lower.contains("query") {
            Some("CQRS".to_string())
        } else if query_lower.contains("hexagonal") || query_lower.contains("port") || query_lower.contains("adapter") {
            Some("Hexagonal Architecture".to_string())
        } else if query_lower.contains("repository") || query_lower.contains("data access") {
            Some("Repository Pattern".to_string())
        } else {
            None
        }
    }
}
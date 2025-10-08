//! Tantivy Full-Text Search Integration
//!
//! High-performance full-text search using Tantivy for codebase analysis.

use tantivy::{
    collector::TopDocs,
    query::QueryParser,
    schema::*,
    Index, ReloadPolicy, TantivyDocument,
};
use serde::{Deserialize, Serialize};
use anyhow::Result;

/// Tantivy search result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TantivySearchResult {
    pub file_path: String,
    pub content: String,
    pub business_domain: Option<String>,
    pub architecture_pattern: Option<String>,
    pub security_pattern: Option<String>,
    pub score: f32,
    pub line_number: Option<u32>,
}

/// Tantivy search response
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TantivySearchResponse {
    pub results: Vec<TantivySearchResult>,
    pub total_hits: usize,
    pub search_time_ms: u64,
    pub query: String,
}

/// Tantivy search engine
pub struct TantivySearchEngine {
    index: Index,
    schema: Schema,
    file_path_field: Field,
    content_field: Field,
    business_domain_field: Field,
    architecture_pattern_field: Field,
    security_pattern_field: Field,
    line_number_field: Field,
}

impl TantivySearchEngine {
    /// Create a new Tantivy search engine
    pub fn new() -> Result<Self> {
        // Define schema for code data
        let mut schema_builder = Schema::builder();
        
        // File path (stored for retrieval)
        let file_path_field = schema_builder.add_text_field("file_path", TEXT | STORED);
        
        // Code content (indexed for search)
        let content_field = schema_builder.add_text_field("content", TEXT);
        
        // Business domain (indexed for faceted search)
        let business_domain_field = schema_builder.add_text_field("business_domain", TEXT);
        
        // Architecture pattern (indexed for faceted search)
        let architecture_pattern_field = schema_builder.add_text_field("architecture_pattern", TEXT);
        
        // Security pattern (indexed for faceted search)
        let security_pattern_field = schema_builder.add_text_field("security_pattern", TEXT);
        
        // Line number (stored for location)
        let line_number_field = schema_builder.add_u64_field("line_number", STORED);
        
        let schema = schema_builder.build();
        
        // Create in-memory index
        let index = Index::create_in_ram(schema.clone());
        
        Ok(Self {
            index,
            schema,
            file_path_field,
            content_field,
            business_domain_field,
            architecture_pattern_field,
            security_pattern_field,
            line_number_field,
        })
    }
    
    /// Initialize the search engine with code data
    pub async fn initialize(&mut self, code_data: Vec<CodeDocument>) -> Result<()> {
        let mut index_writer = self.index.writer(50_000_000)?;
        
        for doc in code_data {
            let tantivy_doc = TantivyDocument::new();
            let mut doc_builder = tantivy_doc;
            
            // Add file path
            doc_builder = doc_builder.add_text(self.file_path_field, &doc.file_path);
            
            // Add content
            doc_builder = doc_builder.add_text(self.content_field, &doc.content);
            
            // Add business domain if present
            if let Some(domain) = &doc.business_domain {
                doc_builder = doc_builder.add_text(self.business_domain_field, domain);
            }
            
            // Add architecture pattern if present
            if let Some(pattern) = &doc.architecture_pattern {
                doc_builder = doc_builder.add_text(self.architecture_pattern_field, pattern);
            }
            
            // Add security pattern if present
            if let Some(pattern) = &doc.security_pattern {
                doc_builder = doc_builder.add_text(self.security_pattern_field, pattern);
            }
            
            // Add line number if present
            if let Some(line) = doc.line_number {
                doc_builder = doc_builder.add_u64(self.line_number_field, line as u64);
            }
            
            index_writer.add_document(doc_builder)?;
        }
        
        index_writer.commit()?;
        Ok(())
    }
    
    /// Perform full-text search
    pub async fn search(&self, query: &str, options: TantivySearchOptions) -> Result<TantivySearchResponse> {
        let start_time = std::time::Instant::now();
        
        // Reload index to get latest changes
        self.index.reload(ReloadPolicy::OnCommit)?;
        
        let reader = self.index.reader()?;
        let searcher = reader.searcher();
        
        // Create query parser for content field
        let query_parser = QueryParser::for_index(&self.index, vec![self.content_field]);
        let tantivy_query = query_parser.parse_query(query)?;
        
        // Perform search
        let top_docs = searcher.search(&tantivy_query, &TopDocs::with_limit(options.max_results))?;
        
        let mut results = Vec::new();
        
        for (score, doc_address) in top_docs {
            let retrieved_doc = searcher.doc(doc_address)?;
            
            // Extract fields from document
            let file_path = retrieved_doc
                .get_first(self.file_path_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let content = retrieved_doc
                .get_first(self.content_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let business_domain = retrieved_doc
                .get_first(self.business_domain_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let architecture_pattern = retrieved_doc
                .get_first(self.architecture_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let security_pattern = retrieved_doc
                .get_first(self.security_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let line_number = retrieved_doc
                .get_first(self.line_number_field)
                .and_then(|v| v.as_u64())
                .map(|n| n as u32);
            
            results.push(TantivySearchResult {
                file_path,
                content,
                business_domain,
                architecture_pattern,
                security_pattern,
                score,
                line_number,
            });
        }
        
        let search_time_ms = start_time.elapsed().as_millis() as u64;
        
        Ok(TantivySearchResponse {
            results,
            total_hits: results.len(),
            search_time_ms,
            query: query.to_string(),
        })
    }
    
    /// Perform faceted search by business domain
    pub async fn search_by_business_domain(&self, domain: &str, query: &str) -> Result<TantivySearchResponse> {
        let start_time = std::time::Instant::now();
        
        self.index.reload(ReloadPolicy::OnCommit)?;
        
        let reader = self.index.reader()?;
        let searcher = reader.searcher();
        
        // Create query parser for content and business domain
        let query_parser = QueryParser::for_index(&self.index, vec![self.content_field, self.business_domain_field]);
        let tantivy_query = query_parser.parse_query(&format!("{} AND business_domain:{}", query, domain))?;
        
        let top_docs = searcher.search(&tantivy_query, &TopDocs::with_limit(50))?;
        
        let mut results = Vec::new();
        
        for (score, doc_address) in top_docs {
            let retrieved_doc = searcher.doc(doc_address)?;
            
            let file_path = retrieved_doc
                .get_first(self.file_path_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let content = retrieved_doc
                .get_first(self.content_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let business_domain = retrieved_doc
                .get_first(self.business_domain_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let architecture_pattern = retrieved_doc
                .get_first(self.architecture_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let security_pattern = retrieved_doc
                .get_first(self.security_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let line_number = retrieved_doc
                .get_first(self.line_number_field)
                .and_then(|v| v.as_u64())
                .map(|n| n as u32);
            
            results.push(TantivySearchResult {
                file_path,
                content,
                business_domain,
                architecture_pattern,
                security_pattern,
                score,
                line_number,
            });
        }
        
        let search_time_ms = start_time.elapsed().as_millis() as u64;
        
        Ok(TantivySearchResponse {
            results,
            total_hits: results.len(),
            search_time_ms,
            query: format!("{} (business_domain: {})", query, domain),
        })
    }
    
    /// Perform faceted search by architecture pattern
    pub async fn search_by_architecture_pattern(&self, pattern: &str, query: &str) -> Result<TantivySearchResponse> {
        let start_time = std::time::Instant::now();
        
        self.index.reload(ReloadPolicy::OnCommit)?;
        
        let reader = self.index.reader()?;
        let searcher = reader.searcher();
        
        // Create query parser for content and architecture pattern
        let query_parser = QueryParser::for_index(&self.index, vec![self.content_field, self.architecture_pattern_field]);
        let tantivy_query = query_parser.parse_query(&format!("{} AND architecture_pattern:{}", query, pattern))?;
        
        let top_docs = searcher.search(&tantivy_query, &TopDocs::with_limit(50))?;
        
        let mut results = Vec::new();
        
        for (score, doc_address) in top_docs {
            let retrieved_doc = searcher.doc(doc_address)?;
            
            let file_path = retrieved_doc
                .get_first(self.file_path_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let content = retrieved_doc
                .get_first(self.content_field)
                .and_then(|v| v.as_text())
                .unwrap_or("")
                .to_string();
            
            let business_domain = retrieved_doc
                .get_first(self.business_domain_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let architecture_pattern = retrieved_doc
                .get_first(self.architecture_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let security_pattern = retrieved_doc
                .get_first(self.security_pattern_field)
                .and_then(|v| v.as_text())
                .map(|s| s.to_string());
            
            let line_number = retrieved_doc
                .get_first(self.line_number_field)
                .and_then(|v| v.as_u64())
                .map(|n| n as u32);
            
            results.push(TantivySearchResult {
                file_path,
                content,
                business_domain,
                architecture_pattern,
                security_pattern,
                score,
                line_number,
            });
        }
        
        let search_time_ms = start_time.elapsed().as_millis() as u64;
        
        Ok(TantivySearchResponse {
            results,
            total_hits: results.len(),
            search_time_ms,
            query: format!("{} (architecture_pattern: {})", query, pattern),
        })
    }
}

/// Code document for indexing
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CodeDocument {
    pub file_path: String,
    pub content: String,
    pub business_domain: Option<String>,
    pub architecture_pattern: Option<String>,
    pub security_pattern: Option<String>,
    pub line_number: Option<u32>,
}

/// Tantivy search options
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TantivySearchOptions {
    pub max_results: usize,
    pub include_facets: bool,
    pub sort_by_score: bool,
}

impl Default for TantivySearchOptions {
    fn default() -> Self {
        Self {
            max_results: 50,
            include_facets: true,
            sort_by_score: true,
        }
    }
}
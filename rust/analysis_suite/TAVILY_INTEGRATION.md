# 🔍 Tavily Integration with Rust

## 🎯 **Tavily Rust Dependency**

### **Add Tavily to Cargo.toml:**
```toml
[dependencies]
tavily = "0.1.0"  # Tavily Rust client
# OR if using HTTP client directly:
reqwest = { version = "0.11", features = ["json"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

### **Tavily Rust Client Usage:**
```rust
use tavily::TavilyClient;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct TavilySearchResult {
    pub title: String,
    pub url: String,
    pub content: String,
    pub score: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TavilySearchResponse {
    pub results: Vec<TavilySearchResult>,
    pub query: String,
}

pub struct TavilyClient {
    api_key: String,
    client: reqwest::Client,
}

impl TavilyClient {
    pub fn new(api_key: String) -> Self {
        Self {
            api_key,
            client: reqwest::Client::new(),
        }
    }
    
    pub async fn search(&self, query: &str) -> Result<TavilySearchResponse, Box<dyn std::error::Error>> {
        let url = "https://api.tavily.com/search";
        
        let request_body = serde_json::json!({
            "api_key": self.api_key,
            "query": query,
            "search_depth": "basic",
            "include_answer": true,
            "include_images": false,
            "include_raw_content": false,
            "max_results": 5
        });
        
        let response = self.client
            .post(url)
            .json(&request_body)
            .send()
            .await?;
            
        let search_response: TavilySearchResponse = response.json().await?;
        Ok(search_response)
    }
}
```

## 🚀 **Hybrid Search Engine Integration**

### **Combined Tavily + Custom Vector Search:**
```rust
use codebase::*;
use tavily::TavilyClient;

pub struct HybridSearchEngine {
    tavily_client: TavilyClient,
    custom_search: SemanticSearchEngine,
}

impl HybridSearchEngine {
    pub fn new(tavily_api_key: String) -> Self {
        Self {
            tavily_client: TavilyClient::new(tavily_api_key),
            custom_search: SemanticSearchEngine::new(),
        }
    }
    
    pub async fn search(&self, query: &str, context: SearchContext) -> Result<HybridSearchResults> {
        match context {
            SearchContext::Codebase => {
                // Use our custom vector search for codebase
                let code_results = self.custom_search.search(query, SearchOptions::default()).await?;
                Ok(HybridSearchResults {
                    codebase_results: Some(code_results),
                    web_results: None,
                    search_type: SearchType::Codebase,
                })
            },
            SearchContext::Research => {
                // Use Tavily for external research
                let web_results = self.tavily_client.search(query).await?;
                Ok(HybridSearchResults {
                    codebase_results: None,
                    web_results: Some(web_results),
                    search_type: SearchType::Research,
                })
            },
            SearchContext::Hybrid => {
                // Combine both for comprehensive results
                let code_results = self.custom_search.search(query, SearchOptions::default()).await?;
                let web_results = self.tavily_client.search(query).await?;
                
                Ok(HybridSearchResults {
                    codebase_results: Some(code_results),
                    web_results: Some(web_results),
                    search_type: SearchType::Hybrid,
                })
            }
        }
    }
}

#[derive(Debug)]
pub enum SearchContext {
    Codebase,
    Research,
    Hybrid,
}

#[derive(Debug)]
pub enum SearchType {
    Codebase,
    Research,
    Hybrid,
}

#[derive(Debug)]
pub struct HybridSearchResults {
    pub codebase_results: Option<SemanticSearchResult>,
    pub web_results: Option<TavilySearchResponse>,
    pub search_type: SearchType,
}
```

## 🎯 **Usage Examples**

### **Research with Tavily:**
```rust
use codebase::*;
use tavily::TavilyClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize Tavily client
    let tavily_client = TavilyClient::new("your-tavily-api-key".to_string());
    
    // Research microservices best practices
    let best_practices = tavily_client.search("microservices best practices 2024").await?;
    
    println!("Found {} web results:", best_practices.results.len());
    for result in best_practices.results {
        println!("- {}: {}", result.title, result.url);
        println!("  Score: {}", result.score);
        println!("  Content: {}", &result.content[..100]);
        println!();
    }
    
    Ok(())
}
```

### **Codebase Analysis with Custom Search:**
```rust
use codebase::*;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize custom search engine
    let search_engine = SemanticSearchEngine::new();
    
    // Analyze your microservices
    let your_microservices = search_engine.search("find all microservices", SearchOptions::default()).await?;
    
    println!("Found {} microservices in your codebase:", your_microservices.results.len());
    for result in your_microservices.results {
        println!("- {}: {}", result.file_path, result.code_snippet);
        println!("  Relevance: {}", result.relevance_score);
        println!("  Architecture Pattern: {:?}", result.architecture_pattern);
        println!();
    }
    
    Ok(())
}
```

### **Hybrid Search (Best of Both Worlds):**
```rust
use codebase::*;
use tavily::TavilyClient;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize hybrid search engine
    let hybrid_engine = HybridSearchEngine::new("your-tavily-api-key".to_string());
    
    // Research + analyze
    let results = hybrid_engine.search("microservices architecture", SearchContext::Hybrid).await?;
    
    // Web research results
    if let Some(web_results) = results.web_results {
        println!("=== Web Research Results ===");
        for result in web_results.results {
            println!("- {}: {}", result.title, result.url);
        }
    }
    
    // Codebase analysis results
    if let Some(code_results) = results.codebase_results {
        println!("\n=== Your Codebase Analysis ===");
        for result in code_results.results {
            println!("- {}: {}", result.file_path, result.code_snippet);
            println!("  Business Domain: {:?}", result.business_domain);
            println!("  Architecture Pattern: {:?}", result.architecture_pattern);
        }
    }
    
    Ok(())
}
```

## 🔧 **Environment Setup**

### **Add to .envrc:**
```bash
export TAVILY_API_KEY="your-tavily-api-key-here"
```

### **Add to Cargo.toml:**
```toml
[dependencies]
codebase = { path = "../analysis-suite" }
tavily = "0.1.0"  # Tavily Rust client
tokio = { version = "1.0", features = ["full"] }
anyhow = "1.0"
```

## 🎯 **Search Strategy**

### **When to Use Tavily:**
- **Learning**: "How to implement microservices?"
- **Research**: "Latest React patterns 2024"
- **Documentation**: "Stripe API best practices"
- **External Resources**: "Docker security guidelines"

### **When to Use Custom Vector Search:**
- **Code Discovery**: "Find all payment processing code"
- **Architecture Analysis**: "Show me all microservices in our system"
- **Security Audit**: "Find all SQL injection vulnerabilities"
- **Business Analysis**: "Where do we handle user authentication?"

### **When to Use Hybrid:**
- **Comprehensive Analysis**: Research + analyze your implementation
- **Best Practices**: Compare external best practices with your code
- **Learning + Implementation**: Learn how to implement + find existing code
- **Security Research**: Latest threats + find vulnerabilities in your code

## 🚀 **Advanced Integration**

### **Smart Search Router:**
```rust
pub struct SmartSearchRouter {
    hybrid_engine: HybridSearchEngine,
}

impl SmartSearchRouter {
    pub async fn smart_search(&self, query: &str) -> Result<HybridSearchResults> {
        // Analyze query intent
        let intent = self.analyze_query_intent(query).await?;
        
        match intent {
            QueryIntent::Learning => {
                self.hybrid_engine.search(query, SearchContext::Research).await
            },
            QueryIntent::CodeAnalysis => {
                self.hybrid_engine.search(query, SearchContext::Codebase).await
            },
            QueryIntent::Comprehensive => {
                self.hybrid_engine.search(query, SearchContext::Hybrid).await
            }
        }
    }
    
    async fn analyze_query_intent(&self, query: &str) -> Result<QueryIntent> {
        // Simple keyword-based intent detection
        if query.contains("how to") || query.contains("best practices") || query.contains("tutorial") {
            Ok(QueryIntent::Learning)
        } else if query.contains("find") || query.contains("show me") || query.contains("where") {
            Ok(QueryIntent::CodeAnalysis)
        } else {
            Ok(QueryIntent::Comprehensive)
        }
    }
}

#[derive(Debug)]
pub enum QueryIntent {
    Learning,
    CodeAnalysis,
    Comprehensive,
}
```

This integration gives you the best of both worlds: **Tavily for external research** and **custom vector search for codebase analysis**! 🎯
//! LLM Query Expansion
//!
//! Simple LLM integration for semantic query expansion

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// LLM provider for query expansion
pub trait LLMProvider: Send + Sync {
    /// Expand a code search query with semantic synonyms
    fn expand_query(&mut self, query: &str) -> Result<Vec<String>>;

    /// Get provider name
    fn name(&self) -> &str;
}

/// Simple built-in query expander (no LLM required)
pub struct BuiltinExpander {
    synonym_dict: std::collections::HashMap<String, Vec<String>>,
}

impl Default for BuiltinExpander {
    fn default() -> Self {
        let mut dict = std::collections::HashMap::new();

        // Code operation synonyms
        dict.insert("get".to_string(), vec!["fetch".to_string(), "retrieve".to_string(), "load".to_string(), "read".to_string()]);
        dict.insert("set".to_string(), vec!["update".to_string(), "save".to_string(), "write".to_string(), "store".to_string()]);
        dict.insert("delete".to_string(), vec!["remove".to_string(), "destroy".to_string(), "drop".to_string(), "clear".to_string()]);
        dict.insert("create".to_string(), vec!["add".to_string(), "insert".to_string(), "new".to_string(), "make".to_string()]);

        // Authentication synonyms
        dict.insert("auth".to_string(), vec!["authentication".to_string(), "login".to_string(), "signin".to_string(), "verify".to_string()]);
        dict.insert("user".to_string(), vec!["account".to_string(), "profile".to_string(), "person".to_string(), "member".to_string()]);

        // Common patterns
        dict.insert("handle".to_string(), vec!["process".to_string(), "manage".to_string(), "deal".to_string(), "control".to_string()]);
        dict.insert("validate".to_string(), vec!["verify".to_string(), "check".to_string(), "confirm".to_string(), "ensure".to_string()]);
        dict.insert("send".to_string(), vec!["emit".to_string(), "dispatch".to_string(), "publish".to_string(), "transmit".to_string()]);

        Self { synonym_dict: dict }
    }
}

impl LLMProvider for BuiltinExpander {
    fn expand_query(&mut self, query: &str) -> Result<Vec<String>> {
        let mut expansions = Vec::new();

        for word in query.split_whitespace() {
            let lower = word.to_lowercase();
            if let Some(synonyms) = self.synonym_dict.get(&lower) {
                expansions.extend(synonyms.clone());
            }
        }

        Ok(expansions)
    }

    fn name(&self) -> &str {
        "builtin"
    }
}

/// HTTP-based LLM provider (for Claude, GPT, etc.)
pub struct HttpLLMProvider {
    endpoint: String,
    api_key: Option<String>,
    model: String,
    client: reqwest::blocking::Client,
}

impl HttpLLMProvider {
    /// Create new HTTP LLM provider
    pub fn new(endpoint: String, api_key: Option<String>, model: String) -> Self {
        Self {
            endpoint,
            api_key,
            model,
            client: reqwest::blocking::Client::new(),
        }
    }

    /// Create Claude provider
    pub fn claude(api_key: String) -> Self {
        Self::new(
            "https://api.anthropic.com/v1/messages".to_string(),
            Some(api_key),
            "claude-3-5-sonnet-20241022".to_string(),
        )
    }

    /// Create OpenAI provider
    pub fn openai(api_key: String) -> Self {
        Self::new(
            "https://api.openai.com/v1/chat/completions".to_string(),
            Some(api_key),
            "gpt-4".to_string(),
        )
    }
}

#[derive(Serialize)]
struct ClaudeRequest {
    model: String,
    max_tokens: u32,
    messages: Vec<ClaudeMessage>,
}

#[derive(Serialize)]
struct ClaudeMessage {
    role: String,
    content: String,
}

#[derive(Deserialize)]
struct ClaudeResponse {
    content: Vec<ClaudeContent>,
}

#[derive(Deserialize)]
struct ClaudeContent {
    text: String,
}

impl LLMProvider for HttpLLMProvider {
    fn expand_query(&mut self, query: &str) -> Result<Vec<String>> {
        let prompt = format!(
            "Given this code search query: \"{}\"\n\n\
            Provide 5-10 related programming terms and synonyms that would help find similar code.\n\
            Return only the terms, one per line, no explanations.",
            query
        );

        let request = ClaudeRequest {
            model: self.model.clone(),
            max_tokens: 200,
            messages: vec![ClaudeMessage {
                role: "user".to_string(),
                content: prompt,
            }],
        };

        let mut req = self.client
            .post(&self.endpoint)
            .json(&request);

        if let Some(api_key) = &self.api_key {
            req = req
                .header("x-api-key", api_key)
                .header("anthropic-version", "2023-06-01");
        }

        let response: ClaudeResponse = req.send()?.json()?;

        if let Some(content) = response.content.first() {
            let terms: Vec<String> = content.text
                .lines()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect();

            Ok(terms)
        } else {
            Ok(Vec::new())
        }
    }

    fn name(&self) -> &str {
        "http-llm"
    }
}

/// LLM query expander with caching
pub struct CachedLLMExpander {
    provider: Box<dyn LLMProvider>,
    cache: std::collections::HashMap<String, Vec<String>>,
}

impl CachedLLMExpander {
    /// Create with any provider
    pub fn new(provider: Box<dyn LLMProvider>) -> Self {
        Self {
            provider,
            cache: std::collections::HashMap::new(),
        }
    }

    /// Create with built-in expander (fast, offline)
    pub fn builtin() -> Self {
        Self::new(Box::new(BuiltinExpander::default()))
    }

    /// Create with Claude
    pub fn claude(api_key: String) -> Self {
        Self::new(Box::new(HttpLLMProvider::claude(api_key)))
    }

    /// Expand query (with caching)
    pub fn expand(&mut self, query: &str) -> Result<Vec<String>> {
        // Check cache
        if let Some(cached) = self.cache.get(query) {
            return Ok(cached.clone());
        }

        // Call provider
        let expansions = self.provider.expand_query(query)?;

        // Cache result
        self.cache.insert(query.to_string(), expansions.clone());

        Ok(expansions)
    }

    /// Clear cache
    pub fn clear_cache(&mut self) {
        self.cache.clear();
    }

    /// Get cache size
    pub fn cache_size(&self) -> usize {
        self.cache.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_builtin_expander() {
        let mut expander = BuiltinExpander::default();

        let expansions = expander.expand_query("get user auth").unwrap();

        assert!(expansions.contains(&"fetch".to_string()));
        assert!(expansions.contains(&"account".to_string()));
        assert!(expansions.contains(&"authentication".to_string()));
    }

    #[test]
    fn test_cached_expander() {
        let mut expander = CachedLLMExpander::builtin();

        // First call
        let result1 = expander.expand("get user").unwrap();
        assert!(!result1.is_empty());
        assert_eq!(expander.cache_size(), 1);

        // Second call (cached)
        let result2 = expander.expand("get user").unwrap();
        assert_eq!(result1, result2);
        assert_eq!(expander.cache_size(), 1);
    }
}

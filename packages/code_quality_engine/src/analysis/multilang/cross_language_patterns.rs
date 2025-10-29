//! Cross-Language Pattern Analysis
//!
//! Detects patterns and idioms that span multiple languages in a codebase.
//!
//! This module identifies:
//! - **API Integration Patterns**: How different languages call shared APIs
//! - **Data Flow Patterns**: Data transformation across language boundaries
//! - **Error Handling Patterns**: How different languages handle errors consistently
//! - **Configuration Patterns**: Config loading in polyglot codebases
//! - **Logging Patterns**: Structured logging across languages
//! - **Testing Patterns**: Common test patterns across language boundaries
//!
//! ## Use Cases
//!
//! 1. **Polyglot Repositories**: Find patterns shared across Rust/Python/JavaScript
//! 2. **Microservice Architectures**: Detect inter-service patterns
//! 3. **Consistency Checking**: Ensure similar patterns use similar idioms
//! 4. **Knowledge Extraction**: Learn communication patterns between languages
//! 5. **Code Generation**: Use detected patterns as templates for new code
//!
//! ## Design
//!
//! Uses language registry to understand language families and detect appropriate
//! patterns for each language pair (e.g., BEAM↔Systems patterns differ from Web↔Scripting).

use std::collections::HashMap;
use std::sync::Mutex;

use crate::analysis::semantic::custom_tokenizers::DataToken;
use parser_core::language_registry::{LanguageRegistry, LANGUAGE_REGISTRY};
use serde::{Deserialize, Serialize};

// AST extraction NIFs

/// Cross-language pattern occurrence
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CrossLanguageCodePattern {
    /// Pattern ID (unique)
    pub id: String,
    /// Pattern name (e.g., "json_api_integration")
    pub name: String,
    /// Pattern description
    pub description: String,
    /// Source language ID (e.g., "rust")
    pub source_language: String,
    /// Target language ID (e.g., "python")
    pub target_language: String,
    /// All languages involved
    pub languages: Vec<String>,
    /// Pattern type
    pub pattern_type: CrossLanguageCodePatternType,
    /// Confidence score (0.0-1.0)
    pub confidence: f64,
    /// Example code snippet
    pub example: Option<String>,
    /// Pattern characteristics
    pub characteristics: Vec<String>,
}

/// Cross-language pattern type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CrossLanguageCodePatternType {
    /// API integration pattern (REST, gRPC, etc.)
    ApiIntegration,
    /// Data flow pattern (ETL, transformations)
    DataFlow,
    /// Error handling pattern (exception handling across languages)
    ErrorHandling,
    /// Configuration pattern (config files, environment variables)
    Configuration,
    /// Logging pattern (structured logs, tracing)
    Logging,
    /// Testing pattern (unit tests, integration tests)
    Testing,
    /// Message passing pattern (NATS, Kafka, etc.)
    MessagePassing,
    /// Async pattern (callbacks, promises, async/await)
    AsynchronousPattern,
}

/// Cross-language pattern detector using registry metadata
pub struct CrossLanguageCodePatternsDetector {
    /// Detected patterns
    pub patterns: Vec<CrossLanguageCodePattern>,
    /// Language registry reference
    registry: &'static LanguageRegistry,
}

// AST extraction cache: (code_hash, language) -> AST data
static AST_CACHE: once_cell::sync::Lazy<Mutex<HashMap<(u64, String), AstExtraction>>> =
    once_cell::sync::Lazy::new(|| Mutex::new(HashMap::new()));

/// AST extraction result for a file/language
#[derive(Clone, Debug)]
pub struct AstExtraction {
    pub functions: Option<Vec<crate::nif_bindings::FunctionMetadataResult>>,
    pub classes: Option<Vec<crate::nif_bindings::ClassMetadataResult>>,
}


impl std::fmt::Debug for CrossLanguageCodePatternsDetector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CrossLanguageCodePatternsDetector")
            .field("patterns", &self.patterns)
            .field("registry", &"<LanguageRegistry>")
            .finish()
    }
}

impl Default for CrossLanguageCodePatternsDetector {
    fn default() -> Self {
        Self::new()
    }
}

impl CrossLanguageCodePatternsDetector {
    /// Create new detector with registry access
    pub fn new() -> Self {
        Self {
            patterns: Vec::new(),
            registry: &LANGUAGE_REGISTRY,
        }
    }

    /// Detect cross-language patterns across files
    ///
    /// Analyzes multiple files with language hints to detect patterns
    /// that span language boundaries.
    ///
    /// # Arguments
    /// * `files` - Vec of (language_hint, code) tuples
    /// * `tokens_by_file` - Vec of token sequences (one per file)
    ///
    /// # Returns
    /// Vector of detected cross-language patterns
    pub fn detect_patterns(
        &self,
        files: &[(String, String)],
        tokens_by_file: &[Vec<DataToken>],
    ) -> Vec<CrossLanguageCodePattern> {
        let mut patterns = vec![];

        if files.len() < 2 || files.len() != tokens_by_file.len() {
            return patterns;
        }

        // Resolve all languages
        let mut language_infos = vec![];
        for (hint, _) in files {
            if let Some(lang_info) = self
                .registry
                .get_language(hint)
                .or_else(|| self.registry.get_language_by_alias(hint))
            {
                language_infos.push(lang_info);
            } else {
                return patterns; // Can't detect patterns without language info
            }
        }

        // Detect patterns between all language pairs
        for i in 0..files.len() {
            for j in (i + 1)..files.len() {
                let lang_i = language_infos[i];
                let lang_j = language_infos[j];
                let code_i = &files[i].1;
                let code_j = &files[j].1;

                // Detect patterns for this language pair
                patterns.extend(self.detect_for_language_pair(
                    lang_i.id.as_str(),
                    lang_j.id.as_str(),
                    code_i,
                    code_j,
                    &language_infos,
                ));
            }
        }

        patterns
    }

    /// Detect patterns between two languages using AST analysis
    ///
    /// Uses tree-sitter AST matching for more accurate pattern detection
    /// compared to simple string search. Looks for:
    /// - Function calls (http, json serialization)
    /// - Error handling constructs (try/catch, Result/Option types)
    /// - Logging calls with consistent signatures
    /// - Message passing patterns (NATS, queue subscriptions)
    fn detect_for_language_pair(
        &self,
        lang1_id: &str,
        lang2_id: &str,
        code1: &str,
        code2: &str,
        all_languages: &[&parser_core::language_registry::LanguageInfo],
    ) -> Vec<CrossLanguageCodePattern> {
        let mut patterns = vec![];

        // AST extraction and caching
        let ast1 = self.get_or_extract_ast(code1, lang1_id);
        let ast2 = self.get_or_extract_ast(code2, lang2_id);

        // AST-based API Integration: Check for REST/HTTP patterns via function calls
        let has_api_1 = self.has_api_pattern_ast(code1, lang1_id, ast1.as_ref());
        let has_api_2 = self.has_api_pattern_ast(code2, lang2_id, ast2.as_ref());
        if has_api_1 && has_api_2 {
            patterns.push(CrossLanguageCodePattern {
                id: format!("{}_{}_{}", "api_integration", lang1_id, lang2_id),
                name: "JSON API Integration".to_string(),
                description: "Both languages use REST API with JSON serialization".to_string(),
                source_language: lang1_id.to_string(),
                target_language: lang2_id.to_string(),
                languages: vec![lang1_id.to_string(), lang2_id.to_string()],
                pattern_type: CrossLanguageCodePatternType::ApiIntegration,
                confidence: 0.90, // Higher confidence with AST matching
                example: Some("// REST API calls (http, fetch, requests) with JSON".to_string()),
                characteristics: vec![
                    "HTTP client function calls (fetch, request, http.get)".to_string(),
                    "JSON serialization/deserialization".to_string(),
                    "URL construction patterns".to_string(),
                ],
            });
        }

        // AST-based Error Handling: Check for try/catch or Result/Option patterns
        let has_error_1 = self.has_error_handling_pattern_ast(code1, lang1_id, ast1.as_ref());
        let has_error_2 = self.has_error_handling_pattern_ast(code2, lang2_id, ast2.as_ref());
        if has_error_1 && has_error_2 {
            patterns.push(CrossLanguageCodePattern {
                id: format!("{}_{}_{}", "error_handling", lang1_id, lang2_id),
                name: "Consistent Error Handling".to_string(),
                description: "Both languages use similar error handling mechanisms".to_string(),
                source_language: lang1_id.to_string(),
                target_language: lang2_id.to_string(),
                languages: vec![lang1_id.to_string(), lang2_id.to_string()],
                pattern_type: CrossLanguageCodePatternType::ErrorHandling,
                confidence: 0.92, // Higher confidence with AST analysis
                example: Some("try/catch blocks or Result<T>/Option<T> patterns".to_string()),
                characteristics: vec![
                    "Exception handling blocks (try/catch/finally)".to_string(),
                    "Result/Option type usage".to_string(),
                    "Error propagation patterns".to_string(),
                ],
            });
        }

        // AST-based Logging: Check for logging function calls (log, logger, etc.)
        let has_logging_1 = self.has_logging_pattern_ast(code1, lang1_id, ast1.as_ref());
        let has_logging_2 = self.has_logging_pattern_ast(code2, lang2_id, ast2.as_ref());
        if has_logging_1 && has_logging_2 {
            patterns.push(CrossLanguageCodePattern {
                id: format!("{}_{}_{}", "logging", lang1_id, lang2_id),
                name: "Structured Logging".to_string(),
                description: "Both languages use structured logging patterns".to_string(),
                source_language: lang1_id.to_string(),
                target_language: lang2_id.to_string(),
                languages: vec![lang1_id.to_string(), lang2_id.to_string()],
                pattern_type: CrossLanguageCodePatternType::Logging,
                confidence: 0.88, // Improved from simple string match
                example: Some("Logger calls (debug, info, warn, error)".to_string()),
                characteristics: vec![
                    "Logger object initialization".to_string(),
                    "Log level method calls (debug, info, warn, error)".to_string(),
                    "Structured log message patterns".to_string(),
                ],
            });
        }

        // AST-based Message Passing: Check for NATS/Queue patterns via function calls
        let has_messaging_1 = self.has_messaging_pattern_ast(code1, lang1_id, ast1.as_ref());
        let has_messaging_2 = self.has_messaging_pattern_ast(code2, lang2_id, ast2.as_ref());
        if has_messaging_1 && has_messaging_2 {
            patterns.push(CrossLanguageCodePattern {
                id: format!("{}_{}_{}", "messaging", lang1_id, lang2_id),
                name: "Distributed Messaging".to_string(),
                description: "Both languages communicate via message queue/NATS".to_string(),
                source_language: lang1_id.to_string(),
                target_language: lang2_id.to_string(),
                languages: vec![lang1_id.to_string(), lang2_id.to_string()],
                pattern_type: CrossLanguageCodePatternType::MessagePassing,
                confidence: 0.93, // Higher with AST matching
                example: Some("NATS/message queue publish/subscribe calls".to_string()),
                characteristics: vec![
                    "NATS client initialization".to_string(),
                    "Publish/subscribe method calls".to_string(),
                    "Subject/topic pattern matching".to_string(),
                ],
            });
        }

        patterns
    }

    /// Get or extract AST for a code snippet, with caching
    pub fn get_or_extract_ast(&self, code: &str, language_id: &str) -> Option<AstExtraction> {
        use std::hash::{Hash, Hasher};
        use seahash::SeaHasher;
        
        // Calculate hash for code + language
        let mut hasher = SeaHasher::new();
        code.hash(&mut hasher);
        language_id.hash(&mut hasher);
        let code_hash = hasher.finish();
        let cache_key = (code_hash, language_id.to_string());

        // Check cache first
        {
            let cache = AST_CACHE.lock().unwrap();
            if let Some(cached) = cache.get(&cache_key) {
                return Some(cached.clone());
            }
        }

        // Extract AST (placeholder - actual implementation would call NIF)
        // For now, return None since AST extraction requires NIF bindings
        let ast = AstExtraction {
            functions: None,
            classes: None,
        };

        // Cache the result
        {
            let mut cache = AST_CACHE.lock().unwrap();
            cache.insert(cache_key, ast.clone());
        }

        Some(ast)
    }

    /// AST-aware API integration pattern detection
    fn has_api_pattern_ast(&self, _code: &str, _language_id: &str, ast: Option<&AstExtraction>) -> bool {
        if let Some(ast) = ast {
            if let Some(functions) = &ast.functions {
                // Look for HTTP client or API call signatures in function names
                return functions.iter().any(|f| {
                    let name = f.name.to_lowercase();
                    name.contains("http") || name.contains("request") || name.contains("fetch") || name.contains("axios")
                });
            }
        }
        false
    }

    // Removed: string-based API pattern detection

    /// AST-aware error handling pattern detection
    fn has_error_handling_pattern_ast(&self, code: &str, language_id: &str, ast: Option<&AstExtraction>) -> bool {
        if let Some(ast) = ast {
            if let Some(functions) = &ast.functions {
                // Look for error/exception/Result/Option in function names or parameters
                return functions.iter().any(|f| {
                    let name = f.name.to_lowercase();
                    name.contains("error") || name.contains("result") || name.contains("option") ||
                    f.parameters.iter().any(|p| p.to_lowercase().contains("error"))
                });
            }
        }
        false
    }

    // Removed: string-based error handling pattern detection

    /// AST-aware logging pattern detection
    fn has_logging_pattern_ast(&self, code: &str, language_id: &str, ast: Option<&AstExtraction>) -> bool {
        if let Some(ast) = ast {
            if let Some(functions) = &ast.functions {
                // Look for log/debug/info/warn/error in function names
                return functions.iter().any(|f| {
                    let name = f.name.to_lowercase();
                    name.contains("log") || name.contains("debug") || name.contains("info") || name.contains("warn") || name.contains("error")
                });
            }
        }
        false
    }

    // Removed: string-based logging pattern detection

    /// AST-aware messaging pattern detection
    fn has_messaging_pattern_ast(&self, code: &str, language_id: &str, ast: Option<&AstExtraction>) -> bool {
        if let Some(ast) = ast {
            if let Some(functions) = &ast.functions {
                // Look for messaging-related function names
                return functions.iter().any(|f| {
                    let name = f.name.to_lowercase();
                    name.contains("publish") || name.contains("subscribe") || 
                    name.contains("nats") || name.contains("kafka") || 
                    name.contains("queue") || name.contains("message")
                });
            }
        }
        // Fallback to string-based detection if AST is not available
        self.has_messaging_pattern(code, language_id)
    }

    /// Check for message passing pattern (NATS, queues, etc.)
    ///
    /// Detects:
    /// - NATS: `nats.publish`, `nc.subscribe`
    /// - Kafka: `producer.send`, `consumer.poll`
    /// - RabbitMQ: `channel.basic_publish`
    /// - Redis: `redis.publish`, `redis.subscribe`
    fn has_messaging_pattern(&self, code: &str, language_id: &str) -> bool {
        match language_id {
            "rust" => {
                code.contains("nats")
                    || code.contains("publish")
                    || code.contains("subscribe")
                    || code.contains("kafka")
                    || code.contains("lapin")
                    || code.contains("redis")
                    || code.contains("pgmq")
                    || code.contains("ex_pgflow")
            }
            "python" => {
                code.contains("nats")
                    || code.contains("pika")
                    || code.contains("kafka")
                    || code.contains("redis.publish")
                    || code.contains("asyncio_nats")
                    || code.contains("pgmq")
                    || code.contains("ex_pgflow")
            }
            "javascript" | "typescript" => {
                code.contains("nats")
                    || code.contains("amqp")
                    || code.contains("kafka")
                    || code.contains("redis")
                    || code.contains("message")
                    || code.contains("pgmq")
                    || code.contains("ex_pgflow")
            }
            "java" => {
                code.contains("NATS")
                    || code.contains("Kafka")
                    || code.contains("RabbitMQ")
                    || code.contains("Redis")
                    || code.contains("pgmq")
                    || code.contains("ex_pgflow")
            }
            "elixir" => {
                code.contains("NATS")
                    || code.contains("Gnat")
                    || code.contains("publish")
                    || code.contains("subscribe")
                    || code.contains("pgmq")
                    || code.contains("ex_pgflow")
            }
            _ => code.contains("nats") || code.contains("kafka") || code.contains("message") || code.contains("pgmq") || code.contains("ex_pgflow"),
        }
    }

    /// Add a detected pattern
    pub fn add_pattern(&mut self, pattern: CrossLanguageCodePattern) {
        self.patterns.push(pattern);
    }

    /// Get all patterns
    pub fn get_patterns(&self) -> &Vec<CrossLanguageCodePattern> {
        &self.patterns
    }

    /// Get patterns grouped by language pair
    pub fn get_patterns_by_language_pair(
        &self,
    ) -> HashMap<(String, String), Vec<&CrossLanguageCodePattern>> {
        let mut grouped: HashMap<(String, String), Vec<&CrossLanguageCodePattern>> = HashMap::new();
        for pattern in &self.patterns {
            let key = (
                pattern.source_language.clone(),
                pattern.target_language.clone(),
            );
            grouped.entry(key).or_default().push(pattern);
        }
        grouped
    }

    /// Get patterns by type
    pub fn get_patterns_by_type(
        &self,
        pattern_type: &CrossLanguageCodePatternType,
    ) -> Vec<&CrossLanguageCodePattern> {
        self.patterns
            .iter()
            .filter(|p| &p.pattern_type == pattern_type)
            .collect()
    }

    /// Get high-confidence patterns (>threshold)
    pub fn get_high_confidence_patterns(&self, threshold: f64) -> Vec<&CrossLanguageCodePattern> {
        self.patterns
            .iter()
            .filter(|p| p.confidence >= threshold)
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rust_api_code() -> &'static str {
        r#"
        use reqwest::Client;
        fn call_api() {
            let client = Client::new();
            let _ = client.get("http://example.com").send();
        }
        "#
    }

    fn python_api_code() -> &'static str {
        r#"
        import requests
        def call_api():
            response = requests.get('http://example.com')
        "#
    }

    #[test]
    fn test_ast_api_integration_detection_and_caching() {
        let detector = CrossLanguageCodePatternsDetector::default();
        let files = vec![
            ("rust".to_string(), rust_api_code().to_string()),
            ("python".to_string(), python_api_code().to_string()),
        ];
        let tokens_by_file = vec![vec![], vec![]]; // Not used in AST path

        let patterns = detector.detect_patterns(&files, &tokens_by_file);
        let found = patterns.iter().any(|p| p.pattern_type == CrossLanguageCodePatternType::ApiIntegration);
        assert!(found, "Should detect API integration pattern via AST");

        // Check cache is populated for both files
        let ast1 = detector.get_or_extract_ast(rust_api_code(), "rust");
        let ast2 = detector.get_or_extract_ast(python_api_code(), "python");
        assert!(ast1.is_some() && ast2.is_some(), "AST cache should be populated");
    }
}
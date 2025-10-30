//! Smart Package Context API
//!
//! Core unified interface for all 4 channels (MCP, VS Code, CLI, API).
//!
//! ## 5 Core Functions
//!
//! 1. `get_package_info()` - Get complete package metadata
//! 2. `get_package_examples()` - Get code examples from documentation
//! 3. `get_package_patterns()` - Get community consensus patterns
//! 4. `search_patterns()` - Semantic search across all patterns
//! 5. `analyze_file()` - Analyze a file and suggest patterns

use crate::cache::Cache;
use crate::error::Result;
use crate::integrations::Integrations;
use crate::types::*;

/// Main Smart Package Context service
///
/// This is the unified backend that MCP, VS Code, CLI, and API all call.
/// It orchestrates PackageIntelligence, Patterns, and Embeddings.
pub struct SmartPackageContext {
    integrations: Integrations,
    cache: Cache,
}

impl SmartPackageContext {
    /// Create a new SmartPackageContext instance
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::SmartPackageContext;
    /// let ctx = SmartPackageContext::new().await?;
    /// ```
    pub async fn new() -> Result<Self> {
        let integrations = Integrations::new().await?;
        let cache = Cache::new();

        Ok(Self {
            integrations,
            cache,
        })
    }

    /// Get complete information about a package
    ///
    /// Combines:
    /// - Official metadata (name, version, description, etc.)
    /// - Quality score
    /// - Download statistics
    ///
    /// # Arguments
    ///
    /// * `name` - Package name (e.g., "react", "tokio", "phoenix")
    /// * `ecosystem` - Package ecosystem (npm, cargo, hex, pypi, etc.)
    ///
    /// # Returns
    ///
    /// Complete package information including quality metrics
    ///
    /// # Errors
    ///
    /// Returns `Error::PackageNotFound` if package doesn't exist
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::{SmartPackageContext, Ecosystem};
    /// let ctx = SmartPackageContext::new().await?;
    /// let pkg = ctx.get_package_info("react", Ecosystem::Npm).await?;
    /// println!("Quality: {}", pkg.quality_score);
    /// ```
    pub async fn get_package_info(
        &self,
        name: &str,
        ecosystem: Ecosystem,
    ) -> Result<PackageInfo> {
        // Check cache first
        if let Some(cached) = self.cache.get_package(name) {
            return Ok(cached);
        }

        // Fetch from integrations
        let package_info = self
            .integrations
            .fetch_package_info(name, ecosystem)
            .await?;

        // Cache the result
        self.cache.set_package(name.to_string(), package_info.clone());

        Ok(package_info)
    }

    /// Get code examples from package documentation
    ///
    /// Returns real code examples extracted from:
    /// - Official documentation
    /// - GitHub README files
    /// - Community examples
    ///
    /// # Arguments
    ///
    /// * `name` - Package name
    /// * `ecosystem` - Package ecosystem
    /// * `limit` - Maximum number of examples to return (default: 5)
    ///
    /// # Returns
    ///
    /// Vector of code examples with descriptions and source links
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::{SmartPackageContext, Ecosystem};
    /// let ctx = SmartPackageContext::new().await?;
    /// let examples = ctx.get_package_examples("react", Ecosystem::Npm, 5).await?;
    /// for example in examples {
    ///     println!("{}: {}", example.title, example.code);
    /// }
    /// ```
    pub async fn get_package_examples(
        &self,
        name: &str,
        ecosystem: Ecosystem,
        limit: usize,
    ) -> Result<Vec<CodeExample>> {
        self.integrations
            .fetch_package_examples(name, ecosystem, limit)
            .await
    }

    /// Get consensus patterns for a package
    ///
    /// Returns the most reliable patterns based on:
    /// - Community usage (frequency)
    /// - Success rate (confidence)
    /// - Expert consensus (agreement)
    ///
    /// Patterns are ranked by confidence score (0.0-1.0).
    /// Only high-confidence patterns (>0.7) should be auto-applied.
    ///
    /// # Arguments
    ///
    /// * `name` - Package name
    ///
    /// # Returns
    ///
    /// Vector of patterns ranked by confidence
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::SmartPackageContext;
    /// let ctx = SmartPackageContext::new().await?;
    /// let patterns = ctx.get_package_patterns("react").await?;
    /// for pattern in patterns {
    ///     if pattern.confidence > 0.9 {
    ///         println!("Highly recommended: {}", pattern.name);
    ///     }
    /// }
    /// ```
    pub async fn get_package_patterns(&self, name: &str) -> Result<Vec<PatternConsensus>> {
        self.integrations.fetch_package_patterns(name).await
    }

    /// Search patterns across all packages using semantic search
    ///
    /// Uses embeddings to find relevant patterns even with fuzzy queries.
    /// Great for finding patterns when you don't know exact package name.
    ///
    /// # Arguments
    ///
    /// * `query` - Natural language search query (e.g., "async error handling in javascript")
    /// * `limit` - Maximum number of results to return (default: 10)
    ///
    /// # Returns
    ///
    /// Vector of pattern matches with relevance scores (0.0-1.0)
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::SmartPackageContext;
    /// let ctx = SmartPackageContext::new().await?;
    /// let results = ctx.search_patterns("async error handling", 10).await?;
    /// for match_ in results {
    ///     println!("{} (relevance: {})", match_.pattern.name, match_.relevance);
    /// }
    /// ```
    pub async fn search_patterns(&self, query: &str, limit: usize) -> Result<Vec<PatternMatch>> {
        self.integrations.search_patterns(query, limit).await
    }

    /// Analyze a file and suggest improvements
    ///
    /// Scans the file and suggests patterns based on:
    /// - Code quality best practices
    /// - Community consensus patterns
    /// - Package-specific conventions
    ///
    /// # Arguments
    ///
    /// * `content` - File content as string
    /// * `file_type` - Programming language
    ///
    /// # Returns
    ///
    /// Vector of suggestions with severity levels and pattern recommendations
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::{SmartPackageContext, FileType};
    /// let ctx = SmartPackageContext::new().await?;
    /// let code = r#"
    /// function handleError(err) {
    ///     console.log(err);
    /// }
    /// "#;
    /// let suggestions = ctx.analyze_file(code, FileType::JavaScript).await?;
    /// for suggestion in suggestions {
    ///     println!("{}: {}", suggestion.severity, suggestion.title);
    /// }
    /// ```
    pub async fn analyze_file(&self, content: &str, file_type: FileType) -> Result<Vec<Suggestion>> {
        self.integrations.analyze_file(content, file_type).await
    }

    /// Health check for the service
    ///
    /// # Returns
    ///
    /// Health check status with version info
    ///
    /// # Example
    ///
    /// ```ignore
    /// use singularity_smart_package_context_backend::SmartPackageContext;
    /// let ctx = SmartPackageContext::new().await?;
    /// let health = ctx.health_check().await?;
    /// println!("Healthy: {}", health.healthy);
    /// ```
    pub async fn health_check(&self) -> Result<HealthCheck> {
        Ok(HealthCheck {
            healthy: true,
            version: crate::VERSION.to_string(),
            message: "Smart Package Context backend is running".to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_health_check() {
        let ctx = SmartPackageContext::new().await.unwrap();
        let health = ctx.health_check().await.unwrap();
        assert!(health.healthy);
    }
}

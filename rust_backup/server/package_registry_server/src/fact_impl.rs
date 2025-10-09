impl Fact {
  /// Create a new FACT instance
  #[must_use]
  pub fn new() -> Self {
    Self {
      engine: EngineFact::new(),
      cache: Arc::new(RwLock::new(Cache::new())),
    }
  }

  /// Create a new FACT instance with custom configuration
  #[must_use]
  pub fn with_config(config: FactConfig) -> Self {
    Self {
      engine: EngineFact::with_config(config.engine_config),
      cache: Arc::new(RwLock::new(Cache::with_capacity(config.cache_size))),
    }
  }

  /// Process a query using a cognitive template
  /// Process a template with the given context
  ///
  /// # Errors
  /// Returns an error if template processing fails or template is not found
  pub async fn process(
    &self,
    template_id: &str,
    context: serde_json::Value,
  ) -> Result<serde_json::Value> {
    // Check cache first
    let cache_key = Self::generate_cache_key(template_id, &context);

    // Need to use write lock for get() since it updates access stats
    let cached_value = self.cache.write().get(&cache_key);
    if let Some(cached) = cached_value {
      return Ok(cached);
    }

    // Process with engine
    let result = self.engine.process(template_id, context).await?;

    // Cache the result
    self.cache.write().put(cache_key, result.clone());

    Ok(result)
  }

  /// Get cache statistics
  #[must_use]
  pub fn cache_stats(&self) -> CacheStats {
    self.cache.read().stats()
  }

  /// Clear the cache
  pub fn clear_cache(&self) {
    self.cache.write().clear();
  }

  fn generate_cache_key(
    template_id: &str,
    context: &serde_json::Value,
  ) -> String {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    template_id.hash(&mut hasher);
    context.to_string().hash(&mut hasher);

    format!("fact:{}:{:x}", template_id, hasher.finish())
  }
}

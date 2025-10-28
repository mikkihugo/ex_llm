//! Vector index for semantic search over FACT storage

use crate::embedding::EmbeddingGenerator;
use crate::storage::{PackageKey, PackageMetadata, PackageStorage};
use anyhow::Result;
use std::collections::HashMap;
use std::sync::Arc;

/// Vector index for fast similarity search
pub struct VectorIndex {
  storage: Arc<dyn PackageStorage>,
  embedder: Arc<EmbeddingGenerator>,
  semantic_index: HashMap<String, Vec<f32>>, // fact_id -> semantic embedding
  code_index: HashMap<String, Vec<f32>>,     // fact_id -> code embedding
}

impl VectorIndex {
  /// Build a new vector index from storage
  pub async fn build(storage: Arc<dyn PackageStorage>) -> Result<Self> {
    let mut embedder = EmbeddingGenerator::new()?;

    // Get all facts to build vocabulary
    let all_facts = storage.get_all_facts().await?;

    // Extract all text for vocabulary building
    let documents: Vec<String> = all_facts
      .iter()
      .map(|(_, fact)| {
        format!(
          "{} {} {} {}",
          fact.tool,
          fact.documentation,
          fact.tags.join(" "),
          fact
            .examples
            .iter()
            .map(|ex| format!("{} {}", ex.title, ex.explanation))
            .collect::<Vec<_>>()
            .join(" ")
        )
      })
      .collect();

    // Build vocabulary
    embedder.build_vocabulary(&documents);

    let embedder = Arc::new(embedder);
    let mut semantic_index = HashMap::new();
    let mut code_index = HashMap::new();

    // Build indexes from existing embeddings
    for (key, fact) in &all_facts {
      let fact_id = key.storage_key();

      if let Some(embedding) = &fact.semantic_embedding {
        semantic_index.insert(fact_id.clone(), embedding.clone());
      }

      if let Some(embedding) = &fact.code_embedding {
        code_index.insert(fact_id, embedding.clone());
      }
    }

    Ok(Self {
      storage,
      embedder,
      semantic_index,
      code_index,
    })
  }

  /// Search for semantically similar facts
  pub async fn semantic_search(
    &self,
    query: &str,
    limit: usize,
  ) -> Result<Vec<(PackageKey, f64)>> {
    // Generate query embedding
    let query_embedding = self.embedder.embed_text(query)?;

    // Calculate similarities
    let mut scores: Vec<(String, f64)> = self
      .semantic_index
      .iter()
      .map(|(id, emb)| {
        let similarity = self.embedder.cosine_similarity(&query_embedding, emb);
        (id.clone(), similarity)
      })
      .collect();

    // Sort by similarity (highest first)
    scores.sort_by(|a, b| {
      b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal)
    });

    // Take top results and convert to PackageKey
    Ok(
      scores
        .into_iter()
        .take(limit)
        .filter_map(|(id, score)| {
          PackageKey::from_storage_key(&id)
            .ok()
            .map(|key| (key, score))
        })
        .collect(),
    )
  }

  /// Search for similar code patterns
  pub async fn code_similarity_search(
    &self,
    code_snippet: &str,
    language: &str,
    limit: usize,
  ) -> Result<Vec<(PackageKey, f64)>> {
    // Generate code embedding
    let query_embedding = self.embedder.embed_code(code_snippet, language)?;

    // Calculate similarities
    let mut scores: Vec<(String, f64)> = self
      .code_index
      .iter()
      .map(|(id, emb)| {
        let similarity = self.embedder.cosine_similarity(&query_embedding, emb);
        (id.clone(), similarity)
      })
      .collect();

    // Sort by similarity
    scores.sort_by(|a, b| {
      b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal)
    });

    // Take top results
    Ok(
      scores
        .into_iter()
        .take(limit)
        .filter_map(|(id, score)| {
          PackageKey::from_storage_key(&id)
            .ok()
            .map(|key| (key, score))
        })
        .collect(),
    )
  }

  /// Add or update a fact in the index
  pub async fn index_fact(
    &mut self,
    key: &PackageKey,
    fact: &PackageMetadata,
  ) -> Result<()> {
    let fact_id = key.storage_key();

    // Index semantic embedding if present
    if let Some(embedding) = &fact.semantic_embedding {
      self
        .semantic_index
        .insert(fact_id.clone(), embedding.clone());
    } else {
      // Generate semantic embedding
      let text = format!(
        "{} {} {}",
        fact.tool,
        fact.documentation,
        fact.tags.join(" ")
      );
      let embedding = self.embedder.embed_text(&text)?;
      self.semantic_index.insert(fact_id.clone(), embedding);
    }

    // Index code embedding if present
    if let Some(embedding) = &fact.code_embedding {
      self.code_index.insert(fact_id, embedding.clone());
    } else if let Some(first_example) = fact.examples.first() {
      // Generate code embedding from first example
      let embedding = self
        .embedder
        .embed_code(&first_example.code, "typescript")?;
      self.code_index.insert(fact_id, embedding);
    }

    Ok(())
  }

  /// Remove a fact from the index
  pub fn remove_fact(&mut self, key: &PackageKey) {
    let fact_id = key.storage_key();
    self.semantic_index.remove(&fact_id);
    self.code_index.remove(&fact_id);
  }

  /// Get index statistics
  pub fn stats(&self) -> IndexStats {
    IndexStats {
      total_facts: self.semantic_index.len(),
      semantic_indexed: self.semantic_index.len(),
      code_indexed: self.code_index.len(),
      embedding_dimension: 384,
    }
  }
}

/// Statistics about the vector index
#[derive(Debug, Clone)]
pub struct IndexStats {
  pub total_facts: usize,
  pub semantic_indexed: usize,
  pub code_indexed: usize,
  pub embedding_dimension: usize,
}

#[cfg(test)]
mod tests {
  use super::*;
  use crate::storage::{PackageExample, PackageMetadata, UsageStats};
  use std::time::SystemTime;

  // Mock storage for testing
  struct MockStorage {
    facts: HashMap<String, PackageMetadata>,
  }

  #[async_trait::async_trait]
  impl PackageStorage for MockStorage {
    async fn store_fact(
      &self,
      _key: &PackageKey,
      _data: &PackageMetadata,
    ) -> Result<()> {
      Ok(())
    }

    async fn get_fact(
      &self,
      key: &PackageKey,
    ) -> Result<Option<PackageMetadata>> {
      Ok(self.facts.get(&key.storage_key()).cloned())
    }

    async fn exists(&self, key: &PackageKey) -> Result<bool> {
      Ok(self.facts.contains_key(&key.storage_key()))
    }

    async fn delete_fact(&self, _key: &PackageKey) -> Result<()> {
      Ok(())
    }

    async fn list_tools(&self, _ecosystem: &str) -> Result<Vec<PackageKey>> {
      Ok(vec![])
    }

    async fn search_tools(&self, _prefix: &str) -> Result<Vec<PackageKey>> {
      Ok(vec![])
    }

    async fn stats(&self) -> Result<crate::storage::StorageStats> {
      Ok(crate::storage::StorageStats {
        total_entries: 0,
        total_size_bytes: 0,
        ecosystems: HashMap::new(),
        last_compaction: None,
      })
    }

    async fn search_by_tags(
      &self,
      _tags: &[String],
    ) -> Result<Vec<PackageKey>> {
      Ok(vec![])
    }

    async fn get_all_facts(
      &self,
    ) -> Result<Vec<(PackageKey, PackageMetadata)>> {
      Ok(
        self
          .facts
          .iter()
          .filter_map(|(id, fact)| {
            PackageKey::from_storage_key(id)
              .ok()
              .map(|key| (key, fact.clone()))
          })
          .collect(),
      )
    }
  }

  fn create_test_fact(tool: &str, docs: &str) -> PackageMetadata {
    PackageMetadata {
      tool: tool.to_string(),
      version: "1.0".to_string(),
      ecosystem: "test".to_string(),
      documentation: docs.to_string(),
      snippets: vec![],
      examples: vec![PackageExample {
        title: "Example".to_string(),
        code: "fn main() {}".to_string(),
        explanation: "Test example".to_string(),
        tags: vec![],
      }],
      best_practices: vec![],
      troubleshooting: vec![],
      github_sources: vec![],
      dependencies: vec![],
      tags: vec!["test".to_string()],
      last_updated: SystemTime::now(),
      source: "test".to_string(),
      code_index: None,
      detected_framework: None,
      prompt_templates: vec![],
      quick_starts: vec![],
      migration_guides: vec![],
      usage_patterns: vec![],
      cli_commands: vec![],
      semantic_embedding: None,
      code_embedding: None,
      graph_embedding: None,
      relationships: vec![],
      usage_stats: UsageStats::default(),
      execution_history: vec![],
      learning_data: Default::default(),
    }
  }

  #[tokio::test]
  async fn test_vector_index_build() {
    let mut facts = HashMap::new();
    facts.insert(
      "fact:test:auth:1.0".to_string(),
      create_test_fact("auth", "authentication and security"),
    );
    facts.insert(
      "fact:test:database:1.0".to_string(),
      create_test_fact("database", "database operations and queries"),
    );

    let storage = Arc::new(MockStorage { facts });
    let index = VectorIndex::build(storage).await.unwrap();

    let stats = index.stats();
    assert_eq!(stats.total_facts, 2);
  }

  #[tokio::test]
  async fn test_semantic_search() {
    let mut facts = HashMap::new();
    facts.insert(
      "fact:test:auth:1.0".to_string(),
      create_test_fact("auth", "authentication security login password"),
    );
    facts.insert(
      "fact:test:database:1.0".to_string(),
      create_test_fact("database", "database sql query search"),
    );

    let storage = Arc::new(MockStorage { facts });
    let index = VectorIndex::build(storage).await.unwrap();

    let results = index
      .semantic_search("authentication login", 5)
      .await
      .unwrap();
    assert!(!results.is_empty());

    // Auth should be more similar to "authentication login" than database
    if results.len() >= 2 {
      assert!(results[0].1 >= results[1].1);
    }
  }
}

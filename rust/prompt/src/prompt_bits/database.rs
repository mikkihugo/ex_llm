//! Prompt bit database with LLM fallback for missing entries

use std::{collections::HashMap, path::PathBuf};

use anyhow::Result;
use serde::{Deserialize, Serialize};

/// Stored prompt bit in database
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StoredPromptBit {
    pub id: String,
    pub category: PromptBitCategory,
    pub trigger: PromptBitTrigger,
    pub content: String,
    pub metadata: PromptBitMetadata,
    pub source: PromptBitSource,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub usage_count: u32,
    pub success_rate: f64,
}

/// What triggers this bit
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum PromptBitTrigger {
    Framework(String),      // "Next.js", "Spring Boot", etc.
    Language(String),       // "Rust", "Go", etc.
    BuildSystem(String),    // "Moon", "Cargo", etc.
    Infrastructure(String), // "NATS", "Kafka", etc.
    CodePattern(String),    // "Microservices", "CQRS", etc.
    Custom(String),
}

/// Prompt bit category
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum PromptBitCategory {
    Commands,      // How to run commands
    Dependencies,  // How to add dependencies
    Configuration, // How to configure
    BestPractices, // Best practices for this tech
    Examples,      // Code examples
    Integration,   // How to integrate with other systems
    Testing,       // How to test
    Deployment,    // How to deploy
}

/// Where this bit came from
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PromptBitSource {
    Builtin, // Hand-written in code
    LLMGenerated {
        model: String,
        timestamp: chrono::DateTime<chrono::Utc>,
    },
    CommunityContributed {
        author: String,
    },
    Learned {
        from_feedback: String,
    },
}

/// Metadata for learning
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptBitMetadata {
    pub confidence: f64, // How confident we are this is correct
    pub last_updated: chrono::DateTime<chrono::Utc>,
    pub versions: Vec<String>,     // Which versions this applies to
    pub related_bits: Vec<String>, // Related prompt bit IDs
}

/// Prompt bit database with LLM fallback
pub struct PromptBitDatabase {
    storage_path: PathBuf,
    cache: HashMap<PromptBitTrigger, Vec<StoredPromptBit>>,
    llm_client: Option<Box<dyn LLMClient>>,
}

/// LLM client trait for generating missing bits
#[async_trait::async_trait]
pub trait LLMClient: Send + Sync {
    async fn generate_prompt_bit(
        &self,
        trigger: &PromptBitTrigger,
        category: &PromptBitCategory,
        context: &GenerationContext,
    ) -> Result<String>;
}

/// Context for LLM generation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationContext {
    pub task_description: String,
    pub existing_bits: Vec<String>, // Similar bits for reference
    pub repo_context: String,       // Repository context
}

impl PromptBitDatabase {
    pub fn new(storage_path: PathBuf) -> Self {
        Self {
            storage_path,
            cache: HashMap::new(),
            llm_client: None,
        }
    }

    /// Set LLM client for fallback generation
    pub fn with_llm_client(mut self, client: Box<dyn LLMClient>) -> Self {
        self.llm_client = Some(client);
        self
    }

    /// Load database from disk
    pub async fn load(&mut self) -> Result<()> {
        let db_file = self.storage_path.join("prompt_bits.json");
        if !db_file.exists() {
            self.initialize_builtin_bits()?;
            return Ok(());
        }

        let contents = std::fs::read_to_string(db_file)?;
        let bits: Vec<StoredPromptBit> = serde_json::from_str(&contents)?;

        // Build cache
        self.cache.clear();
        for bit in bits {
            self.cache.entry(bit.trigger.clone()).or_default().push(bit);
        }

        Ok(())
    }

    /// Save database to disk
    pub async fn save(&self) -> Result<()> {
        std::fs::create_dir_all(&self.storage_path)?;
        let db_file = self.storage_path.join("prompt_bits.json");

        let all_bits: Vec<StoredPromptBit> = self.cache.values().flatten().cloned().collect();

        let json = serde_json::to_string_pretty(&all_bits)?;
        std::fs::write(db_file, json)?;

        Ok(())
    }

    /// Get prompt bit with LLM fallback
    pub async fn get_or_generate(
        &mut self,
        trigger: &PromptBitTrigger,
        category: &PromptBitCategory,
        context: &GenerationContext,
    ) -> Result<String> {
        // 1. Try to find in database
        let found_bit = if let Some(bits) = self.cache.get(trigger) {
            bits.iter()
                .find(|b| &b.category == category)
                .map(|b| (b.id.clone(), b.content.clone()))
        } else {
            None
        };

        if let Some((bit_id, content)) = found_bit {
            // Found! Update usage stats
            self.increment_usage(&bit_id).await?;
            return Ok(content);
        }

        // 2. Not found - generate with LLM if available
        if let Some(llm) = &self.llm_client {
            println!(
                "⚠️  No prompt bit for {:?} + {:?}, generating with LLM...",
                trigger, category
            );

            let generated_content = llm.generate_prompt_bit(trigger, category, context).await?;

            // Store for future use
            let bit = StoredPromptBit {
                id: uuid::Uuid::new_v4().to_string(),
                category: category.clone(),
                trigger: trigger.clone(),
                content: generated_content.clone(),
                metadata: PromptBitMetadata {
                    confidence: 0.6, // Lower confidence for generated
                    last_updated: chrono::Utc::now(),
                    versions: vec!["*".to_string()],
                    related_bits: vec![],
                },
                source: PromptBitSource::LLMGenerated {
                    model: "claude-3-5-sonnet".to_string(), // Or from config
                    timestamp: chrono::Utc::now(),
                },
                created_at: chrono::Utc::now(),
                usage_count: 1,
                success_rate: 0.5, // Unknown until feedback
            };

            self.store_bit(bit).await?;

            Ok(generated_content)
        } else {
            // No LLM client - return default fallback
            Ok(self.default_fallback(trigger, category))
        }
    }

    /// Store new prompt bit
    pub async fn store_bit(&mut self, bit: StoredPromptBit) -> Result<()> {
        self.cache.entry(bit.trigger.clone()).or_default().push(bit);

        self.save().await?;

        Ok(())
    }

    /// Update prompt bit with feedback
    pub async fn update_with_feedback(&mut self, bit_id: &str, success: bool) -> Result<()> {
        for bits in self.cache.values_mut() {
            for bit in bits.iter_mut() {
                if bit.id == bit_id {
                    bit.usage_count += 1;
                    let total = bit.usage_count as f64;
                    let successes =
                        (bit.success_rate * (total - 1.0)) + if success { 1.0 } else { 0.0 };
                    bit.success_rate = successes / total;
                    bit.metadata.last_updated = chrono::Utc::now();

                    self.save().await?;
                    return Ok(());
                }
            }
        }

        Ok(())
    }

    /// Increment usage count
    async fn increment_usage(&mut self, bit_id: &str) -> Result<()> {
        for bits in self.cache.values_mut() {
            for bit in bits.iter_mut() {
                if bit.id == bit_id {
                    bit.usage_count += 1;
                    // Don't save on every increment (performance)
                    return Ok(());
                }
            }
        }
        Ok(())
    }

    /// Default fallback when no LLM available
    fn default_fallback(&self, trigger: &PromptBitTrigger, category: &PromptBitCategory) -> String {
        format!(
            "## {:?} for {:?}\n\n\
       No specific guidance available yet.\n\
       Please refer to official documentation.\n\n\
       (This prompt bit will be generated automatically in future runs)\n",
            category, trigger
        )
    }

    /// Initialize builtin bits
    fn initialize_builtin_bits(&mut self) -> Result<()> {
        // Add some builtin bits for common tech
        let builtin_bits = vec![
            // Rust + Actix
            StoredPromptBit {
                id: uuid::Uuid::new_v4().to_string(),
                trigger: PromptBitTrigger::Framework("Actix Web".to_string()),
                category: PromptBitCategory::Commands,
                content: r#"
## Actix Web Commands

```bash
# Add dependency
cargo add actix-web

# Add with features
cargo add actix-web --features macros

# Run dev server
cargo run

# Build release
cargo build --release
```
"#
                .to_string(),
                metadata: PromptBitMetadata {
                    confidence: 0.95,
                    last_updated: chrono::Utc::now(),
                    versions: vec!["4.x".to_string()],
                    related_bits: vec![],
                },
                source: PromptBitSource::Builtin,
                created_at: chrono::Utc::now(),
                usage_count: 0,
                success_rate: 1.0,
            },
            // NATS messaging
            StoredPromptBit {
                id: uuid::Uuid::new_v4().to_string(),
                trigger: PromptBitTrigger::Infrastructure("NATS".to_string()),
                category: PromptBitCategory::Integration,
                content: r#"
## NATS Integration

Connection:
```rust
use async_nats::Client;

let client = async_nats::connect("nats://localhost:4222").await?;
```

Publish:
```rust
client.publish("subject.name", "message".into()).await?;
```

Subscribe:
```rust
let mut sub = client.subscribe("subject.*").await?;
while let Some(msg) = sub.next().await {
    println!("Received: {:?}", msg);
}
```

Best practices:
- Use hierarchical subjects (e.g., `auth.login`, `auth.logout`)
- Enable JetStream for persistence
- Implement retry logic
- Add message validation
"#
                .to_string(),
                metadata: PromptBitMetadata {
                    confidence: 0.95,
                    last_updated: chrono::Utc::now(),
                    versions: vec!["*".to_string()],
                    related_bits: vec![],
                },
                source: PromptBitSource::Builtin,
                created_at: chrono::Utc::now(),
                usage_count: 0,
                success_rate: 1.0,
            },
        ];

        for bit in builtin_bits {
            self.cache.entry(bit.trigger.clone()).or_default().push(bit);
        }

        Ok(())
    }

    /// Query statistics
    pub fn get_statistics(&self) -> DatabaseStatistics {
        let total_bits = self.cache.values().map(|v| v.len()).sum();
        let llm_generated = self
            .cache
            .values()
            .flatten()
            .filter(|b| matches!(b.source, PromptBitSource::LLMGenerated { .. }))
            .count();

        let mut by_trigger: HashMap<String, usize> = HashMap::new();
        for (trigger, bits) in &self.cache {
            by_trigger.insert(format!("{:?}", trigger), bits.len());
        }

        DatabaseStatistics {
            total_bits,
            builtin_bits: total_bits - llm_generated,
            llm_generated_bits: llm_generated,
            by_trigger,
        }
    }
}

/// Database statistics
#[derive(Debug, Serialize, Deserialize)]
pub struct DatabaseStatistics {
    pub total_bits: usize,
    pub builtin_bits: usize,
    pub llm_generated_bits: usize,
    pub by_trigger: HashMap<String, usize>,
}

#[cfg(test)]
mod tests {

    #[tokio::test]
    async fn test_database_load_save() {
        // Test database persistence
    }
}

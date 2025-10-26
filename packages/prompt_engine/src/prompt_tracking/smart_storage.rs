//! Pure computation smart storage for prompt definitions
//!
//! This module provides pure computation functions for prompt management.
//! All data is passed in via parameters and returned as results.
//! No I/O operations - designed for NIF usage.

use anyhow::Result;
use std::collections::HashMap;
use serde::{Deserialize, Serialize};

/// Pure computation smart storage
/// 
/// This struct holds prompt data in memory for the current computation.
/// No persistent storage - data is passed in via NIF parameters.
pub struct SmartStorage {
    /// In-memory cache of prompt definitions
    prompts: HashMap<String, PromptDefinition>,
    /// In-memory cache of facts
    facts: HashMap<String, PromptFact>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptDefinition {
    pub id: String,
    pub name: String,
    pub content: String,
    pub template_type: String,
    pub metadata: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PromptFact {
    pub id: String,
    pub fact_type: String,
    pub content: String,
    pub metadata: HashMap<String, String>,
}

impl SmartStorage {
    /// Create new smart storage
    pub fn new() -> Self {
        Self {
            prompts: HashMap::new(),
            facts: HashMap::new(),
        }
    }

    /// Store prompt definition in memory
    pub fn store_prompt(&mut self, prompt: PromptDefinition) -> Result<()> {
        self.prompts.insert(prompt.id.clone(), prompt);
        Ok(())
    }

    /// Store fact in memory
    pub fn store_fact(&mut self, fact: PromptFact) -> Result<()> {
        self.facts.insert(fact.id.clone(), fact);
        Ok(())
    }

    /// Get prompt by ID
    pub fn get_prompt(&self, id: &str) -> Option<&PromptDefinition> {
        self.prompts.get(id)
    }

    /// Get fact by ID
    pub fn get_fact(&self, id: &str) -> Option<&PromptFact> {
        self.facts.get(id)
    }

    /// Get all prompts
    pub fn get_all_prompts(&self) -> Vec<&PromptDefinition> {
        self.prompts.values().collect()
    }

    /// Get all facts
    pub fn get_all_facts(&self) -> Vec<&PromptFact> {
        self.facts.values().collect()
    }

    /// Search prompts by name
    pub fn search_prompts(&self, query: &str) -> Vec<&PromptDefinition> {
        self.prompts.values()
            .filter(|p| p.name.contains(query) || p.content.contains(query))
            .collect()
    }

    /// Get statistics
    pub fn get_stats(&self) -> SmartStorageStats {
        SmartStorageStats {
            prompt_count: self.prompts.len(),
            fact_count: self.facts.len(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct SmartStorageStats {
    pub prompt_count: usize,
    pub fact_count: usize,
}

impl Default for SmartStorage {
    fn default() -> Self {
        Self::new()
    }
}

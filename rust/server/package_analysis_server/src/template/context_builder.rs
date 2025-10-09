//! Context Builder for assembling rich SPARC prompts
//!
//! Combines:
//! - Base templates (from files)
//! - Composable bits (from files)
//! - Code snippets (from database)
//! - Best practices (from database)
//! - Framework docs (from database)

use super::{Template, TemplateLoader};
use crate::detection::DetectionResult;
use anyhow::{Context, Result};
use std::path::PathBuf;

/// Rich context for prompt generation
#[derive(Debug, Clone)]
pub struct PromptContext {
    /// Base template
    pub template: Template,

    /// Composed bits content
    pub bits: Vec<String>,

    /// Code snippets from database
    pub snippets: Vec<CodeSnippet>,

    /// Best practices from database
    pub patterns: Vec<BestPractice>,

    /// Framework documentation
    pub framework_docs: Option<String>,

    /// Final assembled prompt
    pub assembled_prompt: String,
}

/// Code snippet from database
#[derive(Debug, Clone)]
pub struct CodeSnippet {
    pub code: String,
    pub explanation: Option<String>,
    pub language: String,
    pub tags: Vec<String>,
    pub quality_score: f64,
}

/// Best practice pattern from database
#[derive(Debug, Clone)]
pub struct BestPractice {
    pub title: String,
    pub description: String,
    pub code_example: Option<String>,
    pub pattern_type: String,
    pub quality_score: f64,
}

/// Context builder for assembling complete prompts
pub struct ContextBuilder {
    /// Template loader
    loader: TemplateLoader,

    /// Framework name
    framework: Option<String>,

    /// Framework version
    version: Option<String>,

    /// SPARC phase
    sparc_phase: Option<String>,

    /// Template path
    template_path: Option<String>,

    /// Additional bits to compose
    extra_bits: Vec<String>,

    /// Snippet categories to load
    snippet_categories: Vec<String>,

    /// Pattern types to load
    pattern_types: Vec<String>,

    /// Max snippets to load
    max_snippets: usize,

    /// Max patterns to load
    max_patterns: usize,

    /// Include framework docs
    include_docs: bool,
}

impl ContextBuilder {
    /// Create new context builder
    pub fn new(templates_dir: impl Into<PathBuf>) -> Self {
        Self {
            loader: TemplateLoader::new(templates_dir),
            framework: None,
            version: None,
            sparc_phase: None,
            template_path: None,
            extra_bits: Vec::new(),
            snippet_categories: Vec::new(),
            pattern_types: Vec::new(),
            max_snippets: 5,
            max_patterns: 10,
            include_docs: false,
        }
    }

    /// Set framework and version
    pub fn for_framework(mut self, framework: &str, version: &str) -> Self {
        self.framework = Some(framework.to_string());
        self.version = Some(version.to_string());
        self
    }

    /// Set SPARC phase
    pub fn for_sparc_phase(mut self, phase: &str) -> Self {
        self.sparc_phase = Some(phase.to_string());

        // Auto-add relevant bits based on phase
        match phase {
            "security" => {
                self.extra_bits.push("bits/security/oauth2.md".to_string());
                self.extra_bits.push("bits/security/input-validation.md".to_string());
                self.pattern_types.push("security".to_string());
            }
            "performance" => {
                self.extra_bits.push("bits/performance/async-optimization.md".to_string());
                self.extra_bits.push("bits/performance/caching.md".to_string());
                self.pattern_types.push("performance".to_string());
            }
            "implementation" => {
                self.extra_bits.push("bits/testing/pytest-async.md".to_string());
                self.snippet_categories.push("crud".to_string());
                self.snippet_categories.push("auth".to_string());
                self.pattern_types.push("best_practice".to_string());
            }
            _ => {}
        }

        self
    }

    /// Load specific template
    pub fn load_template(mut self, template_path: &str) -> Self {
        self.template_path = Some(template_path.to_string());
        self
    }

    /// Add extra composable bits
    pub fn add_bits(mut self, bits: Vec<&str>) -> Self {
        self.extra_bits.extend(bits.iter().map(|s| s.to_string()));
        self
    }

    /// Add snippet categories to load
    pub fn add_snippet_categories(mut self, categories: Vec<&str>) -> Self {
        self.snippet_categories.extend(categories.iter().map(|s| s.to_string()));
        self
    }

    /// Add pattern types to load
    pub fn add_pattern_types(mut self, types: Vec<&str>) -> Self {
        self.pattern_types.extend(types.iter().map(|s| s.to_string()));
        self
    }

    /// Set max snippets to load
    pub fn max_snippets(mut self, max: usize) -> Self {
        self.max_snippets = max;
        self
    }

    /// Set max patterns to load
    pub fn max_patterns(mut self, max: usize) -> Self {
        self.max_patterns = max;
        self
    }

    /// Include framework documentation
    pub fn with_framework_docs(mut self) -> Self {
        self.include_docs = true;
        self
    }

    /// Build the complete context
    pub fn build(mut self) -> Result<PromptContext> {
        // 1. Load base template
        let template_path = self.template_path
            .context("Template path not set")?;

        let mut template = self.loader.load(&template_path)?;

        // 2. Load bits (already handled by TemplateLoader.compose)
        let bits = if let Some(ref compose) = template.compose {
            self.loader.load_bits(compose)?
        } else {
            Vec::new()
        };

        // 3. Load snippets from database
        let snippets = if self.framework.is_some() && !self.snippet_categories.is_empty() {
            self.load_snippets_from_db()?
        } else {
            Vec::new()
        };

        // 4. Load patterns from database
        let patterns = if self.framework.is_some() && !self.pattern_types.is_empty() {
            self.load_patterns_from_db()?
        } else {
            Vec::new()
        };

        // 5. Load framework docs
        let framework_docs = if self.include_docs && self.framework.is_some() {
            Some(self.load_framework_docs()?)
        } else {
            None
        };

        // 6. Assemble final prompt
        let assembled_prompt = self.assemble_prompt(
            &template,
            &bits,
            &snippets,
            &patterns,
            framework_docs.as_deref(),
        )?;

        Ok(PromptContext {
            template,
            bits,
            snippets,
            patterns,
            framework_docs,
            assembled_prompt,
        })
    }

    /// Load snippets from database (TODO: implement actual DB query)
    fn load_snippets_from_db(&self) -> Result<Vec<CodeSnippet>> {
        // TODO: Query tool_examples table
        // For now, return empty vec
        //
        // Example query:
        // SELECT te.code, te.explanation, te.language, te.tags
        // FROM tool_examples te
        // JOIN tools t ON te.tool_id = t.id
        // WHERE t.tool_name = $framework
        //   AND $category = ANY(te.tags)
        // ORDER BY te.quality_score DESC
        // LIMIT $max_snippets

        Ok(Vec::new())
    }

    /// Load patterns from database (TODO: implement actual DB query)
    fn load_patterns_from_db(&self) -> Result<Vec<BestPractice>> {
        // TODO: Query tool_patterns table
        // For now, return empty vec
        //
        // Example query:
        // SELECT tp.title, tp.description, tp.code_example, tp.pattern_type
        // FROM tool_patterns tp
        // JOIN tools t ON tp.tool_id = t.id
        // WHERE t.tool_name = $framework
        //   AND tp.pattern_type = ANY($pattern_types)
        // ORDER BY similarity DESC
        // LIMIT $max_patterns

        Ok(Vec::new())
    }

    /// Load framework documentation (TODO: implement)
    fn load_framework_docs(&self) -> Result<String> {
        // TODO: Query tools table for documentation
        // For now, return placeholder
        Ok(String::new())
    }

    /// Assemble final prompt from all components
    fn assemble_prompt(
        &self,
        template: &Template,
        bits: &[String],
        snippets: &[CodeSnippet],
        patterns: &[BestPractice],
        framework_docs: Option<&str>,
    ) -> Result<String> {
        let mut prompt = String::new();

        // Header
        prompt.push_str(&format!("# {} - {}\n\n",
            self.sparc_phase.as_deref().unwrap_or("Code Generation"),
            template.name
        ));

        // Framework context
        if let Some(ref framework) = self.framework {
            prompt.push_str(&format!("**Framework:** {} {}\n\n",
                framework,
                self.version.as_deref().unwrap_or("latest")
            ));
        }

        // Composable bits
        if !bits.is_empty() {
            prompt.push_str("## Reusable Patterns\n\n");
            for bit in bits {
                prompt.push_str(bit);
                prompt.push_str("\n\n---\n\n");
            }
        }

        // Code snippets from database
        if !snippets.is_empty() {
            prompt.push_str("## Proven Code Examples\n\n");
            for (i, snippet) in snippets.iter().enumerate() {
                prompt.push_str(&format!("### Example {} (Quality: {:.2})\n\n", i + 1, snippet.quality_score));
                prompt.push_str(&format!("```{}\n{}\n```\n\n", snippet.language, snippet.code));
                if let Some(ref explanation) = snippet.explanation {
                    prompt.push_str(&format!("*{}*\n\n", explanation));
                }
            }
            prompt.push_str("---\n\n");
        }

        // Best practices from database
        if !patterns.is_empty() {
            prompt.push_str("## Best Practices\n\n");
            for pattern in patterns {
                prompt.push_str(&format!("### {}\n\n", pattern.title));
                prompt.push_str(&format!("{}\n\n", pattern.description));
                if let Some(ref code) = pattern.code_example {
                    prompt.push_str(&format!("```\n{}\n```\n\n", code));
                }
            }
            prompt.push_str("---\n\n");
        }

        // Framework documentation
        if let Some(docs) = framework_docs {
            prompt.push_str("## Framework Documentation\n\n");
            prompt.push_str(docs);
            prompt.push_str("\n\n---\n\n");
        }

        // Base template content
        if let Some(ref content) = template.template_content {
            prompt.push_str("## Task\n\n");
            prompt.push_str(content);
        }

        Ok(prompt)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_context_builder_creation() {
        let builder = ContextBuilder::new("templates");
        assert_eq!(builder.max_snippets, 5);
        assert_eq!(builder.max_patterns, 10);
    }

    #[test]
    fn test_sparc_phase_auto_bits() {
        let builder = ContextBuilder::new("templates")
            .for_sparc_phase("security");

        assert!(builder.extra_bits.contains(&"bits/security/oauth2.md".to_string()));
    }
}
